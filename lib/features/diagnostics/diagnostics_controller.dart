import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/dtc_dictionary.dart';
import '../../data/repositories/dtc_repository.dart';
import '../../protocol/dtc_decoder.dart';
import '../../protocol/vin_reader.dart';
import '../../session/health_score.dart';
import '../../session/obd_session.dart';

/// Where the scan is.
enum ScanPhase {
  /// Never run on this connection.
  idle,

  running,

  /// Finished. The result may still be partial — see
  /// [DtcReadResult.complete].
  done,
}

/// One step of the scan, in the order §5.4 fixes.
///
/// The label is what the user reads while it runs, and it names the thing
/// actually on the wire at that moment — not a progress bar with invented
/// stages.
class ScanStep {
  const ScanStep(this.mode, this.label);
  final String mode;
  final String label;

  static const all = [
    ScanStep('03', 'Reading stored codes'),
    ScanStep('07', 'Reading pending codes'),
    ScanStep('0A', 'Reading permanent codes'),
    ScanStep('0101', 'Reading the warning light and monitors'),
    ScanStep('0902', 'Reading the VIN'),
    ScanStep('live', 'Reading live values'),
  ];

  static int indexOf(String mode) =>
      all.indexWhere((s) => s.mode == mode).clamp(0, all.length - 1);
}

/// Drives SPEC §5.4 — the scan, the clear, and the §9.5 reconciliation of
/// a clear that was interrupted.
///
/// The screen holds none of this. It listens, reads, and draws; every
/// decision about what the car said lives here, so the wording the user
/// gets is decided in one place and can be tested without a widget tree.
class DiagnosticsController extends ChangeNotifier {
  DiagnosticsController({
    required this.session,
    this.dictionary = const EmptyDtcDictionary(),
    this.dtcs,
    String? vehicleId,
    this.overdueReminders = 0,
  }) {
    _vehicleId = vehicleId;
  }

  final ObdSession session;
  final DtcDictionary dictionary;

  /// Null in tests that do not exercise history. Without it a scan is not
  /// recorded and a clear keeps no snapshot — which is why the sheet says
  /// so rather than claiming a snapshot it did not write.
  final DtcRepository? dtcs;

  String? _vehicleId;

  /// Which car the snapshots belong to. Null until the Garage names one,
  /// which is why it is settable: the primary vehicle is read from the
  /// database after this controller already exists.
  String? get vehicleId => _vehicleId;
  set vehicleId(String? id) {
    if (_vehicleId == id) return;
    _vehicleId = id;
    _notify();
  }

  /// Counted by the Garage; feeds the −5 each in the health breakdown.
  final int overdueReminders;

  /// PIDs the health score wants that the Dashboard may not be polling.
  static const _healthPids = ['0105', '0106', '0107', '0142'];

  ScanPhase _phase = ScanPhase.idle;
  ScanPhase get phase => _phase;

  DtcReadResult? _result;
  DtcReadResult? get result => _result;

  VinResult? _vin;
  VinResult? get vin => _vin;

  HealthScore? _health;
  HealthScore? get health => _health;

  DateTime? _scannedAt;

  /// When the result on screen was read. Shown with every empty state, so
  /// "no codes" is always anchored to a moment rather than floating.
  DateTime? get scannedAt => _scannedAt;

  String? _stepLabel;
  String? get stepLabel => _stepLabel;

  int _stepIndex = 0;
  int get stepIndex => _stepIndex;
  int get stepCount => ScanStep.all.length;

  final Map<String, DtcDefinition?> _definitions = {};

  /// The dictionary entry for [code], or null — which the UI must render
  /// as "unknown", never as a guess (hard rule 7).
  DtcDefinition? definitionFor(String code) => _definitions[code];

  ClearResult? _lastClear;

  /// How the last clear attempt ended, or null if none was made on this
  /// connection.
  ClearResult? get lastClear => _lastClear;

  List<DtcSnapshotRow> _unreconciled = const [];

  /// §9.5 — `beforeClear` snapshots still `pending` because the app died
  /// or the link dropped mid-clear. Non-empty means the screen must say
  /// the last clear was never verified.
  List<DtcSnapshotRow> get unreconciled => _unreconciled;

  bool _busy = false;

  /// True while a scan or a clear is in flight. One at a time: both hold
  /// the link for several round trips and overlapping them would
  /// interleave two conversations about the same codes.
  bool get busy => _busy;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------- the scan

