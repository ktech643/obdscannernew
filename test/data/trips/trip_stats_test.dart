import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/trips/trip_stats.dart';

/// §4.3's trip figures from 010D (speed, km/h) and 015E (fuel rate, L/h).
/// Every fixture is something a car can send: speeds a car reaches, at the
/// 1–10 Hz a poll loop reaches, with the gaps Doze and a hold leave.
void main() {
  const speed = TripStats.speedPid;
  const fuel = TripStats.fuelRatePid;

  /// [values] at [stepMs] apart, starting at [from].
  void feed(
    TripStats s,
    String pid,
    List<double?> values, {
    int from = 0,
    int stepMs = 1000,
  }) {
    for (var i = 0; i < values.length; i++) {
      s.add(from + i * stepMs, pid, values[i]);
    }
  }

  test('★ distance is a trapezoid over consecutive samples', () {
    // 36 km/h held for 10 s at 1 s steps: 0.1 km.
    final held = TripStats();
    feed(held, speed, List.filled(11, 36.0));
    expect(held.totals.distanceKm, closeTo(0.1, 1e-12));
    expect(held.totals.speedCoveredMs, 10000);
    expect(held.totals.avgSpeedKph, closeTo(36, 1e-9));

    // 0 → 72 km/h linearly over 10 s: 0.1 km. A left-hold (rectangle)
    // rule reads 0.09 km, a right-hold 0.11.
    final ramp = TripStats();
    feed(ramp, speed, [for (var i = 0; i <= 10; i++) 7.2 * i]);
    expect(ramp.totals.distanceKm, closeTo(0.1, 1e-12));
    expect(ramp.totals.maxSpeedKph, closeTo(72, 1e-9));
  });

  test('★ a null speed is absence, not 0 km/h, and not bridged', () {
    // Hard rule 5: the ECU answered NO DATA once, between two 60s.
    final s = TripStats();
    feed(s, speed, [60, null, 60]);
    expect(
      s.totals.distanceKm,
      0.0,
      reason:
          'as 0 km/h it would add 0.0167 km; bridged over it, 0.0333 km — '
          'neither was driven as far as anyone knows',
    );
    expect(s.totals.speedCoveredMs, 0);
    expect(s.totals.rows, 3, reason: 'a null answer is still a row');
    expect(s.totals.maxSpeedKph, 60);
  });

  test('★ Doze: a long silence adds nothing; background gaps bridge', () {
    // §9.3 timestamp every sample. 60 km/h, then 10 minutes of nothing (a
    // hold, Doze), then 60 km/h again: those 10 minutes are unknown.
    final doze = TripStats();
    doze.add(0, speed, 60);
    doze.add(600000, speed, 60);
    expect(doze.totals.distanceKm, 0.0, reason: 'not +10 km');

    // iOS in the background: one cycle every 2 s (§5.3's 0.5 Hz). 60 s of
    // that at 60 km/h is a kilometre.
    final bg = TripStats();
    feed(bg, speed, List.filled(31, 60.0), stepMs: 2000);
    expect(bg.totals.distanceKm, closeTo(1.0, 1e-12));
    expect(bg.totals.speedCoveredMs, 60000);

    // The bridge's edge: 15 s bridges, 15.001 s does not.
    final edge = TripStats()
      ..add(0, speed, 36)
      ..add(TripStats.maxBridgeMs, speed, 36)
      ..add(2 * TripStats.maxBridgeMs + 1, speed, 36);
    expect(edge.totals.speedCoveredMs, TripStats.maxBridgeMs);
  });

  test('★ fuel is null until the car sends a fuel rate, never 0.0', () {
    // §4.3 "Trip fuel used ∫ fuel rate dt". A car without 015E has no
    // fuel figure; 0.0 would print "0.0 L used".
    final none = TripStats();
    feed(none, speed, List.filled(11, 50.0));
    expect(none.totals.fuelUsedL, isNull);

    // 3.6 L/h for 10 s is 0.01 L.
    final some = TripStats();
    feed(some, fuel, List.filled(11, 3.6));
    expect(some.totals.fuelUsedL, closeTo(0.01, 1e-12));
    expect(some.totals.distanceKm, isNull, reason: 'no speed, no distance');

    // One answer is a figure (0 L so far), not absence.
    expect((TripStats()..add(0, fuel, 3.6)).totals.fuelUsedL, 0.0);
  });

  test('★ #segment breaks the chain: a Resume never integrates the kill', () {
    final s = TripStats();
    s.add(10000, speed, 60);
    s.newSegment();
    s.add(10500, speed, 60);
    s.add(10500, fuel, 3.6);
    expect(s.totals.distanceKm, 0.0, reason: 'nothing bridged across');
    expect(s.totals.speedCoveredMs, 0);
  });

  test('a seed carries every figure, and bridges nothing into it', () {
    final first = TripStats();
    feed(first, speed, List.filled(11, 36.0));
    feed(first, fuel, List.filled(11, 3.6));
    final resumed = TripStats(first.totals)
      ..add(10500, speed, 36)
      ..add(11500, speed, 36);
    expect(resumed.totals.rows, 24);
    expect(resumed.totals.distanceKm, closeTo(0.11, 1e-12));
    expect(resumed.totals.speedCoveredMs, 11000);
    expect(resumed.totals.maxSpeedKph, 36);
    expect(resumed.totals.fuelUsedL, closeTo(0.01, 1e-12));
  });

  test('the average needs 10 s of coverage; other PIDs are rows only', () {
    final s = TripStats();
    feed(s, speed, List.filled(10, 36.0)); // 9 s covered
    expect(s.totals.avgSpeedKph, isNull);
    s.add(10000, '010C', 850); // RPM: a row, not a figure
    expect(s.totals.rows, 11);
    expect(s.totals.avgSpeedKph, isNull);
    s.add(10000, speed, 36);
    expect(s.totals.avgSpeedKph, closeTo(36, 1e-9));
    // A non-finite value is the same absence as a null.
    s.add(11000, speed, double.nan);
    s.add(12000, speed, 36);
    expect(s.totals.speedCoveredMs, 10000);
  });
}
