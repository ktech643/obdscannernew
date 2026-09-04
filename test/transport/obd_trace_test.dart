import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/elm_session.dart';
import 'package:torque_obd2/protocol/response_parser.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';
import 'package:torque_obd2/transport/obd_transport.dart';

void main() {
  group('.obdtrace parsing', () {
    const source = '''
# torque.obdtrace v1
# vehicle: 2014 Honda Civic 1.8 petrol
# adapter: Vgate iCar Pro BLE 4.0
# protocol: 6 (ISO 15765-4 CAN 11/500)
T+0000  > ATZ
T+0983  < ELM327 v1.5\\r\\r>
T+0990  > ATE0
T+1024  < OK\\r\\r>
T+1031  > 010C
T+1119  < 41 0C 1A F8\\r\\r>
T+1130  > 010C
T+1220  < LV RESET\\r\\r>
T+1230  > ATRV
''';

    test('reads the header', () {
      final t = ObdTrace.parse(source);
      expect(t.vehicle, '2014 Honda Civic 1.8 petrol');
      expect(t.adapter, 'Vgate iCar Pro BLE 4.0');
      expect(t.protocol, '6 (ISO 15765-4 CAN 11/500)');
    });

    test('unescapes carriage returns and the prompt', () {
      final t = ObdTrace.parse(source);
      final reply = t.events[1];
      expect(reply.direction, TraceDirection.response);
      expect(reply.payload, 'ELM327 v1.5\r\r>');
      expect(reply.payload.codeUnits.last, ElmSession.promptByte);
    });

    test('records offsets in milliseconds', () {
      final t = ObdTrace.parse(source);
      expect(t.events[1].offset, const Duration(milliseconds: 983));
    });

    test('a repeated command keeps every reply, in order', () {
      final t = ObdTrace.parse(source);
      expect(t.repliesByCommand['010C'], ['41 0C 1A F8\r\r>', 'LV RESET\r\r>']);
    });

    test('latency is per send, parallel to the replies', () {
      final t = ObdTrace.parse(source);
      expect(t.latenciesByCommand['010C'], [
        const Duration(milliseconds: 88),
        const Duration(milliseconds: 90),
      ]);
    });

    test('a command with no reply is recorded as unanswered', () {
      final t = ObdTrace.parse(source);
      expect(t.unansweredCommands, contains('ATRV'));
      expect(t.repliesByCommand.containsKey('ATRV'), isFalse);
    });

    test('escape round-trips', () {
      const raw = 'a\rb\nc\\d';
      expect(ObdTrace.unescape(ObdTrace.escape(raw)), raw);
    });
  });

  group('MockTransport replay', () {
    late MockTransport transport;
    late ElmSession session;

    setUp(() async {
      transport = MockTransport(
        ObdTrace.parse('''
T+0000  > 010C
T+0088  < 41 0C 1A F8\\r\\r>
T+0100  > 010C
T+0400  < LV RESET\\r\\r>
T+0500  > ATZ
'''),
        speed: 100,
      );
      session = ElmSession(transport, timeScale: 0.01);
      await transport.connect();
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('is indistinguishable from a live adapter to the session', () async {
      final r = await session.send('010C');
      expect(r.isOk, isTrue);
      expect(r.frames.single, '410C1AF8');
    });

    test('★ the Nth send gets the Nth recorded reply', () async {
      expect((await session.send('010C')).isOk, isTrue);
      expect((await session.send('010C')).status, ElmStatus.lowVoltage);
    });

    test('past the end of the recording, the last reply holds', () async {
      await session.send('010C');
      await session.send('010C');
      // A third poll keeps returning the last recorded state rather than
      // inventing a recovery the recording never showed.
      expect((await session.send('010C')).status, ElmStatus.lowVoltage);
    });

    test(
      'an unanswered command times out, as it did in the recording',
      () async {
        final r = await session.send(
          'ATZ',
          timeout: const Duration(seconds: 5),
        );
        expect(r.status, ElmStatus.timeout);
      },
    );

    test('an unknown command gets the honest default', () async {
      expect((await session.send('015C')).status, ElmStatus.noData);
    });

    test(
      'delivers in MTU-sized chunks — the session must reassemble',
      () async {
        final chunks = <List<int>>[];
        final sub = transport.inbound.listen(chunks.add);
        await session.send('010C');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        // '41 0C 1A F8\r\r>' is 14 bytes; chunkSize 20 fits it in one. Use a
        // smaller chunk to prove fragmentation is exercised.
        expect(chunks, isNotEmpty);
      },
    );

    test('a small chunk size fragments every reply', () async {
      final tiny = MockTransport(
        ObdTrace.parse('T+0000  > 010C\nT+0088  < 41 0C 1A F8\\r\\r>\n'),
        speed: 100,
        chunkSize: 4,
      );
      final s = ElmSession(tiny, timeScale: 0.01);
      await tiny.connect();
      final chunks = <List<int>>[];
      final sub = tiny.inbound.listen(chunks.add);
      final r = await s.send('010C');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(chunks.length, greaterThan(1));
      expect(r.frames.single, '410C1AF8', reason: 'reassembly across chunks');
      await s.dispose();
      await tiny.dispose();
    });

    test(
      'dropNext simulates an adapter that died without a callback',
      () async {
        transport.dropNext = 1;
        final r = await session.send(
          '010C',
          timeout: const Duration(seconds: 1),
        );
        expect(r.status, ElmStatus.timeout);
        // The next one is answered again.
        expect((await session.send('010C')).isOk, isTrue);
      },
    );

    test('reports itself as a mock', () {
      expect(transport.kind, TransportKind.mock);
      expect(transport.capabilities.supportsBackgroundHold, isFalse);
    });
  });
}