  /// Runs §5.4's five steps in order, then the live values the health
  /// score needs. Safe to call when disconnected: it returns without
  /// pretending, leaving whatever was last read on screen as *last read*.
  Future<void> scan() async {
    if (_busy || !session.isLive) return;
    _busy = true;
    _phase = ScanPhase.running;
    _stepIndex = 0;
    _stepLabel = ScanStep.all.first.label;
    // A previous clear's verdict describes a reading this scan is about to
    // replace. Leaving it up would put "codes cleared" above a fresh list
    // it says nothing about.
    _lastClear = null;
    _notify();

    try {
      final result = await session.readDtcs(onStep: _onStep);
      // Installed before the VIN so a car that does not answer Mode 09
      // does not leave the previous scan's codes on screen while it times
      // out.
      _result = result;
      _notify();

      _step('0902');
      _vin = await session.readVin();

      _step('live');
      await _install(result);

      final vehicle = _vehicleId;
      if (dtcs != null && vehicle != null) {
        await dtcs!.recordScan(
          vehicleId: vehicle,
          codes: result.all,
          milOn: result.milOn,
          dtcCount: result.reportedCount,
          protocol: session.protocol?.number,
          now: _scannedAt,
        );
      }
      _phase = ScanPhase.done;
    } catch (_) {
      // Nothing below the session throws today, but a scan is the longest
      // thing this screen does and a stranded "Scanning…" with no way out
      // is the worst way to be wrong. Whatever was read stays on screen,
      // labelled with the time it was read.
      _phase = ScanPhase.done;
    } finally {
      _busy = false;
      _stepLabel = null;
      _notify();
    }
  }

  /// Makes [result] what the screen shows: its codes, their definitions,
  /// the time it was read, and a health score computed from it and from
  /// live values read *now*.
  ///
  /// One place on purpose. Every caller — scan, clear, reconcile — has to
  /// do the same four things, and a reconcile that swapped the codes but
  /// left the old score beside them is precisely what happens when they
  /// drift apart.
  Future<void> _install(DtcReadResult result) async {
    _result = result;
    await _loadDefinitions(result.all);

    final live = <String, double?>{};
    for (final pid in _healthPids) {
      live[pid] = await session.readPidOnce(pid);
    }
    // The adapter's own voltage is the reliable one — PID 0142 is the
    // ECU's control-module voltage and plenty of cars do not answer it.
    final volts = await session.readBatteryVolts() ?? live['0142'];

    _scannedAt = DateTime.now();
    _health = HealthScore.compute(
      stored: result.stored,
      pending: result.pending,
      permanent: result.permanent,
      milOn: result.milOn,
      readiness: result.readiness,
      severities: {
        for (final d in result.all) d.code: _definitions[d.code]?.severity,
      },
      batteryVolts: volts,
      coolantC: live['0105'],
      fuelTrims: [live['0106'], live['0107']],
      overdueReminders: overdueReminders,
      failedModes: result.failedModes,
    );
    _notify();
  }

  void _onStep(String mode) => _step(mode);

  void _step(String mode) {
    _stepIndex = ScanStep.indexOf(mode);
    _stepLabel = ScanStep.all[_stepIndex].label;
    _notify();
  }

  Future<void> _loadDefinitions(List<RawDtc> codes) async {
    for (final dtc in codes) {
      if (_definitions.containsKey(dtc.code)) continue;
      _definitions[dtc.code] = await dictionary.lookup(dtc.code);
    }
  }

  // ------------------------------------------------------------ the clear

  /// A fresh speed reading for the §9.5 hard gate.
  ///
  /// Deliberately not the bus's last value: the gate is a safety decision
  /// and a stale zero from five seconds ago is exactly the reading that
  /// must not be trusted (hard rule 4). Null means we could not ask, which
  /// the sheet treats as "not safe", not as zero.
  Future<double?> readSpeed() => session.readPidOnce('010D');

  /// SPEC §9.5. The snapshot goes in before Mode 04; the codes are always
  /// re-read after; the result is reported as it happened.
  Future<ClearResult> clear() async {
    if (_busy) return ClearResult.interrupted;
    _busy = true;
    _notify();
    try {
      // §9.5's verifying re-read is the session's, not a second one of
      // our own: the codes on screen after a clear must be the very
      // reading the verdict was decided on.
      DtcReadResult? after;
      final outcome = await session.clearDtcs(
        vehicleId: vehicleId,
        onReread: (r) => after = r,
      );
      _lastClear = outcome;

      final reread = after;
      if (reread != null) await _install(reread);
      await refreshUnreconciled();
      return outcome;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Codes a clear can never remove, so the sheet can say so up front.
  List<RawDtc> get unclearable => _result?.permanent ?? const [];

  // ---------------------------------------------------------- §9.5 relaunch

  /// Call on entering the screen. A `beforeClear` row still `pending`
  /// means the app died between the snapshot and the verifying re-read —
  /// the codes may or may not be gone, and the only honest thing is to say
  /// so and offer to find out.
  Future<void> refreshUnreconciled() async {
    if (dtcs == null) return;
    _unreconciled = await dtcs!.unreconciledClears(vehicleId);
    _notify();
  }

  /// Settles every pending clear by re-reading the car. Needs a live link;
  /// without one the rows stay pending, which is the correct state.
  Future<bool> reconcile() async {
    if (dtcs == null || _unreconciled.isEmpty || !session.isLive) return false;
    if (_busy) return false;
    _busy = true;
    _notify();
    try {
      final after = await session.readDtcs();
      if (!after.complete) return false;
      for (final row in _unreconciled) {
        await dtcs!.completeClear(
          beforeSnapshotId: row.id,
          afterCodes: after.all,
          milOn: after.milOn,
          dtcCount: after.reportedCount,
          protocol: session.protocol?.number,
        );
      }
      await _install(after);
      return true;
    } finally {
      _busy = false;
      await refreshUnreconciled();
      _notify();
    }
  }
}
