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
    this.lastUpdated,
    this.expectedInterval = const Duration(milliseconds: 125),
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

  /// When this PID last answered. Null means the tile carries a fixed state
  /// and does not decay — an unsupported PID has no clock to run.
  final DateTime? lastUpdated;

  /// How often this PID is expected to answer at the current polling rate.
  /// Decay is measured against 2× this, not against a fixed wall-clock delay,
  /// so a tile polled at 2 Hz isn't called stale on a schedule meant for 8 Hz.
  final Duration expectedInterval;

  /// The four-stage decay, resolved against [now].
  ///
  /// Live → past 2× its interval it fades and shows its age → past 5 s it
  /// shows `—`. A tile whose state was set explicitly (unsupported, or a
  /// fixture with no clock) keeps that state. **Never display a stale number
  /// as if it were live** — this is the whole point of the component.
  TileState stateAt(DateTime now) {
    if (state == TileState.unsupported) return TileState.unsupported;
    if (lastUpdated == null) return state;
    final age = now.difference(lastUpdated!);
    if (age > const Duration(seconds: 5)) return TileState.unavailable;
    if (age > expectedInterval * 2) return TileState.stale;
    return TileState.live;
  }

  /// "4 s ago" once a tile has gone stale, so the age is on screen rather than
  /// merely implied by the dimming.
  String? ageNoteAt(DateTime now) {
    if (lastUpdated == null) return note;
    final resolved = stateAt(now);
    if (resolved == TileState.live) return note;
    if (resolved == TileState.unavailable) return 'No data';
    return '${now.difference(lastUpdated!).inSeconds} s ago';
  }

  String valueTextAt(DateTime now) =>
      stateAt(now) == TileState.unavailable ? '—' : valueText;

  String get valueText => display ?? (value == null ? '—' : _fmt(value!));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// The VoiceOver string for this tile, in the state it is actually in.
  ///
  /// Every semantic the sighted user gets from colour and opacity is spoken
  /// here in words: staleness, its age, the caution tone, and the fact that a
  /// PID is unsupported rather than merely missing.
  String semanticLabelAt(DateTime now) {
    final resolved = stateAt(now);
    final unit = this.unit.isEmpty ? '' : ' ${this.unit}';
    return switch (resolved) {
      TileState.unsupported => '$label, not available on this vehicle',
      TileState.unavailable =>
        '$label, no data. Last reading was over 5 seconds ago',
      TileState.stale =>
        '$label, ${valueText}$unit, ${ageNoteAt(now)}. This reading is not live',
      TileState.live => switch (tone) {
        Tone.caution =>
          '$label, ${valueText}$unit, caution, outside its normal range',
        Tone.fault => '$label, ${valueText}$unit, fault',
        _ => '$label, ${valueText}$unit',
      },
    };
  }

  GaugeReading copyWith({
    double? value,
    String? display,
    TileState? state,
    Tone? tone,
    String? note,
    double? position,
    DateTime? lastUpdated,
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
    lastUpdated: lastUpdated ?? this.lastUpdated,
    expectedInterval: expectedInterval,
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
