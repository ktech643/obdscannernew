import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/models/enums.dart';

import 'support.dart';

/// The trips directory, except that the header write fails the way a full
/// disk fails it: part of the header lands, then ENOSPC.
class _HeaderWriteFails extends TripFiles {
  _HeaderWriteFails(super.root);

  @override
  Future<File> create(String sessionId) async =>
      _HalfWrites(await super.create(sessionId));
}

class _HalfWrites implements File {
  _HalfWrites(this._real);
  final File _real;

  @override
  String get path => _real.path;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await _real.writeAsString(contents.substring(0, contents.length ~/ 2));
    throw FileSystemException(
      'write failed',
      path,
      const OSError('No space left on device', 28),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

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

  const day = Duration(days: 1);

  TripFileSummary summarize(TripSessionRow s, {DateTime? now}) =>
      TripCsv.summarizeFileSync(
        repo.fileOf(s).path,
        startedAtMs: s.startedAt.millisecondsSinceEpoch,
        nowMs: (now ?? s.startedAt.add(day)).millisecondsSinceEpoch,
      );

  /// A trip as the recorder leaves it: started, [seconds] of 36 km/h
  /// written with its anchors (none at all when 0), then — unless [finish]
  /// is false — ended with [end] and summarised from its file.
  Future<TripSessionRow> trip({
    required DateTime started,
    int seconds = 0,
    DateTime? opened,
    bool finish = true,
    TripEnd end = TripEnd.stopped,
    String? vehicleId,
  }) async {
    final s = await repo.start(vehicleId: vehicleId ?? vid, now: started);
    if (seconds > 0) {
      await repo
          .fileOf(s)
          .writeAsString(driveCsv(started, toMs: seconds * 1000));
    }
    if (finish) await repo.finish(s.id, end: end, summary: summarize(s));
    if (opened != null) await repo.touch(s.id, now: opened);
    return (await repo.byId(s.id))!;
  }

  test('start writes the header; finish writes the file\'s figures', () async {
    final s = await repo.start(vehicleId: vid, now: at(0));
    final f = repo.fileOf(s);
    expect(await f.readAsString(), TripCsv.header);
    expect(s.samplesFilePath, 'trips/${s.id}.csv');
    expect(s.endedAt, isNull);
    expect(s.fileBytes, TripCsv.header.length);
    expect(await repo.openTrip(), s);

    // 850 rpm at idle, then 36 km/h for 10 s.
    await f.writeAsString(
      '${TripCsv.segment(0, at(0))}1,010C,850.0\n'
      '${[for (var t = 1000; t <= 11000; t += 1000) TripCsv.row(t, '010D', 36)].join()}',
      mode: FileMode.append,
    );
    final done = await repo.finish(
      s.id,
      end: TripEnd.stopped,
      summary: summarize(s),
    );
    expect(done!.fileBytes, await f.length());
    expect(done.endedAt, at(0).add(const Duration(seconds: 11)));
    expect(done.recordedMs, 11000);
    expect(done.sampleCount, 12);
    expect(done.distanceKm, closeTo(0.1, 1e-12));
    expect(done.avgSpeedKph, closeTo(36, 1e-9));
    expect(done.maxSpeedKph, 36);
    expect(done.fuelUsedL, isNull, reason: 'the car sent no fuel rate');
    expect(done.interrupted, isFalse);
    expect(done.endReason, TripEnd.stopped);
    expect(await repo.openTrip(), isNull);

    // A row that is gone is not finished into being.
    final summary = summarize(s);
    await repo.delete(s.id);
    expect(
      await repo.finish(s.id, end: TripEnd.stopped, summary: summary),
      isNull,
    );
  });

  test('★ a start that cannot insert its row leaves no file behind', () async {
    // The vehicle vanished between opening the recorder and tapping start.
    await expectLater(
      repo.start(vehicleId: 'gone', now: at(0)),
      throwsA(anything),
    );
    expect(await repo.files.listAll(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  });

  test('★ a failed start leaves neither row nor file', () async {
    // The disk fills while the header is being written: the file exists
    // with half a header. Left behind, it is an orphan until the next
    // launch, and a later start might have reused nothing but its space.
    final failing = TripRepository(db, _HeaderWriteFails(dir));
    await expectLater(
      failing.start(vehicleId: vid, now: at(0)),
      throwsA(isA<FileSystemException>()),
    );
    expect(await repo.files.listAll(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  });

  test('★ at most one open trip', () async {
    final first = await repo.start(vehicleId: vid, now: at(0));
    final van = await VehicleRepository(db)
        .create(nickname: 'Van', fuel: VehicleFuel.diesel);

    // Through the repository: refused before anything is written, for any
    // car.
    await expectLater(repo.start(vehicleId: vid, now: at(1)), throwsStateError);
    await expectLater(
      repo.start(vehicleId: van.id, now: at(1)),
      throwsStateError,
    );
    expect((await repo.files.listAll()).keys, [first.samplesFilePath]);
    expect(await db.select(db.tripSessions).get(), [first]);

    // Below Dart: the index refuses a second open row outright.
    const other = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    await expectLater(
      db
          .into(db.tripSessions)
          .insert(
            TripSessionsCompanion.insert(
              id: other,
              vehicleId: van.id,
              startedAt: at(2),
              lastOpenedAt: at(2),
              samplesFilePath: TripFiles.pathForId(other),
            ),
          ),
      throwsA(predicate((e) => '$e'.contains('idx_trip_one_open'))),
    );
    // A closed one is fine.
    await db
        .into(db.tripSessions)
        .insert(
          TripSessionsCompanion.insert(
            id: other,
            vehicleId: van.id,
            startedAt: at(2),
            endedAt: Value(at(3)),
            lastOpenedAt: at(2),
            samplesFilePath: TripFiles.pathForId(other),
          ),
        );
  });

  test('delete removes the row and the file together', () async {
    final s = await trip(started: at(0), seconds: 10);
    final f = repo.fileOf(s);
    expect(await f.exists(), isTrue);
    expect(await repo.delete(s.id), isTrue);
    expect(await f.exists(), isFalse);
    expect(await repo.byId(s.id), isNull);
    expect(await repo.delete(s.id), isFalse, reason: 'nothing left to go');
  });

  test('delete tolerates a file that is already gone', () async {
    final s = await trip(started: at(0));
    await repo.fileOf(s).delete();
    expect(await repo.delete(s.id), isTrue);
    expect(await repo.byId(s.id), isNull);
  });

  test(
    '★ delete refuses the trip being recorded; deleteAllFor does not',
    () async {
      // The recorder holds the open trip's file and will finish its row:
      // deleting it from the Garage list would leave it finishing nothing.
      final done = await trip(started: at(0), seconds: 5);
      final live = await trip(started: at(10), seconds: 5, finish: false);
      expect(await repo.delete(live.id), isFalse);
      expect(await repo.byId(live.id), isNotNull);
      expect(await repo.fileOf(live).exists(), isTrue);
      expect(await repo.delete(done.id), isTrue);

      // A vehicle delete takes the car's trips with it — the one recording
      // too, once the recorder has let go of it.
      await repo.deleteAllFor(vid);
      expect(await repo.recent(vid), isEmpty);
      expect(await repo.files.listAll(), isEmpty);
    },
  );

  group('★ closeInterrupted — the launch pass, from the file', () {
    test('★ closeInterrupted ends a trip at its last durable sample, with its '
        'figures', () async {
      // Killed at 18:00 after 90 s of driving, mid-write; found at 08:00.
      final s = await trip(started: at(0), finish: false);
      const torn = '91000,010D,3';
      final durable = driveCsv(at(0), toMs: 90000);
      await repo.fileOf(s).writeAsString('$durable$torn');

      final closed = await repo.closeInterrupted(
        now: at(0).add(const Duration(hours: 14)),
      );
      expect(closed.map((r) => r.id), [s.id]);
      final r = (await repo.byId(s.id))!;
      expect(
        r.endedAt,
        at(0).add(const Duration(seconds: 90)),
        reason: 'the last row by its anchor — not the relaunch 14 h on',
      );
      expect(r.recordedMs, 90000);
      expect(r.sampleCount, 91);
      expect(r.distanceKm, closeTo(0.9, 1e-12));
      expect(r.avgSpeedKph, closeTo(36, 1e-9));
      expect(r.maxSpeedKph, 36);
      expect(r.endReason, TripEnd.appKilled);
      expect(r.interrupted, isTrue);
      // The torn row is cut off, so a Resume appends after a whole line.
      expect(await repo.fileOf(s).readAsString(), durable);
      expect(r.fileBytes, durable.length);
      expect(await repo.openTrip(), isNull);
    });

    test('★ a file that says it ended is not interrupted', () async {
      // The recorder wrote '#end' and closed the file; the app died before
      // the row was written. The file's word stands.
      final s = await trip(started: at(0), finish: false);
      await repo
          .fileOf(s)
          .writeAsString(
            '${driveCsv(at(0), toMs: 30000)}'
            '${TripCsv.end(30000, at(0).add(const Duration(seconds: 30)), TripEnd.stopped)}',
          );
      await repo.closeInterrupted(now: at(60));
      final r = (await repo.byId(s.id))!;
      expect(r.endReason, TripEnd.stopped);
      expect(r.interrupted, isFalse);
      expect(r.endedAt, at(0).add(const Duration(seconds: 30)));
    });

    test('an open trip with no file, or a header only, goes', () async {
      // Nothing was recorded: there is no trip to show.
      final empty = await trip(started: at(0), finish: false);
      expect(await repo.closeInterrupted(now: at(5)), isEmpty);
      expect(await repo.byId(empty.id), isNull);
      expect(await repo.files.listAll(), isEmpty);

      final gone = await trip(started: at(10), seconds: 5, finish: false);
      await repo.fileOf(gone).delete();
      expect(await repo.closeInterrupted(now: at(15)), isEmpty);
      expect(await repo.byId(gone.id), isNull);
    });
  });

  test(
    '★ reopen only an appKilled or linkLost trip, only when none is open',
    () async {
      final stopped = await trip(started: at(0), seconds: 5);
      final capped = await trip(
        started: at(10),
        seconds: 5,
        end: TripEnd.freeCap,
      );
      final lost = await trip(
        started: at(20),
        seconds: 5,
        end: TripEnd.linkLost,
      );
      final killed = await trip(
        started: at(30),
        seconds: 5,
        end: TripEnd.appKilled,
      );
      expect(await repo.reopen(stopped.id, now: at(40)), isNull);
      expect(await repo.reopen(capped.id, now: at(40)), isNull);
      expect((await repo.byId(stopped.id))!.endedAt, isNotNull);

      final r = await repo.reopen(lost.id, now: at(40));
      expect(r!.id, lost.id);
      expect(r.endedAt, isNull);
      expect(r.interrupted, isFalse);
      expect(r.endReason, isNull);
      expect(r.lastOpenedAt, at(40));
      expect(r.startedAt, lost.startedAt, reason: 'the same trip goes on');

      // One is open now: the other resumable trip must wait.
      expect(await repo.reopen(killed.id, now: at(41)), isNull);
      expect((await repo.byId(killed.id))!.endReason, TripEnd.appKilled);
    },
  );

  test('★ resumable', () async {
    // "Resume trip?" (§9.2) offers the car's newest trip, ended by a kill
    // or a lost link, within 30 minutes, with its file. Each exclusion is
    // checked on its own.
    final now = at(1000);
    const within = Duration(minutes: 30);
    Future<TripSessionRow?> offer([String? vehicleId]) =>
        repo.resumable(vehicleId ?? vid, now: now, within: within);
    Future<void> clear() async {
      for (final v in await VehicleRepository(db).all()) {
        await repo.deleteAllFor(v.id);
      }
    }

    /// A 60 s trip that ended [ago] before now.
    Future<TripSessionRow> endedAgo(
      Duration ago, {
      TripEnd end = TripEnd.linkLost,
      String? vehicleId,
    }) => trip(
      started: now.subtract(ago).subtract(const Duration(minutes: 1)),
      seconds: 60,
      end: end,
      vehicleId: vehicleId,
    );

    // Offered: a lost link, and a kill, ten minutes ago.
    final lost = await endedAgo(const Duration(minutes: 10));
    expect((await offer())?.id, lost.id);
    await clear();
    final killed = await endedAgo(
      const Duration(minutes: 10),
      end: TripEnd.appKilled,
    );
    expect((await offer())?.id, killed.id);
    await clear();

    await endedAgo(const Duration(minutes: 10), end: TripEnd.stopped);
    expect(await offer(), isNull, reason: 'a clean stop');
    await clear();

    await endedAgo(const Duration(minutes: 10), end: TripEnd.freeCap);
    expect(await offer(), isNull, reason: 'the free plan ended it');
    await clear();

    final van = await VehicleRepository(db)
        .create(nickname: 'Van', fuel: VehicleFuel.diesel);
    final vans = await endedAgo(const Duration(minutes: 10), vehicleId: van.id);
    expect(await offer(), isNull, reason: 'another car\'s trip');
    expect((await offer(van.id))?.id, vans.id);
    await clear();

    await endedAgo(const Duration(minutes: 31));
    expect(await offer(), isNull, reason: '31 minutes old');
    await clear();

    await endedAgo(const Duration(minutes: -5));
    expect(await offer(), isNull, reason: 'ended in the future');
    await clear();

    final noFile = await endedAgo(const Duration(minutes: 10));
    await repo.fileOf(noFile).delete();
    expect(await offer(), isNull, reason: 'its file is gone');
    await clear();

    await endedAgo(const Duration(minutes: 20));
    await endedAgo(const Duration(minutes: 5), end: TripEnd.stopped);
    expect(await offer(), isNull, reason: 'not the newest');
  });

  group('★ retention — SPEC Part 6', () {
    test('trips older than 30 days go', () async {
      final now = at(0);
      final old = await trip(started: now.subtract(const Duration(days: 31)));
      final fresh = await trip(started: now.subtract(const Duration(days: 29)));
      final removed = await repo.enforceRetention(now: now);
      expect(removed, [old.id]);
      expect((await repo.recent(vid)).map((r) => r.id), [fresh.id]);
      expect(await repo.fileOf(old).exists(), isFalse);
    });

    test('over the byte cap, the least recently opened goes first', () async {
      final now = at(0);
      // Three trips of one size; a cap of two and a half → one must go.
      // The oldest *started* was opened most recently, so it stays; the
      // middle one goes.
      final a = await trip(started: at(-30), seconds: 10, opened: at(-1));
      final b = await trip(started: at(-20), seconds: 10, opened: at(-10));
      final c = await trip(started: at(-10), seconds: 10, opened: at(-5));
      expect(a.fileBytes, greaterThan(TripCsv.header.length));
      expect({b.fileBytes, c.fileBytes}, {a.fileBytes});
      final removed = await repo.enforceRetention(
        now: now,
        maxBytes: a.fileBytes * 5 ~/ 2,
      );
      expect(removed, [b.id]);
      expect((await repo.recent(vid)).map((r) => r.id).toSet(), {a.id, c.id});
    });

    test('a trip still recording is never reclaimed', () async {
      final now = at(0);
      final live = await trip(
        started: now.subtract(const Duration(days: 40)),
        seconds: 100,
        finish: false,
      );
      expect(live.fileBytes, TripCsv.header.length, reason: 'until finish');
      final removed = await repo.enforceRetention(now: now, maxBytes: 10);
      expect(removed, isEmpty);
      expect(await repo.byId(live.id), isNotNull);
    });

    test('totalBytes is what the files hold', () async {
      final a = await trip(started: at(0), seconds: 10);
      final b = await trip(started: at(1), seconds: 5);
      expect(
        await repo.totalBytes(),
        await repo.fileOf(a).length() + await repo.fileOf(b).length(),
      );
      expect(await repo.totalBytes(), greaterThan(2 * TripCsv.header.length));
    });
  });

  group('★ paths — a stored path is data', () {
    test('only trips/<id>.csv is ever resolved', () {
      const id = '0123456789abcdef0123456789abcdef';
      expect(TripFiles.isSafe('trips/$id.csv'), isTrue);
      expect(TripFiles.isSafe(TripFiles.pathForId(id)), isTrue);
      // The database, its journal, attachments, siblings, escapes.
      for (final bad in [
        'torque_obd2.sqlite',
        'torque_obd2.sqlite-wal',
        'photos/golf.jpg',
        'attachments/receipt.pdf',
        'trips/../torque_obd2.sqlite',
        '../../etc/passwd',
        '/etc/passwd',
        r'C:\x.csv',
        'trips/x.csv',
        'trips/$id.CSV',
        'trips/$id.csv/',
        'trips/${id}0.csv',
        '',
      ]) {
        expect(TripFiles.isSafe(bad), isFalse, reason: bad);
      }
      expect(() => repo.files.resolve('../x'), throwsArgumentError);
    });

    test(
      'a hostile row that somehow exists is deleted without touching disk',
      () async {
        final victim = File('${dir.path}/victim.txt');
        await victim.writeAsString('keep me');
        await db
            .into(db.tripSessions)
            .insert(
              TripSessionsCompanion.insert(
                id: 'evil',
                vehicleId: vid,
                startedAt: at(0),
                endedAt: Value(at(1)),
                lastOpenedAt: at(0),
                samplesFilePath: '../victim.txt',
              ),
            );
        expect(await repo.delete('evil'), isTrue);
        expect(await victim.exists(), isTrue);
        expect(await repo.byId('evil'), isNull);
      },
    );

    test('an open hostile row is closed away without touching disk', () async {
      final victim = File('${dir.path}/victim.txt');
      await victim.writeAsString('keep me');
      await db
          .into(db.tripSessions)
          .insert(
            TripSessionsCompanion.insert(
              id: 'evil',
              vehicleId: vid,
              startedAt: at(0),
              lastOpenedAt: at(0),
              samplesFilePath: '../victim.txt',
            ),
          );
      expect(await repo.closeInterrupted(now: at(5)), isEmpty);
      expect(await victim.readAsString(), 'keep me');
      expect(await repo.byId('evil'), isNull);
    });
  });

  group('★ files and rows agree', () {
    test(
      'reconcileFiles removes orphan files and zeroes phantom rows',
      () async {
        final kept = await trip(started: at(0), seconds: 10);
        final orphaned = await trip(started: at(1), seconds: 10);
        final phantom = await trip(started: at(2), seconds: 10);

        // A row-only delete (what a wipe or a cascade does) orphans the file;
        // a missing file (a restore onto a new device) leaves a phantom row.
        await db.wipe();
        final v2 = await golf(db);
        await repo.fileOf(phantom).delete();
        // Re-create only `kept` and `phantom` rows under the new vehicle.
        for (final r in [kept, phantom]) {
          await db
              .into(db.tripSessions)
              .insert(r.toCompanion(false).copyWith(vehicleId: Value(v2.id)));
        }

        final result = await repo.reconcileFiles();
        expect(result.orphanFiles, 1);
        expect(result.missingFiles, 1);
        expect(await repo.fileOf(orphaned).exists(), isFalse);
        expect(await repo.fileOf(kept).exists(), isTrue);
        expect((await repo.byId(phantom.id))!.fileBytes, 0);
        expect((await repo.byId(kept.id))!.fileBytes, kept.fileBytes);
      },
    );

    test('deleteAllFiles is the file half of "Delete all data"', () async {
      await trip(started: at(0), seconds: 1);
      await trip(started: at(1), seconds: 1);
      await repo.deleteAllFiles();
      await db.wipe();
      expect(await repo.files.listAll(), isEmpty);
      expect(await repo.totalBytes(), 0);
    });

    test(
      'deleteAllFor clears the files the vehicle cascade cannot reach',
      () async {
        final s1 = await trip(started: at(0), seconds: 1);
        final s2 = await trip(started: at(1), seconds: 1);
        await repo.deleteAllFor(vid);
        await VehicleRepository(db).delete(vid);
        expect(await repo.fileOf(s1).exists(), isFalse);
        expect(await repo.fileOf(s2).exists(), isFalse);
        expect(await repo.files.listAll(), isEmpty);
      },
    );
  });
}
