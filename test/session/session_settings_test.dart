import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';
import 'package:torque_obd2/transport/obd_transport.dart';

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

    test(
      '★ turned off mid-ladder stops the ladder, not just future drops',
      () async {
        // An adversarial-review find: autoReconnect was only ever consulted
        // at the moment a link is lost. Flipping it off while the §9.2
        // ladder is already running (the banner reading "reconnecting")
        // used to change nothing — the remaining 0.5/1/2/4/8 s rungs kept
        // firing exactly as if the user had never asked it to stop.
        final session = ObdSession(timeScale: 0.05);
        addTearDown(session.dispose);
        // A transport whose connect() always fails, so every rung is spent
        // waiting and retrying rather than succeeding on the first one.
        final transport = _AlwaysFailingConnect(MockTransport(cleanCan, speed: 100));
        expect(await session.connect(transport), isTrue);

        await transport.drop();
        await waitFor(
          () => session.reconnectAttempt >= 1,
          reason: 'the ladder to start',
        );
        final connectsAtToggle = transport.connectAttempts;
        session.autoReconnect = false;

        // Every failed rung also passes through `disconnected`, briefly,
        // with the attempt's own error — so both have to hold at once to
        // tell "the ladder actually stopped" from "one more rung failed".
        await waitFor(
          () =>
              session.state == SessionState.disconnected &&
              session.lastError == 'Connection lost',
          reason: 'the ladder to give up rather than keep retrying',
        );

        // Give the full remaining 0.5/1/2/4/8 s ladder time to have fired
        // every rung if it had not actually stopped.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(
          transport.connectAttempts,
          connectsAtToggle,
          reason: 'no further reconnect attempt was made after the toggle',
        );
      },
    );
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

    test(
      '★ a ceiling below 10 does not trap the BUFFER FULL backoff forever',
      () async {
        // An adversarial-review find: the backoff only ever cleared on
        // `targetHz >= 10` literally. Under any ceiling below 10 the rate
        // can never reach literal 10 again, so a single transient BUFFER
        // FULL — recovered from at the scheduler level — left the poll
        // loop's own backoff latched for the rest of the connection, and
        // `maxPidsPerCycle` frozen at half its normal value.
        //
        // The trace overflows once on 010C, then answers every further
        // 010C quickly and cleanly (held-last-reply repeats the final
        // recorded one) — a fully recovered link in every way except
        // whatever the backoff is still holding onto.
        // The standard replay scale used throughout the session suite
        // (speed: 100, timeScale: 0.05) — a tighter timeScale has flaked
        // before (see the memory on it) by leaving too little margin
        // between a reply's scaled latency and its scaled timeout.
        final trace = ObdTrace.parse(_bufferFullThenRecoversTrace);
        final session = ObdSession(timeScale: 0.05)..scheduler.maxHz = 4;
        addTearDown(session.dispose);
        expect(await session.connect(MockTransport(trace, speed: 100)), isTrue);
        session.setVisible({'010C'});

        await waitFor(
          () => session.bufferOverflows > 0,
          reason: 'the overflow to be seen',
        );
        final afterOverflow = session.scheduler.maxPidsPerCycle;

        // The backoff only re-checks every 30 s (scaled here to 1.5 s);
        // two of those is enough for the rate to relax from 2 Hz back up
        // to the 4 Hz ceiling (2 → 3 → 4), which is when a working clear
        // condition fires.
        await Future<void>.delayed(const Duration(milliseconds: 3500));
        expect(
          session.scheduler.targetHz,
          4,
          reason: 'the rate itself does recover to the ceiling',
        );
        expect(
          session.scheduler.maxPidsPerCycle,
          greaterThan(afterOverflow),
          reason:
              'and the PID budget the backoff was holding down recovers '
              'with it, not frozen at half forever',
        );
        await session.disconnect();
      },
    );
  });
}

