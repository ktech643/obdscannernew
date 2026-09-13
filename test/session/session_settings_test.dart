import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.6 — the connection settings, applied to a real replayed link.
/// Each one used to be stored and read by nothing; these prove the switch
/// is wired to the thing it names.
void main() {
  late final ObdTrace cleanCan;
  setUpAll(() {
    cleanCan = ObdTrace.parse(
      File('assets/traces/clean_can.obdtrace').readAsStringSync(),
    );
  });

  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for ${reason ?? 'condition'}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('★ auto-reconnect', () {
    test('on (the default): a dropped link runs the §9.2 ladder', () async {
      final session = ObdSession(timeScale: 0.05);
      addTearDown(session.dispose);
      final transport = MockTransport(cleanCan, speed: 100);
      expect(await session.connect(transport), isTrue);

      await transport.disconnect(); // what an unplugged adapter looks like
      await waitFor(
        () => session.reconnectAttempt >= 1,
        reason: 'the first rung',
      );
      expect(
        session.state,
        anyOf(
          SessionState.lost,
          SessionState.connecting,
          SessionState.handshaking,
          SessionState.connected,
        ),
      );
      await session.disconnect();
    });

    test('★ off: the drop is reported, and nothing is retried', () async {
      final session = ObdSession(timeScale: 0.05)..autoReconnect = false;
      addTearDown(session.dispose);
      final transport = MockTransport(cleanCan, speed: 100);
      expect(await session.connect(transport), isTrue);
      final handshakes = transport.written.where((c) => c == 'ATZ').length;

      await transport.disconnect();
      await waitFor(
        () => session.lastError == 'Connection lost',
        reason: 'the drop to be named',
      );
      expect(session.state, SessionState.disconnected);
      expect(session.reconnectAttempt, 0);
      // Give a ladder time to have run if it were going to.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        transport.written.where((c) => c == 'ATZ').length,
        handshakes,
        reason: 'no second handshake went out',
      );
      expect(session.bus.of('010C').value, isNull, reason: 'tiles decay');
    });
  });

  group('polling rate', () {
    test('a ceiling set on a live session is honoured by the loop', () async {
      final session = ObdSession(timeScale: 0.05);
      addTearDown(session.dispose);
      session.scheduler.maxHz = 2;
      expect(
        await session.connect(MockTransport(cleanCan, speed: 100)),
        isTrue,
      );
      session.setVisible({'010C'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(session.scheduler.targetHz, lessThanOrEqualTo(2));
      await session.disconnect();
    });
  });
}
