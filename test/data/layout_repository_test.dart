import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/layout_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';

import 'support.dart';

/// SPEC §5.3 "Layouts save per vehicle", on the real schema: the CHECKs
/// are SQL, the cascade is the vehicle's, and a save is a full overwrite.
void main() {
  late AppDatabase db;
  late LayoutRepository repo;
  setUp(() {
    db = memoryDb();
    repo = LayoutRepository(db);
  });
  tearDown(() => db.close());

  const six = '[{"pid":"010C","variant":"numeric"}]';

  DashboardLayoutRow row(
    String vehicleId, {
    String id = 'a0000000000000000000000000000001',
    String name = 'Main',
    String tiles = six,
    int minutes = 0,
  }) => DashboardLayoutRow(
    id: id,
    vehicleId: vehicleId,
    name: name,
    tilesJson: tiles,
    createdAt: at(0),
    selectedAt: at(minutes),
  );

  Future<void> raw(String vehicleId, String name, String tiles) =>
      db.customStatement(
        'INSERT INTO dashboard_layouts '
        '(id, vehicle_id, name, tiles_json, created_at, selected_at) '
        "VALUES (?, ?, ?, ?, '2026-09-05T12:00:00.000Z', "
        "'2026-09-05T12:00:00.000Z')",
        [
          'b${name.length}${tiles.length}'.padRight(32, '0'),
          vehicleId,
          name,
          tiles,
        ],
      );

  test('★ the CHECKs are SQL: not JSON, not a list, empty, too long, a bad '
      'name', () async {
    final v = await golf(db);
    final sixtyFive = '[${List.filled(65, '{"pid":"010C"}').join(',')}]';
    for (final (name, tiles) in [
      ('Main', 'not json'),
      ('Main', '{"a":1}'),
      ('Main', '[]'),
      ('Main', sixtyFive),
      ('', six),
      ('x' * 41, six),
    ]) {
      await expectLater(
        raw(v.id, name, tiles),
        throwsA(predicate((e) => '$e'.contains('CHECK constraint'))),
        // 'not json' especially: a "malformed JSON" error instead would
        // abort a whole import rather than skip one row.
        reason: '$name / ${tiles.length > 20 ? '65 entries' : tiles}',
      );
    }
    await raw(v.id, 'Main', six); // and a good row goes in
    expect(await repo.forVehicle(v.id), hasLength(1));
  });

  test('★ a vehicle\'s delete takes its layouts, and no one else\'s', () async {
    final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.data.values.single, 1);
    final golfRow = await golf(db);
    final civic = await VehicleRepository(db)
        .create(nickname: 'Civic', fuel: VehicleFuel.petrol);
    await repo.save(row(golfRow.id));
    await repo.save(row(civic.id, id: 'c0000000000000000000000000000001'));
    await VehicleRepository(db).delete(golfRow.id);
    expect(await repo.forVehicle(golfRow.id), isEmpty);
    expect(await repo.forVehicle(civic.id), hasLength(1));
  });

  test(
    '★ a save for a vehicle that is gone is refused, and leaves no row',
    () async {
      // A write queued behind Delete all data must not outlive it.
      await expectLater(repo.save(row('nobody')), throwsA(anything));
      expect(await db.select(db.dashboardLayouts).get(), isEmpty);
    },
  );

  test(
    'a save round-trips in UTC and a second save overwrites in full',
    () async {
      final v = await golf(db);
      await repo.save(
        row(v.id).copyWith(
          createdAt: DateTime(2026, 9, 5, 17),
          selectedAt: DateTime(2026, 9, 5, 17),
        ),
      );
      var back = (await repo.forVehicle(v.id)).single;
      expect(back.createdAt.isUtc && back.selectedAt.isUtc, isTrue);
      expect(back.createdAt.isAtSameMomentAs(DateTime(2026, 9, 5, 17)), isTrue);

      await repo.save(
        back.copyWith(name: 'Track day', tilesJson: '[{"pid":"0105"}]'),
      );
      back = (await repo.forVehicle(v.id)).single;
      expect(back.name, 'Track day');
      expect(back.tilesJson, '[{"pid":"0105"}]');
    },
  );
}
