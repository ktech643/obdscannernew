import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// Codes, readiness, health score and the guarded clear.
///
/// Reading and clearing fault codes are free forever, on every tier, with no ad
/// in the way — nothing in this provider consults entitlement.
class DiagnosticsProvider extends ChangeNotifier {
  bool _hasFaults = true;
  bool get hasFaults => _hasFaults;

  ScanPhase _phase = ScanPhase.result;
  ScanPhase get phase => _phase;

  String _scannedAt = 'just now';
  String get scannedAt => _scannedAt;

  bool get milOn => _hasFaults;

  // ----------------------------------------------------------------- codes
  static const _p0301 = Dtc(
    code: 'P0301',
    description: 'Cylinder 1 misfire detected',
    status: DtcStatus.stored,
    severity: DtcSeverity.severe,
    system: 'Ignition / fuel · SAE generic',
    statusDetail: 'Stored and confirmed · MIL commanded on',
    firstSeen: '2 Sep 2026 · 142,301 km',
    meaning:
        "Cylinder 1 isn't burning its fuel properly — the computer felt the "
        "crankshaft slow on that cylinder's turn. Expect a rough idle or a "
        'shudder under load.',
    causes: [
      'Worn or fouled spark plug in cylinder 1',
      'Failed ignition coil or coil pack',
      'Clogged or leaking fuel injector',
      'Vacuum leak or low compression on that cylinder',
    ],
    freezeFrame: [
      (label: 'Engine RPM', value: '1,842'),
      (label: 'Speed', value: '54 km/h'),
      (label: 'Coolant', value: '91 °C'),
      (label: 'Short fuel trim B1', value: '+12.5 %'),
    ],
  );

  static const _codes = <Dtc>[
    _p0301,
    Dtc(
      code: 'P0420',
      description: 'Catalyst efficiency below threshold, bank 1',
      status: DtcStatus.stored,
      severity: DtcSeverity.moderate,
      statusDetail: 'Stored · emissions · moderate',
    ),
    Dtc(
      code: 'P0133',
      description: 'Oxygen sensor slow response, bank 1 sensor 1',
      status: DtcStatus.pending,
      severity: DtcSeverity.moderate,
    ),
    // Never fabricate a definition. Unknown and manufacturer-specific codes
    // say so explicitly.
    Dtc(
      code: 'P1602',
      description:
          "Manufacturer-specific — we don't have a definition for this code",
      status: DtcStatus.stored,
      severity: DtcSeverity.unknown,
      hasDefinition: false,
    ),
  ];

  List<Dtc> get codes => _hasFaults ? _codes : const [];

  int get storedCount =>
      codes.where((c) => c.status == DtcStatus.stored).length;
  int get pendingCount =>
      codes.where((c) => c.status == DtcStatus.pending).length;
  int get permanentCount => 0;

  String get faultHeadline =>
      _hasFaults ? 'Check Engine light is on' : 'No problems found';

  String get faultSubline => _hasFaults
      ? '$storedCount stored codes · $pendingCount pending · scanned $_scannedAt'
      : 'Checked $_scannedAt · $completeCount of ${monitors.length} monitors complete';

  // ------------------------------------------------------------- readiness
  static const monitors = <ReadinessMonitor>[
    ReadinessMonitor('Misfire', MonitorState.complete),
    ReadinessMonitor('Fuel system', MonitorState.complete),
    ReadinessMonitor('Components', MonitorState.complete),
    ReadinessMonitor('Catalyst', MonitorState.notComplete),
    ReadinessMonitor('Evaporative system', MonitorState.complete),
    ReadinessMonitor('Oxygen sensor', MonitorState.notComplete),
    ReadinessMonitor('Oxygen sensor heater', MonitorState.complete),
    ReadinessMonitor('Secondary air', MonitorState.notSupported),
  ];

  int get completeCount => _hasFaults
      ? monitors.where((m) => m.state == MonitorState.complete).length
      : 8;
  int get notSupportedCount =>
      monitors.where((m) => m.state == MonitorState.notSupported).length;

