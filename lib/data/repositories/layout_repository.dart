import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';

/// SPEC §5.3 — the Dashboard's layouts, per vehicle.
///
/// Rows only: what a tile *is* (its PID and style) is the feature layer's
/// to encode, so nothing in `lib/data` knows about gauges. No stream
/// either — the layout controller is the one writer, and anything else
/// that writes this table (an import while the app runs) must ask it to
/// `reload()`.
class LayoutRepository {
  LayoutRepository(this._db);
  final AppDatabase _db;

  /// [vehicleId]'s layouts, oldest first — the order the Layouts sheet
  /// lists them in.
  Future<List<DashboardLayoutRow>> forVehicle(String vehicleId) =>
      (_db.select(_db.dashboardLayouts)
            ..where((l) => l.vehicleId.equals(vehicleId))
            ..orderBy([
              (l) => OrderingTerm.asc(l.createdAt),
              (l) => OrderingTerm.asc(l.id),
            ]))
          .get();

  /// Insert or overwrite the whole row. `toCompanion(false)` with
  /// `DoUpdate`, because `insertOnConflictUpdate` leaves out nulls.
  Future<void> save(DashboardLayoutRow row) {
    final c = row
        .copyWith(
          createdAt: utc(row.createdAt),
          selectedAt: utc(row.selectedAt),
        )
        .toCompanion(false);
    return _db
        .into(_db.dashboardLayouts)
        .insert(c, onConflict: DoUpdate((_) => c));
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.dashboardLayouts)..where((l) => l.id.equals(id))).go();
}
