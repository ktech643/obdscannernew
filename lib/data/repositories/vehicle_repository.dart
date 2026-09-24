import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/enums.dart';
import '../clock.dart';
import '../db/app_database.dart';
import '../ids.dart';

/// The garage's vehicles. Exactly one is primary whenever any exist; the
/// first created becomes it.
class VehicleRepository {
  VehicleRepository(this._db);
  final AppDatabase _db;

  $VehiclesTable get _t => _db.vehicles;

  List<OrderingTerm Function($VehiclesTable)> get _order => [
    (v) => OrderingTerm.desc(v.isPrimary),
    (v) => OrderingTerm.asc(v.createdAt),
  ];

  /// Primary first, then by creation — the order the garage lists them.
  Stream<List<VehicleRow>> watchAll() =>
      (_db.select(_t)..orderBy(_order)).watch();

  Future<List<VehicleRow>> all() => (_db.select(_t)..orderBy(_order)).get();

  Future<VehicleRow?> byId(String id) =>
      (_db.select(_t)..where((v) => v.id.equals(id))).getSingleOrNull();

  /// SPEC §9.6: two vehicles, one adapter — compare VIN on connect. Several
  /// garage entries may share a VIN (§9.8 allows it), so this is a list,
  /// primary first; the caller decides, or asks.
  Future<List<VehicleRow>> byVin(String vin) =>
      (_db.select(_t)
            ..where((v) => v.vin.equals(vin))
            ..orderBy(_order))
          .get();

