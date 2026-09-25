import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/elm_session.dart';
import 'package:torque_obd2/protocol/response_parser.dart';
import 'package:torque_obd2/transport/obd_transport.dart';

/// A transport that records writes and lets a test push bytes back, so the
/// session's queueing can be driven deterministically with no device.
class FakeTransport implements ObdTransport {
  final _inbound = StreamController<List<int>>.broadcast();
  final writes = <String>[];

  /// Every command seen while a previous one was still outstanding. Must stay
  /// empty — this is the serialisation invariant.
  final overlaps = <String>[];
  bool _awaitingReply = false;

  @override
  Stream<List<int>> get inbound => _inbound.stream;

  @override
  Future<void> write(List<int> bytes) async {
    final cmd = String.fromCharCodes(bytes).trim();
    if (_awaitingReply) overlaps.add(cmd);
    _awaitingReply = true;
    writes.add(cmd);
  }

  /// Simulates the adapter answering, prompt byte included.
  void reply(String text) {
    _awaitingReply = false;
    _inbound.add(text.codeUnits);
  }

  /// Bytes with no prompt — the session must not complete on these.
  void partial(String text) => _inbound.add(text.codeUnits);

  @override
  TransportKind get kind => TransportKind.mock;
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  Stream<TransportState> get state => const Stream.empty();
  @override
  int get maxWriteLength => 20;
  @override
  TransportCapabilities get capabilities => TransportCapabilities.mock;
  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {}
  @override
  Future<void> disconnect() async {}

  Future<void> close() => _inbound.close();
}

void main() {
  late FakeTransport transport;
  late ElmSession session;

  setUp(() {
    transport = FakeTransport();
    session = ElmSession(transport);
  });

  tearDown(() async {
    await session.dispose();
    await transport.close();
  });

  group('★ strict serialisation — the invariant', () {
    test(
      'a second command is not written until the first is answered',
      () async {
        final a = session.send('010C');
        final b = session.send('010D');

        // Only the first has gone out.
        expect(transport.writes, ['010C']);
        expect(session.isBusy, isTrue);
        expect(session.queueDepth, 1);

        transport.reply('41 0C 1A F8\r\r>');
        await a;
        await Future<void>.delayed(Duration.zero);

        expect(transport.writes, ['010C', '010D']);
        transport.reply('41 0D 42\r\r>');
        await b;

        expect(
          transport.overlaps,
          isEmpty,
          reason: 'ELM327 has no pipelining — one command at a time, ever',
        );
      },
    );

    test('★ a disposed session writes nothing, and says the link is gone', () async {
      // The reconnect ladder reuses the transport object: a command from
      // the old session would be a second conversation on the new link.
      await session.dispose();
      final r = await session.send('04');
      expect(transport.writes, isEmpty, reason: 'never reached the wire');
      expect(r.status, ElmStatus.timeout);
    });

    test('a burst of ten commands never overlaps', () async {
      final futures = [for (var i = 0; i < 10; i++) session.send('010$i')];
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
        transport.reply('41 0$i 00\r\r>');
      }
      await Future.wait(futures);

      expect(transport.writes.length, 10);
      expect(transport.overlaps, isEmpty);
    });
  });

  group('prompt framing', () {
    test('completes on the > byte, not on a carriage return', () async {
      final future = session.send('0100');
      // A response containing CRs but no prompt must not complete.
      transport.partial('SEARCHING...\r41 00 BE 3F A8 13\r');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(session.isBusy, isTrue);

      transport.reply('\r>');
      final response = await future;
      expect(response.isOk, isTrue);
      expect(response.frames.single, '4100BE3FA813');
    });

    test('a response split across many chunks is reassembled', () async {
      final future = session.send('010C');
      transport.partial('41 ');
      transport.partial('0C 1A');
      transport.reply(' F8\r\r>');
      final response = await future;
      expect(response.frames.single, '410C1AF8');
    });
  });

  group('timeouts and recovery', () {
    test('a silent adapter times out and the queue keeps moving', () async {
      final a = session.send('010C', timeout: const Duration(milliseconds: 30));
      final response = await a;
      expect(response.status, ElmStatus.timeout);

      // The queue must not deadlock behind the dead command.
      await Future<void>.delayed(Duration.zero);
      final b = session.send('010D');
      await Future<void>.delayed(Duration.zero);
      transport.reply('41 0D 42\r\r>');
      expect((await b).isOk, isTrue);
    });

    test(
      'a garbage flood is capped rather than growing without limit',
      () async {
        final future = session.send(
          '010C',
          timeout: const Duration(seconds: 5),
        );
        transport.partial('A' * (ElmSession.maxResponseChars + 10));
        final response = await future;
        expect(response.status, ElmStatus.malformed);
      },
    );

    test('non-ASCII bytes are filtered out of the buffer', () async {
      final future = session.send('010C');
      transport.partial(String.fromCharCodes([0x00, 0xFF, 0x01]));
      transport.reply('41 0C 1A F8\r\r>');
      expect((await future).frames.single, '410C1AF8');
    });

    test('flush completes everything in flight rather than hanging', () async {
      final a = session.send('010C');
      final b = session.send('010D');
      session.flush();
      expect((await a).status, ElmStatus.timeout);
      expect((await b).status, ElmStatus.timeout);
    });
  });

  group('round-trip measurement', () {
    test('records RTT for answered commands and exposes p95', () async {
      for (var i = 0; i < 5; i++) {
        final f = session.send('010C');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        transport.reply('41 0C 1A F8\r\r>');
        await f;
        await Future<void>.delayed(Duration.zero);
      }
      expect(session.rttSamples.length, 5);
      expect(session.p95Rtt, isNotNull);
    });

    test('a timeout is not counted as a round trip', () async {
      await session.send('010C', timeout: const Duration(milliseconds: 20));
      expect(session.rttSamples, isEmpty);
    });

    test('the RTT window is bounded', () async {
      for (var i = 0; i < 25; i++) {
        final f = session.send('010C');
        await Future<void>.delayed(Duration.zero);
        transport.reply('41 0C 1A F8\r\r>');
        await f;
        await Future<void>.delayed(Duration.zero);
      }
      expect(session.rttSamples.length, lessThanOrEqualTo(20));
    });
  });
}
