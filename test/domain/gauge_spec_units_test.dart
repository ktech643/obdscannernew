import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/domain/pid_sample.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';

/// SPEC §5.6 — the user's units reach the gauges through the spec, never
/// through the samples. An earlier version had no seam for this, and the
/// unit toggles in Settings changed nothing on the Dashboard.
void main() {
  const coolant = GaugeSpec(
    pid: '0105',
    label: 'Coolant',
    unit: '°C',
    min: -40,
    max: 215,
    normalLow: 75,
    normalHigh: 105,
  );

  group('UnitScale', () {
    test('the two conversions the settings offer', () {
      expect(UnitScale.celsiusToFahrenheit.apply(100), closeTo(212, 1e-9));
      expect(UnitScale.celsiusToFahrenheit.apply(-40), closeTo(-40, 1e-9));
      expect(UnitScale.kmToMiles.apply(100), closeTo(62.1371, 1e-6));
      expect(UnitScale.identity.apply(89), 89);
      expect(UnitScale.identity.isIdentity, isTrue);
      expect(UnitScale.kmToMiles.isIdentity, isFalse);
    });
  });

  group('★ GaugeSpec.displayedAs', () {
    final f = coolant.displayedAs('°F', UnitScale.celsiusToFahrenheit);

    test('★ the numeral is in the displayed unit, from a raw sample', () {
      expect(coolant.format(89), '89');
      expect(f.format(89), '192', reason: '89 °C is 192.2 °F');
      expect(f.format(null), '—');
      expect(f.unit, '°F');
    });

    test('★ never a signed zero: −18 °C is 0 °F, not "-0"', () {
      // −18 °C is −0.4 °F, which toStringAsFixed(0) prints as "-0" — a
      // winter cold start, on a default-layout tile.
      expect(f.format(-18), '0');
      expect(f.format(-40), '-40', reason: 'a real negative keeps its sign');
      const volts = GaugeSpec(
        pid: '0142',
        label: 'Battery',
        unit: 'V',
        min: 0,
        max: 20,
        decimals: 1,
      );
      expect(volts.format(-0.04), '0.0');
    });

    test('the range and the band are converted once', () {
      expect(f.min, closeTo(-40, 1e-9));
      expect(f.max, closeTo(419, 1e-9));
      expect(f.normalLow, closeTo(167, 1e-9));
      expect(f.normalHigh, closeTo(221, 1e-9));
    });

    test('a reading sits at the same place on the bar in either unit', () {
      for (final raw in [-40.0, 0.0, 75.0, 89.0, 105.0, 215.0]) {
        expect(f.position(raw), closeTo(coolant.position(raw), 1e-9));
      }
      expect(f.bandLow, closeTo(coolant.bandLow!, 1e-9));
      expect(f.bandHigh, closeTo(coolant.bandHigh!, 1e-9));
    });

    test('caution means the same thing in either unit', () {
      expect(f.inRange(89), isTrue);
      expect(f.inRange(110), isFalse, reason: '110 °C is over the band');
      expect(f.inRange(70), isFalse);
      expect(coolant.inRange(110), isFalse);
    });

    test('copyWith keeps the scale', () {
      expect(
        f.copyWith(supported: false).display,
        UnitScale.celsiusToFahrenheit,
      );
      expect(f.copyWith(supported: false).format(89), '192');
    });

    test('a spec already in another unit refuses a second scale', () {
      expect(
        () => f.displayedAs('K', const UnitScale(1, 273.15)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('★ GaugeCatalog.specFor with the user\'s units', () {
    test('★ temperature PIDs go to °F, distance PIDs to miles', () {
      final coolantF = GaugeCatalog.specFor(
        '0105',
        temperature: TemperatureUnit.fahrenheit,
      )!;
      expect(coolantF.unit, '°F');
      expect(coolantF.format(89), '192');

      final speedMph = GaugeCatalog.specFor('010D', distance: DistanceUnit.mi)!;
      expect(speedMph.unit, 'mph');
      expect(speedMph.format(68), '42', reason: '68 km/h is 42.3 mph');

      final sinceClear = GaugeCatalog.specFor(
        '0131',
        distance: DistanceUnit.mi,
      )!;
      expect(sinceClear.unit, 'mi');
      expect(sinceClear.format(100), '62');
    });

    test('the defaults are the registry\'s metric units, untouched', () {
      final coolantC = GaugeCatalog.specFor('0105')!;
      expect(coolantC.unit, '°C');
      expect(coolantC.display, UnitScale.identity);
      expect(coolantC.format(89), '89');
    });

    test('a unit the user cannot choose is never converted', () {
      for (final pid in ['010C', '0111', '0142', '010B']) {
        final metric = GaugeCatalog.specFor(pid)!;
        final imperial = GaugeCatalog.specFor(
          pid,
          distance: DistanceUnit.mi,
          temperature: TemperatureUnit.fahrenheit,
        )!;
        expect(imperial.unit, metric.unit, reason: pid);
        expect(imperial.display, UnitScale.identity, reason: pid);
      }
    });

    test('the two toggles are independent', () {
      final onlyMiles = GaugeCatalog.specFor(
        '0105',
        distance: DistanceUnit.mi,
      )!;
      expect(onlyMiles.unit, '°C');
      final onlyF = GaugeCatalog.specFor(
        '010D',
        temperature: TemperatureUnit.fahrenheit,
      )!;
      expect(onlyF.unit, 'km/h');
    });
  });
}
