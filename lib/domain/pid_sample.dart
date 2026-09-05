import 'package:flutter/foundation.dart';

/// One reading of one PID. [value] is `null` when the ECU answered with no
/// data; zero is a value (EV mode RPM), null is absence. Hard rule 5.
@immutable
class PidSample {
  const PidSample({required this.pid, required this.value, required this.at});

  /// OBD2 PID hex, e.g. `0C`.
  final String pid;
  final double? value;

  /// When the reply arrived, not when it was rendered.
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is PidSample &&
      other.pid == pid &&
      other.value == value &&
      other.at == at;

  @override
  int get hashCode => Object.hash(pid, value, at);

  @override
  String toString() => 'PidSample($pid=$value @$at)';
}

/// What a gauge tile knows about its PID that never changes at 10 Hz:
/// name, unit, physical range, the normal band, and how often to expect an
/// answer. The tile's chrome is built from this once.
@immutable
class GaugeSpec {
  const GaugeSpec({
    required this.pid,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    this.normalLow,
    this.normalHigh,
    this.decimals = 0,
    this.expectedInterval = const Duration(milliseconds: 125),
    this.supported = true,
  });

  final String pid;

  /// Rendered UPPERCASE on the tile — the one place uppercase appears.
  final String label;
  final String unit;
  final double min;
  final double max;

  /// The normal operating band. Both null means "no meaningful band" —
  /// the bar is drawn without one and nothing is ever called out of range.
  final double? normalLow;
  final double? normalHigh;
  final int decimals;

  /// Staleness is measured against 2× this, not a fixed wall-clock delay.
  final Duration expectedInterval;

  /// False when the vehicle's support bitmask says this PID doesn't exist.
  final bool supported;

  bool get hasBand => normalLow != null || normalHigh != null;

  /// 0…1 along the physical range.
  double position(double value) =>
      max == min ? 0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

  double? get bandLow => normalLow == null ? null : position(normalLow!);
  double? get bandHigh => normalHigh == null ? null : position(normalHigh!);

  bool inRange(double value) =>
      (normalLow == null || value >= normalLow!) &&
      (normalHigh == null || value <= normalHigh!);

  /// Numerals only. `—` for absence.
  String format(double? value) =>
      value == null ? '—' : value.toStringAsFixed(decimals);

  GaugeSpec copyWith({bool? supported}) => GaugeSpec(
    pid: pid,
    label: label,
    unit: unit,
    min: min,
    max: max,
    normalLow: normalLow,
    normalHigh: normalHigh,
    decimals: decimals,
    expectedInterval: expectedInterval,
    supported: supported ?? this.supported,
  );
}

/// SPEC §1.4 — one `ValueNotifier` per PID.
///
/// Hard rule 3: live samples never go through a provider that widgets
/// watch. The scheduler publishes here; each tile listens to exactly one
/// notifier and rebuilds only its numeral.
class PidBus {
  final Map<String, ValueNotifier<PidSample?>> _notifiers = {};

  /// The notifier for [pid], created on first use so a tile can subscribe
  /// before the first sample arrives.
  ValueNotifier<PidSample?> of(String pid) =>
      _notifiers.putIfAbsent(pid, () => ValueNotifier<PidSample?>(null));

  Iterable<String> get pids => _notifiers.keys;

  void publish(PidSample sample) => of(sample.pid).value = sample;

  /// On disconnect: every tile decays to `—` through its own clock rather
  /// than snapping, so nothing here forces a value.
  void clear() {
    for (final n in _notifiers.values) {
      n.value = null;
    }
  }

  void dispose() {
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
  }
}

/// A shared clock tiles use to notice staleness without a new sample.
/// One ticker for the whole dashboard, not one per tile.
class DashboardClock extends ValueNotifier<DateTime> {
  DashboardClock({DateTime? start}) : super(start ?? DateTime.now());

  void tick([DateTime? now]) => value = now ?? DateTime.now();
}
