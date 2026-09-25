import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/typed_number.dart';
import 'package:torque_obd2/features/garage/distance.dart';
import 'package:torque_obd2/features/garage/service_intervals.dart';

/// §9.7 comma-decimal locales: a number is typed in either convention.
void main() {
  group('★ an amount, in either convention', () {
    test('★ the European grouping is not a decimal point', () {
      // It was read as 1.23456 and saved without an error.
      expect(Money.parse('1.234,56'), 1234.56);
      expect(Money.parse('€1.234,56'), 1234.56);
      expect(Money.parse('1.234.567,89'), 1234567.89);
      expect(Money.parse('1.500'), 1500, reason: 'no price has 3 decimals');
    });

    test('the English grouping, and plain decimals, still read', () {
      expect(Money.parse('1,234.56'), 1234.56);
      expect(Money.parse('1,042.50'), 1042.5);
      expect(Money.parse('42.50'), 42.5);
      expect(Money.parse('42,50'), 42.5);
      expect(Money.parse('1 042,50'), 1042.5);
      expect(Money.parse('1 042,50'), 1042.5, reason: 'narrow no-break');
      expect(Money.parse('£42.50'), 42.5);
      expect(Money.parse('Rs 1,500'), 1500);
      expect(Money.parse('1,500 PKR'), 1500);
      expect(Money.parse('1,23,456'), 123456, reason: 'lakh grouping');
    });

    test('not amounts', () {
      for (final s in [
        '',
        'abc',
        '1e9',
        'NaN',
        'Infinity',
        '1,2,3',
        '1.2.3',
        '1.234.56,7,8',
        '12a4',
      ]) {
        expect(Money.parse(s), isNull, reason: s);
      }
    });
  });

  group('★ a reading, in either convention', () {
    test('★ "142.380,5" is a hundred and forty-two thousand', () {
      expect(Distance.parse('142.380,5'), 142380.5);
      expect(Distance.parse('142.380'), 142380);
      expect(Distance.parse('142,380.5'), 142380.5);
    });

    test('what it read before, it still reads', () {
      expect(Distance.parse('142,380'), 142380);
      expect(Distance.parse('142380'), 142380);
      expect(Distance.parse('142 380'), 142380);
      expect(Distance.parse('142380.5'), 142380.5);
      expect(Distance.parse('142380,5'), 142380.5);
      expect(Distance.parse('Infinity'), isNull);
      expect(Distance.parse('NaN'), isNull);
    });
  });

  test('★ litres keep three decimals: a pump shows them', () {
    expect(parseTypedNumber('45.123', threeDecimalsPlausible: true), 45.123);
    expect(parseTypedNumber('45,123', threeDecimalsPlausible: true), 45.123);
    expect(parseTypedNumber('38,5', threeDecimalsPlausible: true), 38.5);
  });
}
