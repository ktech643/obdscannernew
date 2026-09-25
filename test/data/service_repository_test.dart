import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/clock.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  late ServiceRepository repo;
  late String vid;
  setUp(() async {
    db = memoryDb();
    repo = ServiceRepository(db);
    vid = (await golf(db)).id;
  });
  tearDown(() => db.close());

  group('service records', () {
    test('list newest first, count, and link back to codes', () async {
      await repo.addRecord(
        vehicleId: vid,
        type: ServiceType.repair,
        title: 'Coil pack',
        date: at(0),
        linkedDtcs: ['P0301'],
      );
      await repo.addRecord(
        vehicleId: vid,
        type: ServiceType.maintenance,
        title: 'Oil',
        date: at(60),
      );
      final rows = await repo.records(vid);
      expect(rows.map((r) => r.title), ['Oil', 'Coil pack']);
      expect(await repo.recordCount(vid), 2);
      expect((await repo.recordsLinkedTo(vid, 'P0301')).map((r) => r.title), [
        'Coil pack',
      ]);
      expect(await repo.recordsLinkedTo(vid, 'P0420'), isEmpty);
    });

    test('★ updateRecord normalises a picker date to UTC text', () async {
      final r = await repo.addRecord(
        vehicleId: vid,
        type: ServiceType.repair,
        title: 'x',
        date: at(0),
      );
      final local = DateTime(2026, 9, 5, 3);
      await repo.updateRecord(r.copyWith(date: local));
      final raw = await db
          .customSelect(
            'SELECT date FROM service_records WHERE id = ?',
            variables: [Variable.withString(r.id)],
          )
          .getSingle();
      expect(raw.read<String>('date'), local.toUtc().toIso8601String());
      expect(raw.read<String>('date'), endsWith('Z'));
    });

    test('a corrupt JSON column costs its list, not the row', () async {
      final r = await repo.addRecord(
        vehicleId: vid,
        type: ServiceType.repair,
        title: 'x',
        date: at(0),
        attachmentPaths: ['a.jpg'],
      );
      expect(r.attachmentPaths, ['a.jpg']);
      await (db.update(db.serviceRecords)..where((x) => x.id.equals(r.id)))
          .write(const ServiceRecordsCompanion(linkedDtcsJson: Value('[[')));
      final again = (await repo.records(vid)).single;
      expect(again.linkedDtcs, isEmpty);
      expect(again.attachmentPaths, ['a.jpg']);
    });
  });

  group('reminders', () {
    test(
      'a one-off completes; a recurring one rolls forward from now',
      () async {
        final once = await repo.addReminder(
          vehicleId: vid,
          title: 'MOT',
          dueDate: at(0),
        );
        final byDays = await repo.addReminder(
          vehicleId: vid,
          title: 'Oil',
          dueDate: at(0),
          repeatEveryDays: 180,
        );
        final byKm = await repo.addReminder(
          vehicleId: vid,
          title: 'Tyres',
          dueOdometerKm: 125000,
          repeatEveryKm: 20000,
        );

        // Completed 3 days late: the next is 180 days from *today*.
        final late = at(3 * 24 * 60);
        await repo.complete(once.id, now: late);
        await repo.complete(byDays.id, now: late);
        await repo.complete(byKm.id, now: late, odometerKm: 126400);

        final rows = {for (final r in await repo.reminders(vid)) r.id: r};
        expect(rows[once.id]!.completedAt, late);
        expect(rows[byDays.id]!.completedAt, isNull);
        // A calendar day: today on the phone's calendar plus 180 — not
        // this instant plus 180 × 24 h, which a DST change moves a day.
        expect(rows[byDays.id]!.dueDate, addDays(today(now: late), 180));
        expect(rows[byKm.id]!.dueOdometerKm, 146400);
      },
    );

    test('★ a km-recurring reminder completed without a reading rolls from '
        'the vehicle odometer, never a silent no-op', () async {
      // golf() has odometerKm 120000.
      final tyres = await repo.addReminder(
        vehicleId: vid,
        title: 'Tyres',
        dueOdometerKm: 125000,
        repeatEveryKm: 20000,
      );
      await repo.complete(tyres.id, now: at(0));
      final row = (await repo.reminders(vid)).single;
      expect(row.dueOdometerKm, 140000);
      expect(row.completedAt, isNull);
    });

    test(
      'a one-off target beside a recurring one is dropped on completion',
      () async {
        // "Every 365 days", with a one-off odometer target for this occurrence.
        final r = await repo.addReminder(
          vehicleId: vid,
          title: 'Service',
          dueDate: at(0),
          dueOdometerKm: 130000,
          repeatEveryDays: 365,
        );
        await repo.complete(r.id, now: at(10));
        final row = (await repo.reminders(vid)).single;
        expect(row.dueDate, addDays(today(now: at(10)), 365));
        expect(row.dueOdometerKm, isNull, reason: 'else it stays due now');
        expect(row.completedAt, isNull);
      },
    );

    test(
      'a recurrence with nothing to roll from is simply completed',
      () async {
        final v = await VehicleRepository(db)
            .create(nickname: 'NoOdo', fuel: VehicleFuel.petrol);
        final r = await repo.addReminder(
          vehicleId: v.id,
          title: 'Belt',
          repeatEveryKm: 100000,
        );
        await repo.complete(r.id, now: at(0));
        final row = (await repo.reminders(v.id)).single;
        expect(row.completedAt, at(0));
        expect(row.dueOdometerKm, isNull);
      },
    );

    test('pause is a flag, not a deletion', () async {
      final r = await repo.addReminder(vehicleId: vid, title: 'Oil');
      await repo.setPaused(r.id, true);
      expect((await repo.reminders(vid)).single.paused, isTrue);
    });
  });

  group('fuel economy', () {
    test('★ is computed between full fills only, partials folded in', () async {
      // Odometer 1000: full. 1300: partial 10 L. 1500: full 30 L.
      await repo.addFuel(
        vehicleId: vid,
        date: at(0),
        odometerKm: 1000,
        litres: 40,
      );
      await repo.addFuel(
        vehicleId: vid,
        date: at(1),
        odometerKm: 1300,
        litres: 10,
        partFill: true,
      );
      await repo.addFuel(
        vehicleId: vid,
        date: at(2),
        odometerKm: 1500,
        litres: 30,
      );
      final e = await repo.economy(vid);
      expect(e[0].litresPer100Km, isNull, reason: 'first full: no baseline');
      expect(e[1].litresPer100Km, isNull, reason: 'partial: never rated');
      // 500 km on 40 L (10 partial + 30 full) = 8.0 L/100km.
      expect(e[2].litresPer100Km, closeTo(8.0, 1e-9));
    });

    test(
      '★ same-date fills are walked in odometer order, not entry order',
      () async {
        final day = at(0);
        // Entered out of order: evening fill first, then the morning partial.
        await repo.addFuel(
          vehicleId: vid,
          date: day,
          odometerKm: 1000,
          litres: 40,
        );
        await repo.addFuel(
          vehicleId: vid,
          date: day,
          odometerKm: 1500,
          litres: 30,
        );
        await repo.addFuel(
          vehicleId: vid,
          date: day,
          odometerKm: 1300,
          litres: 10,
          partFill: true,
        );
        final e = await repo.economy(vid);
        expect(e.map((x) => x.entry.odometerKm), [1000, 1300, 1500]);
        expect(e[2].litresPer100Km, closeTo(8.0, 1e-9));
      },
    );

    test('a fill at the same odometer cannot divide by zero', () async {
      await repo.addFuel(
        vehicleId: vid,
        date: at(0),
        odometerKm: 1000,
        litres: 40,
      );
      await repo.addFuel(
        vehicleId: vid,
        date: at(1),
        odometerKm: 1000,
        litres: 5,
      );
      final e = await repo.economy(vid);
      expect(e[1].litresPer100Km, isNull);
    });
  });
}
