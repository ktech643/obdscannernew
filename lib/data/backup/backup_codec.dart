import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../repositories/trip_repository.dart';
import '../repositories/vehicle_repository.dart';

/// SPEC Part 6 — "no cloud sync at v1. Full JSON export/import instead."
///
/// One JSON document holds every row of every table. Files (attachments,
/// photos, trip CSVs) are referenced by path and are **not** inside it;
/// a restore onto a fresh device gets the history and loses the files,
/// which the UI must say. Ids are preserved, so importing a backup twice is
/// idempotent and cross-references (linked snapshots, vehicle FKs) survive.
///
/// Timestamps are written as UTC instants (`…Z`) and read back as UTC, so a
/// backup restored in another time zone keeps every moment where it was.
///
/// After `import(replace: true)`, call `TripRepository.reconcileFiles()`:
/// the wipe removes rows, and the CSVs of trips the backup doesn't know
/// about would otherwise sit on disk uncounted. And after any import while
/// the app runs, call `live.dashboard.reload()` (or rebuild the provider
/// tree, as Delete all data does): the layout controller keeps no stream
/// on its table, so it would show — and on the next edit overwrite — what
/// it read before.
class BackupCodec {
  BackupCodec(this._db);
  final AppDatabase _db;

  static const format = 'torque-obd2-backup';
  static const version = 1;

  static const _json = _UtcSerializer();

  Future<Map<String, Object?>> export({DateTime? now}) async => {
    'format': format,
    'version': version,
    'schemaVersion': _db.schemaVersion,
    'exportedAt': (now ?? DateTime.timestamp()).toUtc().toIso8601String(),
    'vehicles': [
      for (final r in await _db.select(_db.vehicles).get())
        r.toJson(serializer: _json),
    ],
    'serviceRecords': [
      for (final r in await _db.select(_db.serviceRecords).get())
        r.toJson(serializer: _json),
    ],
    'reminders': [
      for (final r in await _db.select(_db.reminders).get())
        r.toJson(serializer: _json),
    ],
    'fuelEntries': [
      for (final r in await _db.select(_db.fuelEntries).get())
        r.toJson(serializer: _json),
    ],
    'dtcSnapshots': [
      for (final r in await _db.select(_db.dtcSnapshots).get())
        r.toJson(serializer: _json),
    ],
    'tripSessions': [
      for (final r in await _db.select(_db.tripSessions).get())
        r.toJson(serializer: _json),
    ],
    'dashboardLayouts': [
      for (final r in await _db.select(_db.dashboardLayouts).get())
        r.toJson(serializer: _json),
    ],
  };

  /// Imports in one transaction. [replace] wipes first; otherwise rows merge
  /// by id, and a row with a known id is overwritten in full — a null in the
  /// backup replaces a value on the device. Rows that don't parse, or that
  /// fail the schema's limits, are skipped and counted, never fatal: one
  /// corrupt line in a backup costs that line, not the restore. A replace
  /// whose vehicles are *all* unreadable is refused and rolled back.
  ///
  /// Child rows whose vehicle is missing are skipped too, and a trip row is
  /// only accepted with the one path the app itself produces for its id.
  /// The one-primary-vehicle invariant is restored at the end; on a merge
  /// the device's own primary wins.
  ///
  /// Trips: a backup from before schema v4 reads the new columns as null;
  /// an open trip arrives closed, as [TripEnd.appKilled]; and the trip being
  /// recorded on this device is never overwritten. Replace wipes that one
  /// with everything else — when Restore gets a UI, it must stop the
  /// recorder first.
  Future<ImportReport> import(
    Map<String, Object?> doc, {
    bool replace = false,
  }) async {
    if (doc['format'] != format) {
      throw const FormatException('Not a Torque OBD2 backup');
    }
    final v = doc['version'];
    if (v is! int || v > version) {
      throw FormatException('Backup version $v is newer than this app');
    }
    if (replace && doc['vehicles'] is! List) {
      // A truncated or edited file must not be allowed to wipe the device.
      throw const FormatException('Backup has no vehicle list');
    }

    final report = ImportReport();
    await _db.transaction(() async {
      final vehicles = VehicleRepository(_db);
      final localPrimary = replace ? null : (await vehicles.primary())?.id;
      if (replace) await _db.wipe();

      for (final r in _rows(doc['vehicles'], VehicleRow.fromJson, report)) {
        if (await _upsert(_db.vehicles, r.toCompanion(false), report)) {
          report.vehicles++;
        }
      }

      final known = {
        for (final r in await _db.select(_db.vehicles).get()) r.id,
      };
      bool owned(String vehicleId) {
        if (known.contains(vehicleId)) return true;
        report.skipped++;
        return false;
      }

      for (final r in _rows(
        doc['serviceRecords'],
        ServiceRecordRow.fromJson,
        report,
      )) {
        if (!owned(r.vehicleId)) continue;
        if (await _upsert(_db.serviceRecords, r.toCompanion(false), report)) {
          report.serviceRecords++;
        }
      }
      for (final r in _rows(doc['reminders'], ReminderRow.fromJson, report)) {
        if (!owned(r.vehicleId)) continue;
        if (await _upsert(_db.reminders, r.toCompanion(false), report)) {
          report.reminders++;
        }
      }
      for (final r in _rows(
        doc['fuelEntries'],
        FuelEntryRow.fromJson,
        report,
      )) {
        if (!owned(r.vehicleId)) continue;
        if (await _upsert(_db.fuelEntries, r.toCompanion(false), report)) {
          report.fuelEntries++;
        }
      }
      for (final r in _rows(
        doc['dtcSnapshots'],
        DtcSnapshotRow.fromJson,
        report,
      )) {
        if (!owned(r.vehicleId)) continue;
        if (await _upsert(_db.dtcSnapshots, r.toCompanion(false), report)) {
          report.dtcSnapshots++;
        }
      }
      // The trip being recorded here, if any. At most one row may be open
      // (idx_trip_one_open), and `_upsert` rethrows a UNIQUE clash, which
      // would abort the whole import.
      final recording = {
        for (final r in await (_db.select(
          _db.tripSessions,
        )..where((s) => s.endedAt.isNull())).get())
          r.id,
      };
      for (final r in _rows(
        doc['tripSessions'],
        TripSessionRow.fromJson,
        report,
      )) {
        if (!owned(r.vehicleId)) continue;
        // Only the path the app produces for this id. Anything else could
        // name the database, an attachment, or another trip's file.
        if (r.samplesFilePath != TripFiles.pathForId(r.id)) {
          report.skipped++;
          continue;
        }
        // A merge never overwrites the trip being recorded: the recorder
        // holds its file and will finish that row itself.
        if (recording.contains(r.id)) {
          report.skipped++;
          continue;
        }
        // A backup taken mid-recording holds an open row. Nothing records
        // it here, so it arrives closed, the way the launch pass closes a
        // trip the app was killed during — never as a phantom recording.
        final row = r.endedAt != null
            ? r
            : r.copyWith(
                endedAt: Value(r.startedAt),
                interrupted: true,
                endReason: const Value(TripEnd.appKilled),
              );
        if (await _upsert(_db.tripSessions, row.toCompanion(false), report)) {
          report.tripSessions++;
        }
      }
      // A layout overwrites a known id in full — its tile list is replaced,
      // never unioned, so a tile removed on one device is not brought back
      // by the other. Nothing is trimmed to the free plan (§7.5); the
      // Dashboard shows the plan's share. After a merge the layout shown is
      // whichever row, here or in the backup, was chosen last.
      for (final r in _rows(
        doc['dashboardLayouts'],
        DashboardLayoutRow.fromJson,
        report,
      )) {
        if (!owned(r.vehicleId)) continue;
        if (await _upsert(_db.dashboardLayouts, r.toCompanion(false), report)) {
          report.dashboardLayouts++;
        }
      }

      // A list of vehicles none of which could be read is a damaged file,

      // not an empty garage: roll the wipe back rather than commit it.

      if (replace &&
          (doc['vehicles'] as List).isNotEmpty &&
          report.vehicles == 0) {
        throw const FormatException('Backup contains no readable vehicle');
      }

      await vehicles.reconcilePrimary(prefer: localPrimary);
    });
    return report;
  }

