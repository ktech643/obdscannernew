import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/enums.dart';
import '../clock.dart';
import '../db/app_database.dart';
import '../ids.dart';

/// Garage history: service records, reminders, fuel.
class ServiceRepository {
  ServiceRepository(this._db);
  final AppDatabase _db;

  // ------------------------------------------------------------- records

  Stream<List<ServiceRecordRow>> watchRecords(String vehicleId) =>
      (_db.select(_db.serviceRecords)
            ..where((r) => r.vehicleId.equals(vehicleId))
            ..orderBy([(r) => OrderingTerm.desc(r.date)]))
          .watch();

  Future<List<ServiceRecordRow>> records(String vehicleId) =>
      (_db.select(_db.serviceRecords)
            ..where((r) => r.vehicleId.equals(vehicleId))
            ..orderBy([(r) => OrderingTerm.desc(r.date)]))
          .get();

  /// SPEC §7.2: the free tier allows 10. The gate lives with the
  /// entitlement, not here — this only answers the question.
  Future<int> recordCount(String vehicleId) async {
    final c = _db.serviceRecords.id.count();
    final q = _db.selectOnly(_db.serviceRecords)
      ..addColumns([c])
      ..where(_db.serviceRecords.vehicleId.equals(vehicleId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<ServiceRecordRow> addRecord({
    required String vehicleId,
    required ServiceType type,
    required String title,
    required DateTime date,
    double? odometerKm,
    double? cost,
    String currencyCode = 'USD',
    String? vendor,
    String? notes,
    List<String> attachmentPaths = const [],
    List<String> linkedDtcs = const [],
    DateTime? now,
  }) async {
    final id = newId();
    await _db
        .into(_db.serviceRecords)
        .insert(
          ServiceRecordsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            type: type,
            title: title,
            date: utc(date),
            odometerKm: Value(odometerKm),
            cost: Value(cost),
            currencyCode: Value(currencyCode),
            vendor: Value(vendor),
            notes: Value(notes),
            attachmentPathsJson: Value(jsonEncode(attachmentPaths)),
            linkedDtcsJson: Value(jsonEncode(linkedDtcs)),
            createdAt: utc(now ?? utcNow()),
          ),
        );
    return (await (_db.select(
      _db.serviceRecords,
    )..where((r) => r.id.equals(id))).getSingle());
  }

  /// Whole-row update; dates normalised to UTC like every other write.
  Future<void> updateRecord(ServiceRecordRow row) => _db
      .update(_db.serviceRecords)
      .replace(
        row.copyWith(date: utc(row.date), createdAt: utc(row.createdAt)),
      );

  Future<void> deleteRecord(String id) =>
      (_db.delete(_db.serviceRecords)..where((r) => r.id.equals(id))).go();

  /// Every record that says it fixed [code], newest first — what the
  /// diagnostics screen shows under "you've seen this before".
  Future<List<ServiceRecordRow>> recordsLinkedTo(
    String vehicleId,
    String code,
  ) async {
    final all = await records(vehicleId);
    return [
      for (final r in all)
        if (r.linkedDtcs.contains(code)) r,
    ];
  }

  // ----------------------------------------------------------- reminders

  Stream<List<ReminderRow>> watchReminders(String vehicleId) =>
      (_db.select(_db.reminders)
            ..where((r) => r.vehicleId.equals(vehicleId))
            ..orderBy([(r) => OrderingTerm.asc(r.dueDate)]))
          .watch();

  Future<List<ReminderRow>> reminders(String vehicleId) =>
      (_db.select(_db.reminders)
            ..where((r) => r.vehicleId.equals(vehicleId))
            ..orderBy([(r) => OrderingTerm.asc(r.dueDate)]))
          .get();

  Future<ReminderRow> addReminder({
    required String vehicleId,
    required String title,
    String? detail,
    DateTime? dueDate,
    double? dueOdometerKm,
    int? repeatEveryDays,
    double? repeatEveryKm,
    bool critical = false,
    DateTime? now,
  }) async {
    final id = newId();
    await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            title: title,
            detail: Value(detail),
            dueDate: Value(utcOrNull(dueDate)),
            dueOdometerKm: Value(dueOdometerKm),
            repeatEveryDays: Value(repeatEveryDays),
            repeatEveryKm: Value(repeatEveryKm),
            critical: Value(critical),
            createdAt: utc(now ?? utcNow()),
          ),
        );
    return (await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(id))).getSingle());
  }

  Future<void> setPaused(String id, bool paused) =>
      (_db.update(_db.reminders)..where((r) => r.id.equals(id))).write(
        RemindersCompanion(paused: Value(paused)),
      );

  /// Marks done. A recurring reminder rolls forward from *now* — a late oil
  /// change doesn't make the next one early — and from the odometer given,
  /// else the vehicle's last reading, else its own target. A recurrence
  /// that has nothing to roll from is completed outright rather than
  /// silently left due.
  Future<void> complete(String id, {DateTime? now, double? odometerKm}) async {
    final at = utc(now ?? utcNow());
    final r = await (_db.select(
      _db.reminders,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (r == null) return;
    final days = r.repeatEveryDays;
    final km = r.repeatEveryKm;

    // Only a target with a recurrence rolls forward. A one-off target next
    // to a recurring one was for *this* occurrence and is dropped — carried
    // along, it would keep the reminder due the moment it was completed.
    DateTime? nextDue;
    double? nextKm;
    if (days != null) nextDue = at.add(Duration(days: days));
    if (km != null) {
      final base =
          odometerKm ??
          (await (_db.select(
                _db.vehicles,
              )..where((v) => v.id.equals(r.vehicleId))).getSingleOrNull())
              ?.odometerKm ??
          r.dueOdometerKm;
      if (base != null) nextKm = base + km;
    }
    final rolled = nextDue != null || nextKm != null;

    await (_db.update(_db.reminders)..where((x) => x.id.equals(id))).write(
      rolled
          ? RemindersCompanion(
              dueDate: Value(nextDue),
              dueOdometerKm: Value(nextKm),
              completedAt: const Value(null),
            )
          : RemindersCompanion(completedAt: Value(at)),
    );
  }

  Future<void> deleteReminder(String id) =>
      (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();

  // ---------------------------------------------------------------- fuel

  Stream<List<FuelEntryRow>> watchFuel(String vehicleId) =>
      (_db.select(_db.fuelEntries)
            ..where((f) => f.vehicleId.equals(vehicleId))
            ..orderBy([(f) => OrderingTerm.desc(f.date)]))
          .watch();

  Future<List<FuelEntryRow>> fuel(String vehicleId) =>
      (_db.select(_db.fuelEntries)
            ..where((f) => f.vehicleId.equals(vehicleId))
            ..orderBy([(f) => OrderingTerm.asc(f.date)]))
          .get();

  Future<FuelEntryRow> addFuel({
    required String vehicleId,
    required DateTime date,
    required double odometerKm,
    required double litres,
    double? cost,
    String currencyCode = 'USD',
    bool partFill = false,
    String? notes,
  }) async {
    final id = newId();
    await _db
        .into(_db.fuelEntries)
        .insert(
          FuelEntriesCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            date: utc(date),
            odometerKm: odometerKm,
            litres: litres,
            cost: Value(cost),
            currencyCode: Value(currencyCode),
            partFill: Value(partFill),
            notes: Value(notes),
          ),
        );
    return (await (_db.select(
      _db.fuelEntries,
    )..where((f) => f.id.equals(id))).getSingle());
  }

  Future<void> deleteFuel(String id) =>
      (_db.delete(_db.fuelEntries)..where((f) => f.id.equals(id))).go();

  /// Litres per 100 km for each **full** fill, computed from the previous
  /// full fill: distance between them, litres of everything added in
  /// between (partials included — they went in the tank). The first full
  /// fill, and any partial, gets null. This is the only honest number a
  /// fuel log can give; per-fill economy on partials is the classic lie.
  ///
  /// Walked in odometer order, not date order: fills logged from a date
  /// picker share a midnight timestamp, and the odometer is the physical
  /// sequence anyway.
  Future<List<FuelEconomy>> economy(String vehicleId) async {
    final entries =
        await (_db.select(_db.fuelEntries)
              ..where((f) => f.vehicleId.equals(vehicleId))
              ..orderBy([
                (f) => OrderingTerm.asc(f.odometerKm),
                (f) => OrderingTerm.asc(f.date),
              ]))
            .get();
    final out = <FuelEconomy>[];
    FuelEntryRow? lastFull;
    var litresSince = 0.0;
    for (final e in entries) {
      double? lPer100;
      if (e.partFill) {
        litresSince += e.litres;
      } else {
        if (lastFull != null) {
          final km = e.odometerKm - lastFull.odometerKm;
          if (km > 0) lPer100 = (litresSince + e.litres) / km * 100;
        }
        lastFull = e;
        litresSince = 0;
      }
      out.add(FuelEconomy(e, lPer100));
    }
    return out;
  }
}

class FuelEconomy {
  const FuelEconomy(this.entry, this.litresPer100Km);
  final FuelEntryRow entry;
  final double? litresPer100Km;
}

extension ServiceRecordRowX on ServiceRecordRow {
  List<String> get linkedDtcs => _stringList(linkedDtcsJson);
  List<String> get attachmentPaths => _stringList(attachmentPathsJson);
}

List<String> _stringList(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  } on FormatException {
    return const [];
  }
}
