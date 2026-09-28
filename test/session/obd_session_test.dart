import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';
import 'package:torque_obd2/transport/obd_transport.dart';

import '../data/support.dart';

/// The whole session — transport, handshake, discovery, poll loop, Modes 03
/// and 04 — driven through the twenty recorded sessions in `assets/traces/`.
///
/// Replay runs at 100x with every internal delay scaled to match, so a full
/// conversation with a car takes milliseconds and nothing is mocked except
/// the wire itself.
/// Replay timing note: `speed: 100` makes recorded replies arrive at a
/// hundredth of their real latency (a 900 ms NO DATA lands in 9 ms), while
/// `timeScale` scales the *timeouts* waiting for them. At 0.01 the deadline
/// was 12 ms against a 9 ms reply — a 3 ms margin, which any machine load
/// blows through, and the suite flaked. 0.05 keeps replay just as fast and
/// gives the deadline 60 ms, which is a margin rather than a coin toss.
void main() {
  const traceDir = 'assets/traces';

  Future<MockTransport> transportFor(String name) async {
    final source = await File('$traceDir/$name.obdtrace').readAsString();
    return MockTransport(ObdTrace.parse(source), speed: 100);
  }

  /// A session wired to [name], at replay speed. Always disconnected at the
  /// end of the test so no poll loop outlives it.
  Future<ObdSession> sessionFor(String name, {DtcRepository? dtcs}) async {
    final s = ObdSession(timeScale: 0.05, dtcs: dtcs);
    addTearDown(() async {
      await s.disconnect();
      s.dispose();
    });
    return s;
  }

  /// Waits for [condition], polling the microtask queue. Replay is fast, so
  /// a generous ceiling still fails quickly when something is wrong.
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
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  group('★ a clean CAN session, end to end', () {
    test(
      'connects, handshakes, discovers PIDs and publishes live values',
      () async {
        final session = await sessionFor('clean_can');
        final states = <SessionState>[];
        session.addListener(() => states.add(session.state));

        final ok = await session.connect(await transportFor('clean_can'));

        expect(ok, isTrue);
        expect(session.state, SessionState.connected);
        expect(session.protocol?.number, 6);
        expect(session.adapterIdentity, contains('ELM327'));
        // The raw ATZ reply still carries the '>' prompt and its carriage
        // returns; what reaches the UI must be a name, not framing.
        expect(session.adapterIdentity, 'ELM327 v1.5');
        expect(session.batteryVolts, closeTo(14.2, 0.01));
        expect(states, contains(SessionState.handshaking));

        // The support bitmasks decided what may be polled at all.
        expect(session.supportedPids, contains('010C'));
        expect(session.supportedPids, contains('0105'));

        // ...and the poll loop is publishing real decoded values.
        await waitFor(
          () => session.bus.of('010C').value?.value != null,
          reason: 'an RPM sample',
        );
        expect(session.bus.of('010C').value!.value, 1726);

        await waitFor(() => session.bus.of('0105').value?.value != null);
        expect(session.bus.of('0105').value!.value, 89, reason: 'coolant °C');
      },
    );

    test(
      'the dashboard clock ticks so tiles can decay without new samples',
      () async {
        final session = await sessionFor('clean_can');
        final start = session.clock.value;
        await session.connect(await transportFor('clean_can'));
        await waitFor(() => session.clock.value.isAfter(start));
      },
    );

    test('only visible, supported PIDs are ever asked for', () async {
      final session = await sessionFor('clean_can');
      final transport = await transportFor('clean_can');
      await session.connect(transport);
      session.setVisible({'010C'});

      // Let a few cycles run, then look at what actually went out.
      await waitFor(() => session.bus.of('010C').value != null);
      final before = transport.written.length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final asked = transport.written
          .skip(before)
          .map((w) => w.trim())
          .where((c) => c.startsWith('01'))
          .toSet();
      expect(asked, isNotEmpty);
      expect(asked, everyElement('010C'));
    });

    test(
      '★ hard rule 9 — backgrounding stops the loop unless recording',
      () async {
        final session = await sessionFor('clean_can');
        final transport = await transportFor('clean_can');
        await session.connect(transport);
        await waitFor(() => session.bus.of('010C').value != null);

        session.setBackgrounded(true);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final quiet = transport.written.length;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          transport.written.length,
          quiet,
          reason: 'no polling backgrounded',
        );

        // A trip recording is the one thing that keeps it running.
        session.setRecording(true);
        await waitFor(
          () => transport.written.length > quiet,
          reason: 'polling resumes while recording',
        );
      },
    );
  });

  group('★ diagnostics', () {
    test(
      'no codes: every mode answers, and the readiness summary decodes',
      () async {
        final session = await sessionFor('no_dtcs');
        await session.connect(await transportFor('no_dtcs'));
        final r = await session.readDtcs();
        expect(r.isEmpty, isTrue);
        expect(r.milOn, isFalse);
        expect(r.readiness, isNotNull);
      },
    );

    test('twelve codes reassemble out of a multi-frame reply', () async {
      final session = await sessionFor('twelve_dtc');
      await session.connect(await transportFor('twelve_dtc'));
      final r = await session.readDtcs();
      expect(r.stored, hasLength(12));
      expect(r.stored.map((d) => d.code), contains('P0301'));
      expect(r.milOn, isTrue);
    });

    test('stored, pending and permanent are kept apart', () async {
      final session = await sessionFor('pending_permanent');
      await session.connect(await transportFor('pending_permanent'));
      final r = await session.readDtcs();
      expect(r.pending, isNotEmpty);
      expect(r.permanent, isNotEmpty);
      for (final d in r.pending) {
        expect(d.mode, DtcMode.pending);
      }
      for (final d in r.permanent) {
        expect(d.mode, DtcMode.permanent);
      }
    });

    test('permanent codes can be withheld for the free tier', () async {
      final session = await sessionFor('pending_permanent');
      await session.connect(await transportFor('pending_permanent'));
      final r = await session.readDtcs(includePermanent: false);
      expect(r.permanent, isEmpty);
      expect(r.pending, isNotEmpty, reason: 'free tier still sees these');
    });

    test('a multi-frame VIN reassembles and validates', () async {
      final session = await sessionFor('vin_multiframe');
      await session.connect(await transportFor('vin_multiframe'));
      final vin = await session.readVin();
      expect(vin, isNotNull);
      expect(vin!.vin.length, 17);
    });
  });

  group('★ SPEC §9.5 — clearing codes', () {
    late AppDatabase db;
    late DtcRepository repo;
    late String vehicleId;

    setUp(() async {
      db = memoryDb();
      repo = DtcRepository(db);
      vehicleId = (await golf(db)).id;
    });
    tearDown(() => db.close());

    test(
      'the snapshot is written before Mode 04 and settled after the re-read',
      () async {
        final session = await sessionFor('clear_ok', dtcs: repo);
        await session.connect(await transportFor('clear_ok'));

        final result = await session.clearDtcs(vehicleId: vehicleId);
        expect(result, ClearResult.cleared);

        final history = await repo.history(vehicleId);
        expect(history, hasLength(2), reason: 'a before and an after');
        final before = history.firstWhere(
          (s) => s.purpose == SnapshotPurpose.beforeClear,
        );
        final after = history.firstWhere(
          (s) => s.purpose == SnapshotPurpose.afterClear,
        );
        expect(before.clearOutcome, ClearOutcome.cleared);
        expect(before.relatedSnapshotId, after.id);
        expect(after.relatedSnapshotId, before.id);
        expect(await repo.unreconciledClears(), isEmpty);
      },
    );

    test(
      '★ a code that comes straight back is never reported as cleared',
      () async {
        final session = await sessionFor('clear_returns', dtcs: repo);
        await session.connect(await transportFor('clear_returns'));

        final result = await session.clearDtcs(vehicleId: vehicleId);
        expect(result, ClearResult.codesReturned);
        final before = (await repo.history(vehicleId))
            .firstWhere((s) => s.purpose == SnapshotPurpose.beforeClear);
        expect(before.clearOutcome, ClearOutcome.codesReturned);
      },
    );

    test(
      'clearing without a repository still works, it just keeps no history',
      () async {
        final session = await sessionFor('clear_ok');
        await session.connect(await transportFor('clear_ok'));
        expect(await session.clearDtcs(), ClearResult.cleared);
      },
    );

    test('clearing with no link is interrupted, not a crash', () async {
      final session = await sessionFor('clear_ok', dtcs: repo);
      expect(
        await session.clearDtcs(vehicleId: vehicleId),
        ClearResult.interrupted,
      );
    });
  });

  group('★ failure paths', () {
    test('an adapter that never answers fails the handshake', () async {
      final session = await sessionFor('adapter_unresponsive');
      final ok = await session.connect(
        await transportFor('adapter_unresponsive'),
      );
      expect(ok, isFalse);
      expect(session.isLive, isFalse);
      expect(session.lastError, isNotNull);
    });

    test('UNABLE TO CONNECT ends as unsupported, with a reason', () async {
      final session = await sessionFor('unable_to_connect');
      final ok = await session.connect(await transportFor('unable_to_connect'));
      expect(ok, isFalse);
      expect(session.state, isNot(SessionState.connected));
      expect(session.lastError, isNotNull);
      expect(session.bus.of('010C').value, isNull, reason: 'nothing published');
    });

    test('a slow ISO 9141 car still lands, on the right protocol', () async {
      final session = await sessionFor('slow_iso9141');
      final ok = await session.connect(await transportFor('slow_iso9141'));
      expect(ok, isTrue);
      expect(session.protocol?.number, isNot(6));
    });

    test('KWP fast init lands too', () async {
      final session = await sessionFor('kwp_fast');
      expect(await session.connect(await transportFor('kwp_fast')), isTrue);
    });

    test('an echoing clone is handled without corrupting values', () async {
      final session = await sessionFor('clone_echo');
      final ok = await session.connect(await transportFor('clone_echo'));
      expect(ok, isTrue);
      await waitFor(() => session.bus.of('010C').value?.value != null);
      expect(session.bus.of('010C').value!.value, greaterThan(0));
    });

    test(
      '★ BUFFER FULL halves the poll rate rather than dropping the link',
      () async {
        final session = await sessionFor('buffer_full_poll');
        final before = session.scheduler.targetHz;
        final ok = await session.connect(
          await transportFor('buffer_full_poll'),
        );
        expect(ok, isTrue);

        // This adapter never recovers — the recorded overflow is the last
        // reply and is held — so the rate must stay down rather than be put
        // back to 10 Hz by the latency feedback on the next fast cycle.
        await waitFor(
          () => session.bufferOverflows > 0,
          reason: 'the overflow to be seen',
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(session.scheduler.targetHz, lessThan(before));
        expect(session.isLive, isTrue, reason: 'an overflow is not a drop');
      },
    );

    test(
      'a clone that overflows only on batched reads is an ordinary session',
      () async {
        // This build never batches, so clone_buffer_full never overflows.
        final session = await sessionFor('clone_buffer_full');
        expect(
          await session.connect(await transportFor('clone_buffer_full')),
          isTrue,
        );
        expect(session.bufferOverflows, 0);
      },
    );
  });

  group('lifecycle', () {
    test('disconnect stops the loop and clears the bus', () async {
      final session = ObdSession(timeScale: 0.05);
      final transport = await transportFor('clean_can');
      await session.connect(transport);
      await waitFor(() => session.bus.of('010C').value != null);

      await session.disconnect();
      expect(session.state, SessionState.disconnected);
      expect(session.bus.of('010C').value, isNull);
      expect(session.protocol, isNull);

      final quiet = transport.written.length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        transport.written.length,
        quiet,
        reason: 'the loop really stopped',
      );
      session.dispose();
    });

    test(
      '★ a second connect supersedes the first; the loser is closed',
      () async {
        final session = ObdSession(timeScale: 0.05);
        final first = await transportFor('clean_can');
        final second = await transportFor('clean_can');

        final a = session.connect(first);
        final b = session.connect(second);
        await Future.wait([a, b]);

        expect(session.state, SessionState.connected);
        await waitFor(() => session.bus.of('010C').value != null);

        // The loser never got a handshake; the winner did.
        expect(first.written, isEmpty);
        expect(second.written, contains('ATZ'));

        // And the loser's transport really is shut: MockTransport drops
        // writes when it is not connected, so nothing is recorded.
        await first.write('ATZ\r'.codeUnits);
        expect(first.written, isEmpty, reason: 'the superseded link is shut');

        await session.disconnect();
        session.dispose();
      },
    );
  });

  group('GaugeCatalog', () {
    test('every default-layout PID has a spec the registry knows', () {
      for (final pid in GaugeCatalog.defaultLayout) {
        final spec = GaugeCatalog.specFor(pid);
        expect(spec, isNotNull, reason: pid);
        expect(spec!.label, isNotEmpty);
        expect(spec.max, greaterThan(spec.min));
      }
    });

    test('bands sit inside the PID physical range, never outside it', () {
      for (final pid in GaugeCatalog.gaugeable) {
        final spec = GaugeCatalog.specFor(pid)!;
        if (spec.normalLow != null) {
          expect(spec.normalLow, greaterThanOrEqualTo(spec.min), reason: pid);
          expect(spec.normalLow, lessThan(spec.max), reason: pid);
        }
        if (spec.normalHigh != null) {
          expect(spec.normalHigh, lessThanOrEqualTo(spec.max), reason: pid);
          expect(spec.normalHigh, greaterThan(spec.min), reason: pid);
        }
        if (spec.normalLow != null && spec.normalHigh != null) {
          expect(spec.normalHigh!, greaterThan(spec.normalLow!), reason: pid);
        }
      }
    });

    test('enums and one-shot reads are never offered as gauges', () {
      expect(
        GaugeCatalog.gaugeable,
        isNot(contains('0151')),
        reason: 'fuel type',
      );
      expect(GaugeCatalog.gaugeable, contains('010C'));
    });

    test('an unsupported PID still gets a spec, so the tile can say why', () {
      final spec = GaugeCatalog.specFor('015C', supported: false);
      expect(spec, isNotNull);
      expect(spec!.supported, isFalse);
    });
  });
  // ------------------------------------------------------------------
  // Regressions from the Phase 6 slice-1 review. Each of these failed
  // before the fix it names.
  // ------------------------------------------------------------------

  group('★ headers — ATH1 is on, so every reply carries one', () {
    test(
      'the header width is measured, not assumed, and everything decodes',
      () async {
        final session = await sessionFor('headers_can');
        final ok = await session.connect(await transportFor('headers_can'));
        expect(ok, isTrue);

        // 11-bit CAN: a 3-character header. Three is odd, which is what
        // shifted every byte-pairing by a nibble before this was handled.
        expect(session.headerChars, 3);

        // The support masks decoded, so there is something to poll at all.
        expect(session.supportedPids, contains('010C'));
        expect(session.supportedPids, contains('0142'));

        // The same physical values as the header-less clean_can trace.
        await waitFor(() => session.bus.of('010C').value?.value != null);
        expect(session.bus.of('010C').value!.value, 1726);
        await waitFor(() => session.bus.of('0105').value?.value != null);
        expect(session.bus.of('0105').value!.value, 89);
      },
    );

    test('codes and a multi-frame VIN decode through the header too', () async {
      final session = await sessionFor('headers_can');
      await session.connect(await transportFor('headers_can'));

      final r = await session.readDtcs();
      expect(r.stored.map((d) => d.code), containsAll(['P0301', 'P0420']));
      expect(r.milOn, isTrue, reason: 'from the headered 0101 summary');
      expect(r.complete, isTrue);

      final vin = await session.readVin();
      expect(vin, isNotNull);
      expect(vin!.vin, '1HGBH41JXMN109186');
    });

    test('a header-less adapter still calibrates to zero', () async {
      final session = await sessionFor('clean_can');
      await session.connect(await transportFor('clean_can'));
      expect(session.headerChars, 0);
      await waitFor(() => session.bus.of('010C').value?.value != null);
      expect(session.bus.of('010C').value!.value, 1726);
    });

    test('two ECUs answering one query still yield a usable mask', () async {
      final session = await sessionFor('two_ecu');
      final ok = await session.connect(await transportFor('two_ecu'));
      expect(ok, isTrue);
      expect(session.headerChars, 3);
      expect(session.supportedPids, isNotEmpty);
    });
  });

  group('★ the clock is independent of the poll loop (hard rule 4)', () {
    test('it keeps ticking while backgrounded, so tiles still decay', () async {
      final session = await sessionFor('clean_can');
      await session.connect(await transportFor('clean_can'));
      await waitFor(() => session.bus.of('010C').value != null);

      session.setBackgrounded(true);
      final at = session.clock.value;
      await waitFor(
        () => session.clock.value.isAfter(at),
        reason: 'the clock to tick with the loop stopped',
      );
    });
  });

  group('★ clearing — what the app is allowed to claim', () {
    late AppDatabase db;
    late DtcRepository repo;
    late String vehicleId;

    setUp(() async {
      db = memoryDb();
      repo = DtcRepository(db);
      vehicleId = (await golf(db)).id;
    });
    tearDown(() => db.close());

    test(
      'a negative response is a refusal, not "the code came back"',
      () async {
        final session = await sessionFor('clear_refused', dtcs: repo);
        await session.connect(await transportFor('clear_refused'));
        expect(
          await session.clearDtcs(vehicleId: vehicleId),
          ClearResult.refused,
        );
        final before = (await repo.history(vehicleId))
            .firstWhere((s) => s.purpose == SnapshotPurpose.beforeClear);
        expect(before.clearOutcome, ClearOutcome.refused);
      },
    );

    test('a link drop during Mode 04 leaves the snapshot pending', () async {
      // Mode 04 is never answered: the ECU may well have cleared and only
      // the reply was lost, which is exactly what the snapshot is for.
      final session = await sessionFor('clear_interrupted', dtcs: repo);
      await session.connect(await transportFor('clear_interrupted'));
      expect(
        await session.clearDtcs(vehicleId: vehicleId),
        ClearResult.interrupted,
      );
      final pending = await repo.unreconciledClears(vehicleId);
      expect(pending, hasLength(1), reason: 'relaunch must reconcile this');
      expect(pending.single.clearOutcome, ClearOutcome.pending);
    });

    test('an unverifiable re-read is never reported as cleared', () async {
      // Mode 04 succeeds, but the verifying Mode 03 does not answer.
      final session = await sessionFor('clear_unverified', dtcs: repo);
      await session.connect(await transportFor('clear_unverified'));
      expect(
        await session.clearDtcs(vehicleId: vehicleId),
        ClearResult.interrupted,
      );
      expect(await repo.unreconciledClears(vehicleId), hasLength(1));
    });

    test('an unanswered mode is not the same as no codes', () async {
      final session = await sessionFor('clear_unverified');
      await session.connect(await transportFor('clear_unverified'));

      // The first read answers normally.
      final first = await session.readDtcs();
      expect(first.complete, isTrue);
      expect(first.stored, isNotEmpty);

      // The second finds the bus busy: no codes were parsed, but that is
      // not the same as the car having none.
      final second = await session.readDtcs();
      expect(second.complete, isFalse);
      expect(second.stored, isEmpty);
      expect(second.isEmpty, isFalse, reason: 'empty but not trustworthy');
      expect(second.failedModes, contains('03'));
    });
  });

  group('★ recovery paths that used to wedge', () {
    test(
      'LV RESET re-handshakes and polling resumes in the same loop',
      () async {
        final session = await sessionFor('lv_reset_recovers');
        final ok = await session.connect(
          await transportFor('lv_reset_recovers'),
        );
        expect(ok, isTrue);

        // The first poll answers LV RESET; the session must re-handshake and
        // then keep polling rather than going quiet for good.
        await waitFor(
          () => session.bus.of('010C').value?.value != null,
          reason: 'a sample after the re-handshake',
        );
        expect(session.isLive, isTrue);
      },
    );

    test(
      'ignitionOff keeps a slow probe running and recovers on its own',
      () async {
        final session = await sessionFor('ignition_wakes');
        final ok = await session.connect(await transportFor('ignition_wakes'));
        expect(ok, isTrue);

        await waitFor(
          () => session.state == SessionState.ignitionOff,
          reason: 'three UNABLE TO CONNECT replies',
        );
        // The key comes back: the probe must notice without any user action.
        await waitFor(
          () => session.state == SessionState.connected,
          reason: 'the session to wake up again',
          timeout: const Duration(seconds: 10),
        );
        expect(session.bus.of('010C').value?.value, isNotNull);
      },
    );
  });

  group('★ connect and reconnect', () {
    test(
      'a transport that refuses to open is reported, and nothing leaks',
      () async {
        final session = await sessionFor('clean_can');
        final transport = _RefusingTransport();
        final ok = await session.connect(transport);
        expect(ok, isFalse);
        expect(session.state, SessionState.disconnected);
        expect(session.lastError, contains('adapter refused'));
        expect(session.isLive, isFalse);
      },
    );

    test(
      'the escalating ATZ retry recovers from three dropped commands',
      () async {
        final session = await sessionFor('clean_can');
        final transport = await transportFor('clean_can');
        transport.dropNext = 3;
        final ok = await session.connect(transport);
        expect(ok, isTrue, reason: 'the fourth ATZ is answered');
        expect(session.adapterIdentity, contains('ELM327'));
      },
    );

    test(
      '★ the reconnect ladder runs every rung, not just the first',
      () async {
        final session = await sessionFor('clean_can');
        final transport = _FlakyTransport(await transportFor('clean_can'));
        await session.connect(transport);

        // Fail the next three handshakes, then let it through.
        transport.failConnects = 3;
        transport.drop();

        await waitFor(
          () => session.reconnectAttempt >= 3,
          reason: 'the ladder to reach at least rung 3',
          timeout: const Duration(seconds: 10),
        );
      },
    );
  });

  // ------------------------------------------------------------------
  // Slice 17: the session under a trip recording, and in the background.
  // ------------------------------------------------------------------

  /// Longer than the whole §9.2 ladder: 0.5 + 1 + 2 + 4 + 8 s is 775 ms at
  /// 0.05, and every rung's own connect on top.
  const pastTheLadder = Duration(milliseconds: 1200);

  group('★ hard rule 9 — the ladder parks in the background', () {
    test('★ backgrounded with no recording, a lost link parks the ladder '
        '(AC-11)', () async {
      final session = await sessionFor('clean_can');
      final inner = await transportFor('clean_can');
      final transport = _FlakyTransport(inner);
      await session.connect(transport);
      await waitFor(() => session.bus.of('010C').value != null);
      session.setBackgrounded(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final before = inner.written.length;

      transport.drop();
      await Future<void>.delayed(pastTheLadder);

      // Not even a handshake: an adapter dialled from a pocket all the way
      // down the ladder, and a phone that never sleeps.
      expect(inner.written.skip(before), isEmpty);
      expect(session.state, SessionState.lost);
      expect(session.reconnecting, isTrue, reason: 'the ladder owns it');

      session.setBackgrounded(false);
      await waitFor(
        () => session.state == SessionState.connected,
        reason: 'the parked ladder to pick up where it stopped',
      );
      expect(inner.written.skip(before), contains('ATZ'));
    });

    test('★ a ladder already running parks at its next rung when '
        'backgrounded', () async {
      final session = await sessionFor('clean_can');
      final transport = _FlakyTransport(await transportFor('clean_can'));
      await session.connect(transport);
      transport.failConnects = 1000;
      transport.drop();
      await waitFor(
        () => session.reconnectAttempt >= 2,
        reason: 'the ladder under way in the foreground',
      );

      session.setBackgrounded(true);
      final dialled = transport.connects;
      await Future<void>.delayed(pastTheLadder);

      // The rung already waiting may dial once more; none after it. Parked
      // only where the link was lost, the rest of the ladder ran here.
      expect(transport.connects, lessThanOrEqualTo(dialled + 1));
      expect(session.lastError, isNot('Could not reconnect'));
      expect(session.reconnecting, isTrue);

      transport.failConnects = 0;
      session.setBackgrounded(false);
      await waitFor(
        () => session.state == SessionState.connected,
        reason: 'the rest of the ladder, run in the foreground',
        timeout: const Duration(seconds: 10),
      );
    });

    test('★ a user connect cancels a parked ladder', () async {
      final session = await sessionFor('clean_can');
      final lost = _FlakyTransport(await transportFor('clean_can'));
      await session.connect(lost);
      session.setBackgrounded(true);
      lost.drop();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(session.reconnecting, isTrue, reason: 'parked');
      final dialled = lost.connects;

      final chosen = _FlakyTransport(await transportFor('clean_can'));
      expect(await session.connect(chosen), isTrue);

      // The user's link drops in turn. Left set from the park,
      // `_reconnecting` turned this loss away: no ladder, and a dead link
      // shown as connected.
      chosen.drop();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(session.state, SessionState.lost);

      session.setBackgrounded(false);
      await waitFor(
        () => session.state == SessionState.connected,
        reason: "the fresh ladder, over the user's link",
      );
      expect(chosen.connects, 2);
      expect(lost.connects, dialled, reason: 'the old link is never dialled');
    });
  });

  group('★ §9.2 — how the end of a link is heard', () {
    test('★ giving up is heard as over', () async {
      final session = await sessionFor('clean_can');
      final transport = _FlakyTransport(await transportFor('clean_can'));
      await session.connect(transport);
      transport.failConnects = 1000;
      final heard = <({SessionState state, String? error, bool ladder})>[];
      session.addListener(
        () => heard.add((
          state: session.state,
          error: session.lastError,
          ladder: session.reconnecting,
        )),
      );

      transport.drop();
      await waitFor(
        () => session.lastError == 'Could not reconnect',
        reason: 'the ladder to give up',
        timeout: const Duration(seconds: 10),
      );

      // Heard with `reconnecting` still set, the end reads as one more
      // failed rung, and a trip holds on a link that is not coming back.
      final end = heard.firstWhere((h) => h.error == 'Could not reconnect');
      expect(end.state, SessionState.disconnected);
      expect(end.ladder, isFalse);
      final rungs = heard.where(
        (h) =>
            h.state == SessionState.disconnected &&
            h.error != 'Could not reconnect',
      );
      expect(rungs, isNotEmpty);
      expect(rungs.every((h) => h.ladder), isTrue, reason: 'a failed rung');
    });

    test('★ auto-reconnect off: one notification, with its reason', () async {
      final session = await sessionFor('clean_can');
      session.autoReconnect = false;
      final transport = await transportFor('clean_can');
      await session.connect(transport);
      await waitFor(() => session.bus.of('010C').value != null);
      final heard = <(SessionState, String?)>[];
      session.addListener(() => heard.add((session.state, session.lastError)));

      // The adapter dies without a word: three timeouts, the watchdog.
      transport.dropNext = 1 << 30;
      await waitFor(
        () => session.state == SessionState.disconnected,
        reason: 'the watchdog',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Heard first with no error, the loss read as the user's own stop,
      // and a trip it ended was filed as a clean one.
      expect(heard.where((h) => h.$1 == SessionState.disconnected), [
        (SessionState.disconnected, 'Connection lost'),
      ]);
    });
  });

  group('★ a trip recording in the background', () {
    test('★ a backgrounded recording polls once per background interval '
        '(§5.3, §9.3)', () async {
      final session = await sessionFor('trip_drive_can');
      session.backgroundInterval = const Duration(seconds: 2);
      final transport = await transportFor('trip_drive_can');
      await session.connect(transport);
      session.setVisible({'010D', '015E'});
      await waitFor(() => session.bus.of('010D').value != null);
      final hz = session.scheduler.targetHz;

      session.setBackgrounded(true);
      session.setRecording(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final from = transport.written.length;
      await Future<void>.delayed(const Duration(seconds: 1));

      // 2 s at 0.05 is a 100 ms window: about ten cycles in the second,
      // each asking Speed once. At the foreground rate, about two hundred.
      final cycles = transport.written.skip(from).where((c) => c == '010D');
      expect(cycles.length, inInclusiveRange(1, 12));
      // A floor on the wait, not a rate: a rate of 0.5 Hz is "Weak link".
      expect(session.state, SessionState.connected);
      expect(session.scheduler.targetHz, hz);
    });

    test("★ a quiet PID's drop does not raise Weak link", () async {
      // This car declares 5E in its 0140 mask and answers NO DATA to it —
      // a real car can. Without its exchanges the mock says NO DATA.
      final full = ObdTrace.parse(
        await File('$traceDir/trip_drive_can.obdtrace').readAsString(),
      );
      final events = <TraceEvent>[];
      for (var i = 0; i < full.events.length; i++) {
        final e = full.events[i];
        if (e.isRequest && ObdTrace.normalise(e.payload) == '015E') {
          i++; // and its reply
          continue;
        }
        events.add(e);
      }
      final trace = ObdTrace(events: events, adapter: full.adapter);
      expect(trace.repliesByCommand.keys, isNot(contains('015E')));

      Future<ObdSession> dropFuelRate({required Set<String> quiet}) async {
        final session = await sessionFor('trip_drive_can');
        session.setVisible({'010D', '015E'});
        session.setQuiet(quiet);
        expect(await session.connect(MockTransport(trace, speed: 100)), isTrue);
        expect(session.supportedPids, contains('015E'), reason: 'declared');
        await waitFor(
          () => session.scheduler.droppedPids.contains('015E'),
          reason: 'three NO DATA',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return session;
      }

      final recorded = await dropFuelRate(quiet: {'015E'});
      expect(
        recorded.state,
        SessionState.connected,
        reason: 'nothing on screen is missing',
      );
      final shown = await dropFuelRate(quiet: const {});
      expect(
        shown.state,
        SessionState.degraded,
        reason: 'a tile gone missing is a weak link',
      );

      // ★ The recording ends: Fuel rate is neither quiet nor asked for any
      // more. Counted still, it raised "Weak link" for the rest of the
      // connection over nothing on screen.
      recorded
        ..setQuiet(const {})
        ..setVisible({'010D'});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(recorded.scheduler.droppedPids, contains('015E'));
      expect(
        recorded.state,
        SessionState.connected,
        reason: 'what is not asked for cannot be missing',
      );
    });
  });

  group('the session after dispose, and what it runs over', () {
    test('setBackgrounded and setRecording after dispose start nothing and '
        'throw nothing', () async {
      final session = ObdSession(timeScale: 0.05);
      final transport = await transportFor('clean_can');
      await session.connect(transport);
      await waitFor(() => session.bus.of('010C').value != null);
      session.setBackgrounded(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      session.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final quiet = transport.written.length;

      // A lifecycle event that lands after the owner is gone.
      expect(() => session.setRecording(true), returnsNormally);
      expect(() => session.setBackgrounded(false), returnsNormally);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(transport.written.length, quiet);
    });

    test('transportKind is set while connected', () async {
      final session = await sessionFor('clean_can');
      expect(session.transportKind, isNull);
      await session.connect(await transportFor('clean_can'));
      expect(session.transportKind, TransportKind.mock);
      await session.disconnect();
      expect(session.transportKind, isNull);
    });
  });
}

/// A transport whose `connect` throws, for the failure path.
class _RefusingTransport implements ObdTransport {
  @override
  TransportKind get kind => TransportKind.mock;
  @override
  String get id => 'mock:refusing';
  @override
  String get displayName => 'Refusing adapter';
  @override
  Stream<TransportState> get state => const Stream.empty();
  @override
  Stream<List<int>> get inbound => const Stream.empty();
  @override
  int get maxWriteLength => 20;
  @override
  TransportCapabilities get capabilities => TransportCapabilities.mock;
  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    throw Exception('adapter refused');
  }

  @override
  Future<void> write(List<int> bytes) async {}
  @override
  Future<void> disconnect() async {}
}

/// Wraps a [MockTransport] so a test can drop the link and make the next
/// few `connect` calls fail — the shape the reconnect ladder is for.
class _FlakyTransport implements ObdTransport {
  _FlakyTransport(this._inner);
  final MockTransport _inner;
  final _state = StreamController<TransportState>.broadcast();

  int failConnects = 0;

  /// Every `connect` asked of this link, failed ones included: how a test
  /// sees a ladder rung dial.
  int connects = 0;

  void drop() => _state.add(TransportState.disconnected);

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
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    connects++;
    if (failConnects > 0) {
      failConnects--;
      throw Exception('still down');
    }
    await _inner.connect();
  }

  @override
  Future<void> write(List<int> bytes) => _inner.write(bytes);

  @override
  Future<void> disconnect() => _inner.disconnect();
}
