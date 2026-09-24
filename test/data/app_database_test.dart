import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('opens at the current schema version with every table empty', () async {
    expect(db.schemaVersion, 2);
    expect(await db.select(db.vehicles).get(), isEmpty);
    expect(await db.select(db.serviceRecords).get(), isEmpty);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.fuelEntries).get(), isEmpty);
    expect(await db.select(db.dtcSnapshots).get(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  });

  test('★ foreign keys are enforced on every connection', () async {
    // SQLite defaults them OFF; beforeOpen turns them on. Without this every
    // cascade in the schema is decoration.
    final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.read<int>('foreign_keys'), 1);

    await expectLater(
      db
          .into(db.serviceRecords)
          .insert(
            ServiceRecordsCompanion.insert(
              id: 'r1',
              vehicleId: 'no-such-vehicle',
              type: ServiceType.repair,
              title: 'Orphan',
              date: t0,
              createdAt: t0,
            ),
          ),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('FOREIGN KEY'),
          'a FOREIGN KEY constraint failure',
        ),
      ),
    );
  });

  test('★ deleting a vehicle cascades to everything it owns', () async {
    final v = await golf(db);
    final svc = ServiceRepository(db);
    await svc.addRecord(
      vehicleId: v.id,
      type: ServiceType.repair,
      title: 'Coil pack',
      date: t0,
    );
    await svc.addReminder(vehicleId: v.id, title: 'Oil');
    await svc.addFuel(vehicleId: v.id, date: t0, odometerKm: 1, litres: 1);
    await DtcRepository(db).recordScan(
      vehicleId: v.id,
      codes: const [RawDtc('P0301', DtcMode.stored)],
    );
    await db
        .into(db.tripSessions)
        .insert(
          TripSessionsCompanion.insert(
            id: 't1',
            vehicleId: v.id,
            startedAt: t0,
            lastOpenedAt: t0,
            samplesFilePath: 'trips/t1.csv',
          ),
        );

    await VehicleRepository(db).delete(v.id);

    expect(await db.select(db.serviceRecords).get(), isEmpty);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.fuelEntries).get(), isEmpty);
    expect(await db.select(db.dtcSnapshots).get(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  });

  group('the spec length limits', () {
    test('are refused by Drift before any SQL runs', () async {
      final v = await golf(db);
      final svc = ServiceRepository(db);
      await expectLater(
        svc.addRecord(
          vehicleId: v.id,
          type: ServiceType.repair,
          title: 'x' * 201,
          date: t0,
        ),
        throwsA(isA<InvalidDataException>()),
      );
      await expectLater(
        svc.addRecord(
          vehicleId: v.id,
          type: ServiceType.repair,
          title: 'ok',
          date: t0,
          notes: 'x' * 5001,
        ),
        throwsA(isA<InvalidDataException>()),
      );
      await expectLater(
        svc.addRecord(
          vehicleId: v.id,
          type: ServiceType.repair,
          title: 'x' * 200,
          date: t0,
          notes: 'x' * 5000,
        ),
        completes,
      );
    });

    test('★ are real CHECK constraints — raw SQL cannot bypass them', () async {
      final v = await golf(db);
      Future<void> raw(String title, String currency) => db.customStatement(
        'INSERT INTO service_records '
        '(id, vehicle_id, type, title, date, currency_code, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'raw',
          v.id,
          'repair',
          title,
          '2026-01-01T00:00:00.000Z',
          currency,
          '2026-01-01T00:00:00.000Z',
        ],
      );
      await expectLater(raw('x' * 201, 'USD'), throwsA(anything));
      await expectLater(raw('', 'USD'), throwsA(anything));
      await expectLater(raw('ok', 'EURO'), throwsA(anything));
      await expectLater(raw('ok', 'USD'), completes);
    });
  });

  test(
    'enums are stored by name, so reordering can never corrupt a row',
    () async {
      final v = await golf(db);
      final raw = await db
          .customSelect(
            'SELECT fuel_type FROM vehicles WHERE id = ?',
            variables: [Variable.withString(v.id)],
          )
          .getSingle();
      expect(raw.read<String>('fuel_type'), 'petrol');
    },
  );

  test('★ dates are ISO-8601 UTC text, whatever the caller passed', () async {
    // A local time in is a UTC instant on disk: text order stays
    // chronological across zones and DST, and equality still holds.
    final local = DateTime(2026, 9, 5, 12);
    final v = await VehicleRepository(db)
        .create(nickname: 'Local', fuel: VehicleFuel.petrol, now: local);
    final raw = await db
        .customSelect(
          'SELECT created_at FROM vehicles WHERE id = ?',
          variables: [Variable.withString(v.id)],
        )
        .getSingle();
    final text = raw.read<String>('created_at');
    expect(text, endsWith('Z'));
    expect(text, local.toUtc().toIso8601String());
    expect(v.createdAt.isUtc, isTrue);
    expect(v.createdAt.isAtSameMomentAs(local), isTrue);
  });

  test('wipe empties every table in one transaction', () async {
    await golf(db);
    await golf(db, vin: 'WVWZZZ1KZBW000002');
    await db.wipe();
    expect(await db.select(db.vehicles).get(), isEmpty);
  });
}
