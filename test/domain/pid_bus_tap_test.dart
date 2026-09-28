import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/domain/pid_sample.dart';

/// SPEC §5.3 — the trip recorder hears the car through one synchronous
/// tap on the bus, inside the poll loop. What it may hear, and what it
/// may never do to the loop.
void main() {
  final t0 = DateTime.utc(2026, 9, 28, 14, 5);

  group('★ PidBus.tap', () {
    test('★ publish sets the notifier, then calls the tap once', () {
      final bus = PidBus();
      addTearDown(bus.dispose);
      final heard = <PidSample>[];
      final onBusThen = <PidSample?>[];
      bus.tap = (s) {
        heard.add(s);
        // A tap that reads the bus must find the sample it was handed:
        // tiles and the trip file agree on what the car said.
        onBusThen.add(bus.of(s.pid).value);
      };

      final a = PidSample(pid: '010D', value: 48, at: t0);
      final b = PidSample(pid: '015E', value: 3.35, at: t0);
      bus.publish(a);
      bus.publish(b);

      expect(heard, [a, b], reason: 'once each, in order');
      expect(onBusThen, [a, b], reason: 'the notifier is set first');
      expect(bus.of('010D').value, a);
    });

    test('★ clear() never calls the tap — a disconnect is not a reading', () {
      final bus = PidBus();
      addTearDown(bus.dispose);
      final heard = <PidSample>[];
      bus.tap = heard.add;
      bus.publish(PidSample(pid: '010D', value: 48, at: t0));
      heard.clear();

      bus.clear();

      // Through the tap, each tile's null would be a row in the trip file:
      // "no speed" at the moment the user pressed Disconnect.
      expect(heard, isEmpty);
      expect(bus.of('010D').value, isNull, reason: 'the tile still decays');
    });

    test('★ a throwing tap is reported, and never reaches the poll loop', () {
      final bus = PidBus();
      addTearDown(bus.dispose);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      bus.tap = (_) => throw StateError('a recorder bug');

      final s = PidSample(pid: '010C', value: 1726, at: t0);
      // Thrown out of publish, it would end the loop that called it, and
      // every gauge would freeze on its last value.
      expect(() => bus.publish(s), returnsNormally);
      expect(bus.of('010C').value, s, reason: 'the tile still updates');
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
    });
  });

  test('with no tap, publish is what it always was', () {
    final bus = PidBus();
    addTearDown(bus.dispose);
    final s = PidSample(pid: '0105', value: 89, at: t0);
    bus.publish(s);
    expect(bus.of('0105').value, s);
  });
}
