import 'package:intl/intl.dart';

import '../../core/decimal_text.dart';
import '../../models/enums.dart';
import '../garage/distance.dart';

/// A trip's figures as a person reads them: in their unit, their phone's
/// number convention and its 24-hour setting.
///
/// The CSV and the rows stay metric — kilometres, km/h, litres — and are
/// converted here, on the way to the screen, and nowhere else. Decimals go
/// through [decimalText], so a German phone reads `12,4 km` (§9.7); the
/// app sets no `Intl.defaultLocale`, so the locale is passed in, never
/// assumed.
class TripFormat {
  const TripFormat(
    this.unit, {
    required this.numberLocale,
    required this.use24h,
  });

  /// The user's distance setting.
  final DistanceUnit unit;

  /// The device locale, canonicalised (`de_DE`). Decides `12,4` or `12.4`.
  final String numberLocale;

  /// `MediaQuery.alwaysUse24HourFormatOf`: `14:32` or `2:32 PM`.
  final bool use24h;

  /// `12.4 km`, `7,7 mi`: one decimal, in the user's unit.
  String distance(double km) =>
      '${_decimal(Distance.fromKm(km, unit), 1)} ${unit.label}';

  /// `41 km/h`, `26 mph`: whole units. A speed converts as a distance
  /// does, per hour.
  String speed(double kph) =>
      '${_decimal(Distance.fromKm(kph, unit), 0)} ${unit.speedLabel}';

  /// `1.1 L`, `1,1 L`: one decimal.
  String litres(double l) => '${_decimal(l, 1)} L';

  /// The running meter: `0:05`, `18:05`, then `1:02:10` from an hour.
  /// Whole seconds, rounded down, so it never shows time not yet recorded.
  String timer(int ms) {
    final s = _seconds(ms);
    final h = s ~/ 3600, m = s % 3600 ~/ 60, sec = _two(s % 60);
    return h == 0 ? '$m:$sec' : '$h:${_two(m)}:$sec';
  }

  /// A span in words: `45 s`, `18 min`, `1 h 05 min`. Rounded down, the
  /// meter's way, so a trip the meter left at 18:04 reads `18 min`.
  String duration(int ms) {
    final s = _seconds(ms);
    if (s < 60) return '$s s';
    if (s < 3600) return '${s ~/ 60} min';
    return '${s ~/ 3600} h ${_two(s % 3600 ~/ 60)} min';
  }

  /// A moment, as the phone's clock shows it: `14:32`, or `2:32 PM` with
  /// the 24-hour setting off. `DateFormat.jm` ignores that setting, so the
  /// pattern is chosen here.
  ///
  /// The locale is pinned to `en_US` — the only date data intl compiles
  /// in. Any other needs `initializeDateFormatting`, which this app never
  /// calls, and a `DateFormat` under an `Intl.defaultLocale` of `de_DE`
  /// throws `LocaleDataException` instead. The patterns are fixed, so the
  /// AM/PM marker is all the locale would change.
  String clock(DateTime at) =>
      DateFormat(use24h ? 'HH:mm' : 'h:mm a', 'en_US').format(at.toLocal());

  /// What a screen reader should say for [distance], [speed], [litres]
  /// and a span: the words, not the abbreviations — "km/h" is read out
  /// letter by letter on some voices.
  String spokenDistance(double km) =>
      '${_decimal(Distance.fromKm(km, unit), 1)} '
      '${unit == DistanceUnit.km ? 'kilometres' : 'miles'}';

  String spokenSpeed(double kph) =>
      '${_decimal(Distance.fromKm(kph, unit), 0)} '
      '${unit == DistanceUnit.km ? 'kilometres per hour' : 'miles per hour'}';

  String spokenLitres(double l) => '${_decimal(l, 1)} litres';

  /// `1 minute 42 seconds`, `2 minutes`, `1 hour 5 minutes 10 seconds`;
  /// rounded down, as the meter is.
  String spokenDuration(int ms) {
    final s = _seconds(ms);
    String part(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';
    final parts = [
      if (s >= 3600) part(s ~/ 3600, 'hour'),
      if (s % 3600 >= 60) part(s % 3600 ~/ 60, 'minute'),
      if (s % 60 > 0 || s == 0) part(s % 60, 'second'),
    ];
    return parts.join(' ');
  }

  String _decimal(double v, int digits) =>
      decimalText(v, digits: digits, locale: numberLocale);

  /// Whole seconds, never below 0: a pre-v4 row's span is endedAt −
  /// startedAt, which a clock set back can make negative.
  static int _seconds(int ms) => ms <= 0 ? 0 : ms ~/ 1000;

  static String _two(int v) => v.toString().padLeft(2, '0');
}
