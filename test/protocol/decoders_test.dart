import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/pid_registry.dart';
import 'package:torque_obd2/protocol/pid_scheduler.dart';
import 'package:torque_obd2/protocol/readiness_decoder.dart';
import 'package:torque_obd2/protocol/response_parser.dart';
import 'package:torque_obd2/protocol/vin_reader.dart';

void main() {
  List<int> hex(String s) => ResponseParser.hexToBytes(s.replaceAll(' ', ''));

  group('PID decoding — SPEC §4.3 formulas', () {
    test('RPM: ((A*256)+B)/4', () {
      // 41 0C 1A F8 → 0x1AF8 / 4 = 1726 rpm
      expect(PidRegistry.decodeResponse('010C', hex('41 0C 1A F8')), 1726);
    });

    test('speed is a raw byte', () {
      expect(PidRegistry.decodeResponse('010D', hex('41 0D 44')), 68);
    });

    test('coolant is offset by 40', () {
      expect(PidRegistry.decodeResponse('0105', hex('41 05 81')), 89);
    });

    test('a sub-zero temperature decodes with its sign', () {
      expect(PidRegistry.decodeResponse('0105', hex('41 05 00')), -40);
    });

    test('engine load scales to a percentage', () {
      expect(
        PidRegistry.decodeResponse('0104', hex('41 04 FF')),
        closeTo(100, 0.01),
      );
    });

    test('module voltage is millivolts', () {
      expect(
        PidRegistry.decodeResponse('0142', hex('41 42 37 72')),
        closeTo(14.194, 0.001),
      );
    });

    test('fuel trim is centred on 128', () {
      expect(PidRegistry.decodeResponse('0106', hex('41 06 80')), 0);
      expect(
        PidRegistry.decodeResponse('0106', hex('41 06 90')),
        closeTo(12.5, 0.01),
      );
    });
  });

  group('★ bounds rejection — corrupt frames never reach the UI', () {
    test('the bounds predicate rejects values outside the physical range', () {
      // Worth being precise about what this guard does. The SAE encodings are
      // designed so a well-formed frame always decodes inside its range — a
      // full-scale 0xFFFF lambda is 1.99997, which is legal. So the bound is
      // defence in depth against a decoder bug or a future formula, and the
      // *length* check below is what actually catches corrupt frames.
      final lambda = PidRegistry.lookup('0144')!;
      expect(lambda.inBounds(1.99997), isTrue);
      expect(lambda.inBounds(2.5), isFalse);
      expect(lambda.inBounds(-0.1), isFalse);

      final coolant = PidRegistry.lookup('0105')!;
      expect(coolant.inBounds(-40), isTrue, reason: 'sub-zero is legitimate');
      expect(coolant.inBounds(216), isFalse);
    });

    test('a full-scale frame on a scalar PID stays inside its bounds', () {
      // If an encoding ever exceeded its own bound, every full-throttle
      // reading would be silently dropped. Guard against that regression.
      for (final def in PidRegistry.all) {
        // Enum PIDs are exempt: fuel type is 0–23, so 0xFF genuinely is
        // corrupt and rejecting it is the point of the bound.
        if (def.isEnum) continue;
        final full = List.filled(def.dataBytes, 0xFF);
        final value = def.decode(full);
        expect(
          def.inBounds(value),
          isTrue,
          reason:
              '${def.pid} ${def.name}: full scale $value is out of its '
              'own declared bounds ${def.min}..${def.max}',
        );
      }
    });

    test('a short frame is rejected rather than read as a small value', () {
      // RPM needs two data bytes; one is malformed, not "low revs".
      expect(PidRegistry.decodeResponse('010C', hex('41 0C 1A')), isNull);
    });

    test('a response for a different PID is not decoded', () {
      expect(PidRegistry.decodeResponse('010C', hex('41 0D 44')), isNull);
    });

    test('an unknown PID has no decoder', () {
      expect(PidRegistry.decodeResponse('01FF', hex('41 FF 00')), isNull);
    });

    test('★ zero is a value, null is absence — they are never conflated', () {
      // A hybrid in EV mode genuinely reads 0 rpm. That must decode to 0.0,
      // not to null, and never to a sentinel.
      final zero = PidRegistry.decodeResponse('010C', hex('41 0C 00 00'));
      expect(zero, 0.0);
      expect(zero, isNotNull);
      expect(PidRegistry.decodeResponse('010C', hex('41 0C')), isNull);
    });
  });

  group('supported-PID bitmasks', () {
    test('unpacks the 32-bit mask, MSB is PID 01', () {
      // BE 3F A8 13 — the canonical example response to 0100.
      final supported = PidRegistry.decodeSupportMask(
        '0100',
        hex('41 00 BE 3F A8 13'),
      );
      expect(supported, contains('010C')); // RPM
      expect(supported, contains('010D')); // speed
      expect(supported, contains('0105')); // coolant
      expect(supported, isNot(contains('0102')));
    });

    test('a higher bank offsets correctly', () {
      final supported = PidRegistry.decodeSupportMask(
        '0120',
        hex('41 20 80 00 00 00'),
      );
      expect(supported, {'0121'});
    });

    test('a mismatched response yields nothing rather than guessing', () {
      expect(
        PidRegistry.decodeSupportMask('0100', hex('41 20 80 00 00 00')),
        isEmpty,
      );
    });
  });

  group('readiness monitors — SPEC §4.7', () {
    // A: MIL on, 2 DTCs.  B: spark, all three continuous available+complete.
    test('reads MIL state and DTC count from byte A', () {
      final report = ReadinessDecoder.decode(hex('41 01 82 07 00 00'))!;
      expect(report.milOn, isTrue);
      expect(report.dtcCount, 2);
    });

    test('MIL off with no codes', () {
      final report = ReadinessDecoder.decode(hex('41 01 00 07 00 00'))!;
      expect(report.milOn, isFalse);
      expect(report.dtcCount, 0);
    });

    test('★ three states, and "not supported" is not "not complete"', () {
      // B = 0x07 → all three continuous available; none incomplete.
      // C = 0x01 → only catalyst available.  D = 0x01 → catalyst incomplete.
      final report = ReadinessDecoder.decode(hex('41 01 00 07 01 01'))!;

      final catalyst = report.monitors.firstWhere((m) => m.name == 'Catalyst');
      final evap = report.monitors.firstWhere(
        (m) => m.name == 'Evaporative system',
      );
      expect(catalyst.state, MonitorState.notComplete);
      expect(
        evap.state,
        MonitorState.notSupported,
        reason: 'a monitor the vehicle lacks must never read "not complete"',
      );
    });

    test('spark ignition gets the petrol monitor set', () {
      final report = ReadinessDecoder.decode(hex('41 01 00 07 FF 00'))!;
      expect(report.ignitionType, IgnitionType.spark);
      expect(report.monitors.map((m) => m.name), contains('Oxygen sensor'));
      expect(
        report.monitors.map((m) => m.name),
        contains('Evaporative system'),
      );
    });

    test('★ compression ignition gets the diesel monitor set', () {
      // B bit 3 set → compression.
      final report = ReadinessDecoder.decode(hex('41 01 00 0F FF 00'))!;
      expect(report.ignitionType, IgnitionType.compression);
      expect(report.monitors.map((m) => m.name), contains('NOx / SCR monitor'));
      expect(report.monitors.map((m) => m.name), contains('PM filter'));
      // Petrol-only monitors must not appear on a diesel.
      expect(
        report.monitors.map((m) => m.name),
        isNot(contains('Evaporative system')),
      );
    });

    test('reserved bits are skipped, not mislabelled', () {
      final report = ReadinessDecoder.decode(hex('41 01 00 0F FF 00'))!;
      expect(report.monitors.any((m) => m.name.isEmpty), isFalse);
    });

    test(
      'the emissions verdict is a guideline, and MIL on always fails it',
      () {
        final clean = ReadinessDecoder.decode(hex('41 01 00 07 FF 00'))!;
        expect(clean.likelyPassesEmissions, isTrue);

        final milOn = ReadinessDecoder.decode(hex('41 01 81 07 FF 00'))!;
        expect(milOn.likelyPassesEmissions, isFalse);
      },
    );

    test('a short payload is rejected rather than half-decoded', () {
      expect(ReadinessDecoder.decode(hex('41 01 00')), isNull);
      expect(ReadinessDecoder.decode(hex('43 00 00 00 00 00')), isNull);
    });
  });

  group('VIN — ISO 3779', () {
    const valid = '1HGBH41JXMN109186'; // the standard's own worked example

    test('accepts a VIN with a correct check digit', () {
      final result = VinReader.validate(valid)!;
      expect(result.vin, valid);
      expect(result.checkDigitValid, isTrue);
      expect(result.wmi, '1HG');
    });

    test('★ a failed check digit is stored but never decoded', () {
      final result = VinReader.validate('1HGBH41J1MN109186')!;
      expect(result.checkDigitValid, isFalse);
      expect(result.isTrustworthy, isFalse);
      // Deriving a make or year from a corrupt read is worse than nothing.
      expect(result.wmi, isNull);
      expect(result.modelYear, isNull);
    });

    test('★ I, O and Q are forbidden — their presence proves a bad read', () {
      expect(VinReader.validate('1HGBH41JXMN10918I'), isNull);
      expect(VinReader.validate('1HGBH4OJXMN109186'), isNull);
      expect(VinReader.validate('1HGBH4QJXMN109186'), isNull);
    });

    test('a truncated VIN is rejected — 8 characters is not a VIN', () {
      expect(VinReader.validate('1HGBH41J'), isNull);
      expect(VinReader.validate(''), isNull);
    });

    test('parses a Mode 09 response', () {
      final payload = [0x49, 0x02, 0x01, ...valid.codeUnits];
      final result = VinReader.parseBytes(payload)!;
      expect(result.vin, valid);
      expect(result.checkDigitValid, isTrue);
    });

    test('a truncated multi-frame reply yields nothing, not a partial VIN', () {
      final payload = [0x49, 0x02, 0x01, ...'1HGBH41J'.codeUnits];
      expect(VinReader.parseBytes(payload), isNull);
    });

    test('masking keeps the WMI and the serial, hides the middle', () {
      expect(VinReader.mask(valid), '1HG••••••••••9186');
      expect(VinReader.mask(valid).length, valid.length);
    });
  });

  group('scheduler — SPEC §4.5', () {
    test('criticals run every cycle, low priority every twentieth', () {
      final s = PidScheduler()
        ..setSupported({'010C', '010D', '0105', '010E'})
        ..setVisible({'010C', '010D', '0105', '010E'});

      final first = s.nextCycle();
      expect(first, contains('010C')); // critical
      expect(first, contains('0105')); // high, cycle 0
      expect(first, contains('010E')); // low, cycle 0

      final second = s.nextCycle();
      expect(second, contains('010C'));
      expect(second, isNot(contains('0105')), reason: 'high runs every 2nd');
      expect(second, isNot(contains('010E')), reason: 'low runs every 20th');
    });

    test('★ only visible PIDs are polled', () {
      final s = PidScheduler()
        ..setSupported({'010C', '010D'})
        ..setVisible({'010C'});
      expect(s.nextCycle(), ['010C']);
    });

    test('unsupported PIDs are never polled', () {
      final s = PidScheduler()
        ..setSupported({'010C'})
        ..setVisible({'010C', '015C'});
      expect(s.nextCycle(), ['010C']);
    });

    test('three consecutive NO DATA drops a PID', () {
      final s = PidScheduler()
        ..setSupported({'010C', '010D'})
        ..setVisible({'010C', '010D'});

      s
        ..recordNoData('010D')
        ..recordNoData('010D');
      expect(s.nextCycle(), contains('010D'));

      s.recordNoData('010D');
      expect(s.droppedPids, contains('010D'));
      expect(s.nextCycle(), isNot(contains('010D')));
    });

    test('a success resets the streak and restores the PID', () {
      final s = PidScheduler()
        ..setSupported({'010D'})
        ..setVisible({'010D'});
      s
        ..recordNoData('010D')
        ..recordNoData('010D')
        ..recordNoData('010D');
      expect(s.droppedPids, contains('010D'));
      s.recordSuccess('010D');
      expect(s.droppedPids, isEmpty);
    });

    test('rate drops as latency rises, per the spec thresholds', () {
      final s = PidScheduler();
      expect(s.targetHz, 10);
      s.recordP95Rtt(300);
      expect(s.targetHz, 5);
      s.recordP95Rtt(700);
      expect(s.targetHz, 2);
      expect(s.isDegraded, isTrue, reason: 'the banner must appear at 2 Hz');
    });

    test('★ BUFFER FULL halves the rate immediately', () {
      final s = PidScheduler();
      expect(s.targetHz, 10);
      s.onBufferFull();
      expect(s.targetHz, 5);
      s.onBufferFull();
      expect(s.targetHz, 3);
    });

    test('the rate ramps back up but never past the target', () {
      final s = PidScheduler()..onBufferFull();
      for (var i = 0; i < 20; i++) {
        s.relax();
      }
      expect(s.targetHz, lessThanOrEqualTo(10));
    });

    test('a slow adapter reduces PIDs per cycle', () {
      final s = PidScheduler()..recordP95Rtt(300);
      // 5 Hz → 200 ms budget, 300 ms per command → one PID per cycle.
      expect(s.maxPidsPerCycle, 1);
    });
  });

  group('★ a tight budget delays PIDs, it never starves them', () {
    // Found by running the app: with six default tiles and a budget of
    // four, the two that sorted last were never asked for at all, so their
    // tiles read "No data" on a car that answers them.
    const layout = {'010C', '010D', '0105', '0104', '0111', '0142'};

    test('every visible PID is served within a few cycles', () {
      final s = PidScheduler()
        ..setSupported(layout)
        ..setVisible(layout);

      final served = <String>{};
      for (var i = 0; i < 12; i++) {
        served.addAll(s.nextCycle(maxPids: 4));
      }
      expect(
        served,
        containsAll(layout),
        reason: 'nothing may be permanently dropped',
      );
    });

    test('criticals are in every cycle they are due', () {
      final s = PidScheduler()
        ..setSupported(layout)
        ..setVisible(layout);
      for (var i = 0; i < 8; i++) {
        expect(s.nextCycle(maxPids: 4), containsAll(['010C', '010D']));
      }
    });

    test('a budget smaller than the criticals still returns them', () {
      final s = PidScheduler()
        ..setSupported(layout)
        ..setVisible(layout);
      final cycle = s.nextCycle(maxPids: 1);
      expect(cycle, containsAll(['010C', '010D']));
    });

    test('★ criticals that fill the budget still leave the rest a turn', () {
      // RPM and Speed on a 45 ms adapter are a budget of two. Returning
      // the criticals alone starved every other tile for good — "No data"
      // on a car that answers them, found by recording a trip, which asks
      // for Speed beside RPM.
      for (final budget in [1, 2]) {
        final s = PidScheduler()
          ..setSupported(layout)
          ..setVisible(layout);
        final served = <String>{};
        for (var i = 0; i < 24; i++) {
          served.addAll(s.nextCycle(maxPids: budget));
        }
        expect(served, containsAll(layout), reason: 'budget $budget');
      }
    });

    test('the budget is still respected when it can be', () {
      final s = PidScheduler()
        ..setSupported(layout)
        ..setVisible(layout);
      for (var i = 0; i < 8; i++) {
        expect(s.nextCycle(maxPids: 4).length, lessThanOrEqualTo(4));
      }
    });
  });
}
