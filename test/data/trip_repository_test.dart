import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';

import 'support.dart';

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

  Future<TripSessionRow> trip({
    required DateTime started,
    int bodyBytes = 0,
    DateTime? opened,
    bool finish = true,
  }) async {
    final s = await repo.start(vehicleId: vid, now: started);
    final f = repo.files.resolve(s.samplesFilePath);
    if (bodyBytes > 0) {
      await f.writeAsString('x' * bodyBytes, mode: FileMode.append);
    }
    if (finish) {
      await repo.finish(s.id, now: started.add(const Duration(minutes: 5)));
    }
    if (opened != null) await repo.touch(s.id, now: opened);
    return (await repo.byId(s.id))!;
  }

  test(
    'start writes the file with its header; finish records the bytes',
    () async {
      final s = await repo.start(vehicleId: vid, now: at(0));
      final f = repo.files.resolve(s.samplesFilePath);
      expect(await f.readAsString(), 'ts_ms,pid,value\n');
      expect(s.samplesFilePath, 'trips/${s.id}.csv');
      expect(s.endedAt, isNull);

      await f.writeAsString('1,0C,850\n', mode: FileMode.append);
      await repo.finish(s.id, distanceKm: 12.4, sampleCount: 1, now: at(18));
      final done = (await repo.byId(s.id))!;
      expect(done.fileBytes, utf8.encode('ts_ms,pid,value\n1,0C,850\n').length);
      expect(done.endedAt, at(18));
      expect(done.distanceKm, 12.4);
      expect(done.interrupted, isFalse);
    },
  );

  test('★ a start that cannot insert its row leaves no file behind', () async {
    // The vehicle vanished between opening the recorder and tapping start.
    await expectLater(
      repo.start(vehicleId: 'gone', now: at(0)),
      throwsA(anything),
    );
    expect(await repo.files.listAll(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  });

  test('delete removes the row and the file together', () async {
    final s = await trip(started: at(0), bodyBytes: 10);
    final f = repo.files.resolve(s.samplesFilePath);
    expect(await f.exists(), isTrue);
    await repo.delete(s.id);
    expect(await f.exists(), isFalse);
    expect(await repo.byId(s.id), isNull);
  });

  test('delete tolerates a file that is already gone', () async {
    final s = await trip(started: at(0));
    await repo.files.resolve(s.samplesFilePath).delete();
    await expectLater(repo.delete(s.id), completes);
    expect(await repo.byId(s.id), isNull);
  });

  test('sessions left open on launch are closed as interrupted', () async {
    await trip(started: at(0), finish: false);
    await trip(started: at(10));
    expect(await repo.closeInterrupted(now: at(30)), 1);
    final rows = await repo.recent(vid);
    expect(rows.where((r) => r.interrupted).length, 1);
    expect(rows.every((r) => r.endedAt != null), isTrue);
  });

  group('★ retention — SPEC Part 6', () {
    test('trips older than 30 days go', () async {
      final now = at(0);
      final old = await trip(started: now.subtract(const Duration(days: 31)));
      final fresh = await trip(started: now.subtract(const Duration(days: 29)));
      final removed = await repo.enforceRetention(now: now);
      expect(removed, [old.id]);
      expect((await repo.recent(vid)).map((r) => r.id), [fresh.id]);
      expect(await repo.files.resolve(old.samplesFilePath).exists(), isFalse);
    });

    test('over the byte cap, the least recently opened goes first', () async {
      final now = at(0);
      // Three 100-byte trips; cap at 250 → one must go. The oldest *started*
      // was opened most recently, so it stays; the middle one goes.
      final a = await trip(started: at(-30), bodyBytes: 100, opened: at(-1));
      final b = await trip(started: at(-20), bodyBytes: 100, opened: at(-10));
      final c = await trip(started: at(-10), bodyBytes: 100, opened: at(-5));
      final removed = await repo.enforceRetention(
        now: now,
        maxBytes: 250 + 3 * 16,
      );
      expect(removed, [b.id]);
      expect((await repo.recent(vid)).map((r) => r.id).toSet(), {a.id, c.id});
    });

    test('a trip still recording is never reclaimed', () async {
      final now = at(0);
      final live = await trip(
        started: now.subtract(const Duration(days: 40)),
        bodyBytes: 1000,
        finish: false,
      );
      final removed = await repo.enforceRetention(now: now, maxBytes: 10);
      expect(removed, isEmpty);
      expect(await repo.byId(live.id), isNotNull);
    });

    test('totalBytes is what the files hold', () async {
      await trip(started: at(0), bodyBytes: 100);
      await trip(started: at(1), bodyBytes: 50);
      expect(await repo.totalBytes(), 150 + 2 * 16);
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
                lastOpenedAt: at(0),
                samplesFilePath: '../victim.txt',
              ),
            );
        await repo.delete('evil');
        expect(await victim.exists(), isTrue);
        expect(await repo.byId('evil'), isNull);
      },
    );
  });

  group('★ files and rows agree', () {
    test(
      'reconcileFiles removes orphan files and zeroes phantom rows',
      () async {
        final kept = await trip(started: at(0), bodyBytes: 10);
        final orphaned = await trip(started: at(1), bodyBytes: 10);
        final phantom = await trip(started: at(2), bodyBytes: 10);

        // A row-only delete (what a wipe or a cascade does) orphans the file;
        // a missing file (a restore onto a new device) leaves a phantom row.
        await db.wipe();
        final v2 = await golf(db);
        await repo.files.resolve(phantom.samplesFilePath).delete();
        // Re-create only `kept` and `phantom` rows under the new vehicle.
        for (final r in [kept, phantom]) {
          await db
              .into(db.tripSessions)
              .insert(r.toCompanion(false).copyWith(vehicleId: Value(v2.id)));
        }

        final result = await repo.reconcileFiles();
        expect(result.orphanFiles, 1);
        expect(result.missingFiles, 1);
        expect(
          await repo.files.resolve(orphaned.samplesFilePath).exists(),
          isFalse,
        );
        expect(await repo.files.resolve(kept.samplesFilePath).exists(), isTrue);
        expect((await repo.byId(phantom.id))!.fileBytes, 0);
        expect((await repo.byId(kept.id))!.fileBytes, kept.fileBytes);
      },
    );

    test('deleteAllFiles is the file half of "Delete all data"', () async {
      await trip(started: at(0), bodyBytes: 1);
      await trip(started: at(1), bodyBytes: 1);
      await repo.deleteAllFiles();
      await db.wipe();
      expect(await repo.files.listAll(), isEmpty);
      expect(await repo.totalBytes(), 0);
    });

    test(
      'deleteAllFor clears the files the vehicle cascade cannot reach',
      () async {
        final s1 = await trip(started: at(0), bodyBytes: 1);
        final s2 = await trip(started: at(1), bodyBytes: 1);
        await repo.deleteAllFor(vid);
        await VehicleRepository(db).delete(vid);
        expect(await repo.files.resolve(s1.samplesFilePath).exists(), isFalse);
        expect(await repo.files.resolve(s2.samplesFilePath).exists(), isFalse);
        expect(await repo.files.listAll(), isEmpty);
      },
    );
  });
}
