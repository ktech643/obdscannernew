import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/protocol_log.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §10.4 through the real session: what the log holds is exactly what
/// went over the wire, described only where the app genuinely decoded it.
void main() {
  late final ObdTrace headersCan;
  setUpAll(() {
    headersCan = ObdTrace.parse(
      File('assets/traces/headers_can.obdtrace').readAsStringSync(),
    );
  });

  test(
    '★ every command and reply, in order, with latency and meaning',
    () async {
      final log = ProtocolLog();
      final session = ObdSession(timeScale: 0.05, log: log);
      addTearDown(session.dispose);
      expect(
        await session.connect(MockTransport(headersCan, speed: 100)),
        isTrue,
      );
      await session.readVin();
      // Let a couple of poll cycles through.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await session.disconnect();

      final events = log.events;
      expect(events.first.outbound, isTrue);
      expect(events.first.raw, 'ATZ', reason: 'the handshake starts the log');
      final atzReply = events[1];
      expect(atzReply.outbound, isFalse);
      expect(atzReply.raw, contains('ELM327'));
      expect(atzReply.latencyMs, isNotNull);

      // A PID reply is described as the value the app actually decoded.
      final rpm = events.firstWhere(
        (e) => !e.outbound && e.parsed != null && e.parsed!.contains('1726'),
      );
      expect(rpm.raw, contains('41 0C 1A F8'));

      // The VIN reply is described as the VIN — and masked on render.
      final vin = events.firstWhere((e) => e.parsed == '1HGBH41JXMN109186');
      expect(vin.raw, contains('49 02 01'));
      final text = log.render(vin: '1HGBH41JXMN109186');
      expect(text, isNot(contains('1HGBH41JXMN109186')));
      expect(text, isNot(contains('42 48 34 31 4A 58 4D')));
      expect(text, contains('1HG••••••••••9186'));

      // Commands and replies alternate: exactly one outstanding (hard rule 2).
      for (var i = 0; i + 1 < events.length; i++) {
        if (events[i].outbound) {
          expect(
            events[i + 1].outbound,
            isFalse,
            reason: 'command ${events[i].raw} got a reply line',
          );
        }
      }
    },
  );

  test('a reply that never came is named, not invented', () async {
    final log = ProtocolLog();
    final session = ObdSession(timeScale: 0.05, log: log);
    addTearDown(session.dispose);
    expect(
      await session.connect(MockTransport(headersCan, speed: 100)),
      isTrue,
    );
    // no_dtcs has no 0902; headers_can does — ask for something it lacks.
    await session.readPidOnce('0106');
    await session.disconnect();

    final asked = log.events.indexWhere((e) => e.outbound && e.raw == '0106');
    expect(asked, greaterThan(-1));
    final reply = log.events[asked + 1];
    expect(reply.outbound, isFalse);
    expect(
      reply.parsed,
      anyOf('timeout', 'noData', 'badCommand', 'link closed'),
    );
    // An answered "NO DATA" is a real round trip and carries a latency; a
    // timeout or a closed link completed none and carries null.
    final answered = reply.parsed == 'noData' || reply.parsed == 'badCommand';
    expect(reply.latencyMs, answered ? isNotNull : isNull);
  });

  test('without a log nothing is kept and nothing breaks', () async {
    final session = ObdSession(timeScale: 0.05);
    addTearDown(session.dispose);
    expect(
      await session.connect(MockTransport(headersCan, speed: 100)),
      isTrue,
    );
    await session.disconnect();
    expect(session.log, isNull);
  });
}
