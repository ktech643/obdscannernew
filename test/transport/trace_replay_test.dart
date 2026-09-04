import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/protocol/elm_session.dart';
import 'package:torque_obd2/protocol/isotp_reassembler.dart';
import 'package:torque_obd2/protocol/pid_registry.dart';
import 'package:torque_obd2/protocol/pid_scheduler.dart';
import 'package:torque_obd2/protocol/protocol_negotiator.dart';
import 'package:torque_obd2/protocol/readiness_decoder.dart';
import 'package:torque_obd2/protocol/response_parser.dart';
import 'package:torque_obd2/protocol/vin_reader.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// Every bundled trace, end to end through the Phase 1 engine.
///
/// This is the integration tier of the pyramid: no device, no plugin, no car,
/// and every clone quirk the field has produced replayed on every commit.
void main() {
  const traceDir = 'assets/traces';

  /// A session over a trace at 100× speed with timeouts scaled to match.
  Future<
    ({
      MockTransport transport,
      ElmSession session,
      ProtocolNegotiator negotiator,
    })
  >
  open(String name) async {
    final source = await File('$traceDir/$name.obdtrace').readAsString();
    final transport = MockTransport(ObdTrace.parse(source), speed: 100);
    final session = ElmSession(transport, timeScale: 0.01);
    await transport.connect();
    return (
      transport: transport,
      session: session,
      negotiator: ProtocolNegotiator(session),
    );
  }

  test('all 20 bundled traces are present and parse', () async {
    final files = Directory(traceDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.obdtrace'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(20));
    for (final f in files) {
      final trace = ObdTrace.parse(await f.readAsString());
      expect(trace.events, isNotEmpty, reason: f.path);
      expect(
        trace.adapter,
        isNotNull,
        reason: '${f.path} lacks an adapter header',
      );
    }
  });

  group('clean CAN — the reference session', () {
    test('handshakes on protocol 6 with a healthy voltage', () async {
      final o = await open('clean_can');
      final steps = <String>[];
      final result = await o.negotiator.handshake(
        onProgress: (n, label) => steps.add('$n $label'),
      );

      expect(result.ok, isTrue);
      expect(result.protocol?.number, 6);
      expect(result.batteryVolts, closeTo(14.2, 0.01));
      expect(result.adapterIdentity, contains('ELM327'));
      expect(result.echoActive, isFalse);
      expect(result.headersUnavailable, isFalse);
      expect(steps.first, startsWith('1 '));
      expect(steps.last, startsWith('7 '));
      expect(o.transport.written.take(7), [
        'ATZ',
        'ATE0',
        'ATL0',
        'ATS0',
        'ATH1',
        'ATSP0',
        '0100',
      ]);
    });

    test('discovers supported PIDs and never polls outside them', () async {
      final o = await open('clean_can');
      await o.negotiator.handshake();

      final supported = <String>{};
      for (final q in PidRegistry.supportQueries.take(3)) {
        final r = await o.session.send(q, timeout: ElmSession.slowTimeout);
        if (r.isOk) supported.addAll(PidRegistry.decodeSupportMask(q, r.bytes));
      }
      expect(supported, contains('010C'));
      expect(supported, contains('010D'));

      final scheduler = PidScheduler()
        ..setSupported(supported)
        ..setVisible({'010C', '010D', '01FF'}); // 01FF isn't real
      expect(scheduler.nextCycle(), isNot(contains('01FF')));
    });

    test('decodes live values', () async {
      final o = await open('clean_can');
      await o.negotiator.handshake();

      final rpm = await o.session.send('010C');
      expect(PidRegistry.decodeResponse('010C', rpm.bytes), 1726);
      final speed = await o.session.send('010D');
      expect(PidRegistry.decodeResponse('010D', speed.bytes), 68);
      final coolant = await o.session.send('0105');
      expect(PidRegistry.decodeResponse('0105', coolant.bytes), 89);
      final volts = await o.session.send('0142');
      expect(
        PidRegistry.decodeResponse('0142', volts.bytes),
        closeTo(14.19, 0.01),
      );
    });

    test('reads readiness and finds no codes', () async {
      final o = await open('clean_can');
      await o.negotiator.handshake();
      final readiness = ReadinessDecoder.decode(
        (await o.session.send('0101')).bytes,
      )!;
      expect(readiness.milOn, isFalse);
      expect(readiness.ignitionType, IgnitionType.spark);
      expect(readiness.incompleteCount, 0);
      expect(
        DtcDecoder.decode((await o.session.send('03')).frames, DtcMode.stored),
        isEmpty,
      );
    });
  });

  group('★ twelve_dtc — the classic cheap-app bug, on a real trace', () {
    test('all twelve codes come back, in order', () async {
      final o = await open('twelve_dtc');
      await o.negotiator.handshake();
      final r = await o.session.send('03');
      final codes = DtcDecoder.decode(r.frames, DtcMode.stored);
      expect(codes.length, 12);
      expect(codes.first.code, 'P0101');
      expect(codes.last.code, 'P0011');
      expect(codes.map((c) => c.code), contains('U0100'));
    });

    test('the ECU count agrees with the decoded count', () async {
      final o = await open('twelve_dtc');
      await o.negotiator.handshake();
      final payload = IsoTpReassembler.reassemble(
        (await o.session.send('03')).frames,
      );
      expect(DtcDecoder.reportedCount(payload, DtcMode.stored), 12);
    });

    test('readiness reports the MIL on with 12 codes', () async {
      final o = await open('twelve_dtc');
      await o.negotiator.handshake();
      final r = ReadinessDecoder.decode((await o.session.send('0101')).bytes)!;
      expect(r.milOn, isTrue);
      expect(r.dtcCount, 12);
    });
  });

  test('pending_permanent — the three lists stay distinct', () async {
    final o = await open('pending_permanent');
    await o.negotiator.handshake();
    final stored = DtcDecoder.decode(
      (await o.session.send('03')).frames,
      DtcMode.stored,
    );
    final pending = DtcDecoder.decode(
      (await o.session.send('07')).frames,
      DtcMode.pending,
    );
    final permanent = DtcDecoder.decode(
      (await o.session.send('0A')).frames,
      DtcMode.permanent,
    );
    expect(stored.map((c) => c.code), ['P0301', 'P0420']);
    expect(pending.single.code, 'P0133');
    expect(pending.single.mode, DtcMode.pending);
    expect(permanent.single.code, 'P0420');
    expect(permanent.single.mode, DtcMode.permanent);
  });

  group('diesel_readiness', () {
    test('the compression bit switches the monitor set', () async {
      final o = await open('diesel_readiness');
      await o.negotiator.handshake();
      final r = ReadinessDecoder.decode((await o.session.send('0101')).bytes)!;
      expect(r.ignitionType, IgnitionType.compression);
      expect(r.monitors.map((m) => m.name), contains('NOx / SCR monitor'));
      expect(
        r.monitors.map((m) => m.name),
        isNot(contains('Evaporative system')),
      );
    });

    test('three NO DATAs drop lambda from the schedule', () async {
      final o = await open('diesel_readiness');
      await o.negotiator.handshake();
      final scheduler = PidScheduler()
        ..setSupported({'010C', '0144'})
        ..setVisible({'010C', '0144'});
      for (var i = 0; i < 3; i++) {
        final r = await o.session.send('0144');
        expect(r.status, ElmStatus.noData);
        scheduler.recordNoData('0144');
      }
      expect(scheduler.droppedPids, contains('0144'));
      expect(scheduler.nextCycle(), ['010C']);
    });
  });

  test(
    'ev_minimal — fewer than 6 PIDs and no RPM is the honest-state trigger',
    () async {
      final o = await open('ev_minimal');
      final result = await o.negotiator.handshake();
      expect(result.ok, isTrue, reason: '0100 answers on an EV');

      final supported = <String>{};
      for (final q in PidRegistry.supportQueries.take(3)) {
        final r = await o.session.send(q, timeout: ElmSession.slowTimeout);
        if (r.isOk) supported.addAll(PidRegistry.decodeSupportMask(q, r.bytes));
      }
      expect(supported.length, lessThan(6));
      expect(supported, isNot(contains('010C')));
      expect(supported, isNot(contains('0110')));
      expect((await o.session.send('010C')).status, ElmStatus.noData);
    },
  );

  group('clone quirks, on real traces', () {
    test(
      'clone_echo — the echo is stripped and the session still works',
      () async {
        final o = await open('clone_echo');
        final result = await o.negotiator.handshake();
        expect(result.ok, isTrue);
        final rpm = await o.session.send('010C');
        expect(rpm.isOk, isTrue);
        expect(PidRegistry.decodeResponse('010C', rpm.bytes), 1000);
      },
    );

    test(
      'clone_buffer_full — BUFFER FULL halves the rate, ATWS recovers',
      () async {
        final o = await open('clone_buffer_full');
        await o.negotiator.handshake();
        final scheduler = PidScheduler();
        final batch = await o.session.send('010C0D11');
        expect(batch.status, ElmStatus.bufferFull);
        scheduler.onBufferFull();
        expect(scheduler.targetHz, 5);
        expect((await o.session.send('ATWS')).isOk, isTrue);
        expect((await o.session.send('010C')).isOk, isTrue);
      },
    );

    test(
      'spaces_survive_ats0 — ATS0 rejected, frames still normalise',
      () async {
        final o = await open('spaces_survive_ats0');
        expect((await o.negotiator.handshake()).ok, isTrue);
        final rpm = await o.session.send('010C');
        expect(rpm.frames.single, '410C1AF8');
      },
    );

    test('no_headers — ATH1 rejected, flagged, session continues', () async {
      final o = await open('no_headers');
      final result = await o.negotiator.handshake();
      expect(result.ok, isTrue);
      expect(result.headersUnavailable, isTrue);
      expect(o.session.headersUnavailable, isTrue);
    });

    test(
      'two_ecu — headers on, both replies kept, first one decodes',
      () async {
        final o = await open('two_ecu');
        expect((await o.negotiator.handshake()).ok, isTrue);
        final rpm = await o.session.send('010C');
        expect(
          rpm.frames.length,
          2,
          reason: 'engine and gearbox both answered',
        );
        final payload = IsoTpReassembler.reassemble([
          rpm.frames.first,
        ], headerChars: 3);
        expect(PidRegistry.decodeResponse('010C', payload), 1726);
      },
    );
  });

  group('failure and recovery, on real traces', () {
    test(
      'lv_reset — the second read browns out and demands a re-handshake',
      () async {
        final o = await open('lv_reset');
        await o.negotiator.handshake();
        expect((await o.session.send('010C')).isOk, isTrue);
        final r = await o.session.send('010C');
        expect(r.status, ElmStatus.lowVoltage);
        expect(r.status.requiresRehandshake, isTrue);
        expect(r.status.isUserFacing, isTrue);
      },
    );

    test('can_error — CAN ERROR then ATWS then back to normal', () async {
      final o = await open('can_error');
      await o.negotiator.handshake();
      expect((await o.session.send('010D')).status, ElmStatus.canError);
      expect((await o.session.send('ATWS')).isOk, isTrue);
      expect((await o.session.send('010D')).isOk, isTrue);
    });

    test(
      '★ unable_to_connect — ignition-off is distinguished from a dead link',
      () async {
        final o = await open('unable_to_connect');
        final result = await o.negotiator.handshake();
        expect(result.ok, isFalse);
        expect(result.failedAtStep, 6);
        expect(result.status, ElmStatus.noEcu);
        // The adapter is alive — it's the car that isn't answering. That is
        // "turn the ignition on", not an error.
        final volts = await o.session.send('ATRV');
        expect(volts.isOk, isTrue);
        expect(volts.raw, contains('11.8'));
      },
    );

    test('adapter_unresponsive — ATZ escalates then fails at step 1', () async {
      final o = await open('adapter_unresponsive');
      final result = await o.negotiator.handshake();
      expect(result.ok, isFalse);
      expect(result.failedAtStep, 1);
      expect(result.status, ElmStatus.timeout);
      // Four ATZ attempts with escalating delay, then a warm start.
      expect(o.transport.written.where((c) => c == 'ATZ').length, 4);
      expect(o.transport.written.last, 'ATWS');
    });

    test(
      'searching_slow — SEARCHING alone is waited out, not retried blind',
      () async {
        final o = await open('searching_slow');
        final result = await o.negotiator.handshake();
        expect(result.ok, isTrue);
        expect(o.transport.written.where((c) => c == '0100').length, 2);
      },
    );
  });

  group('older vehicles — the protocol ladder', () {
    test('slow_iso9141 — walks the ladder to ATSP3', () async {
      final o = await open('slow_iso9141');
      final steps = <String>[];
      final result = await o.negotiator.handshake(
        onProgress: (n, label) => steps.add(label),
      );
      expect(result.ok, isTrue);
      expect(result.protocol?.number, 3);
      expect(result.protocol?.slowInit, isTrue);
      expect(steps, contains('Trying protocol 7 of 9'));
      expect(o.transport.written, contains('ATSP3'));
    });

    test('kwp_fast — auto-detect lands on protocol 5', () async {
      final o = await open('kwp_fast');
      final result = await o.negotiator.handshake();
      expect(result.ok, isTrue);
      expect(result.protocol?.number, 5);
    });

    test('a cached protocol skips negotiation entirely', () async {
      final o = await open('clean_can');
      final result = await o.negotiator.handshake(cachedProtocol: 6);
      expect(result.ok, isTrue);
      expect(result.protocol?.number, 6);
      // Straight to the probe — no ATSP0, no ladder.
      expect(o.transport.written, isNot(contains('ATSP0')));
    });
  });

  test('vin_multiframe — three frames reassemble into a valid VIN', () async {
    final o = await open('vin_multiframe');
    await o.negotiator.handshake();
    final r = await o.session.send('0902');
    expect(r.frames.length, 3);
    final vin = VinReader.parse(r.frames)!;
    expect(vin.vin, '1HGBH41JXMN109186');
    expect(vin.checkDigitValid, isTrue);
    expect(vin.wmi, '1HG');
    expect(VinReader.mask(vin.vin), '1HG••••••••••9186');
  });

  test('★ the serialisation invariant holds across every trace', () async {
    // If any trace ever provoked an overlapping write, this would catch it.
    final files = Directory(traceDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.obdtrace'));
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.obdtrace', '');
      final o = await open(name);
      await o.negotiator.handshake();
      // Fire a burst without awaiting, then drain.
      final burst = [for (var i = 0; i < 5; i++) o.session.send('010C')];
      await Future.wait(burst);
      expect(o.session.isBusy, isFalse, reason: name);
      expect(o.session.queueDepth, 0, reason: name);
      await o.session.dispose();
      await o.transport.dispose();
    }
  });
}
