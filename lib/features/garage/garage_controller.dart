import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/dtc_repository.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../models/enums.dart';
import '../../protocol/vin_reader.dart';
import '../../session/obd_session.dart';
import 'service_intervals.dart';
import 'vehicle_identity.dart';

/// SPEC §5.5 — the vehicles, and §9.6 — which one is plugged in.
///
/// The garage is the thing every record hangs off: a scan, a trip, a
/// service entry all need a `vehicleId`. Until a vehicle exists nothing is
/// recorded and the screens say so. This controller owns that list, keeps
/// exactly one primary, and on every connect decides whether the car on
/// the wire *is* the primary — before anything is written under its name.
class GarageController extends ChangeNotifier {
  GarageController({
    required this.vehicles,
    this.services,
    this.trips,
    this.dtcs,
  }) {
    _sub = vehicles.watchAll().listen((rows) {
      _rows = rows;
      if (!_loaded) {
        _loaded = true;
        _ready.complete();
      }
      _watchPrimary();
      _reconsider();
      _notify();
    });
  }

  StreamSubscription<Object?>? _snapshotSub;
  StreamSubscription<Object?>? _reminderSub;
  String? _watching;
  int _revision = 0;

  /// Bumped whenever a diagnostic snapshot or a reminder changes for the
  /// primary vehicle. The garage's counts change on *other* tabs — a scan
  /// on Diagnostics, a reminder ticked off — while the Garage stays
  /// mounted in the tab stack; the screen re-reads when this moves.
  int get revision => _revision;

  void _watchPrimary() {
    final p = primary;
    if (p?.id == _watching) return;
    _watching = p?.id;
    _snapshotSub?.cancel();
    _reminderSub?.cancel();
    if (p == null) return;
    _snapshotSub = dtcs?.watchLatest(p.id).listen((_) => _bump());
    _reminderSub = services?.watchReminders(p.id).listen((_) => _bump());
  }

  void _bump() {
    _revision++;
    _notify();
  }

  final _ready = Completer<void>();

  /// Completes once the garage has been read from disk. A connect can
  /// land before the first row does, and judging a VIN against an empty
  /// list would call every car a stranger — so [onConnected] waits here.
  Future<void> get ready => _ready.future;

  final VehicleRepository vehicles;
  final ServiceRepository? services;

  /// Trip *files* live outside the database and the row cascade cannot
  /// reach them; deleting a vehicle removes them through here first.
  final TripRepository? trips;
  final DtcRepository? dtcs;

  StreamSubscription<List<VehicleRow>>? _sub;
  List<VehicleRow> _rows = const [];
  bool _loaded = false;
  bool _disposed = false;

  /// Primary first, then by creation — the repository's order.
  List<VehicleRow> get all => _rows;

  /// False until the first read lands, so an empty garage is not drawn
  /// for a frame before a full one.
  bool get loaded => _loaded;

  VehicleRow? get primary {
    for (final v in _rows) {
      if (v.isPrimary) return v;
    }
    return null;
  }

  List<VehicleRow> get others => [
    for (final v in _rows)
      if (!v.isPrimary) v,
  ];

  /// §7.2: one vehicle free, unlimited on Pro. The screen decides what to
  /// show; this is just the count that matters.
  bool get hasVehicle => _rows.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _snapshotSub?.cancel();
    _reminderSub?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------ the list

  Future<VehicleRow> add({
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
  }) => vehicles.create(
    nickname: nickname,
    fuel: fuel,
    vin: vin,
    vinUnverified: vinUnverified,
    make: make,
    model: model,
    trim: trim,
    year: year,
    odometerKm: odometerKm,
    plate: plate,
  );

  Future<void> setPrimary(String id) => vehicles.setPrimary(id);

  Future<void> updateOdometer(String id, double km) =>
      vehicles.updateOdometer(id, km);

  /// Files first, then the row; the cascade takes every record with it.
  Future<void> delete(String id) async {
    await trips?.deleteAllFor(id);
    await vehicles.delete(id);
  }

  // --------------------------------------------------------- what it holds

  /// Reminders past their date or their odometer, for the −5 each in the
  /// health breakdown and the "overdue" word on the garage card. Paused
  /// and completed ones do not count.
  Future<int> overdueCount(
    String vehicleId, {
    double? odometerKm,
    DateTime? now,
  }) async {
    final s = services;
    if (s == null) return 0;
    final at = now ?? DateTime.now();
    // The one rule, shared with the reminders list, so the card's count and
    // the list's "Overdue" section can never disagree.
    var n = 0;
    for (final r in await s.reminders(vehicleId)) {
      if (reminderStatus(r, odometerKm: odometerKm, now: at) ==
          ReminderStatus.overdue) {
        n++;
      }
    }
    return n;
  }

  Future<int> snapshotCount(String vehicleId) async {
    final d = dtcs;
    if (d == null) return 0;
    return (await d.history(vehicleId, limit: 1000)).length;
  }

  // -------------------------------------------------------- §9.6 identity

  IdentityVerdict? _pending;

  /// A verdict the user has to answer before anything is recorded. Null
  /// when the car on the wire is the primary, or when it answered no VIN.
  IdentityVerdict? get pendingIdentity => _pending;

  /// The verdict of the last connect, prompt or no prompt, for the garage
  /// card to show what the car said.
  IdentityVerdict? _last;
  IdentityVerdict? get lastIdentity => _last;

