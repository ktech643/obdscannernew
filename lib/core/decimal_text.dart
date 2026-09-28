import 'package:intl/intl.dart';

/// [v] for a person to read, with [digits] decimals in [locale]'s
/// convention: `12,4` in Germany, `12.4` in England, `1.234,5` and
/// `1,234.5`. SPEC §9.7 — never `toStringAsFixed` interpolated into copy,
/// which shows a German reader `12.4`.
///
/// [locale] is the device's, as the platform names it (`de_DE`). intl's
/// number symbols are compiled in, so nothing needs loading first, but they
/// are keyed by language where the region changes nothing: there is a `de`
/// and a `de_CH`, no `de_DE`. `NumberFormat.localeExists` is a plain key
/// lookup, so `localeExists(locale) ? locale : 'en'` sends every German,
/// French and Spanish phone to `en`: `12.4`. [Intl.verifiedLocale] walks
/// intl's own fallbacks (`de_DE` → `de`); only a locale with none at all
/// reads as `en`, where `NumberFormat` alone would throw.
///
/// The digits themselves stay 0–9: an Egyptian or Persian locale's own
/// numerals beside the meter's, the clock's and every gauge's ASCII read as
/// two number systems in one line. Only the separators follow the locale.
String decimalText(double v, {required int digits, required String locale}) {
  final f = NumberFormat.decimalPatternDigits(
    locale: Intl.verifiedLocale(
      locale,
      NumberFormat.localeExists,
      onFailure: (_) => 'en',
    ),
    decimalDigits: digits,
  );
  final text = f.format(v);
  final zero = f.symbols.ZERO_DIGIT.codeUnitAt(0);
  if (zero == 0x30) return text;
  return String.fromCharCodes([
    for (final c in text.codeUnits)
      c >= zero && c <= zero + 9 ? 0x30 + c - zero : c,
  ]);
}
