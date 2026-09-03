import 'enums.dart';

/// One gauge tile's reading.
///
/// [value] is nullable on purpose — see the library note in `enums.dart`. A
/// tile holding `0` is a live zero; a tile holding `null` has no reading.
class GaugeReading {
  const GaugeReading({
    required this.pid,
    required this.label,
    required this.unit,
    this.value,
    this.display,
    this.state = TileState.live,
    this.tone = Tone.ink,
    this.note,
    this.position = 0,
    this.cautionAt,
    this.criticalAt,
  });

  /// OBD2 PID, e.g. `010C`. Identity for reordering and layout persistence.
  final String pid;
  final String label;
  final String unit;
  final double? value;

  /// Pre-formatted numeral where grouping or precision differs from the raw
  /// value (`2,480` rather than `2480.0`).
  final String? display;

  final TileState state;
  final Tone tone;

  /// Top-right note: "CAUTION", "4 s ago", "EV mode", "No data".
  final String? note;

  /// Marker position along the range bar, 0–100.
  final double position;

  /// Band boundaries along the range bar, 0–100. Null on tiles with no
  /// meaningful normal range.
  final double? cautionAt;
  final double? criticalAt;

  String get valueText => display ?? (value == null ? '—' : _fmt(value!));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  GaugeReading copyWith({
    double? value,
    String? display,
    TileState? state,
    Tone? tone,
    String? note,
    double? position,
    bool clearNote = false,
  }) => GaugeReading(
    pid: pid,
    label: label,
    unit: unit,
    value: value ?? this.value,
    display: display ?? this.display,
    state: state ?? this.state,
    tone: tone ?? this.tone,
    note: clearNote ? null : (note ?? this.note),
    position: position ?? this.position,
    cautionAt: cautionAt,
    criticalAt: criticalAt,
  );
}

/// A diagnostic trouble code.
class Dtc {
  const Dtc({
    required this.code,
    required this.description,
    required this.status,
    required this.severity,
    this.system,
    this.statusDetail,
    this.firstSeen,
    this.meaning,
    this.causes = const [],
    this.freezeFrame = const [],
    this.hasDefinition = true,
  });

  final String code;

  /// For codes with no bundled definition this reads "Manufacturer-specific —
  /// we don't have a definition for this code". We never fabricate one.
  final String description;
  final DtcStatus status;
  final DtcSeverity severity;
  final String? system;
  final String? statusDetail;
  final String? firstSeen;
  final String? meaning;

  /// Ordered most likely first.
  final List<String> causes;
  final List<({String label, String value})> freezeFrame;
  final bool hasDefinition;

  String get statusLine => switch (status) {
    DtcStatus.stored => 'Stored',
    DtcStatus.pending => 'Pending — being monitored',
    DtcStatus.permanent => 'Permanent',
  };
}

class ReadinessMonitor {
  const ReadinessMonitor(this.name, this.state);
  final String name;
  final MonitorState state;
}

/// One line of the health-score breakdown. A score is never shown without it.
class ScoreDeduction {
  const ScoreDeduction(this.title, this.remedy, this.points);
  final String title;
  final String remedy;
  final int points;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.nickname,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
    required this.fuel,
    required this.odometerKm,
    required this.vin,
    this.isPrimary = false,
  });

  final String id;
  final String nickname;
  final int year;
  final String make;
  final String model;
  final String trim;
  final VehicleFuel fuel;
  final double odometerKm;

  /// Stored full; rendered masked unless the user turns masking off.
  final String vin;
  final bool isPrimary;

  String get title => '$year $make $model $trim · ${fuel.name}';

  /// `WVW••••••••••1234` — first three and last four.
  String get maskedVin =>
      '${vin.substring(0, 3)}${'•' * (vin.length - 7)}${vin.substring(vin.length - 4)}';
}

class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.odometerKm,
    required this.cost,
    this.vendor,
    this.fixedCode,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime date;
  final double odometerKm;
  final double cost;
  final String? vendor;

  /// Links a repair back to the code it cleared, e.g. `P0301`.
  final String? fixedCode;
  final String? notes;
}

class Reminder {
  const Reminder({
    required this.title,
    required this.detail,
    this.overdue = false,
    this.critical = false,
    this.paused = false,
  });

  final String title;
  final String detail;
  final bool overdue;
  final bool critical;
  final bool paused;
}

class FuelEntry {
  const FuelEntry({
    required this.date,
    required this.odometerKm,
    required this.litres,
    required this.cost,
    this.consumption,
    this.partFill = false,
  });

  final DateTime date;
  final double odometerKm;
  final double litres;
  final double cost;

  /// Null on a part fill. Economy is calculated between full fill-ups only —
  /// including partials is the most common way fuel logs lie.
  final double? consumption;
  final bool partFill;
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.when,
    required this.distanceKm,
    required this.minutes,
    required this.avgSpeed,
    this.interrupted = false,
    this.locked = false,
  });

  final String id;
  final String name;
  final String when;
  final double distanceKm;
  final int minutes;
  final double avgSpeed;
  final bool interrupted;

  /// Beyond the free tier's 2-minute cap or 3-trip window.
  final bool locked;
}

class Adapter {
  const Adapter({
    required this.name,
    required this.transport,
    required this.rssi,
    this.rating = AdapterRating.knownGood,
    this.subtitle,
  });

  final String name;
  final Transport transport;
  final int? rssi;
  final AdapterRating rating;
  final String? subtitle;
}

class AdapterListing {
  const AdapterListing(this.name, this.detail, this.badge, this.rating);
  final String name;
  final String detail;
  final String badge;
  final AdapterRating rating;
}

/// A saved copy of codes, freeze frame and readiness — written *before* every
/// Mode 04 clear, per spec rule 5.
class Snapshot {
  const Snapshot({
    required this.summary,
    required this.when,
    required this.odometerKm,
    this.beforeClear = false,
  });

  final String summary;
  final String when;
  final double odometerKm;
  final bool beforeClear;
}

/// One line of the protocol log. This is the whole support system — nothing is
/// uploaded unless the user sends it.
class LogEvent {
  const LogEvent({
    required this.time,
    required this.frame,
    this.ms,
    this.outbound = true,
    this.tone = Tone.ink,
  });

  final String time;
  final String frame;
  final int? ms;
  final bool outbound;
  final Tone tone;
}

class Mode06Test {
  const Mode06Test(this.name, this.value, this.limit, this.result);
  final String name;

  /// Null when the adapter or vehicle doesn't support the test — we say so
  /// rather than showing an empty table that reads like a clean result.
  final String? value;
  final String? limit;
  final String? result;
}
