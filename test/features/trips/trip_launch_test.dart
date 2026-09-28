import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/ids.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/features/trips/trip_launch.dart';

import '../../data/support.dart';
import 'support.dart';

/// §9.2 / §6.1 / Part 6 — the launch pass `main()` starts before anything
/// can record: take down a stale "Recording trip" notification, close what
/// a killed run left open from its own file, delete files no row owns,
/// then reclaim by age and size. Real drift, real files, plain `test()`.
void main() {
  late AppDatabase db;
  late Directory dir;
  late TripRepository repo;
  late String vid;
  setUp(() async {
    db = memoryDb();
    dir = await scratchDir();
    repo = TripRepository(db, TripFiles(dir));
    vid = (await golf(db)).id;
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  /// A trip the recorder was writing when the app died: its row still
  /// open, its file holding [seconds] of 36 km/h with the anchors a
  /// recorder writes.
  Future<TripSessionRow> killedTrip(
    DateTime started, {
    int seconds = 60,
  }) async {
    final s = await repo.start(vehicleId: vid, now: started);
    await repo.fileOf(s).writeAsString(driveCsv(started, toMs: seconds * 1000));
    return s;
  }

  /// A trip that ended normally and was saved from its file.
  Future<TripSessionRow> savedTrip(DateTime started) async {
    final s = await killedTrip(started, seconds: 10);
    final f = repo.fileOf(s);
    final summary = TripCsv.summarizeFileSync(
      f.path,
      startedAtMs: started.millisecondsSinceEpoch,
      nowMs: started.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    return (await repo.finish(s.id, end: TripEnd.stopped, summary: summary))!;
  }

  /// A CSV no row owns — what the build before this one left when the
  /// disk filled mid-header: the file made, half its header written, the
  /// row rolled back.
  Future<File> orphanCsv() async {
    final f = await repo.files.create(newId());
    await f.writeAsString(TripCsv.header.substring(0, 9));
    return f;
  }

  test('★ close before retention', () async {
    // A trip killed a month ago; Torque was not opened again until today.
    // Retention skips a trip that is still recording (endedAt IS NULL), so
    // run before the close it passes this one over, and the pass ends
    // with a month-old trip kept past Part 6's 30 days.
    final now = at(0);
    final started = now.subtract(const Duration(days: 31));
    final crashed = await killedTrip(started);
    final orphan = await orphanCsv();
    // A hot restart, or an engine that crashed, left the service's
    // "Recording trip" notification up with no recorder behind it.
    final bg = FakeBackgroundService()..running = true;

    final report = await runTripLaunchPass(repo, background: bg, now: now);

    expect(bg.calls, contains('stopRecording'));
    expect(bg.running, isFalse, reason: 'a stale service is taken down');
    expect(report.fgsStopped, isTrue);

    // Closed from its own file, a month ago, at its last row...
    expect(report.closed.map((r) => r.id), [crashed.id]);
    final closed = report.closed.single;
    expect(closed.endReason, TripEnd.appKilled);
    expect(closed.endedAt, started.add(const Duration(seconds: 60)));
    // ...and then, in the same pass, reclaimed: it is 31 days old.
    expect(report.removed, [crashed.id]);
    expect(await repo.byId(crashed.id), isNull);
    expect(await db.select(db.tripSessions).get(), isEmpty);

    // The orphan went too: no file is left that nothing can find.
    expect(report.orphanFiles, 1);
    expect(await orphan.exists(), isFalse);
    expect(await repo.files.listAll(), isEmpty);
  });

  test('one unreadable file does not stop reconcile or retention', () async {
    // The file of the trip the app died recording cannot be read this
    // launch (an I/O error, a file the OS will not hand back). The pass
    // must still finish: a stale file is deleted, an old trip reclaimed.
    final now = at(0);
    final old = await savedTrip(now.subtract(const Duration(days: 31)));
    final unreadable = await killedTrip(now.subtract(const Duration(hours: 2)));
    final unreadablePath = repo.fileOf(unreadable).path;
    final content = await repo.fileOf(unreadable).readAsString();
    final orphan = await orphanCsv();

    // Fails the way Isolate.run hands back the reader's error: as a
    // failed future, for this one path.
    Future<TripFileSummary> summarize(
      String path, {
      required int startedAtMs,
      required int nowMs,
    }) async {
      if (path == unreadablePath) {
        throw FileSystemException(
          'Cannot open file',
          path,
          const OSError('Input/output error', 5),
        );
      }
      return summarizeTripFile(path, startedAtMs: startedAtMs, nowMs: nowMs);
    }

    final report = await runTripLaunchPass(
      repo,
      background: FakeBackgroundService(),
      now: now,
      summarize: summarize,
    );

    expect(report.closed, isEmpty, reason: 'nothing could be read');
    // Reconcile ran...
    expect(report.orphanFiles, 1);
    expect(await orphan.exists(), isFalse);
    // ...and retention ran.
    expect(report.removed, [old.id]);
    expect(await repo.byId(old.id), isNull);
    // What could not be read is not destroyed: the row and every byte of
    // its file are still there for a later launch to read.
    expect(await repo.byId(unreadable.id), isNotNull);
    expect(await repo.fileOf(unreadable).readAsString(), content);
    expect((await repo.files.listAll()).keys, [unreadable.samplesFilePath]);
  });
}
