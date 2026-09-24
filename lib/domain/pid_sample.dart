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

/// An affine map from a PID's own unit to the unit the tile shows:
/// `°C → °F` is ×1.8 + 32, `km → mi` is ×0.621371. Affine covers every
/// unit SPEC §5.6 lets the user choose, and it keeps a reading's *position*
/// along its range the same in either unit, so the bar, the arc and the
/// caution band mean the same thing in Fahrenheit as in Celsius.
@immutable
class UnitScale {
  const UnitScale(this.factor, [this.offset = 0]);

  static const identity = UnitScale(1);
  static const celsiusToFahrenheit = UnitScale(1.8, 32);
  static const kmToMiles = UnitScale(0.621371);

  final double factor;
  final double offset;

  double apply(double v) => v * factor + offset;

  bool get isIdentity => factor == 1 && offset == 0;

  @override
  bool operator ==(Object other) =>
      other is UnitScale && other.factor == factor && other.offset == offset;

  @override
  int get hashCode => Object.hash(factor, offset);
}

/// What a gauge tile knows about its PID that never changes at 10 Hz:
/// name, unit, physical range, the normal band, and how often to expect an
/// answer. The tile's chrome is built from this once.
///
/// Samples arrive in the PID's own unit — the registry's, always metric.
/// [unit], [min], [max] and the band are in the unit *shown*, and
/// [format], [position] and [inRange] put a raw sample through [display]
/// first, so the tile, the bus and the scheduler never learn that the user
/// chose °F. An earlier version had no such seam, and the unit toggles in
/// Settings changed nothing on the Dashboard.
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
    this.display = UnitScale.identity,
  });

  final String pid;

  /// Rendered UPPERCASE on the tile — the one place uppercase appears.
  final String label;

  /// The unit shown next to the numeral.
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

  /// From the PID's own unit to [unit]. Identity unless [displayedAs] made
  /// this spec.
  final UnitScale display;

  bool get hasBand => normalLow != null || normalHigh != null;

  /// 0…1 along the displayed range, from a raw sample.
  double position(double value) {
    final v = display.apply(value);
    return max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0);
  }

  double? get bandLow => normalLow == null ? null : _positionShown(normalLow!);
  double? get bandHigh =>
      normalHigh == null ? null : _positionShown(normalHigh!);

  /// [position] for a value already in the displayed unit.
  double _positionShown(double v) =>
      max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0);

  /// Whether a raw sample sits inside the normal band.
  bool inRange(double value) {
    final v = display.apply(value);
    return (normalLow == null || v >= normalLow!) &&
        (normalHigh == null || v <= normalHigh!);
  }

  /// Numerals only, in the displayed unit. `—` for absence.
  String format(double? value) =>
      value == null ? '—' : display.apply(value).toStringAsFixed(decimals);

  /// This spec shown in another unit: label, range and band converted once
  /// here, every raw sample converted on its way through. Only from a spec
  /// in the PID's own unit — two scales do not compose.
  GaugeSpec displayedAs(String unit, UnitScale scale) {
    assert(display.isIdentity, 'already displayed in another unit');
    return GaugeSpec(
      pid: pid,
      label: label,
      unit: unit,
      min: scale.apply(min),
      max: scale.apply(max),
      normalLow: normalLow == null ? null : scale.apply(normalLow!),
      normalHigh: normalHigh == null ? null : scale.apply(normalHigh!),
      decimals: decimals,
      expectedInterval: expectedInterval,
      supported: supported,
      display: scale,
    );
  }

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
    display: display,
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
