import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';

import 'schema/schema.dart';

/// SPEC Part 6: "migrations with a schema-version test per step."
///
/// `drift_schemas/drift_schema_vN.json` is the immutable record of what
/// version N looked like on users' devices. The v1 test opens a *fresh*
/// database so the app's own `onCreate` builds the schema, and checks it
/// column-for-column against the dump — starting at v1 and validating at
/// v1 would only compare the dump with itself. Each later step opens a
/// database at N-1 exactly as it was, runs the app's migration, and checks
/// the result against the dump of N. When `schemaVersion` is bumped: run
/// `tool/schema.sh`, then add the step here.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('★ v3: what tables.dart creates is exactly what was dumped', () async {
    // A fresh executor is at user_version 0, so opening runs onCreate.
    final db = AppDatabase(NativeDatabase.memory());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('★ v1 → v2: a device on v1 migrates to exactly the v2 dump', () async {
    // Opens the schema as it was on users' devices at v1, then lets the
    // app's own onUpgrade run — the freeze-frame column on DtcSnapshots.
    final db = AppDatabase(await verifier.startAt(1));
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('★ v2 → v3: the layouts table and its index', () async {
    // createTable writes no index; without createIndex this fails on the
    // missing idx_layout_vehicle.
    final db = AppDatabase(await verifier.startAt(2));
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('★ v1 → v3: both steps, in order', () async {
    final db = AppDatabase(await verifier.startAt(1));
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('the current schemaVersion has a dumped snapshot', () {
    // A bumped version without a dump means the step above can't exist.
    final db = AppDatabase(NativeDatabase.memory());
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
    db.close();
  });
}
