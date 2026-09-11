import '../data/dtc_dictionary.dart';
import '../protocol/dtc_decoder.dart';
import '../protocol/readiness_decoder.dart';

/// One line of the breakdown: what cost points, and how many.
///
/// [points] is what was *lost*, always positive. A score with no
/// deductions has an empty list, not a list of zeros.
class HealthDeduction {
  const HealthDeduction(this.reason, this.points);
  final String reason;
  final int points;

  @override
  String toString() => '$reason (−$points)';
}

/// SPEC §5.4 — the Health Score, **always with its full breakdown**.
///
/// A bare number is the thing this app exists not to be: 62/100 with no
/// explanation is indistinguishable from an invented number. So the score
/// is never shown without [deductions], and [notMeasured] names every
/// input that could not be read — because an input we never saw must not
/// silently read as "fine".
class HealthScore {
  const HealthScore({
    required this.value,
    required this.deductions,
    this.notMeasured = const [],
  });

  final int value;
  final List<HealthDeduction> deductions;

  /// Inputs that were absent, in the words the breakdown shows. A score
  /// computed with gaps is a partial score and says so.
  final List<String> notMeasured;

  int get pointsLost => deductions.fold(0, (sum, d) => sum + d.points);
  bool get isComplete => notMeasured.isEmpty;

  /// Weight applied to the −25 a confirmed code costs.
  ///
  /// An unrated code costs the full 25. Treating "we have no rating" as
  /// "mild" would let an unknown code quietly raise the score, which is
  /// the wrong direction to be wrong in.
  static double weightFor(DtcSeverity? severity) => switch (severity) {
    DtcSeverity.high => 1.0,
    DtcSeverity.medium => 0.7,
    DtcSeverity.low => 0.4,
    null => 1.0,
  };

  /// Coolant above this is called out; see the note in [compute] on why
  /// the low side is not.
  static const coolantHighC = 105.0;

  /// Below this, at rest, a 12 V battery is flat enough to matter.
  static const lowBatteryVolts = 12.2;

  /// Fuel trim beyond this much, either way, means the ECU is working hard
  /// to correct something.
  static const fuelTrimLimitPercent = 10.0;

  /// The whole of §5.4's table, in order.
  ///
  /// Only [stored] is charged per code — the spec says "per confirmed
  /// DTC" there and does not for permanent or pending, so those are each
  /// charged once for being present at all. Reminders and incomplete
  /// monitors are per-item, again as written.
  ///
  /// Anything null is *absent*, not zero (hard rule 5): it adds a line to
  /// [notMeasured] and costs nothing.
  static HealthScore compute({
    required List<RawDtc> stored,
    required List<RawDtc> pending,
    required List<RawDtc> permanent,
    bool? milOn,
    ReadinessReport? readiness,
    Map<String, DtcSeverity?> severities = const {},
    double? batteryVolts,
    double? coolantC,
    List<double?> fuelTrims = const [],
    int overdueReminders = 0,
    Set<String> failedModes = const {},
  }) {
    final out = <HealthDeduction>[];
    final gaps = <String>[];

    for (final dtc in stored) {
      final points = (25 * weightFor(severities[dtc.code])).round();
      out.add(HealthDeduction('Confirmed code ${dtc.code}', points));
    }
    if (permanent.isNotEmpty) {
      out.add(
        HealthDeduction(
          permanent.length == 1
              ? 'Permanent code ${permanent.first.code}'
              : '${permanent.length} permanent codes',
          20,
        ),
      );
    }
    if (milOn == true) {
      out.add(const HealthDeduction('Check Engine light is on', 15));
    } else if (milOn == null) {
      gaps.add('Check Engine light — the car did not report its status');
    }
    if (pending.isNotEmpty) {
      out.add(
        HealthDeduction(
          pending.length == 1
              ? 'Pending code ${pending.first.code}'
              : '${pending.length} pending codes',
          10,
        ),
      );
    }

    if (batteryVolts == null) {
      gaps.add('Battery voltage — not read');
    } else if (batteryVolts < lowBatteryVolts) {
      out.add(
        HealthDeduction(
          'Battery at ${batteryVolts.toStringAsFixed(1)} V',
          10,
        ),
      );
    }

    // Only the high side. A cold engine reads far below the normal band
    // and is in perfect health, and nothing on the bus distinguishes
    // "cold" from "the thermostat is stuck open" — so charging for a low
    // reading would fail a healthy car every winter morning.
    if (coolantC == null) {
      gaps.add('Coolant temperature — not read');
    } else if (coolantC > coolantHighC) {
      out.add(
        HealthDeduction(
          'Coolant at ${coolantC.round()} °C, above the normal band',
          8,
        ),
      );
    }

    final trims = fuelTrims.whereType<double>().toList();
    if (trims.isEmpty) {
      gaps.add('Fuel trims — not read');
    } else if (trims.any((t) => t.abs() > fuelTrimLimitPercent)) {
      final worst = trims.reduce((a, b) => a.abs() > b.abs() ? a : b);
      out.add(
        HealthDeduction(
          'Fuel trim at ${worst > 0 ? '+' : ''}${worst.toStringAsFixed(1)}%',
          8,
        ),
      );
    }

    if (overdueReminders > 0) {
      out.add(
        HealthDeduction(
          overdueReminders == 1
              ? '1 overdue service reminder'
              : '$overdueReminders overdue service reminders',
          5 * overdueReminders,
        ),
      );
    }

    if (readiness == null) {
      gaps.add('Readiness monitors — the car did not report them');
    } else if (readiness.incompleteCount > 0) {
      out.add(
        HealthDeduction(
          readiness.incompleteCount == 1
              ? '1 monitor not finished'
              : '${readiness.incompleteCount} monitors not finished',
          3 * readiness.incompleteCount,
        ),
      );
    }

    // A mode that never answered means codes may exist that we did not
    // see. The score is not penalised for that — we do not invent faults
    // — but it is marked incomplete so it is never read as a clean bill.
    for (final mode in failedModes) {
      gaps.add(switch (mode) {
        '03' => 'Stored codes — the car did not answer',
        '07' => 'Pending codes — the car did not answer',
        '0A' => 'Permanent codes — the car did not answer',
        _ => 'Warning light and monitors — the car did not answer',
      });
    }

    final lost = out.fold(0, (sum, d) => sum + d.points);
    return HealthScore(
      value: (100 - lost).clamp(0, 100),
      deductions: out,
      notMeasured: gaps,
    );
  }
}