/// The `buffer_full_poll` fixture's own preamble and first overflow,
/// followed by several clean 010C replies — a link that overflows once and
/// then fully recovers, unlike the checked-in fixture (which holds the
/// overflow forever, by design, to prove the rate stays down).
///
/// **The recovery replies take 240–245 ms, like this adapter's own replies
/// before the overflow.** The first version gave them 10 ms, which no
/// ELM327 can do. At replay speed 100 that is a 0.1 ms round trip, which
/// rounds to a p95 of 0 — and `recordP95Rtt` treats 0 as "no measurement"
/// and returns without recomputing `maxPidsPerCycle`. The test then passed
/// or failed on scheduler jitter (about 3 runs in 5 failed). A fixture that
/// encodes what real hardware cannot do produces results about the fixture,
/// not about the code.
const _bufferFullThenRecoversTrace = '''
# torque.obdtrace v1
# vehicle: 2011 Suzuki Swift 1.3
# adapter: Generic "ELM327 v2.1" BLE clone
# protocol: 6
T+0000  > ATZ
T+0980  < ELM327 v2.1\\r\\r>
T+1010  > ATE0
T+1045  < OK\\r\\r>
T+1075  > ATL0
T+1110  < OK\\r\\r>
T+1140  > ATS0
T+1175  < OK\\r\\r>
T+1205  > ATH1
T+1240  < OK\\r\\r>
T+1270  > ATSP0
T+1305  < OK\\r\\r>
T+1335  > 0100
T+3135  < SEARCHING...\\r41 00 00 10 00 01\\r\\r>
T+3165  > ATRV
T+3205  < 12.4V\\r\\r>
T+3235  > ATDPN
T+3265  < A6\\r\\r>
T+3295  > ATI
T+3325  < ELM327 v2.1\\r\\r>
T+3355  > 0120
T+3450  < 41 20 00 00 00 01\\r\\r>
T+3480  > 0140
T+3575  < 41 40 00 00 00 01\\r\\r>
T+3605  > 0160
T+3700  < 41 60 00 00 00 00\\r\\r>
T+3730  > 010C
T+3970  < 41 0C 0F A0\\r\\r>
T+4000  > 010C
T+4245  < 41 0C 0F A4\\r\\r>
T+4275  > 010C
T+5175  < BUFFER FULL\\r\\r>
T+5200  > 010C
T+5440  < 41 0C 0F A6\\r\\r>
T+5470  > 010C
T+5715  < 41 0C 0F A8\\r\\r>
T+5745  > 010C
T+5985  < 41 0C 0F AA\\r\\r>
''';

/// Wraps a real [MockTransport] for the handshake, then refuses to
/// reconnect — every `connect()` after the first throws — so a reconnect
/// ladder spends every one of its rungs retrying rather than succeeding on
/// the first, which is what a test of "the ladder actually stops" needs.
class _AlwaysFailingConnect implements ObdTransport {
  _AlwaysFailingConnect(this._inner);
  final MockTransport _inner;
  final _state = StreamController<TransportState>.broadcast();

  int connectAttempts = 0;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    connectAttempts++;
    if (connectAttempts == 1) {
      await _inner.connect();
      return;
    }
    throw Exception('refuses to reconnect');
  }

  /// What an unplugged adapter looks like — the ladder's trigger.
  Future<void> drop() async => _state.add(TransportState.disconnected);

  @override
  TransportKind get kind => _inner.kind;
  @override
  String get id => _inner.id;
  @override
  String get displayName => _inner.displayName;
  @override
  Stream<TransportState> get state => _state.stream;
  @override
  Stream<List<int>> get inbound => _inner.inbound;
  @override
  int get maxWriteLength => _inner.maxWriteLength;
  @override
  TransportCapabilities get capabilities => _inner.capabilities;
  @override
  Future<void> write(List<int> bytes) => _inner.write(bytes);
  @override
  Future<void> disconnect() => _inner.disconnect();
}
