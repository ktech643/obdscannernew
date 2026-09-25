import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/domain/pid_sample.dart';
import 'package:torque_obd2/features/dashboard/speed_gate.dart';
import 'package:torque_obd2/features/dashboard/sparkline_history.dart';

/// §8.4's gate, and the trace a tile draws from.
void main() {
  final t = DateTime.utc(2026, 9, 26, 12);
  PidSample kph(double? v, {Duration ago = Duration.zero}) =>
      PidSample(pid: '010D', value: v, at: t.subtract(ago));

  test(
    '★ above 5 km/h and fresh is moving; exactly 5, stale or absent is not',
    () {
      expect(SpeedGate.isMoving(kph(5.0), t), isFalse, reason: 'exactly 5');
      expect(SpeedGate.isMoving(kph(5.1), t), isTrue);
      expect(
        SpeedGate.isMoving(kph(60, ago: const Duration(seconds: 6)), t),
        isFalse,
        reason: 'older than the tile\'s own "No data"',
      );
      expect(SpeedGate.isMoving(kph(null), t), isFalse);
      expect(SpeedGate.isMoving(null, t), isFalse);
    },
  );

  test('the gate notifies only when the answer flips', () {
    final speed = ValueNotifier<PidSample?>(kph(0));
    final clock = ValueNotifier<DateTime>(t);
    final gate = SpeedGate(speed: speed, clock: clock);
    addTearDown(gate.dispose);
    var flips = 0;
    gate.moving.addListener(() => flips++);
    speed.value = kph(3);
    speed.value = kph(40);
    speed.value = kph(41);
    expect(gate.moving.value, isTrue);
    clock.value = t.add(const Duration(seconds: 6)); // the reading goes stale
    expect(gate.moving.value, isFalse);
    expect(flips, 2);
  });

  test('★ no live link, not known to be moving', () {
    // The clock stops with the link; after a reconnect gave up, the last
    // 68 km/h stayed "fresh" and edit mode stayed locked in a parked car.
    final speed = ValueNotifier<PidSample?>(kph(68));
    final clock = ValueNotifier<DateTime>(t);
    final link = ValueNotifier<bool>(true);
    final gate = SpeedGate(
      speed: speed,
      clock: clock,
      link: link,
      isLive: () => link.value,
    );
    addTearDown(gate.dispose);
    expect(gate.moving.value, isTrue);
    link.value = false;
    expect(gate.moving.value, isFalse);
  });

  test(
    'a trace keeps a minute, spaced, and publishes a new list each time',
    () {
      final source = ValueNotifier<PidSample?>(null);
      final h = SparklineHistory(source);
      addTearDown(h.dispose);
      final seen = <List<double>>[];
      h.addListener(() => seen.add(h.value));
      for (var i = 0; i < 10; i++) {
        source.value = PidSample(
          pid: '0105',
          value: 80.0 + i,
          at: t.add(Duration(milliseconds: 100 * i)),
        );
      }
      // 100 ms apart: every third or so is kept (250 ms spacing).
      expect(h.value.length, lessThan(10));
      expect(identical(seen.first, seen.last), isFalse, reason: 'new lists');
      source.value = PidSample(
        pid: '0105',
        value: 1,
        at: t.add(const Duration(minutes: 2)),
      );
      expect(h.value, [1.0], reason: 'older than a minute is gone');
      h.reset();
      expect(h.value, isEmpty);
    },
  );
}
