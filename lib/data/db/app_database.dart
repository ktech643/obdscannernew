import 'package:drift/drift.dart';

// The generated part needs the enum types tables.dart stores by name; a
// part sees only its library's imports.
import '../../models/enums.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The on-device database. Local-first, no sync, no server — SPEC Part 6.
///
/// Construct with any [QueryExecutor]: `openAppDatabase()` for the app,
/// `NativeDatabase.memory()` in tests.
///
/// **Migrations.** Bump [schemaVersion], add a step in [migration], then
/// dump the new schema and regenerate the verifier (`tool/schema.sh`) so
/// `test/data/schema_migration_test.dart` checks that step forever. Never
/// edit a dumped schema file.
@DriftDatabase(
  tables: [
    Vehicles,
    ServiceRecords,
    Reminders,
    FuelEntries,
    DtcSnapshots,
    TripSessions,
    DashboardLayouts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  /// v1 (2026-09-05): the six tables. v2 (2026-09-24): the freeze frame on
  /// `DtcSnapshots` — one nullable column, so a plain `addColumn` is the
  /// whole step and `test/data/schema_migration_test.dart` checks it
  /// against `drift_schemas/drift_schema_v2.json`. A step that changes a
  /// table's shape rather than adding to it should move to
  /// `drift_dev schema steps` + `stepByStep`, which references the old
  /// schema instead of the current table. v3 (2026-09-26): the Dashboard's
  /// layouts, one new table and its index — `createTable` writes no index,
  /// so the step creates it too.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(dtcSnapshots, dtcSnapshots.freezeFrameJson);
      }
      if (from < 3) {
        await m.createTable(dashboardLayouts);
        await m.createIndex(idxLayoutVehicle);
      }
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys off by default; every cascade in
      // tables.dart depends on this being on for every connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The database half of "Delete all data": every row of every table, in
  /// one transaction. Files are the trip repository's — call
  /// `TripRepository.deleteAllFiles()` alongside this, or
  /// `reconcileFiles()` afterwards, or the CSVs outlive their rows.
  Future<void> wipe() => transaction(() async {
    await delete(dashboardLayouts).go();
    await delete(tripSessions).go();
    await delete(dtcSnapshots).go();
    await delete(fuelEntries).go();
    await delete(reminders).go();
    await delete(serviceRecords).go();
    await delete(vehicles).go();
  });
}
