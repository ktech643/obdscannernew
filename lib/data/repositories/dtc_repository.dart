import 'dart:convert';

import 'package:drift/drift.dart';

import '../../protocol/dtc_decoder.dart';
import '../clock.dart';
import '../db/app_database.dart';
import '../ids.dart';

/// DTC history, and the one write that has to happen in the right order.
///
/// SPEC §9.5: **the snapshot is written before Mode 04 is sent.** If the app
/// dies between the clear and the verifying re-read, the `beforeClear` row
/// is still `pending` on relaunch, and the diagnostics screen must say so
/// rather than pretend the codes are gone.
class DtcRepository {
  DtcRepository(this._db);
  final AppDatabase _db;

  $DtcSnapshotsTable get _t => _db.dtcSnapshots;

  Stream<DtcSnapshotRow?> watchLatest(String vehicleId) =>
      (_db.select(_t)
            ..where((s) => s.vehicleId.equals(vehicleId))
            ..orderBy([(s) => OrderingTerm.desc(s.takenAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<DtcSnapshotRow?> latest(String vehicleId) =>
      (_db.select(_t)
            ..where((s) => s.vehicleId.equals(vehicleId))
            ..orderBy([(s) => OrderingTerm.desc(s.takenAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<DtcSnapshotRow>> history(String vehicleId, {int limit = 50}) =>
      (_db.select(_t)
            ..where((s) => s.vehicleId.equals(vehicleId))
            ..orderBy([(s) => OrderingTerm.desc(s.takenAt)])
            ..limit(limit))
          .get();

  Future<DtcSnapshotRow?> byId(String id) =>
      (_db.select(_t)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// An ordinary scan result.
  Future<DtcSnapshotRow> recordScan({
    required String vehicleId,
    required List<RawDtc> codes,
    bool? milOn,
    int? dtcCount,
    Map<String, Object?>? readiness,
    int? protocol,
    DateTime? now,
  }) => _insert(
    vehicleId: vehicleId,
    purpose: SnapshotPurpose.scan,
    codes: codes,
    milOn: milOn,
    dtcCount: dtcCount,
    readiness: readiness,
    protocol: protocol,
    now: now,
  );

  /// ★ Call and **await** this before sending Mode 04. Returns the row whose
  /// id [completeClear] needs afterwards.
  Future<DtcSnapshotRow> beginClear({
    required String vehicleId,
    required List<RawDtc> codes,
    bool? milOn,
    int? dtcCount,
    Map<String, Object?>? readiness,
    int? protocol,
    DateTime? now,
  }) => _insert(
    vehicleId: vehicleId,
    purpose: SnapshotPurpose.beforeClear,
    codes: codes,
    milOn: milOn,
    dtcCount: dtcCount,
    readiness: readiness,
    protocol: protocol,
    clearOutcome: ClearOutcome.pending,
    now: now,
  );

  /// After the re-read that follows Mode 04. Writes the `afterClear` row,
  /// links both ways, and settles the outcome: [ClearOutcome.cleared] when
  /// the re-read is empty, [ClearOutcome.codesReturned] when it isn't — the
  /// UI says "cleared, but P0301 came back", never just "cleared".
  Future<DtcSnapshotRow> completeClear({
    required String beforeSnapshotId,
    required List<RawDtc> afterCodes,
    bool? milOn,
    int? dtcCount,
    int? protocol,
    DateTime? now,
  }) => _db.transaction(() async {
    final before = await byId(beforeSnapshotId);
    if (before == null) {
      throw StateError('No beforeClear snapshot $beforeSnapshotId');
    }
    final after = await _insert(
      vehicleId: before.vehicleId,
      purpose: SnapshotPurpose.afterClear,
      codes: afterCodes,
      milOn: milOn,
      dtcCount: dtcCount,
      protocol: protocol,
      relatedSnapshotId: before.id,
      now: now,
    );
    await (_db.update(_t)..where((s) => s.id.equals(before.id))).write(
      DtcSnapshotsCompanion(
        clearOutcome: Value(
          afterCodes.isEmpty
              ? ClearOutcome.cleared
              : ClearOutcome.codesReturned,
        ),
        relatedSnapshotId: Value(after.id),
      ),
    );
    return after;
  });

  /// The ECU said no (common with the engine running), or the link dropped
  /// before Mode 04 was answered.
  Future<void> failClear(String beforeSnapshotId, ClearOutcome outcome) =>
      (_db.update(_t)..where((s) => s.id.equals(beforeSnapshotId))).write(
        DtcSnapshotsCompanion(clearOutcome: Value(outcome)),
      );

  /// `beforeClear` rows still `pending` — the app died mid-clear. Check on
  /// every launch; each one needs a re-read or an explicit [failClear].
  Future<List<DtcSnapshotRow>> unreconciledClears([String? vehicleId]) =>
      (_db.select(_t)
            ..where(
              (s) =>
                  s.purpose.equalsValue(SnapshotPurpose.beforeClear) &
                  s.clearOutcome.equalsValue(ClearOutcome.pending) &
                  (vehicleId == null
                      ? const Constant(true)
                      : s.vehicleId.equals(vehicleId)),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.takenAt)]))
          .get();

  Future<DtcSnapshotRow> _insert({
    required String vehicleId,
    required SnapshotPurpose purpose,
    required List<RawDtc> codes,
    bool? milOn,
    int? dtcCount,
    Map<String, Object?>? readiness,
    int? protocol,
    ClearOutcome? clearOutcome,
    String? relatedSnapshotId,
    DateTime? now,
  }) async {
    final id = newId();
    await _db
        .into(_t)
        .insert(
          DtcSnapshotsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            takenAt: utc(now ?? utcNow()),
            purpose: purpose,
            codesJson: encodeCodes(codes),
            milOn: Value(milOn),
            dtcCount: Value(dtcCount),
            readinessJson: Value(
              readiness == null ? null : jsonEncode(readiness),
            ),
            protocol: Value(protocol),
            clearOutcome: Value(clearOutcome),
            relatedSnapshotId: Value(relatedSnapshotId),
          ),
        );
    return (await byId(id))!;
  }

  static String encodeCodes(List<RawDtc> codes) => jsonEncode([
    for (final c in codes) {'code': c.code, 'mode': c.mode.name},
  ]);

  /// Tolerant: an unknown mode name or a malformed entry drops that entry,
  /// not the snapshot.
  static List<RawDtc> decodeCodes(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map && e['code'] is String)
            RawDtc(
              e['code'] as String,
              DtcMode.values.firstWhere(
                (m) => m.name == e['mode'],
                orElse: () => DtcMode.stored,
              ),
            ),
      ];
    } on FormatException {
      return const [];
    }
  }
}

extension DtcSnapshotRowX on DtcSnapshotRow {
  List<RawDtc> get codes => DtcRepository.decodeCodes(codesJson);
  bool get isPendingClear =>
      purpose == SnapshotPurpose.beforeClear &&
      clearOutcome == ClearOutcome.pending;
}
