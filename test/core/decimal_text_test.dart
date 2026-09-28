import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:torque_obd2/core/decimal_text.dart';

/// §9.7 comma-decimal locales: a number is shown in the phone's
/// convention, never `toStringAsFixed` interpolated into copy.
///
/// No `initializeDateFormatting` or other set-up: intl's number symbols
/// are compiled in, and these tests prove it by needing none.
void main() {
  group('★ the phone\'s own convention', () {
    test('★ a German phone reads 12,4 — de_DE is not a key intl has', () {
      // intl's table has `de` and `de_CH`, no `de_DE`; a plain
      // `localeExists` check sent every German phone to `en`.
      expect(NumberFormat.localeExists('de_DE'), isFalse);
      expect(decimalText(12.4, digits: 1, locale: 'de_DE'), '12,4');
      expect(decimalText(1234.5, digits: 1, locale: 'de_DE'), '1.234,5');
      expect(decimalText(12.4, digits: 1, locale: 'fr_FR'), '12,4');
      expect(decimalText(12.4, digits: 1, locale: 'es_AR'), '12,4');
    });

    test('★ a locale intl does not know reads as en, and never throws', () {
      // `NumberFormat` alone throws ArgumentError for these — in a build().
      for (final l in ['xx', 'xx_YY', '', 'und']) {
        expect(decimalText(12.4, digits: 1, locale: l), '12.4', reason: l);
      }
    });

    test('an English phone reads 12.4', () {
      expect(decimalText(12.4, digits: 1, locale: 'en_US'), '12.4');
      expect(decimalText(1234.5, digits: 1, locale: 'en_GB'), '1,234.5');
      expect(decimalText(12.4, digits: 1, locale: 'en'), '12.4');
    });
  });

  group('digits', () {
    test('one decimal keeps its zero', () {
      expect(decimalText(12.0, digits: 1, locale: 'en_US'), '12.0');
      expect(decimalText(0.0, digits: 1, locale: 'de_DE'), '0,0');
      expect(decimalText(12.44, digits: 1, locale: 'en_US'), '12.4');
      expect(decimalText(12.46, digits: 1, locale: 'en_US'), '12.5');
    });

    test('whole numbers have no decimal mark', () {
      expect(decimalText(41.4, digits: 0, locale: 'en_US'), '41');
      expect(decimalText(41.6, digits: 0, locale: 'de_DE'), '42');
      expect(decimalText(1234.0, digits: 0, locale: 'de_DE'), '1.234');
    });
  });
}