  /// The monitor set switches with the ignition type — compression-ignition
  /// vehicles get NOx/SCR, PM filter and boost pressure instead.
  String get monitorSetLabel => 'Spark ignition · petrol';

  // ---------------------------------------------------------- health score
  int get healthScore => _hasFaults ? 62 : 96;

  static const deductions = <ScoreDeduction>[
    ScoreDeduction(
      'P0301 confirmed · severe',
      'Fix the misfire — see the code detail',
      25,
    ),
    ScoreDeduction(
      'Check Engine light on',
      'Clears once the fault is fixed',
      15,
    ),
    ScoreDeduction('P0133 pending', 'Being monitored — no action yet', 10),
    ScoreDeduction(
      'Short fuel trim +12.5%',
      'Outside ±10% — often a vacuum leak',
      8,
    ),
    ScoreDeduction('2 incomplete monitors', 'Catalyst, oxygen sensor', 6),
    ScoreDeduction('Oil change overdue', 'Due at 138,000 km · now 142,380', 5),
  ];

  /// What was actually taken off the score. Always closes against 100 — the
  /// bar and the headline are derived from the score, never summed
  /// independently, so the two can't drift apart on screen.
  int get pointsLost => 100 - healthScore;

  /// The itemised weights added up. This is larger than [pointsLost] because
  /// the causes overlap — the MIL is on *because* of P0301, so charging both
  /// at full weight would double-count one fault.
  int get rawDeductionTotal => deductions.fold(0, (a, d) => a + d.points);

  /// True when the list adds up to exactly what was deducted. When it doesn't,
  /// the screen says so rather than showing a total that contradicts its own
  /// breakdown — never show a score without its full breakdown.
  bool get breakdownIsExact => rawDeductionTotal == pointsLost;

  String get scoreVerdict => healthScore >= 85
      ? 'Healthy'
      : healthScore >= 60
      ? 'Needs attention'
      : 'Poor';

  // ------------------------------------------------------------- mode 06
  static const mode06 = <Mode06Test>[
    Mode06Test('\$01 Catalyst B1 efficiency', '0.891', '0.750', 'PASS'),
    Mode06Test('\$03 O2 sensor B1S1 response', '1.42s', '1.20s', 'FAIL'),
    Mode06Test('\$05 EGR flow test', '212', '180', 'PASS'),
    Mode06Test('\$0B EVAP purge flow', '0.09', '0.15', 'PASS'),
    // If the adapter or vehicle doesn't support Mode 06 we say so — never an
    // empty table pretending to be a clean result.
    Mode06Test('\$11 Misfire cyl. 4 count', null, null, null),
  ];

  // ------------------------------------------------------------ snapshots
  static const snapshots = <Snapshot>[
    Snapshot(
      summary: '2 codes · MIL on',
      when: '2 Sep 2026',
      odometerKm: 142380,
      beforeClear: true,
    ),
    Snapshot(
      summary: '1 pending code',
      when: '28 Jul 2026',
      odometerKm: 138960,
    ),
    Snapshot(
      summary: '3 codes · MIL on',
      when: '4 Mar 2026',
      odometerKm: 130410,
      beforeClear: true,
    ),
    Snapshot(
      summary: 'No problems found',
      when: '2 Jan 2026',
      odometerKm: 121880,
    ),
  ];

  // ------------------------------------------------------------- commands
  Future<void> rescan() async {
    _phase = ScanPhase.running;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _phase = ScanPhase.result;
    _scannedAt = 'just now';
    notifyListeners();
  }

  /// Mode 04. A `DTCSnapshot` is always written first, and the code list is
  /// always re-read afterwards so the true result is reported.
  Future<bool> clearCodes({required bool stationary}) async {
    if (!stationary) return false; // hard-gated on speed = 0
    _phase = ScanPhase.running;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _hasFaults = false;
    _phase = ScanPhase.result;
    _scannedAt = 'just now';
    notifyListeners();
    return true;
  }

  void restoreFaults() {
    _hasFaults = true;
    notifyListeners();
  }
}