  /// Never throws, even if the invariant has been broken from outside.
  Future<VehicleRow?> primary() =>
      (_db.select(_t)
            ..where((v) => v.isPrimary.equals(true))
            ..orderBy([(v) => OrderingTerm.asc(v.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> count() async {
    final c = _t.id.count();
    final row = await (_db.selectOnly(_t)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<VehicleRow> create({
    required String nickname,
    required VehicleFuel fuel,
    String? vin,
    bool vinUnverified = false,
    String make = '',
    String model = '',
    String trim = '',
    int? year,
    double? odometerKm,
    String? plate,
    DateTime? now,
  }) => _db.transaction(() async {
    final at = utc(now ?? utcNow());
    // The first vehicle is primary; nothing else needs the user to say so.
    final first = await count() == 0;
    final id = newId();
    await _db
        .into(_t)
        .insert(
          VehiclesCompanion.insert(
            id: id,
            nickname: nickname,
            vin: Value(vin),
            vinUnverified: Value(vinUnverified),
            make: Value(make),
            model: Value(model),
            trim: Value(trim),
            year: Value(year),
            fuelType: fuel,
            odometerKm: Value(odometerKm),
            odometerUpdatedAt: Value(odometerKm == null ? null : at),
            plate: Value(plate),
            isPrimary: Value(first),
            createdAt: at,
          ),
        );
    return (await byId(id))!;
  });

  /// Whole-row update. Dates are normalised to UTC here too — a row edited
  /// from a date picker carries a local time, and a local time on disk
  /// sorts by wall clock, not by moment.
  Future<void> update(VehicleRow row) => _db
      .update(_t)
      .replace(
        row.copyWith(
          createdAt: utc(row.createdAt),
          odometerUpdatedAt: Value(utcOrNull(row.odometerUpdatedAt)),
        ),
      );

  /// Writes only the columns a person edits, and only the ones passed.
  ///
  /// Never `isPrimary`, `createdAt` or the §4.2 connection cache. A form
  /// holds the row as it was when it opened, and [update] replaces the
  /// whole row from that copy — so anything that changed behind the open
  /// form was overwritten with the old value. `isPrimary` changes behind an
  /// open form whenever the §9.6 prompt switches cars, and a whole-row save
  /// then left the garage with two primaries or none. Callers that edit a
  /// vehicle go through here; [update] stays for restoring whole rows.
  Future<void> updateDetails(
    String id, {
    Value<String> nickname = const Value.absent(),
    Value<VehicleFuel> fuelType = const Value.absent(),
    Value<String?> vin = const Value.absent(),
    Value<bool> vinUnverified = const Value.absent(),
    Value<String> make = const Value.absent(),
    Value<String> model = const Value.absent(),
    Value<String> trim = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<double?> odometerKm = const Value.absent(),
    Value<DateTime?> odometerUpdatedAt = const Value.absent(),
    Value<String?> plate = const Value.absent(),
  }) => (_db.update(_t)..where((v) => v.id.equals(id))).write(
    VehiclesCompanion(
      nickname: nickname,
      fuelType: fuelType,
      vin: vin,
      vinUnverified: vinUnverified,
      make: make,
      model: model,
      trim: trim,
      year: year,
      odometerKm: odometerKm,
      odometerUpdatedAt: odometerUpdatedAt.present
          ? Value(utcOrNull(odometerUpdatedAt.value))
          : const Value.absent(),
      plate: plate,
    ),
  );

  Future<void> updateOdometer(String id, double km, {DateTime? now}) =>
      (_db.update(_t)..where((v) => v.id.equals(id))).write(
        VehiclesCompanion(
          odometerKm: Value(km),
          odometerUpdatedAt: Value(utc(now ?? utcNow())),
        ),
      );

  /// Exactly one primary, always: clears the flag everywhere, then sets it.
  /// An unknown [id] rolls the whole thing back — a stale id from a screen
  /// must never leave the garage with no primary.
  Future<void> setPrimary(String id) => _db.transaction(() async {
    await _db
        .update(_t)
        .write(const VehiclesCompanion(isPrimary: Value(false)));
    final n = await (_db.update(_t)..where((v) => v.id.equals(id))).write(
      const VehiclesCompanion(isPrimary: Value(true)),
    );
    if (n == 0) throw ArgumentError.value(id, 'id', 'no such vehicle');
  });

  /// Restores the one-primary invariant after anything that could have
  /// broken it — a merge import, most likely. Keeps [prefer] whenever that
  /// row still exists (flagged or not: the device's choice outranks a
  /// backup's), else the oldest flagged row, else the oldest row.
  Future<void> reconcilePrimary({String? prefer}) => _db.transaction(() async {
    final rows = await all();
    if (rows.isEmpty) return;
    final flagged = rows.where((v) => v.isPrimary).toList();
    final String keep;
    if (prefer != null && rows.any((v) => v.id == prefer)) {
      keep = prefer;
    } else {
      keep = (flagged.isNotEmpty ? flagged.first : rows.first).id;
    }
    if (flagged.length == 1 && flagged.first.id == keep) return;
    await setPrimary(keep);
  });

  /// What the handshake learned, so the next connect skips the ladder and
  /// the scheduler knows what to ask for (SPEC §4.2, §4.5).
  Future<void> cacheConnection(
    String id, {
    int? protocol,
    List<String>? supportedPids,
    bool? supportsBatching,
  }) => (_db.update(_t)..where((v) => v.id.equals(id))).write(
    VehiclesCompanion(
      cachedProtocol: protocol == null ? const Value.absent() : Value(protocol),
      supportedPidsJson: supportedPids == null
          ? const Value.absent()
          : Value(jsonEncode(supportedPids)),
      supportsBatching: supportsBatching == null
          ? const Value.absent()
          : Value(supportsBatching),
    ),
  );

  /// Cascades to every record, reminder, fill-up, snapshot and trip row.
  /// Trip *files* are the trip repository's to remove — call
  /// `TripRepository.deleteAllFor(id)` first.
  Future<void> delete(String id) => _db.transaction(() async {
    await (_db.delete(_t)..where((v) => v.id.equals(id))).go();
    await reconcilePrimary();
  });
}

extension VehicleRowX on VehicleRow {
  List<String> get supportedPids {
    final raw = supportedPidsJson;
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toList() : const [];
    } on FormatException {
      return const [];
    }
  }
}
