import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/elm_session.dart';
import 'package:torque_obd2/transport/obd_transport.dart';
import 'package:torque_obd2/transport/spp_transport.dart';

/// Exercises the Dart half of the SPP channel contract against a scripted
/// native side. The Kotlin half is compile-checked and needs a classic
/// adapter to run for real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('test.spp/method');
  const events = EventChannel('test.spp/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late StreamController<Object?> native;
  Object? Function(MethodCall call)? nativeHandler;
  late int listens;
  StreamSubscription<Object?>? forwarder;

  setUp(() {
    calls = [];
    native = StreamController<Object?>.broadcast();
    nativeHandler = null;

    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return nativeHandler?.call(call) ??
          switch (call.method) {
            'isSupported' => true,
            'connect' => true,
            'write' => null,
            'disconnect' => null,
            'listPaired' => [
              {
                'name': 'OBDII',
                'address': '00:1D:A5:68:98:8B',
                'bondState': 12,
              },
              {'name': '', 'address': '98:d3:31:f5:b2:10', 'bondState': 12},
            ],
            _ => throw MissingPluginException(),
          };
    });

    listens = 0;
    forwarder = null;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listens++;
          forwarder?.cancel();
          forwarder = native.stream.listen(
            (e) => sink.success(e),
            onDone: sink.endOfStream,
          );
        },
        onCancel: (_) {
          forwarder?.cancel();
          forwarder = null;
        },
      ),
    );
  });

  tearDown(() async {
    await SppTransport.resetForTest();
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
    if (!native.isClosed) await native.close();
  });

  SppTransport make({String address = '00:1D:A5:68:98:8B'}) => SppTransport(
    address: address,
    name: 'OBDII',
    methodChannel: method,
    eventChannel: events,
  );

  /// Scripts one method to throw a PlatformException with [code].
  void failNative(String on, String code) {
    nativeHandler = (call) {
      if (call.method == on) {
        throw PlatformException(code: code, message: code);
      }
      return null;
    };
  }

  Matcher failsWith(SppFailure f) =>
      throwsA(isA<SppException>().having((e) => e.failure, 'failure', f));

  group('channel contract — SPEC §3.4', () {
    test('connect sends the address and reports connected', () async {
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);

      await t.connect();
      await Future<void>.delayed(Duration.zero);

      final connect = calls.singleWhere((c) => c.method == 'connect');
      expect(connect.arguments, {'address': '00:1D:A5:68:98:8B'});
      expect(states, [TransportState.connecting, TransportState.connected]);
      expect(t.kind, TransportKind.spp);
      expect(t.id, 'spp:00:1D:A5:68:98:8B');
    });

    test('★ raw bytes from native reach inbound untouched', () async {
      final t = make();
      await t.connect();
      final received = <List<int>>[];
      t.inbound.listen(received.add);

      // Exactly what the socket delivered — the prompt byte included, no
      // parsing on the way through.
      native.add(Uint8List.fromList('41 0C 1A F8\r\r>'.codeUnits));
      await Future<void>.delayed(Duration.zero);

      expect(received.single, '41 0C 1A F8\r\r>'.codeUnits);
      expect(received.single.last, ElmSession.promptByte);
    });

    test(
      '★ the disconnected event flips state — the ACL-broadcast path',
      () async {
        final t = make();
        final states = <TransportState>[];
        t.state.listen(states.add);
        await t.connect();

        native.add({'event': 'disconnected'});
        await Future<void>.delayed(Duration.zero);

        expect(states.last, TransportState.disconnected);
      },
    );

    test('the stream ending is a loss too, reported exactly once', () async {
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await t.connect();

      await native.close();
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        TransportState.connecting,
        TransportState.connected,
        TransportState.disconnected,
      ]);
    });

    test('write forwards bytes as a Uint8List', () async {
      final t = make();
      await t.connect();
      await t.write('010C\r'.codeUnits);

      final write = calls.singleWhere((c) => c.method == 'write');
      final bytes = (write.arguments as Map)['bytes'];
      expect(bytes, isA<Uint8List>());
      expect(bytes, '010C\r'.codeUnits);
    });

    test('a write past maxWriteLength is chunked', () async {
      final t = make();
      await t.connect();
      await t.write(List.filled(t.maxWriteLength * 2 + 10, 0x41));
      expect(calls.where((c) => c.method == 'write').length, 3);
    });

    test('write before connect is a no-op, not a crash', () async {
      final t = make();
      await t.write('ATZ\r'.codeUnits);
      expect(calls.where((c) => c.method == 'write'), isEmpty);
    });

    test('disconnect tells native and drops the event subscription', () async {
      final t = make();
      await t.connect();
      await t.disconnect();
      expect(calls.any((c) => c.method == 'disconnect'), isTrue);

      // Events after disconnect are ignored — the subscription is gone.
      final received = <List<int>>[];
      t.inbound.listen(received.add);
      native.add(Uint8List.fromList([0x3E]));
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    });

    test('disconnect on a transport that never connected is safe', () async {
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await t.disconnect();
      await Future<void>.delayed(Duration.zero);
      // Nothing native belongs to this instance; nothing to tell it.
      expect(calls.where((c) => c.method == 'disconnect'), isEmpty);
      expect(states, [TransportState.disconnected]);
    });

    test(
      'a lower-case address is normalised before it reaches native',
      () async {
        final t = make(address: '00:1d:a5:68:98:8b');
        expect(t.id, 'spp:00:1D:A5:68:98:8B');
        await t.connect();
        final connect = calls.singleWhere((c) => c.method == 'connect');
        expect(connect.arguments, {'address': '00:1D:A5:68:98:8B'});
      },
    );
  });

  group('the engine over SPP', () {
    test('ElmSession frames a reply exactly as it would over BLE', () async {
      final t = make();
      await t.connect();
      final session = ElmSession(t);

      nativeHandler = (call) {
        if (call.method == 'write') {
          // Answer in two chunks, like a real RFCOMM read.
          scheduleMicrotask(() {
            native.add(Uint8List.fromList('41 0C '.codeUnits));
            native.add(Uint8List.fromList('1A F8\r\r>'.codeUnits));
          });
        }
        return null;
      };

      final r = await session.send('010C');
      expect(r.isOk, isTrue);
      expect(r.frames.single, '410C1AF8');
      await session.dispose();
    });
  });

  group('failure mapping', () {
    test('every native code lands on its own SppFailure', () async {
      const codes = {
        'unsupported': SppFailure.unsupported,
        'off': SppFailure.bluetoothOff,
        'permission': SppFailure.permission,
        'unpaired': SppFailure.notPaired,
        'argument': SppFailure.badAddress,
        'io': SppFailure.io,
        'state': SppFailure.state,
        'something-new': SppFailure.state,
      };
      for (final entry in codes.entries) {
        failNative('connect', entry.key);
        await expectLater(
          make().connect(),
          failsWith(entry.value),
          reason: entry.key,
        );
      }
    });

    test(
      'Bluetooth off is its own failure, and the state goes to failed',
      () async {
        failNative('connect', 'off');
        final t = make();
        final states = <TransportState>[];
        t.state.listen(states.add);
        await expectLater(t.connect(), failsWith(SppFailure.bluetoothOff));
        await Future<void>.delayed(Duration.zero);
        expect(states.last, TransportState.failed);
      },
    );

    test('an io failure on write marks the link lost', () async {
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await t.connect();

      failNative('write', 'io');
      await expectLater(t.write([0x41]), throwsA(isA<SppException>()));
      await Future<void>.delayed(Duration.zero);
      expect(states.last, TransportState.disconnected);
    });

    test('★ a connect timeout tells native to stop, then fails', () async {
      nativeHandler = (call) {
        if (call.method == 'connect') {
          return Completer<bool>().future; // never answers
        }
        return null;
      };
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await expectLater(
        t.connect(timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
      await Future<void>.delayed(Duration.zero);
      // Native was still blocked in BluetoothSocket.connect(); without this
      // a late success would leave a socket open that nobody listens to.
      expect(calls.any((c) => c.method == 'disconnect'), isTrue);
      expect(states.last, TransportState.failed);
    });

    test('a native "false" is a refused connect, not a hang', () async {
      nativeHandler = (call) => call.method == 'connect' ? false : null;
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await expectLater(t.connect(), failsWith(SppFailure.io));
      await Future<void>.delayed(Duration.zero);
      expect(states.last, TransportState.failed);
    });

    test('no plugin at all — iOS — is a typed state failure', () async {
      nativeHandler = (_) => throw MissingPluginException();
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);
      await expectLater(t.connect(), failsWith(SppFailure.state));
      await Future<void>.delayed(Duration.zero);
      expect(states.last, TransportState.failed);
    });
  });

  group('overlapping calls', () {
    test('a second connect supersedes a pending first one', () async {
      final first = Completer<bool>();
      var n = 0;
      nativeHandler = (call) {
        if (call.method == 'connect') return ++n == 1 ? first.future : true;
        return null;
      };
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);

      final a = t.connect();
      final b = t.connect();
      await b;
      // Now the stale first attempt fails: it must not knock the winner out.
      first.completeError(PlatformException(code: 'io', message: 'late'));
      await expectLater(a, failsWith(SppFailure.state));
      await Future<void>.delayed(Duration.zero);

      expect(states.last, TransportState.connected);
      final received = <List<int>>[];
      t.inbound.listen(received.add);
      native.add(Uint8List.fromList([0x3E]));
      await Future<void>.delayed(Duration.zero);
      expect(received, isNotEmpty, reason: "the winner's subscription lives");
    });

    test('disconnect during connect wins', () async {
      final pending = Completer<bool>();
      nativeHandler = (call) =>
          call.method == 'connect' ? pending.future : null;
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);

      final a = t.connect();
      await t.disconnect();
      pending.complete(true); // native answers late, after we gave up
      await expectLater(a, failsWith(SppFailure.state));
      await Future<void>.delayed(Duration.zero);

      expect(states.last, TransportState.disconnected);
    });

    test('the native ordering: the first attempt is cancelled before the '
        'second answers', () async {
      final first = Completer<bool>();
      final second = Completer<bool>();
      var n = 0;
      nativeHandler = (call) {
        if (call.method == 'connect') {
          return ++n == 1 ? first.future : second.future;
        }
        return null;
      };
      final t = make();
      final states = <TransportState>[];
      t.state.listen(states.add);

      final a = t.connect();
      final b = t.connect();
      // Kotlin closes A's pending socket the moment B arrives, so A fails
      // first — and must not take B down with it.
      first.completeError(
        PlatformException(code: 'io', message: 'Connect cancelled'),
      );
      await expectLater(a, failsWith(SppFailure.state));
      expect(states.last, TransportState.connecting);
      second.complete(true);
      await b;
      await Future<void>.delayed(Duration.zero);
      expect(states.last, TransportState.connected);
    });

    test(
      '★ a second instance evicts the first — one native link, one owner',
      () async {
        final x = make();
        await x.connect();
        final xStates = <TransportState>[];
        x.state.listen(xStates.add);

        final y = make(address: '98:D3:31:F5:B2:10');
        await y.connect();
        await Future<void>.delayed(Duration.zero);
        expect(xStates.last, TransportState.disconnected);

        // The bytes belong to Y now.
        final xGot = <List<int>>[];
        final yGot = <List<int>>[];
        x.inbound.listen(xGot.add);
        y.inbound.listen(yGot.add);
        native.add(Uint8List.fromList([0x3E]));
        await Future<void>.delayed(Duration.zero);
        expect(xGot, isEmpty);
        expect(yGot, hasLength(1));

        // X letting go must not tear down Y's link.
        final before = calls.where((c) => c.method == 'disconnect').length;
        await x.disconnect();
        expect(calls.where((c) => c.method == 'disconnect').length, before);
        native.add(Uint8List.fromList([0x3E]));
        await Future<void>.delayed(Duration.zero);
        expect(yGot, hasLength(2));
      },
    );

    test(
      'a reconnect after a failed attempt re-subscribes and delivers once',
      () async {
        failNative('connect', 'io');
        final t = make();
        await expectLater(t.connect(), failsWith(SppFailure.io));
        nativeHandler = null;
        await t.connect();
        expect(
          listens,
          2,
          reason: 'the failed attempt let its subscription go',
        );

        final got = <List<int>>[];
        t.inbound.listen(got.add);
        native.add(Uint8List.fromList([0x3E]));
        await Future<void>.delayed(Duration.zero);
        expect(got, hasLength(1));
      },
    );
  });

  group('discovery', () {
    test('lists paired devices, tolerating a missing name', () async {
      final paired = await SppTransport.listPaired(method);
      expect(paired.length, 2);
      expect(paired.first.name, 'OBDII');
      expect(paired.first.bonded, isTrue);
      expect(paired.last.name, '');
      expect(paired.last.address, '98:D3:31:F5:B2:10');
    });

    test(
      'isSupported is false where the plugin is absent — i.e. iOS',
      () async {
        nativeHandler = (_) => throw MissingPluginException();
        expect(await SppTransport.isSupported(method), isFalse);
        expect(await SppTransport.listPaired(method), isEmpty);
      },
    );

    test('Bluetooth off on listPaired is typed, not an empty list', () async {
      failNative('listPaired', 'off');
      await expectLater(
        SppTransport.listPaired(method),
        failsWith(SppFailure.bluetoothOff),
      );
    });

    test('a permission error on listPaired is typed', () async {
      failNative('listPaired', 'permission');
      await expectLater(
        SppTransport.listPaired(method),
        failsWith(SppFailure.permission),
      );
    });
  });
}
