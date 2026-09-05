import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  late DtcRepository repo;
  late String vid;
  setUp(() async {
    db = memoryDb();
    repo = DtcRepository(db);
    vid = (await golf(db)).id;
  });
  tearDown(() => db.close());

  const codes = [
    RawDtc('P0301', DtcMode.stored),
    RawDtc('P0420', DtcMode.pending),
    RawDtc('P0171', DtcMode.permanent),
  ];

  test('a scan stores its codes with their modes', () async {
    final s = await repo.recordScan(
      vehicleId: vid,
      codes: codes,
      milOn: true,
      dtcCount: 3,
      readiness: {'Catalyst': 'notComplete'},
      protocol: 6,
      now: at(0),
    );
    expect(s.purpose, SnapshotPurpose.scan);
    expect(s.codes, codes);
    expect(s.milOn, isTrue);
    expect(s.protocol, 6);
    expect(s.clearOutcome, isNull);
    expect((await repo.latest(vid))!.id, s.id);
  });

  test('★ beginClear is pending until the re-read settles it', () async {
    final before = await repo.beginClear(
      vehicleId: vid,
      codes: codes,
      now: at(0),
    );
    expect(before.isPendingClear, isTrue);
    expect((await repo.unreconciledClears()).map((s) => s.id), [before.id]);
    expect((await repo.unreconciledClears(vid)).length, 1);

    // The re-read is empty: cleared, and the two rows point at each other.
    final after = await repo.completeClear(
      beforeSnapshotId: before.id,
      afterCodes: const [],
      now: at(1),
    );
    final settled = (await repo.byId(before.id))!;
    expect(settled.clearOutcome, ClearOutcome.cleared);
    expect(settled.relatedSnapshotId, after.id);
    expect(after.relatedSnapshotId, before.id);
    expect(after.purpose, SnapshotPurpose.afterClear);
    expect(await repo.unreconciledClears(), isEmpty);
  });

  test('★ a code that comes back is never reported as cleared', () async {
    final before = await repo.beginClear(
      vehicleId: vid,
      codes: codes,
      now: at(0),
    );
    await repo.completeClear(
      beforeSnapshotId: before.id,
      afterCodes: const [RawDtc('P0301', DtcMode.stored)],
      now: at(1),
    );
    expect(
      (await repo.byId(before.id))!.clearOutcome,
      ClearOutcome.codesReturned,
    );
  });

  test(
    '★ a pending clear survives the app being killed and relaunched',
    () async {
      // The relaunch is a new AppDatabase on the same file — the only thing
      // §9.5's "reconcile on relaunch" can rely on.
      final dir = await scratchDir();
      final file = File('${dir.path}/t.db');
      var disk = AppDatabase(NativeDatabase(file));
      final v = await golf(disk);
      final before = await DtcRepository(disk)
          .beginClear(vehicleId: v.id, codes: codes, now: at(0));
      await disk.close();

      disk = AppDatabase(NativeDatabase(file));
      final pending = await DtcRepository(disk).unreconciledClears();
      expect(pending.map((s) => s.id), [before.id]);
      expect(pending.single.codes, codes);
      await disk.close();
      await dir.delete(recursive: true);
    },
  );

  test('a refused clear is recorded, not left pending', () async {
    final before = await repo.beginClear(vehicleId: vid, codes: codes);
    await repo.failClear(before.id, ClearOutcome.refused);
    expect(await repo.unreconciledClears(), isEmpty);
    expect((await repo.byId(before.id))!.clearOutcome, ClearOutcome.refused);
  });

  test(
    'completing a clear that never began is an error, not a phantom row',
    () async {
      await expectLater(
        repo.completeClear(beforeSnapshotId: 'nope', afterCodes: const []),
        throwsStateError,
      );
      expect(await db.select(db.dtcSnapshots).get(), isEmpty);
    },
  );

  test('history is newest first and bounded', () async {
    for (var i = 0; i < 5; i++) {
      await repo.recordScan(vehicleId: vid, codes: const [], now: at(i));
    }
    final h = await repo.history(vid, limit: 3);
    expect(h.map((s) => s.takenAt), [at(4), at(3), at(2)]);
  });

  test('decodeCodes drops garbage entries, keeps the rest', () {
    expect(DtcRepository.decodeCodes('not json'), isEmpty);
    expect(DtcRepository.decodeCodes('{"a":1}'), isEmpty);
    final mixed = DtcRepository.decodeCodes(
      '[{"code":"P0301","mode":"stored"},{"nope":1},'
      '{"code":"P0420","mode":"martian"}]',
    );
    expect(mixed.map((c) => c.code), ['P0301', 'P0420']);
    expect(mixed[1].mode, DtcMode.stored, reason: 'unknown mode → stored');
  });
}
