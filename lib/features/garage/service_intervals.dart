import 'package:flutter/widgets.dart' show BuildContext;
import 'package:intl/intl.dart';

import '../../core/typed_number.dart';
import '../../data/clock.dart';
import '../../data/db/app_database.dart' show ReminderRow;
import '../../design_system/adaptive.dart' show showAdaptiveDatePicker;

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
///
/// Dates are calendar days ([dayOf]): a reminder due on the 27th is due
/// soon on the 26th, due *today* on the 27th, and overdue from the 28th.
/// Compared as instants it was overdue from 00:00 on its own due date,
/// and "today" the day before.
ReminderStatus reminderStatus(
  ReminderRow r, {
  double? odometerKm,
  required DateTime now,
}) {
  if (r.completedAt != null) return ReminderStatus.done;
  if (r.paused) return ReminderStatus.paused;
  final days = reminderDaysLeft(r, now: now);
  final km = reminderKmLeft(r, odometerKm: odometerKm);
  if ((days != null && days < 0) || (km != null && km <= 0)) {
    return ReminderStatus.overdue;
  }
  if ((days != null && days < dueSoonDays) || (km != null && km <= dueSoonKm)) {
    return ReminderStatus.dueSoon;
  }
  return ReminderStatus.upcoming;
}

/// "Due soon": inside a month, or 1,000 km.
const dueSoonDays = 30;
const dueSoonKm = 1000.0;

/// Calendar days to the due date — 0 on the day, negative after. Null
/// when it is not due by date.
int? reminderDaysLeft(ReminderRow r, {required DateTime now}) =>
    r.dueDate == null ? null : daysBetween(today(now: now), r.dueDate!);

/// Kilometres to the due reading — 0 or less once reached. Null when it
/// is not due by distance or the car has no reading.
double? reminderKmLeft(ReminderRow r, {double? odometerKm}) =>
    r.dueOdometerKm == null || odometerKm == null
    ? null
    : r.dueOdometerKm! - odometerKm;

/// `24 Sep 2026`: the calendar day a stored date names ([dayOf]), the
/// same wherever the phone is now.
String formatDay(DateTime at) => DateFormat('d MMM y').format(dayOf(at));

/// The platform's date picker on calendar days: shown in the local
/// calendar, returned as a [calendarDay]. A date outside [first]..[last]
/// widens the range rather than failing the picker's assertion — a
/// reminder saved every 240 months lands past a 20-year [last].
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  DateTime local(DateTime d) {
    final c = dayOf(d);
    return DateTime(c.year, c.month, c.day);
  }

  final picked = await showAdaptiveDatePicker(
    context,
    initial: local(initial),
    first: local(first),
    last: local(last),
  );
  return picked == null
      ? null
      : calendarDay(picked.year, picked.month, picked.day);
}

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

  /// `42.50`, `42,50`, `1,042.50`, `1.042,50`, `1 042,50`, `£42.50`,
  /// `Rs 1,500` — either convention, by [parseTypedNumber]'s rules. No
  /// currency here has three decimals, so `1.500` is fifteen hundred. Null
  /// when it is not an amount; the caller bounds it.
  static double? parse(String raw) => parseTypedNumber(
    // A symbol or code before or after the number: `£`, `Rs`, `PKR`, `€`.
    raw.trim().replaceAll(RegExp(r'^[^0-9\-.,]+|[^0-9.,]+$'), ''),
    threeDecimalsPlausible: false,
  );
}