  /// Insert or overwrite in full. A row the schema refuses (a 201-character
  /// title, a two-letter currency) is skipped: Drift raises before any SQL
  /// runs, so the transaction is untouched.
  Future<bool> _upsert<T extends Table, D>(
    TableInfo<T, D> table,
    Insertable<D> full,
    ImportReport report,
  ) async {
    try {
      await _db.into(table).insert(full, onConflict: DoUpdate((_) => full));
      return true;
    } on InvalidDataException {
      report.skipped++;
      return false;
    } on Exception catch (e) {
      // Drift's length check counts UTF-16 units; SQLite's LENGTH() counts
      // code points and stops at a NUL. A row that passes the first and
      // fails the second raises here, after the statement-level rollback
      // that leaves the transaction usable. Anything else is real trouble.
      if ('$e'.contains('CHECK constraint')) {
        report.skipped++;
        return false;
      }
      rethrow;
    }
  }

  static List<T> _rows<T>(
    Object? raw,
    T Function(Map<String, dynamic>, {ValueSerializer? serializer}) parse,
    ImportReport report,
  ) {
    if (raw == null) return const [];
    if (raw is! List) {
      // A section that is there but isn't a list is damage, not absence.
      report.skipped++;
      return const [];
    }
    final out = <T>[];
    for (final e in raw) {
      if (e is! Map) {
        report.skipped++;
        continue;
      }
      try {
        out.add(parse(Map<String, dynamic>.from(e), serializer: _json));
      } catch (_) {
        report.skipped++;
      }
    }
    return out;
  }
}

/// Drift's default string serializer writes a local DateTime without its
/// offset, so a restore in another zone shifts every instant. This one
/// writes and reads UTC instants only.
class _UtcSerializer extends ValueSerializer {
  const _UtcSerializer();

  static final _base = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  @override
  dynamic toJson<T>(T value) => value is DateTime
      ? value.toUtc().toIso8601String()
      : _base.toJson<T>(value);

  @override
  T fromJson<T>(dynamic json) {
    if (<T>[] is List<DateTime?>) {
      if (json == null) return null as T;
      if (json is String) return DateTime.parse(json).toUtc() as T;
      if (json is int) {
        return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true) as T;
      }
      return (_base.fromJson<DateTime>(json)).toUtc() as T;
    }
    return _base.fromJson<T>(json);
  }
}

class ImportReport {
  int vehicles = 0;
  int serviceRecords = 0;
  int reminders = 0;
  int fuelEntries = 0;
  int dtcSnapshots = 0;
  int tripSessions = 0;
  int dashboardLayouts = 0;

  /// Rows that didn't parse, failed the schema's limits, named a vehicle
  /// the backup doesn't contain, or carried a path the app never writes.
  int skipped = 0;

  int get total =>
      vehicles +
      serviceRecords +
      reminders +
      fuelEntries +
      dtcSnapshots +
      tripSessions +
      dashboardLayouts;

  @override
  String toString() =>
      'ImportReport(vehicles: $vehicles, records: $serviceRecords, '
      'reminders: $reminders, fuel: $fuelEntries, snapshots: $dtcSnapshots, '
      'trips: $tripSessions, layouts: $dashboardLayouts, skipped: $skipped)';
}
