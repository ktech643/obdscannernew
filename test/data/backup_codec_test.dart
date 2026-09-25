import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/backup/backup_codec.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/layout_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  late BackupCodec codec;
  setUp(() {
    db = memoryDb();
    codec = BackupCodec(db);
  });
  tearDown(() => db.close());

  const tripId = '0123456789abcdef0123456789abcdef';
  const layoutId = 'fedcba9876543210fedcba9876543210';

  /// A garage with one of everything, cross-references included.
  Future<VehicleRow> populate() async {
    final v = await golf(db);
    final svc = ServiceRepository(db);
    await svc.addRecord(
      vehicleId: v.id,
      type: ServiceType.repair,
      title: 'Coil pack',
      date: at(0),
      cost: 89.5,
      linkedDtcs: ['P0301'],
      now: at(0),
    );
    await svc.addReminder(
      vehicleId: v.id,
      title: 'Oil',
      dueDate: at(99),
      now: at(0),
    );
    await svc.addFuel(
      vehicleId: v.id,
      date: at(0),
      odometerKm: 1000,
      litres: 40,
    );
    final dtc = DtcRepository(db);
    final before = await dtc.beginClear(
      vehicleId: v.id,
      codes: const [RawDtc('P0301', DtcMode.stored)],
      now: at(0),
    );
    await dtc.completeClear(
      beforeSnapshotId: before.id,
      afterCodes: const [],
      now: at(1),
    );
    await db
        .into(db.tripSessions)
        .insert(
          TripSessionsCompanion.insert(
            id: tripId,
            vehicleId: v.id,
            startedAt: at(0),
            endedAt: Value(at(5)),
            lastOpenedAt: at(0),
            samplesFilePath: TripFiles.pathForId(tripId),
            fileBytes: const Value(123),
          ),
        );
    await LayoutRepository(db).save(
      DashboardLayoutRow(
        id: layoutId,
        vehicleId: v.id,
        name: 'Main',
        tilesJson: '[{"pid":"010C","variant":"arc"},{"pid":"0105","variant":"numeric"}]',
        createdAt: at(0),
        selectedAt: at(2),
      ),
    );
    return v;
  }

  /// Every row of every table as JSON, for a deep equality check.
  Future<Map<String, Object?>> snapshot() async {
    final doc = await codec.export(now: t0);
    doc.remove('exportedAt');
    return doc;
  }

  /// Through real JSON text, so what comes back has JSON's types.
  Map<String, Object?> roundTrip(Map<String, Object?> doc) =>
      jsonDecode(jsonEncode(doc)) as Map<String, Object?>;

  test('★ export → wipe → import reproduces every row exactly', () async {
    await populate();
    final before = await snapshot();
    final doc = roundTrip(await codec.export(now: t0));

    await db.wipe();
    expect(await db.select(db.vehicles).get(), isEmpty);

    final report = await codec.import(doc);
    expect(
      report.total,
      8,
      reason: '1 vehicle, record, reminder, fill, trip, layout; 2 snapshots',
    );
    expect(report.dashboardLayouts, 1);
    expect(report.skipped, 0);
    expect(await snapshot(), before);

    // Cross-references survived: the clear pair still points both ways.
    final rows = await db.select(db.dtcSnapshots).get();
    final pair = {for (final r in rows) r.id: r};
    for (final r in rows) {
      expect(pair[r.relatedSnapshotId]!.relatedSnapshotId, r.id);
    }
  });

  test(
    '★ timestamps are instants: a local time survives another zone',
    () async {
      final local = DateTime(2026, 9, 5, 12, 30);
      final v = await VehicleRepository(db)
          .create(nickname: 'L', fuel: VehicleFuel.petrol, now: local);
      final doc = roundTrip(await codec.export());
      final exported = (doc['vehicles'] as List).single as Map;
      expect(exported['createdAt'], endsWith('Z'));
      expect(exported['createdAt'], local.toUtc().toIso8601String());

      await db.wipe();
      await codec.import(doc);
      final back = (await VehicleRepository(db).byId(v.id))!;
      expect(
        back.createdAt.isAtSameMomentAs(local),
        isTrue,
        reason: 'same instant',
      );
      expect(back.createdAt.isUtc, isTrue);
    },
  );

  test('★ a merge replaces a layout\'s tiles whole — never a union', () async {
    await populate();
    final doc = roundTrip(await codec.export());
    // Since the backup, this device removed Coolant and added Oil temp.
    final repo = LayoutRepository(db);
    final here = (await db.select(db.dashboardLayouts).get()).single;
    await repo.save(
      here.copyWith(
        tilesJson: '[{"pid":"010C","variant":"arc"},{"pid":"015C"}]',
      ),
    );
    await codec.import(doc);
    final back = (await db.select(db.dashboardLayouts).get()).single;
    expect(
      back.tilesJson,
      '[{"pid":"010C","variant":"arc"},{"pid":"0105","variant":"numeric"}]',
    );
  });

  test('★ a layout the schema refuses is skipped and counted; the rest '
      'commits', () async {
    await populate();
    final doc = roundTrip(await codec.export());
    final good = (doc['dashboardLayouts'] as List).single as Map;
    doc['dashboardLayouts'] = [
      good,
      {...good, 'id': 'a' * 32, 'vehicleId': 'nobody'},
      {...good, 'id': 'b' * 32, 'tilesJson': 'not json'},
      {...good, 'id': 'c' * 32, 'name': 'x' * 41},
    ];
    await db.wipe();
    final report = await codec.import(doc);
    expect(report.dashboardLayouts, 1);
    expect(report.skipped, greaterThanOrEqualTo(3));
    expect(
      await db.select(db.vehicles).get(),
      hasLength(1),
      reason: 'committed',
    );
  });

  test('a backup from before layouts imports, with none', () async {
    await populate();
    final doc = roundTrip(await codec.export())..remove('dashboardLayouts');
    await db.wipe();
    final report = await codec.import(doc);
    expect(report.dashboardLayouts, 0);
    expect(report.vehicles, 1);
    expect(BackupCodec.version, 1, reason: 'the section is additive');
  });

  test('importing the same backup twice changes nothing', () async {
    await populate();
    final doc = roundTrip(await codec.export());
    final before = await snapshot();
    await codec.import(doc);
    await codec.import(doc);
    expect(await snapshot(), before);
    expect((await db.select(db.vehicles).get()).length, 1);
  });

  test('★ a merge overwrites a known row in full — nulls included', () async {
    final v = await populate();
    final doc = roundTrip(await codec.export());
    // The device has since learned the odometer; the backup predates it.
    await VehicleRepository(db).updateOdometer(v.id, 130000, now: at(5));
    (doc['vehicles'] as List).cast<Map>().single['odometerKm'] = null;
    await codec.import(doc);
    expect((await VehicleRepository(db).byId(v.id))!.odometerKm, isNull);
  });

  test('★ a merge leaves exactly one primary, the device\'s own', () async {
    // Old phone's backup: Van, primary. New phone already has Golf, primary.
    await VehicleRepository(db)
        .create(nickname: 'Van', fuel: VehicleFuel.diesel, now: at(0));
    final doc = roundTrip(await codec.export());
    await db.wipe();
    final golfRow = await golf(db, now: at(10));

    await codec.import(doc);
    final repo = VehicleRepository(db);
    final all = await repo.all();
    expect(all.length, 2);
    expect(all.where((x) => x.isPrimary).map((x) => x.id), [golfRow.id]);
    expect((await repo.primary())!.id, golfRow.id);
  });

  test(
    '★ replace restores the backup\'s own primary, not the oldest row',
    () async {
      final repo = VehicleRepository(db);
      final van = await repo.create(
        nickname: 'Van',
        fuel: VehicleFuel.diesel,
        now: at(0),
      );
      final golfRow = await repo.create(
        nickname: 'Golf',
        fuel: VehicleFuel.petrol,
        now: at(1),
      );
      await repo.setPrimary(golfRow.id);
      final doc = roundTrip(await codec.export());

      await db.wipe();
      await golf(db, now: at(5)); // something to be replaced
      await codec.import(doc, replace: true);
      final all = await repo.all();
      expect(all.map((v) => v.id).toSet(), {van.id, golfRow.id});
      expect(
        (await repo.primary())!.id,
        golfRow.id,
        reason: 'newer, but flagged',
      );
    },
  );

  test(
    '★ a merge keeps the device\'s primary even when the backup unflags it',
    () async {
      final repo = VehicleRepository(db);
      final mine = await golf(db, now: at(0));
      final other = await repo.create(
        nickname: 'Van',
        fuel: VehicleFuel.diesel,
        now: at(1),
      );
      // An older export of this same garage, taken when Van was primary.
      await repo.setPrimary(other.id);
      final doc = roundTrip(await codec.export());
      await repo.setPrimary(mine.id);

      await codec.import(doc);
      expect((await repo.primary())!.id, mine.id);
      expect((await repo.all()).where((v) => v.isPrimary).length, 1);
    },
  );

  test('an integer timestamp in a backup still lands as UTC text', () async {
    final v = await golf(db);
    final doc = roundTrip(await codec.export());
    final row = (doc['vehicles'] as List).single as Map<String, Object?>;
    row['createdAt'] = DateTime.utc(2026, 1, 2, 3).millisecondsSinceEpoch;
    await db.wipe();
    await codec.import(doc);
    final raw = await db
        .customSelect(
          'SELECT created_at FROM vehicles WHERE id = ?',
          variables: [Variable.withString(v.id)],
        )
        .getSingle();
    expect(raw.read<String>('created_at'), '2026-01-02T03:00:00.000Z');
  });

  test(
    '★ a row that only the SQL CHECK refuses is skipped, not fatal',
    () async {
      await populate();
      final doc = roundTrip(await codec.export());
      // Three UTF-16 units — passes Drift — but two code points for SQLite.
      (doc['fuelEntries'] as List).add(
        Map<String, Object?>.from((doc['fuelEntries'] as List).first as Map)
          ..['id'] = 'emoji'
          ..['currencyCode'] = '😀U',
      );
      await db.wipe();
      final report = await codec.import(doc);
      expect(report.skipped, 1);
      expect(report.fuelEntries, 1);
      expect(report.total, 8, reason: 'the rest of the restore went through');
    },
  );

  test(
    '★ replace with vehicles that cannot be read rolls back the wipe',
    () async {
      await populate();
      await expectLater(
        codec.import({
          'format': BackupCodec.format,
          'version': 1,
          'vehicles': [
            {'id': 'x'},
          ],
        }, replace: true),
        throwsFormatException,
      );
      expect((await db.select(db.vehicles).get()).length, 1);
      expect((await db.select(db.serviceRecords).get()).length, 1);
    },
  );

  test(
    'replace drops what the backup does not contain; merge keeps it',
    () async {
      await populate();
      final doc = roundTrip(await codec.export());
      await VehicleRepository(db)
          .create(nickname: 'Extra', fuel: VehicleFuel.hybrid);

      await codec.import(doc);
      expect((await db.select(db.vehicles).get()).length, 2, reason: 'merge');

      await codec.import(doc, replace: true);
      expect((await db.select(db.vehicles).get()).length, 1, reason: 'replace');
    },
  );

  test(
    '★ a bad row costs that row and is counted, never the restore',
    () async {
      await populate();
      final doc = roundTrip(await codec.export());
      (doc['serviceRecords'] as List).add({'id': 'bad', 'title': 42});
      (doc['reminders'] as List).add(
        Map<String, Object?>.from((doc['reminders'] as List).first as Map)
          ..['id'] = 'orphan'
          ..['vehicleId'] = 'no-such-vehicle',
      );
      (doc['fuelEntries'] as List).add('not even a map');
      // Parses, but the schema refuses it: a 201-character title.
      (doc['serviceRecords'] as List).add(
        Map<String, Object?>.from((doc['serviceRecords'] as List).first as Map)
          ..['id'] = 'toolong'
          ..['title'] = 'x' * 201,
      );
      // A trip row naming a path the app never writes — another trip's file.
      (doc['tripSessions'] as List).add(
        Map<String, Object?>.from((doc['tripSessions'] as List).first as Map)
          ..['id'] = 'ffffffffffffffffffffffffffffffff'
          ..['samplesFilePath'] = TripFiles.pathForId(tripId),
      );

      await db.wipe();
      final report = await codec.import(doc);
      expect(report.skipped, 5);
      expect(report.serviceRecords, 1);
      expect(report.reminders, 1);
      expect(report.fuelEntries, 1);
      expect(report.tripSessions, 1);
      expect(report.total, 8);
    },
  );

  test('a section that is not a list is damage, and is counted', () async {
    await populate();
    final doc = roundTrip(await codec.export());
    doc['reminders'] = {'oops': true};
    await db.wipe();
    final report = await codec.import(doc);
    expect(report.skipped, 1);
    expect(report.reminders, 0);
  });

  test(
    '★ replace refuses a document with no vehicle list — nothing is wiped',
    () async {
      await populate();
      await expectLater(
        codec.import({
          'format': BackupCodec.format,
          'version': 1,
        }, replace: true),
        throwsFormatException,
      );
      await expectLater(
        codec.import({
          'format': BackupCodec.format,
          'version': 1,
          'vehicles': 'nope',
        }, replace: true),
        throwsFormatException,
      );
      expect((await db.select(db.vehicles).get()).length, 1);
    },
  );

  test('the wrong format, or a future version, is refused up front', () async {
    await expectLater(codec.import({'format': 'other'}), throwsFormatException);
    await expectLater(
      codec.import({'format': BackupCodec.format, 'version': 99}),
      throwsFormatException,
    );
    expect(await db.select(db.vehicles).get(), isEmpty);
  });
}
