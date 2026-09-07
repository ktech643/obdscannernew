import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';
import '../platform/background_service.dart';
import 'persistence.dart';

/// The scenario the dashboard is rendering. The board draws each of these as
/// its own frame (C1–C3, N1, N2, N5); here they are one screen driven by state.
enum DashboardScenario { healthy, caution, degraded, diesel, hybrid, imperial }

/// Live gauge data, the tile layout, and the trip strip.
///
/// Sample history lives here rather than in view state, so a rebuild or a
/// rotation never loses a sparkline.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._store, {this.vehicleId = 'golf'}) {
    _tiles = _scenarioTiles(DashboardScenario.healthy);
    _restoreLayout();
  }

  final Persistence _store;
  final BackgroundService _background = BackgroundService();

  /// Layouts save per vehicle, so every layout key is scoped by this.
  final String vehicleId;

  /// Rebuilds the saved layout: which tiles are on the dashboard, in what
  /// order, drawn how.
  ///
  /// The stored PID list is authoritative for *membership*, not just order —
  /// otherwise a tile the user removed reappears on the next launch and a tile
  /// they added disappears, which is what "layouts save per vehicle" would
  /// mean if it only ever re-sorted a fixed set.
  void _restoreLayout() {
    _defaultTileType = _store.enumValue(
      Keys.defaultTileType(vehicleId),
      TileType.values,
      TileType.figure,
    );

    final storedTypes = _store.getJson(Keys.tileTypes(vehicleId));
    if (storedTypes != null) {
      for (final entry in storedTypes.entries) {
        final match = TileType.values
            .where((t) => t.name == entry.value)
            .firstOrNull;
        if (match != null) _tileTypes[entry.key] = match;
      }
    }

    final saved = _store.getStringList(Keys.tileOrder(vehicleId));
    if (saved != null) _applyLayout(saved);
    _seedSamples();
  }

  /// The stored PID list is authoritative for *membership*, not just order.
  /// If it only re-sorted a fixed set, a tile the user removed would reappear
  /// on the next launch and one they added would vanish — which is not what
  /// "layouts save per vehicle" says on the edit screen.
  void _applyLayout(List<String> pids) {
    final byPid = {
      for (final c in catalogue) c.pid: c,
      // Live tiles win over the catalogue entry, so a restored tile keeps its
      // current reading rather than the catalogue's placeholder.
      for (final t in _tiles) t.pid: t,
    };
    final rebuilt = [for (final pid in pids) ?byPid[pid]];
    // A layout that resolves to nothing is treated as absent rather than
    // rendering an empty dashboard.
    if (rebuilt.isNotEmpty) _tiles = rebuilt;
  }

  void _persistLayout() {
    _store.setStringList(Keys.tileOrder(vehicleId), [
      for (final t in _tiles) t.pid,
    ]);
    _store.setJson(Keys.tileTypes(vehicleId), {
      for (final e in _tileTypes.entries) e.key: e.value.name,
    });
    _store.setEnum(Keys.defaultTileType(vehicleId), _defaultTileType);
  }

  /// Stands in for the polling loop. Once a second every answering PID gets a
  /// fresh timestamp; a PID that is answering late gets one backdated by its
  /// lag, so it holds a stable age instead of sliding to `—` on its own.
  ///
  /// This is not animating a value — the numerals never move. It keeps the
  /// *age* honest, which is the failure that matters: a tile reading "4 s ago"
  /// forever is lying about how fresh it is, and so is one that decays to
  /// nothing while the adapter is in fact still answering.
  Timer? _pollTicker;

  /// PID → how far behind that PID is answering. Absent means keeping up.
  Map<String, Duration> _lag = const {};

  void _startPolling() {
    _pollTicker?.cancel();
    if (_lag.isEmpty && !_tiles.any((t) => t.lastUpdated != null)) return;
    _poll();
    _pollTicker = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void _poll() {
    final now = DateTime.now();
    _tiles = [
      for (final t in _tiles)
        t.state == TileState.unsupported
            ? t
            : t.copyWith(
                lastUpdated: now.subtract(_lag[t.pid] ?? Duration.zero),
              ),
    ];
    notifyListeners();
  }

  DashboardScenario _scenario = DashboardScenario.healthy;
  DashboardScenario get scenario => _scenario;

  late List<GaugeReading> _tiles;
  List<GaugeReading> get tiles => List.unmodifiable(_tiles);

  bool _editing = false;
  bool get editing => _editing;

  // ------------------------------------------------------------ treatments
  /// The treatment a tile uses when it has no choice of its own. Figure is the
  /// system default — the numeral over its range bar, which is the densest and
  /// least decorative of the five.
  TileType _defaultTileType = TileType.figure;
  TileType get defaultTileType => _defaultTileType;

  /// Per-PID overrides. Tile type is set per tile, per vehicle, so a user can
  /// watch RPM as a trace, load as a bar, and read coolant as a figure —
  /// the treatment follows what the number is for.
  final Map<String, TileType> _tileTypes = {};

  TileType typeFor(String pid) => _tileTypes[pid] ?? _defaultTileType;

  /// The tile the theme picker is targeting. Null means no tile is selected,
  /// in which case a pick applies to the default for every tile.
  String? _selectedPid;
  String? get selectedPid => _selectedPid;

  /// When on, a pick retypes every tile. Otherwise it changes only the tile
  /// the user tapped.
  bool _applyToEveryTile = false;
  bool get applyToEveryTile => _applyToEveryTile;

  void selectTile(String? pid) {
    _selectedPid = pid;
    notifyListeners();
  }

  void setApplyToEveryTile(bool value) {
    _applyToEveryTile = value;
    notifyListeners();
  }

  /// The single entry point for retyping. With [applyToEveryTile] on — or with
  /// no tile selected — this becomes the default and clears every override, so
  /// the grid can't be left in a half-applied state.
  void setTileType(TileType type) {
    if (_applyToEveryTile || _selectedPid == null) {
      _defaultTileType = type;
      _tileTypes.clear();
    } else {
      _tileTypes[_selectedPid!] = type;
    }
    _seedSamples();
    _persistLayout();
    notifyListeners();
  }

  /// The trace treatment needs history the moment it is chosen, or the tile
  /// would draw a flat line until enough samples accumulated.
  void _seedSamples() {
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (typeFor(t.pid) != TileType.trace || t.samples.isNotEmpty) continue;
      _tiles[i] = t.copyWith(samples: _syntheticWindow(t));
    }
  }

  /// A plausible recent window around the tile's current position, so a trace
  /// reads as this PID's history rather than as noise.
  List<double> _syntheticWindow(GaugeReading t) {
    final centre = t.position;
    return [
      for (var i = 0; i < 24; i++)
        (centre + (_rng.nextDouble() - 0.5) * 26).clamp(0, 100),
    ];
  }

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

  final bool _tripPaused = false;
  bool get tripPaused => _tripPaused;

  final double _tripKm = 12.4;
  final int _tripMinutes = 18;
  final double _tripAvg = 41;

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

  static List<GaugeReading> _degradedAt(DateTime now) => [
    // Fresh: answering inside its interval.
    GaugeReading(
      pid: '010C',
      label: 'Engine RPM',
      unit: 'rpm',
      value: 2480,
      display: '2,480',
      position: 34,
      cautionAt: 78,
      criticalAt: 92,
      lastUpdated: now,
      expectedInterval: _slowPoll,
    ),
    // Stage two: past 2× its interval, so it fades and shows its age.
    GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 68,
      position: 42,
      cautionAt: 80,
      criticalAt: 94,
      lastUpdated: now.subtract(const Duration(seconds: 4)),
      expectedInterval: _slowPoll,
    ),
    GaugeReading(
      pid: '0105',
      label: 'Coolant',
      unit: '°C',
      value: 89,
      position: 52,
      cautionAt: 76,
      criticalAt: 90,
      lastUpdated: now.subtract(const Duration(seconds: 4, milliseconds: 900)),
      expectedInterval: _slowPoll,
    ),
    // Stage three: past 5 s, so the number is replaced by an em dash rather
    // than left on screen looking current.
    GaugeReading(
      pid: '0104',
      label: 'Engine load',
      unit: '%',
      value: 34,
      position: 34,
      cautionAt: 80,
      criticalAt: 94,
      lastUpdated: now.subtract(const Duration(seconds: 7)),
      expectedInterval: _slowPoll,
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
      lastUpdated: now,
      expectedInterval: _slowPoll,
    ),
    // Stage four: the PID is not supported at all, which is a different fact
    // from "we have not heard from it lately".
    GaugeReading(
      pid: '015C',
      label: 'Oil temp',
      unit: '°C',
      state: TileState.unsupported,
    ),
  ];

  /// 2 Hz — what a budget adapter answering in ~640 ms actually sustains.
  static const _slowPoll = Duration(milliseconds: 500);

  /// Every PID a tile can be pointed at, with the band boundaries that make
  /// its range bar meaningful. This is the catalogue behind "Add tile" and
  /// "change what it reads".
  ///
  /// Deliberately absent: any derived horsepower figure. It needs both torque
  /// PIDs, and a MAF-derived estimate is pseudoscience.
  static const catalogue = <GaugeReading>[
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
    GaugeReading(
      pid: '010F',
      label: 'Intake',
      unit: '°C',
      value: 38,
      position: 38,
      cautionAt: 80,
      criticalAt: 92,
    ),
    GaugeReading(
      pid: '010B',
      label: 'Manifold',
      unit: 'kPa',
      value: 98,
      position: 46,
    ),
    GaugeReading(
      pid: '0110',
      label: 'MAF',
      unit: 'g/s',
      value: 12.4,
      display: '12.4',
      position: 40,
    ),
    GaugeReading(
      pid: '0146',
      label: 'Ambient',
      unit: '°C',
      value: 16,
      position: 42,
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
      pid: '0133',
      label: 'Baro',
      unit: 'kPa',
      value: 101,
      position: 50,
    ),
    GaugeReading(
      pid: '0142',
      label: 'Module volts',
      unit: 'V',
      value: 13.8,
      display: '13.8',
      position: 58,
      cautionAt: 82,
      criticalAt: 93,
    ),
  ];

  /// PIDs not already on the dashboard, for the picker.
  List<GaugeReading> availablePids() => [
    for (final c in catalogue)
      if (!_tiles.any((t) => t.pid == c.pid)) c,
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
    DashboardScenario.degraded => _degradedAt(DateTime.now()),
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
  /// Switching scenario swaps the whole tile set — the scenarios stand for
  /// different vehicles and link states, so the saved layout for this vehicle
  /// is deliberately not reapplied over a diesel or hybrid tile set.
  void setScenario(DashboardScenario s) {
    _scenario = s;
    _tiles = _scenarioTiles(s);
    _lag = _lagFor(s);
    _selectedPid = null;
    _seedSamples();
    _startPolling();
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
    if (!value) _selectedPid = null;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final tile = _tiles.removeAt(oldIndex);
    _tiles.insert(newIndex.clamp(0, _tiles.length), tile);
    _persistLayout();
    notifyListeners();
  }

  void removeTile(String pid) {
    _tiles.removeWhere((t) => t.pid == pid);
    _tileTypes.remove(pid);
    if (_selectedPid == pid) _selectedPid = null;
    _persistLayout();
    notifyListeners();
  }

  void addTile(GaugeReading tile) {
    if (_tiles.any((t) => t.pid == tile.pid)) return;
    _tiles.add(tile);
    _seedSamples();
    _persistLayout();
    notifyListeners();
  }

  /// Swaps what a tile reads, keeping its slot and its treatment — the user
  /// picked that position and that look; only the PID changes.
  void replaceTile(String pid, GaugeReading replacement) {
    final i = _tiles.indexWhere((t) => t.pid == pid);
    if (i < 0 || _tiles.any((t) => t.pid == replacement.pid)) return;
    final type = _tileTypes.remove(pid);
    _tiles[i] = replacement;
    if (type != null) _tileTypes[replacement.pid] = type;
    if (_selectedPid == pid) _selectedPid = replacement.pid;
    _seedSamples();
    _persistLayout();
    notifyListeners();
  }

  void toggleRecording() {
    _recording = !_recording;
    // Android: an active recording holds the adapter connection in background
    // through the connectedDevice foreground service (SPEC §9.3). Starting it
    // here keeps the process alive with the screen off; stopping it releases
    // the service. No-op on iOS, which holds the BLE link under
    // bluetooth-central instead.
    if (_recording) {
      _background.startRecording();
    } else {
      _background.stopRecording();
    }
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

  /// Only the degraded scenario has PIDs falling behind — that is the frame
  /// the board draws as "stale + degraded + unsupported".
  static Map<String, Duration> _lagFor(DashboardScenario s) => switch (s) {
    DashboardScenario.degraded => const {
      '010D': Duration(seconds: 4), // Speed — visibly stale, still readable
      '0105': Duration(seconds: 4), // Coolant
      '0104': Duration(seconds: 7), // Engine load — past 5 s, shows an em dash
    },
    _ => const {},
  };

  @override
  void dispose() {
    _pump?.cancel();
    _pollTicker?.cancel();
    super.dispose();
  }
}