  /// Call once the session is live. Reads the VIN — twice if the first
  /// read fails its check digit, as §9.6 says — caches what the handshake
  /// learned on the vehicle it belongs to, and decides whether the car is
  /// the primary.
  ///
  /// Returns the verdict; a [IdentityVerdict.needsPrompt] one is also left
  /// in [pendingIdentity] until [answerIdentity] is called.
  Future<IdentityVerdict> onConnected(ObdSession session) async {
    final epoch = ++_epoch;
    await ready;
    var read = await session.readVin();
    if (read != null && !read.checkDigitValid) {
      // §9.6: re-read once. A clone that dropped a character the first
      // time usually gets it right the second.
      read = await session.readVin() ?? read;
    }

    final verdict = resolveIdentity(
      read: read,
      primary: primary,
      garage: _rows,
    );
    // The link went away, or a newer connect began, while the VIN was
    // being read: this verdict is about a car no longer on the wire, and
    // applying it now would ask a question — or cache a protocol — for the
    // wrong connection.
    if (epoch != _epoch) return verdict;
    _session = session;
    _read = read;
    _readThisConnection = true;
    await _apply(verdict);
    return verdict;
  }

  /// Call when the link drops. A verdict describes the car *on the wire*;
  /// with no wire there is no car to describe, so nothing about it may
  /// carry into the next connection — or into Demo Mode, which must never
  /// inherit a real car's "Connected".
  void onDisconnected() {
    _epoch++;
    _session = null;
    _read = null;
    _readThisConnection = false;
    _verdictPrimaryId = null;
    _last = null;
    _pending = null;
    _notify();
  }

  int _epoch = 0;
  ObdSession? _session;
  VinResult? _read;
  bool _readThisConnection = false;

  /// The primary the current verdict was judged against.
  String? _verdictPrimaryId;

  /// A verdict is relative to the primary it was judged against. When the
  /// primary changes under a live connection — "Make primary", or deleting
  /// the primary so another is promoted — the same VIN has to be judged
  /// again, or the new primary inherits the old one's "Connected" and the
  /// next scan is filed under it unchallenged.
  void _reconsider() {
    if (!_readThisConnection) return;
    if (primary?.id == _verdictPrimaryId) return;
    unawaited(
      _apply(resolveIdentity(read: _read, primary: primary, garage: _rows)),
    );
  }

  Future<void> _apply(IdentityVerdict verdict) async {
    final p = primary;
    // Set before any await, so a row change arriving mid-apply does not
    // judge the same primary twice.
    _verdictPrimaryId = p?.id;
    _last = verdict;
    final session = _session;
    switch (verdict.kind) {
      case IdentityKind.attached:
        // The primary had no VIN and now it does. Flagged if the check
        // digit failed twice, and never decoded from in that case.
        // Two columns, not the whole row: `p` is a snapshot from before
        // the VIN reads, and writing it back would undo anything that
        // changed on the row in the meantime.
        await vehicles.updateDetails(
          p!.id,
          vin: Value(verdict.vin),
          vinUnverified: Value(!verdict.trusted),
        );
        if (session != null) await _cache(session, p.id);
        _pending = null;
      case IdentityKind.primary:
      case IdentityKind.noVin:
        if (p != null && session != null) await _cache(session, p.id);
        _pending = null;
      case IdentityKind.other:
      case IdentityKind.unknown:
        // Nothing is cached and nothing is recorded until the user says
        // which car this is.
        _pending = verdict;
    }
    _notify();
  }

  /// The user's answer to a pending verdict.
  ///
  /// [vehicleId] is the vehicle to record under — the matched one, the
  /// primary anyway, or a vehicle just created for this VIN. It becomes
  /// primary. Null keeps the primary and records nothing extra.
  Future<void> answerIdentity(String? vehicleId, {ObdSession? session}) async {
    final v = _pending;
    _pending = null;
    if (vehicleId != null) {
      await vehicles.setPrimary(vehicleId);
      if (session != null && v != null) await _cache(session, vehicleId);
      // Settled: the car on the wire *is* the primary now, and the card
      // may say so. Answering "record under the primary anyway" settles
      // nothing about identity — the VIN still says otherwise — so that
      // verdict is left as it was and the card shows no "Connected".
      if (v != null) {
        _last = IdentityVerdict(
          IdentityKind.primary,
          vin: v.vin,
          trusted: v.trusted,
        );
      }
    }
    _notify();
  }

  /// SPEC §4.2: the protocol that worked and the PIDs the car supports,
  /// keyed on the vehicle, so the next connect skips the ladder.
  Future<void> _cache(ObdSession session, String vehicleId) async {
    final protocol = session.protocol?.number;
    final pids = session.supportedPids.toList()..sort();
    if (protocol == null && pids.isEmpty) return;
    await vehicles.cacheConnection(
      vehicleId,
      protocol: protocol,
      supportedPids: pids.isEmpty ? null : pids,
    );
  }

  /// A VIN typed by hand, judged the same way a read one is (§9.6, §9.8).
  /// Null means it is not a VIN at all; an untrusted result is allowed
  /// through, flagged.
  static VinResult? judgeTypedVin(String raw) =>
      raw.trim().isEmpty ? null : VinReader.validate(raw);
}
