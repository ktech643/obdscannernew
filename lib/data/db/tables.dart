// Drift table getters reference themselves inside `.check(...)`; the
// generator reads them statically and never evaluates the recursion. The
// lint can't tell, so it is off for this file only.
// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

import '../../models/enums.dart';

/// SPEC Part 6 — the data model.
///
/// Every table keys on a random string id (see `ids.dart`), never an
/// autoincrement, so rows survive an export/import onto another device with
/// their identity intact. Enums are stored by **name**: append new values,
/// never reorder. Dates are ISO-8601 text (see `build.yaml`), always UTC
/// (see `clock.dart`).
///
/// Files — attachments, photos, trip CSVs — are paths, never blobs.
///
/// The spec's length limits are real SQL `CHECK` constraints, not just
/// Drift's Dart-side validation, so nothing that bypasses the Dart layer can
/// write an over-long row either.

@DataClassName('VehicleRow')
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get nickname => text()();

  /// Full VIN, or null for a car that never answered Mode 09 (pre-2008 is
  /// common). Stored unmasked; masking is a display decision. Not unique:
  /// SPEC §9.8 says a duplicate VIN is warned about, then allowed.
  TextColumn get vin => text().nullable()();

  /// SPEC §9.6: a VIN whose check digit failed twice is kept but flagged,
  /// and never decoded.
  BoolColumn get vinUnverified =>
      boolean().withDefault(const Constant(false))();
  TextColumn get make => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  TextColumn get trim => text().withDefault(const Constant(''))();
  IntColumn get year => integer().nullable()();
  TextColumn get fuelType => textEnum<VehicleFuel>()();
  RealColumn get odometerKm => real().nullable()();
  DateTimeColumn get odometerUpdatedAt => dateTime().nullable()();
  TextColumn get plate => text().nullable()();
  TextColumn get photoPath => text().nullable()();

  /// The ATSP number that worked last time — skips the protocol ladder on
  /// the next connect (SPEC §4.2).
  IntColumn get cachedProtocol => integer().nullable()();

  /// JSON list of supported PID hex strings from the 0100/0120/… bitmasks.
  TextColumn get supportedPidsJson => text().nullable()();
  BoolColumn get supportsBatching =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ServiceRecordRow')
@TableIndex(name: 'idx_service_vehicle_date', columns: {#vehicleId, #date})
class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<ServiceType>()();
  TextColumn get title => text()
      .withLength(min: 1, max: 200)
      .check(title.length.isBetweenValues(1, 200))();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometerKm => real().nullable()();
  RealColumn get cost => real().nullable()();
  TextColumn get currencyCode => text()
      .withLength(min: 3, max: 3)
      .withDefault(const Constant('USD'))
      .check(currencyCode.length.equals(3))();
  TextColumn get vendor => text().nullable()();
  TextColumn get notes => text()
      .withLength(max: 5000)
      .nullable()
      .check(notes.isNull() | notes.length.isSmallerOrEqualValue(5000))();

  /// JSON list of file paths relative to the documents directory.
  TextColumn get attachmentPathsJson =>
      text().withDefault(const Constant('[]'))();

  /// JSON list of DTC codes this work addressed, e.g. `["P0301"]`. Links a
  /// repair back to the fault it cleared.
  TextColumn get linkedDtcsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReminderRow')
@TableIndex(name: 'idx_reminder_vehicle', columns: {#vehicleId})
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()
      .withLength(min: 1, max: 200)
      .check(title.length.isBetweenValues(1, 200))();
  TextColumn get detail => text().nullable()();

  /// Due by date, by odometer, or both — whichever comes first.
  DateTimeColumn get dueDate => dateTime().nullable()();
  RealColumn get dueOdometerKm => real().nullable()();

  /// Recurrence, applied when the reminder is completed.
  IntColumn get repeatEveryDays => integer().nullable()();
  RealColumn get repeatEveryKm => real().nullable()();
  BoolColumn get critical => boolean().withDefault(const Constant(false))();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FuelEntryRow')
@TableIndex(name: 'idx_fuel_vehicle_date', columns: {#vehicleId, #date})
class FuelEntries extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get odometerKm => real()();
  RealColumn get litres => real()();
  RealColumn get cost => real().nullable()();
  TextColumn get currencyCode => text()
      .withLength(min: 3, max: 3)
      .withDefault(const Constant('USD'))
      .check(currencyCode.length.equals(3))();

  /// Economy is only computed between full fills. A partial fill is kept
  /// for cost tracking and skipped for consumption.
  BoolColumn get partFill => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Why a snapshot was taken. The `beforeClear` row is the one SPEC §9.5
/// requires to exist *before* Mode 04 is sent.
enum SnapshotPurpose { scan, beforeClear, afterClear }

/// The outcome of a clear, recorded on its `beforeClear` snapshot. `pending`
/// on relaunch means the app died between Mode 04 and the re-read.
enum ClearOutcome { pending, cleared, codesReturned, refused, unknown }

@DataClassName('DtcSnapshotRow')
@TableIndex(name: 'idx_snapshot_vehicle_taken', columns: {#vehicleId, #takenAt})
class DtcSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get purpose => textEnum<SnapshotPurpose>()();

  /// JSON list of `{"code": "P0301", "mode": "stored"}`.
  TextColumn get codesJson => text()();
  BoolColumn get milOn => boolean().nullable()();
  IntColumn get dtcCount => integer().nullable()();

  /// JSON of the readiness report at the time, if one was read.
  TextColumn get readinessJson => text().nullable()();
  IntColumn get protocol => integer().nullable()();
  TextColumn get clearOutcome => textEnum<ClearOutcome>().nullable()();

  /// `beforeClear` → its `afterClear` re-read; `afterClear` → its
  /// `beforeClear`.
  TextColumn get relatedSnapshotId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TripSessionRow')
@TableIndex(name: 'idx_trip_vehicle_started', columns: {#vehicleId, #startedAt})
class TripSessions extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// LRU key for retention (SPEC Part 6: 30 days / 200 MB, least recently
  /// used first). Bumped whenever the trip is opened.
  DateTimeColumn get lastOpenedAt => dateTime()();
  RealColumn get distanceKm => real().nullable()();
  RealColumn get avgSpeedKph => real().nullable()();
  RealColumn get maxSpeedKph => real().nullable()();
  IntColumn get sampleCount => integer().withDefault(const Constant(0))();

  /// The samples CSV, relative to the documents directory — always exactly
  /// `trips/<id>.csv`. Never in the DB.
  TextColumn get samplesFilePath => text()();
  IntColumn get fileBytes => integer().withDefault(const Constant(0))();

  /// The app died (or the link dropped) before the trip was ended cleanly.
  BoolColumn get interrupted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
