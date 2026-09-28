import '../domain/pid_sample.dart';
import '../models/enums.dart' show DistanceUnit, TemperatureUnit;
import '../protocol/pid_registry.dart';

/// Turns the protocol layer's [PidDef] into the design system's [GaugeSpec].
///
/// The two are deliberately separate: `lib/protocol/` imports no Flutter and
/// knows nothing about tiles, while `GaugeSpec` carries display concerns
/// (decimals, the normal band, how often a tile should expect an answer).
/// This is the one place they meet.
class GaugeCatalog {
  GaugeCatalog._();

  /// The normal operating band per PID, in the PID's own units. Absent means
  /// "no meaningful band" — the tile draws no band and never says caution.
  ///
  /// These are deliberately conservative: a band that cries caution on a
  /// healthy car is worse than no band at all.
  static const _bands = <String, ({double? low, double? high})>{
    '0105': (low: 75, high: 105), // coolant: thermostat to fan-on
    '010C': (low: 550, high: 6500), // idle to just under a typical redline
    '010F': (low: -20, high: 60), // intake air
    '0111': (low: 0, high: 100),
    '012F': (low: 15, high: 100), // fuel level: low-fuel lamp territory
    '0142': (low: 12.2, high: 14.8), // module voltage: flat to overcharging
    '0146': (low: -30, high: 45), // ambient
    '015C': (low: 80, high: 120), // oil temp
    '013C': (low: 300, high: 800), // catalyst light-off to damage
    '0104': (low: 0, high: 90), // engine load
    '0143': (low: 0, high: 90),
    '0106': (low: -10, high: 10), // fuel trims: ±10% is the usual rule
    '0107': (low: -10, high: 10),
    '0108': (low: -10, high: 10),
    '0109': (low: -10, high: 10),
    '0144': (low: 0.97, high: 1.03), // lambda
  };

  /// PIDs whose values are fractional enough to want a decimal place.
  static const _decimals = <String, int>{
    '0142': 1,
    '0144': 3,
    '0106': 1,
    '0107': 1,
    '0108': 1,
    '0109': 1,
    '010B': 0,
    '0110': 1,
    '015E': 1,
    '0104': 0,
  };

  /// What the tile shows as its name. Shorter than the registry's engineering
  /// name where the tile is only 2-up wide.
  static const _labels = <String, String>{
    '0105': 'Coolant',
    '010C': 'RPM',
    '010D': 'Speed',
    '010F': 'Intake air',
    '0111': 'Throttle',
    '0142': 'Battery',
    '015C': 'Oil temp',
    '013C': 'Catalyst',
    '0104': 'Load',
    '012F': 'Fuel',
    '0146': 'Ambient',
    '0110': 'MAF',
    '010E': 'Timing',
    '010B': 'MAP',
  };

  /// The six tiles a first connect shows, in order, when the vehicle
  /// supports them. Chosen to answer "is the engine healthy right now?"
  static const defaultLayout = <String>[
    '010C',
    '010D',
    '0105',
    '0104',
    '0111',
    '0142',
  ];

  /// The tile's name for [pid] — the short label, else the registry's.
  static String labelFor(String pid) =>
      _labels[pid] ?? PidRegistry.lookup(pid)?.name ?? pid;

  /// The readings a picker offers, in the order it offers them: the ones
  /// with a short tile name first (the common gauges, in that list's
  /// order), then the rest by name. Gaugeable only.
  static List<String> get pickerOrder {
    final all = gaugeable.toSet();
    final first = [
      for (final p in _labels.keys)
        if (all.contains(p)) p,
    ];
    final rest =
        [
          for (final p in all)
            if (!_labels.containsKey(p)) p,
        ]..sort(
          (a, b) => (PidRegistry.lookup(a)?.name ?? a).compareTo(
            PidRegistry.lookup(b)?.name ?? b,
          ),
        );
    return [...first, ...rest];
  }

  /// SPEC §9.4 — a car that answers 0100 with fewer than six gauges and no
  /// engine speed or airflow is an electric car, and is never sold Pro for
  /// more gauges it does not have.
  static bool looksFullyElectric(Set<String> supported) {
    if (supported.isEmpty) return false;
    if (supported.contains('010C') || supported.contains('0110')) {
      return false;
    }
    final gauges = gaugeable.toSet();
    return supported.where(gauges.contains).length < 6;
  }

  /// Every PID that makes a sensible gauge — enums and one-shot reads are
  /// excluded, since a tile that never changes is a waste of a tile.
  static List<String> get gaugeable => [
    for (final d in PidRegistry.all)
      if (!d.isEnum && d.priority != PidPriority.once) d.pid,
  ];

  /// The spec for [pid], or null if the registry doesn't know it.
  ///
  /// [supported] comes from the vehicle's support bitmask; an unsupported
  /// PID still gets a spec so the tile can say "Not available on this
  /// vehicle" rather than disappearing.
  ///
  /// SPEC §5.6 — units are the user's. The registry's units are metric and
  /// the samples on the bus stay that way; this is the one place °F and
  /// miles happen, once per spec, so neither the tile nor the scheduler
  /// ever knows. Only the units the user can choose are converted:
  /// temperature and distance (which covers speed).
  static GaugeSpec? specFor(
    String pid, {
    bool supported = true,
    Duration? expectedInterval,
    DistanceUnit distance = DistanceUnit.km,
    TemperatureUnit temperature = TemperatureUnit.celsius,
  }) {
    final def = PidRegistry.lookup(pid);
    if (def == null) return null;
    final band = _bands[def.pid];
    final spec = GaugeSpec(
      pid: def.pid,
      label: _labels[def.pid] ?? def.name,
      unit: def.unit,
      min: def.min,
      max: def.max,
      normalLow: band?.low,
      normalHigh: band?.high,
      decimals: _decimals[def.pid] ?? 0,
      expectedInterval: expectedInterval ?? _intervalFor(def.priority),
      supported: supported,
    );
    return switch (def.unit) {
      '°C' when temperature == TemperatureUnit.fahrenheit => spec.displayedAs(
        '°F',
        UnitScale.celsiusToFahrenheit,
      ),
      'km/h' when distance == DistanceUnit.mi => spec.displayedAs(
        'mph',
        UnitScale.kmToMiles,
      ),
      'km' when distance == DistanceUnit.mi => spec.displayedAs(
        'mi',
        UnitScale.kmToMiles,
      ),
      _ => spec,
    };
  }

  /// The tier's pace at 10 Hz with the whole budget free — only a fallback.
  /// A tile is measured against how often the session really asks
  /// (`ObdSession.cadence`) whenever it says; this covers the moments it
  /// does not, before the first cycle ends or for a reading not polled.
  /// On a tight budget or a slow adapter the session asks slower than
  /// this, and tiles measured against it alone faded while healthy.
  static Duration _intervalFor(PidPriority p) => switch (p) {
    PidPriority.critical => const Duration(milliseconds: 100),
    PidPriority.high => const Duration(milliseconds: 200),
    PidPriority.medium => const Duration(milliseconds: 500),
    PidPriority.low => const Duration(seconds: 2),
    PidPriority.once => const Duration(days: 1),
  };
}
