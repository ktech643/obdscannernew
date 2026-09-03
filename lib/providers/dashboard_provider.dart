import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// The scenario the dashboard is rendering. The board draws each of these as
/// its own frame (C1–C3, N1, N2, N5); here they are one screen driven by state.
enum DashboardScenario { healthy, caution, degraded, diesel, hybrid, imperial }

/// Live gauge data, the tile layout, and the trip strip.
///
/// Sample history lives here rather than in view state, so a rebuild or a
/// rotation never loses a sparkline.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider() {
    _tiles = _scenarioTiles(DashboardScenario.healthy);
  }

  DashboardScenario _scenario = DashboardScenario.healthy;
  DashboardScenario get scenario => _scenario;

  late List<GaugeReading> _tiles;
  List<GaugeReading> get tiles => List.unmodifiable(_tiles);

  bool _editing = false;
  bool get editing => _editing;

  /// Free tier ceiling. Pro lifts it and adds named layouts per vehicle.
  int get tileCeiling => 6;

  /// Speed in km/h, used for the safety gates. Null when the PID is
  /// unsupported — the clear-codes gate treats that case explicitly.
  double? _speedKmh = 68;
  double? get speedKmh => _speedKmh;

  /// Gauge editing is disabled above 5 km/h; the display stays live.
  bool get editingAllowed => (_speedKmh ?? 0) <= 5;

  bool get stationary => _speedKmh != null && _speedKmh == 0;

  bool _recording = false;
  bool get recording => _recording;

  bool _tripPaused = false;
  bool get tripPaused => _tripPaused;

  double _tripKm = 12.4;
  int _tripMinutes = 18;
  double _tripAvg = 41;

  String get tripLine {
    if (_tripPaused) return 'Trip paused · ${_tripKm.toStringAsFixed(1)} km';
    return switch (_scenario) {
      DashboardScenario.diesel => 'Trip 12.4 km · 5.1 L/100 km',
      DashboardScenario.hybrid => 'Trip 6.2 km · 3.1 km on electric',
      DashboardScenario.imperial => 'Trip 7.7 mi · 18 min · avg 26 mph',
      _ =>
        'Trip ${_tripKm.toStringAsFixed(1)} km · $_tripMinutes min · '
            'avg ${_tripAvg.toStringAsFixed(0)} km/h',
    };
  }

  /// Rewarded ads unlock two extra tiles for 60 minutes. Offered, never
  /// required.
  DateTime? _rewardExpiry;
  bool get rewardActive =>
      _rewardExpiry != null && _rewardExpiry!.isAfter(DateTime.now());

  /// A rolling window of samples for the full-screen graph. Capped at the
  /// 5-minute view the design shows.
  final List<double> _history = [];
  List<double> get history => List.unmodifiable(_history);

  Timer? _pump;
  final _rng = Random(7);

  // ---------------------------------------------------------------- data
  static const _healthy = <GaugeReading>[
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 2480,
      display: '2,480',
      position: 34,
      cautionAt: 78,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 68,
      position: 42,
      cautionAt: 80,
      criticalAt: 94,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 89,
      position: 52,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(
      pid: '0104',
      label: 'Engine load',
      unit: '%',
      value: 34,
      position: 34,
      cautionAt: 80,
      criticalAt: 94,
    ),
    GaugeReading(
      pid: 'ATRV',
      label: 'Battery',
      unit: 'V',
      value: 14.2,
      display: '14.2',
      position: 62,
      cautionAt: 82,
      criticalAt: 93,
    ),
    GaugeReading(
      pid: '0111',
      label: 'Throttle',
      unit: '%',
      value: 12,
      position: 12,
      cautionAt: 84,
      criticalAt: 95,
    ),
  ];

  static const _caution = <GaugeReading>[
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 2510,
      display: '2,510',
      position: 36,
      cautionAt: 78,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 71,
      position: 44,
      cautionAt: 80,
      criticalAt: 94,
    ),
    // The whole design of this frame is the contrast between one amber tile
    // and five monochrome ones.
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 112,
      tone: Tone.caution,
      note: 'Caution',
      position: 84,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(
      pid: '0104',
      label: 'Engine load',
      unit: '%',
      value: 61,
      position: 61,
      cautionAt: 80,
      criticalAt: 94,
    ),
    GaugeReading(
      pid: 'ATRV',
      label: 'Battery',
      unit: 'V',
      value: 14.1,
      display: '14.1',
      position: 60,
      cautionAt: 82,
      criticalAt: 93,
    ),
    GaugeReading(
      pid: '0106',
      label: 'Fuel trim B1',
      unit: '%',
      value: 4.7,
      display: '+4.7',
      position: 55,
      cautionAt: 78,
      criticalAt: 92,
    ),
  ];

  static const _degraded = <GaugeReading>[
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 2480,
      display: '2,480',
      position: 34,
      cautionAt: 78,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 68,
      state: TileState.stale,
      note: '4 s ago',
      position: 42,
      cautionAt: 80,
      criticalAt: 94,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 89,
      state: TileState.stale,
      note: '6 s ago',
      position: 52,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(
      pid: '0104',
      label: 'Engine load',
      unit: '%',
      display: '—',
      state: TileState.stale,
      note: 'No data',
      cautionAt: 80,
      criticalAt: 94,
    ),
    GaugeReading(
      pid: 'ATRV',
      label: 'Battery',
      unit: 'V',
      value: 13.9,
      display: '13.9',
      position: 55,
      cautionAt: 82,
      criticalAt: 93,
    ),
    GaugeReading(
      pid: '015C',
      label: 'Oil temp',
      unit: '°C',
      state: TileState.unsupported,
    ),
  ];

  static const _diesel = <GaugeReading>[
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 1910,
      display: '1,910',
      position: 30,
    ),
    GaugeReading(
      pid: '0170',
      label: 'Boost',
      unit: 'bar',
      value: 0.82,
      display: '0.82',
      position: 48,
      cautionAt: 80,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 89,
      position: 52,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(
      pid: '015C',
      label: 'Oil temp',
      unit: '°C',
      value: 96,
      position: 56,
      cautionAt: 78,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '015E',
      label: 'Fuel rate',
      unit: 'L/h',
      value: 4.8,
      display: '4.8',
      position: 38,
    ),
    GaugeReading(
      pid: '0144',
      label: 'Lambda',
      unit: '',
      state: TileState.unsupported,
    ),
  ];

  static const _hybrid = <GaugeReading>[
    // Zero is a value, not missing data. These tiles are live — full opacity,
    // no clock glyph.
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 0,
      note: 'EV mode',
    ),
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 34,
      position: 22,
    ),
    GaugeReading(
      pid: 'ATRV',
      label: 'Battery',
      unit: 'V',
      value: 13.9,
      display: '13.9',
      position: 54,
      cautionAt: 82,
      criticalAt: 93,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 62,
      position: 28,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(pid: '0104', label: 'Engine load', unit: '%', value: 0),
    GaugeReading(
      pid: '0146',
      label: 'Ambient',
      unit: '°C',
      value: 16,
      position: 42,
    ),
  ];

  static const _imperial = <GaugeReading>[
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 2480,
      display: '2,480',
      position: 34,
    ),
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'mph',
      value: 42,
      position: 42,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°F',
      value: 192,
      position: 52,
      cautionAt: 76,
      criticalAt: 90,
    ),
    GaugeReading(
      pid: '010B',
      label: 'Intake',
      unit: 'psi',
      value: 14.7,
      display: '14.7',
      position: 46,
    ),
    GaugeReading(
      pid: 'ATRV',
      label: 'Battery',
      unit: 'V',
      value: 14.2,
      display: '14.2',
      position: 62,
      cautionAt: 82,
      criticalAt: 93,
    ),
    // MPG is never unqualified — (US) and (UK) differ by 20%.
    GaugeReading(
      pid: '015E',
      label: 'Economy',
      unit: 'MPG (US)',
      value: 24.6,
      display: '24.6',
      position: 55,
    ),
  ];

  static List<GaugeReading> _scenarioTiles(DashboardScenario s) => switch (s) {
    DashboardScenario.healthy => List.of(_healthy),
    DashboardScenario.caution => List.of(_caution),
    DashboardScenario.degraded => List.of(_degraded),
    DashboardScenario.diesel => List.of(_diesel),
    DashboardScenario.hybrid => List.of(_hybrid),
    DashboardScenario.imperial => List.of(_imperial),
  };

  String? get cautionExplainer => switch (_scenario) {
    DashboardScenario.caution =>
      'Caution — coolant above its normal band. 112 °C is outside 80–105 °C. '
          'If it keeps climbing, stop and let the engine cool.',
    _ => null,
  };

  String? get degradedExplainer => switch (_scenario) {
    DashboardScenario.degraded =>
      'Your adapter is answering in about 640 ms, so Torque has dropped to 2 Hz. '
          'This is normal for budget adapters. Dimmed tiles are showing their '
          'last known value, not a live one.',
    _ => null,
  };

  String get stripText => switch (_scenario) {
    DashboardScenario.diesel => 'CAN 11/500 · COMPRESSION',
    DashboardScenario.hybrid => 'CAN 11/500 · HYBRID',
    DashboardScenario.caution => 'CAN 11/500 · 14.1 V · 8 Hz',
    _ => 'CAN 11/500 · 14.2 V · 8 Hz',
  };

  String get vehicleName => switch (_scenario) {
    DashboardScenario.hybrid => 'The Yaris',
    DashboardScenario.imperial => 'The Mustang',
    _ => 'The Golf',
  };

  // ------------------------------------------------------------ commands
  void setScenario(DashboardScenario s) {
    _scenario = s;
    _tiles = _scenarioTiles(s);
    _speedKmh = _tiles
        .firstWhere(
          (t) => t.pid == '010D',
          orElse: () => const GaugeReading(pid: '', label: '', unit: ''),
        )
        .value;
    notifyListeners();
  }

  void setEditing(bool value) {
    if (value && !editingAllowed) return; // safety gate
    _editing = value;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final tile = _tiles.removeAt(oldIndex);
    _tiles.insert(newIndex, tile);
    notifyListeners();
  }

  void removeTile(String pid) {
    _tiles.removeWhere((t) => t.pid == pid);
    notifyListeners();
  }

  void addTile(GaugeReading tile) {
    _tiles.add(tile);
    notifyListeners();
  }

  void toggleRecording() {
    _recording = !_recording;
    notifyListeners();
  }

  void grantRewardUnlock() {
    _rewardExpiry = DateTime.now().add(const Duration(minutes: 60));
    notifyListeners();
  }

  void setSpeed(double? kmh) {
    _speedKmh = kmh;
    notifyListeners();
  }

  /// Seeds the 5-minute window behind the full-screen graph.
  void seedHistory({double min = 742, double max = 4180, int samples = 90}) {
    if (_history.isNotEmpty) return;
    var v = 2100.0;
    for (var i = 0; i < samples; i++) {
      v += (_rng.nextDouble() - 0.48) * 620;
      _history.add(v.clamp(min, max));
    }
  }

  @override
  void dispose() {
    _pump?.cancel();
    super.dispose();
  }
}
