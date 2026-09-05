import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  late VehicleRepository repo;
  setUp(() {
    db = memoryDb();
    repo = VehicleRepository(db);
  });
  tearDown(() => db.close());

  test('the first vehicle becomes primary; later ones do not', () async {
    final a = await golf(db, now: at(0));
    final b = await repo.create(
      nickname: 'Van',
      fuel: VehicleFuel.diesel,
      now: at(1),
    );
    expect(a.isPrimary, isTrue);
    expect(b.isPrimary, isFalse);
    expect((await repo.primary())!.id, a.id);
    expect(await repo.count(), 2);
  });

  test('★ exactly one primary, always', () async {
    final a = await golf(db, now: at(0));
    final b = await repo.create(
      nickname: 'Van',
      fuel: VehicleFuel.diesel,
      now: at(1),
    );
    await repo.setPrimary(b.id);
    final all = await repo.all();
    expect(all.where((v) => v.isPrimary).map((v) => v.id), [b.id]);
    expect(all.first.id, b.id, reason: 'primary lists first');

    // Deleting the primary promotes the oldest survivor.
    await repo.delete(b.id);
    expect((await repo.primary())!.id, a.id);
  });

  test('★ a broken invariant is repaired, never thrown on', () async {
    final a = await golf(db, now: at(0));
    final b = await repo.create(
      nickname: 'Van',
      fuel: VehicleFuel.diesel,
      now: at(1),
    );
    // Two primaries, as a careless merge could leave.
    await db
        .update(db.vehicles)
        .write(const VehiclesCompanion(isPrimary: Value(true)));
    expect((await repo.primary())!.id, a.id, reason: 'oldest wins, no throw');

    await repo.reconcilePrimary(prefer: b.id);
    expect((await repo.all()).where((v) => v.isPrimary).map((v) => v.id), [
      b.id,
    ]);

    // None flagged at all: the oldest is promoted.
    await db
        .update(db.vehicles)
        .write(const VehiclesCompanion(isPrimary: Value(false)));
    await repo.reconcilePrimary();
    expect((await repo.primary())!.id, a.id);
  });

  test(
    '★ byVin returns every match, primary first — duplicates are allowed',
    () async {
      // SPEC §9.8: duplicate VIN → warn, allow. Two entries for one car must
      // not crash the §9.6 connect-time lookup.
      final a = await golf(db, vin: 'WVWZZZ1KZBW000009', now: at(0));
      final b = await golf(db, vin: 'WVWZZZ1KZBW000009', now: at(1));
      await repo.setPrimary(b.id);
      final found = await repo.byVin('WVWZZZ1KZBW000009');
      expect(found.map((v) => v.id), [b.id, a.id]);
      expect(await repo.byVin('nope'), isEmpty);
    },
  );

  test(
    '★ update(row) normalises a local date, like every other write',
    () async {
      final v = await golf(db);
      final local = DateTime(2026, 9, 5, 3);
      await repo.update(v.copyWith(odometerUpdatedAt: Value(local)));
      final raw = await db
          .customSelect(
            'SELECT odometer_updated_at AS t FROM vehicles WHERE id = ?',
            variables: [Variable.withString(v.id)],
          )
          .getSingle();
      expect(raw.read<String>('t'), local.toUtc().toIso8601String());
      expect(raw.read<String>('t'), endsWith('Z'));
    },
  );

  test(
    'setPrimary with a stale id rolls back and keeps the old primary',
    () async {
      final a = await golf(db, now: at(0));
      await repo.create(nickname: 'Van', fuel: VehicleFuel.diesel, now: at(1));
      await expectLater(repo.setPrimary('nope'), throwsArgumentError);
      expect((await repo.primary())!.id, a.id);
    },
  );

  test(
    'reconcilePrimary honours prefer even when a backup unflagged it',
    () async {
      final a = await golf(db, now: at(0));
      final b = await repo.create(
        nickname: 'Van',
        fuel: VehicleFuel.diesel,
        now: at(1),
      );
      // What a merge of an older export looks like: b flagged, a not.
      await repo.setPrimary(b.id);
      await repo.reconcilePrimary(prefer: a.id);
      expect((await repo.primary())!.id, a.id);
    },
  );

  test('a vehicle without a VIN is allowed — pre-2008 cars', () async {
    final v = await repo.create(
      nickname: 'Old',
      fuel: VehicleFuel.petrol,
      vin: null,
      vinUnverified: true,
    );
    expect(v.vin, isNull);
    expect(v.vinUnverified, isTrue);
  });

  test('the handshake cache round-trips and tolerates garbage', () async {
    final v = await golf(db);
    await repo.cacheConnection(
      v.id,
      protocol: 6,
      supportedPids: ['0C', '0D', '05'],
      supportsBatching: true,
    );
    var row = (await repo.byId(v.id))!;
    expect(row.cachedProtocol, 6);
    expect(row.supportedPids, ['0C', '0D', '05']);
    expect(row.supportsBatching, isTrue);

    // Partial update leaves the rest alone.
    await repo.cacheConnection(v.id, protocol: 7);
    row = (await repo.byId(v.id))!;
    expect(row.cachedProtocol, 7);
    expect(row.supportedPids, ['0C', '0D', '05']);

    await (db.update(db.vehicles)..where((x) => x.id.equals(v.id))).write(
      const VehiclesCompanion(supportedPidsJson: Value('{not json')),
    );
    expect((await repo.byId(v.id))!.supportedPids, isEmpty);
  });

  test('updateOdometer stamps when it was read', () async {
    final v = await golf(db);
    await repo.updateOdometer(v.id, 120500, now: at(10));
    final row = (await repo.byId(v.id))!;
    expect(row.odometerKm, 120500);
    expect(row.odometerUpdatedAt, at(10));
  });

  test('watchAll is live', () async {
    final seen = <int>[];
    final sub = repo.watchAll().listen((rows) => seen.add(rows.length));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await golf(db);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen, containsAllInOrder([0, 1]));
  });
}
