import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';

import 'schema/schema.dart';

/// SPEC Part 6: "migrations with a schema-version test per step."
///
/// `drift_schemas/drift_schema_vN.json` is the immutable record of what
/// version N looked like on users' devices. The fresh test opens a *fresh*
/// database so the app's own `onCreate` builds the schema, and checks it
/// column-for-column against the dump — starting at the current version and
/// validating there would only compare the dump with itself. Each upgrade
/// test opens a database at an old version exactly as it was, runs the
/// app's migration, and checks the result against the dump of the current
/// version. When `schemaVersion` is bumped: run `tool/schema.sh`, then add
/// the step here.
///
/// Every upgrade ends at the current version, because that is the only
/// migration the app runs: the steps carry no `to` guard (§B.29), so a test
/// that stopped at an older version would run later steps too and check a
/// path no device can take. Each test names the step that fails it.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('★ v4: what tables.dart creates is exactly what was dumped', () async {
    // A fresh executor is at user_version 0, so opening runs onCreate.
    final db = AppDatabase(NativeDatabase.memory());
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('★ v1 → v4: every step, in order', () async {
    // Without the freeze-frame addColumn (v2) this fails on dtc_snapshots.
    final db = AppDatabase(await verifier.startAt(1));
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('★ v2 → v4: the layouts table and its index', () async {
    // createTable writes no index; without createIndex this fails on the
    // missing idx_layout_vehicle.
    final db = AppDatabase(await verifier.startAt(2));
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('★ v3 → v4: three trip columns and the one-open index', () async {
    // Without any one addColumn this fails on trip_sessions' columns;
    // without createIndex, on the missing idx_trip_one_open.
    final db = AppDatabase(await verifier.startAt(3));
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('★ v3 → v4: a device with two open trips still opens, with both '
      'closed', () async {
    // v3 had no one-open rule, and closeInterrupted never ran on a trip a
    // crash left open, so two open rows can exist. Without the UPDATE the
    // unique index cannot be created, the migration throws, and the
    // database never opens again.
    final schema = await verifier.schemaAt(3);
    const started1 = '2026-09-20T08:00:00.000Z';
    const started2 = '2026-09-21T09:30:00.000Z';
    const started3 = '2026-09-22T10:00:00.000Z';
    const ended3 = '2026-09-22T10:40:00.000Z';
    schema.rawDatabase.execute(
      "INSERT INTO vehicles (id, nickname, fuel_type, created_at) "
      "VALUES ('v1', 'Golf', 'petrol', '2026-09-01T00:00:00.000Z')",
    );
    for (final (id, started, ended) in [
      ('a' * 32, started1, null),
      ('b' * 32, started2, null),
      ('c' * 32, started3, ended3),
    ]) {
      schema.rawDatabase.execute(
        'INSERT INTO trip_sessions (id, vehicle_id, started_at, ended_at, '
        'last_opened_at, samples_file_path, distance_km) '
        "VALUES (?, 'v1', ?, ?, ?, ?, 12.5)",
        [id, started, ended, started, 'trips/$id.csv'],
      );
    }

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final rows = {
      for (final r in await db.select(db.tripSessions).get()) r.id: r,
    };
    for (final (id, started) in [('a' * 32, started1), ('b' * 32, started2)]) {
      final r = rows[id]!;
      expect(r.endedAt!.isAtSameMomentAs(DateTime.parse(started)), isTrue);
      expect(r.interrupted, isTrue, reason: id);
      expect(r.endReason, TripEnd.appKilled, reason: id);
      expect(r.distanceKm, 12.5, reason: 'nothing else is touched');
    }
    final clean = rows['c' * 32]!;
    expect(clean.endedAt!.isAtSameMomentAs(DateTime.parse(ended3)), isTrue);
    expect(clean.interrupted, isFalse);
    expect(clean.endReason, isNull, reason: 'a pre-v4 row says nothing');
    expect(clean.fuelUsedL, isNull);
    expect(clean.recordedMs, isNull);
    await db.close();
  });

  test('the current schemaVersion has a dumped snapshot', () {
    // A bumped version without a dump means the step above can't exist.
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 4);
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
    db.close();
  });
}
