import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:torque_obd2/features/trips/trip_format.dart';
import 'package:torque_obd2/models/enums.dart';

/// A trip's figures as the strip and the Garage list show them. The CSV
/// and the rows stay metric; this is the one place they are converted.
void main() {
  const en = TripFormat(DistanceUnit.km, numberLocale: 'en_US', use24h: true);
  const de = TripFormat(DistanceUnit.km, numberLocale: 'de_DE', use24h: true);
  const miles = TripFormat(
    DistanceUnit.mi,
    numberLocale: 'en_US',
    use24h: true,
  );

  group('★ §9.7 the phone\'s number convention', () {
    test('★ a German phone reads 12,4 km, 1,1 L', () {
      expect(de.distance(12.4), '12,4 km');
      expect(de.litres(1.1), '1,1 L');
      expect(de.speed(41.2), '41 km/h');
      expect(de.distance(1234.5), '1.234,5 km');
    });

    test('an English phone reads 12.4 km, 1.1 L', () {
      expect(en.distance(12.4), '12.4 km');
      expect(en.litres(1.1), '1.1 L');
      expect(en.distance(0), '0.0 km');
      expect(en.litres(0.04), '0.0 L');
    });
  });

  group('the unit setting', () {
    test('miles convert on screen from the metric figures', () {
      // 12.4 km is 7.705 mi; 41.4 km/h is 25.7 mph.
      expect(miles.distance(12.4), '7.7 mi');
      expect(miles.speed(41.4), '26 mph');
      expect(
        const TripFormat(
          DistanceUnit.mi,
          numberLocale: 'de_DE',
          use24h: true,
        ).distance(12.4),
        '7,7 mi',
      );
    });

    test('kilometres stay as they are; speed is whole', () {
      expect(en.speed(41.4), '41 km/h');
      expect(en.speed(0), '0 km/h');
      expect(en.speed(129.6), '130 km/h');
    });

    test('litres do not follow the distance setting', () {
      expect(miles.litres(1.1), '1.1 L');
    });
  });

  group('the meter', () {
    test('m:ss under an hour, h:mm:ss from one', () {
      expect(en.timer(0), '0:00');
      expect(en.timer(5000), '0:05');
      expect(en.timer(102000), '1:42');
      expect(en.timer(120000), '2:00');
      expect(en.timer(18 * 60000 + 5000), '18:05');
      expect(en.timer(3599999), '59:59');
      expect(en.timer(3600000), '1:00:00');
      expect(en.timer(3730000), '1:02:10');
      expect(en.timer(10 * 3600000), '10:00:00');
    });

    test('whole seconds, rounded down — never time not yet recorded', () {
      expect(en.timer(119999), '1:59');
      expect(en.timer(999), '0:00');
    });

    test('a negative span reads 0:00', () {
      expect(en.timer(-4000), '0:00');
    });
  });

  group('durations', () {
    test('45 s, 18 min, 1 h 05 min', () {
      expect(en.duration(0), '0 s');
      expect(en.duration(45000), '45 s');
      expect(en.duration(59999), '59 s');
      expect(en.duration(60000), '1 min');
      expect(en.duration(18 * 60000 + 4000), '18 min');
      expect(en.duration(3599999), '59 min');
      expect(en.duration(3600000), '1 h 00 min');
      expect(en.duration(3900000), '1 h 05 min');
      expect(en.duration(26 * 3600000 + 30 * 60000), '26 h 30 min');
    });

    test('a pre-v4 row a clock step made negative reads 0 s', () {
      expect(en.duration(-3600000), '0 s');
    });
  });

  group('★ clock times', () {
    final at = DateTime(2026, 9, 28, 14, 32);

    test('★ the 24-hour setting decides, not the locale', () {
      // `DateFormat.jm` ignores the setting: 2:32 PM either way.
      expect(en.clock(at), '14:32');
      expect(
        const TripFormat(
          DistanceUnit.km,
          numberLocale: 'en_US',
          use24h: false,
        ).clock(at),
        '2:32 PM',
      );
      expect(
        const TripFormat(
          DistanceUnit.km,
          numberLocale: 'de_DE',
          use24h: false,
        ).clock(DateTime(2026, 9, 28, 0, 5)),
        '12:05 AM',
      );
      expect(de.clock(DateTime(2026, 9, 28, 9, 5)), '09:05');
    });

    test('★ a time never needs date data it was not given', () {
      // intl compiles in en_US date symbols only. Under any other default
      // locale an unpinned DateFormat throws LocaleDataException — the
      // app never calls initializeDateFormatting.
      final was = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = was);
      Intl.defaultLocale = 'de_DE';
      expect(de.clock(at), '14:32');
      expect(
        const TripFormat(
          DistanceUnit.km,
          numberLocale: 'de_DE',
          use24h: false,
        ).clock(at),
        '2:32 PM',
      );
    });

    test('an instant is shown in local time', () {
      // Trips store UTC instants. The same moment given as UTC reads as
      // the phone's clock read it (meaningful off UTC: run under TZ=).
      expect(en.clock(at.toUtc()), '14:32');
    });
  });
}
