import 'package:intl/intl.dart';

import '../../data/db/app_database.dart' show ReminderRow;

/// SPEC §5.5 — the default service intervals, word for word, and the one
/// sentence every one of them carries.
///
/// Months are stored as days (the `Reminders` table keeps
/// `repeatEveryDays`): an average month, so "6 months" survives the round
/// trip as 6 and never as "5.97".
class ServicePreset {
  const ServicePreset(
    this.title, {
    this.everyKm,
    this.everyMonths,
    this.critical = false,
  });

  final String title;
  final double? everyKm;
  final int? everyMonths;

  /// A failure here wrecks the engine — the timing belt. Shown in the
  /// fault tone when it is overdue.
  final bool critical;

  int? get everyDays =>
      everyMonths == null ? null : daysForMonths(everyMonths!);

  /// §5.5: "Every default interval displays" this.
  static const manualNote =
      "Check your owner's manual — intervals vary by vehicle.";

  static const all = [
    ServicePreset('Oil and filter', everyKm: 10000, everyMonths: 6),
    ServicePreset('Tyre rotation', everyKm: 10000),
    ServicePreset('Air filter', everyKm: 20000),
    ServicePreset('Cabin filter', everyKm: 15000),
    ServicePreset('Brake pads', everyKm: 40000),
    ServicePreset('Brake fluid', everyMonths: 24),
    ServicePreset('Coolant', everyKm: 60000),
    ServicePreset('Transmission fluid', everyKm: 60000),
    // §5.5 "plugs 40,000/100,000": copper plugs, and the long-life kind.
    ServicePreset('Spark plugs (copper)', everyKm: 40000),
    ServicePreset('Spark plugs (iridium or platinum)', everyKm: 100000),
    ServicePreset('Battery', everyMonths: 48),
    ServicePreset('Timing belt', everyKm: 100000, critical: true),
    ServicePreset('Inspection', everyMonths: 12),
  ];

  static const _daysPerMonth = 30.4375;
  static int daysForMonths(int months) => (months * _daysPerMonth).round();
  static int monthsForDays(int days) => (days / _daysPerMonth).round();
}

/// Where a reminder stands, in the order the list shows them.
enum ReminderStatus { overdue, dueSoon, upcoming, paused, done }

/// The one rule for "overdue", shared by the reminders list, the Garage
/// card's count and the health score's −5 each (§5.4): past its date, or at
/// or past its odometer. Paused and completed reminders are never overdue.
/// "Due soon" is inside a month or 1,000 km.
ReminderStatus reminderStatus(
  ReminderRow r, {
  double? odometerKm,
  required DateTime now,
}) {
  if (r.completedAt != null) return ReminderStatus.done;
  if (r.paused) return ReminderStatus.paused;
  final due = r.dueDate;
  final dueKm = r.dueOdometerKm;
  final byDate = due != null && due.isBefore(now);
  final byKm = dueKm != null && odometerKm != null && odometerKm >= dueKm;
  if (byDate || byKm) return ReminderStatus.overdue;
  final soonByDate =
      due != null && due.isBefore(now.add(const Duration(days: 30)));
  final soonByKm =
      dueKm != null && odometerKm != null && dueKm - odometerKm <= 1000;
  if (soonByDate || soonByKm) return ReminderStatus.dueSoon;
  return ReminderStatus.upcoming;
}

/// `24 Sep 2026`, in local time.
String formatDay(DateTime at) => DateFormat('d MMM y').format(at.toLocal());

/// Amounts of money, typed and shown.
///
/// The code is the ISO 4217 three letters the rows store; the setting
/// holds it as `GBP £`, and [codeOf] takes the first word. Shown with the
/// currency's own decimals (yen has none).
class Money {
  const Money._();

  /// The largest amount a record will take — a sanity bound, not a price
  /// list: past it, a typo is likelier than an invoice.
  static const max = 10000000.0;

  static String codeOf(String setting) {
    final code = setting.trim().split(' ').first.toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : 'USD';
  }

  static String format(double amount, String code) =>
      NumberFormat.simpleCurrency(name: code).format(amount);

  /// `42.50`, `42,50`, `1,042.50`, `1 042,50`. Null when it is not an
  /// amount; the caller bounds it.
  static double? parse(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s£$€¥]'), '');
    if (s.isEmpty) return null;
    // A comma followed by exactly one or two digits at the end is the
    // decimal separator; every other comma groups thousands.
    final commaDecimal = RegExp(r',\d{1,2}$');
    if (commaDecimal.hasMatch(s) && !s.contains('.')) {
      final i = s.lastIndexOf(',');
      s = '${s.substring(0, i).replaceAll(',', '')}.${s.substring(i + 1)}';
    } else {
      s = s.replaceAll(',', '');
    }
    final v = double.tryParse(s);
    return v != null && v.isFinite ? v : null;
  }
}
