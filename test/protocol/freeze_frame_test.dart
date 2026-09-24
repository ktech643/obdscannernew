import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/freeze_frame.dart';

/// SPEC §5.4 — Mode 02. A Mode 02 reply is a Mode 01 reply with the frame
/// number wedged in before the data; every decoder here must step over it.
void main() {
  group('decodeDtc', () {
    test('42 02 00 A B is the code the frame belongs to', () {
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x00, 0x03, 0x01]), 'P0301');
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x00, 0x04, 0x20]), 'P0420');
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x00, 0xC1, 0x00]), 'U0100');
    });

    test('00 00 means the ECU keeps no frame', () {
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x00, 0x00, 0x00]), isNull);
    });

    test('another frame, a short reply or a Mode 01 reply is not a frame', () {
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x01, 0x03, 0x01]), isNull);
      expect(FreezeFrameDecoder.decodeDtc([0x42, 0x02, 0x00, 0x03]), isNull);
      expect(FreezeFrameDecoder.decodeDtc([0x41, 0x02, 0x00, 0x03, 0x01]), isNull);
      expect(FreezeFrameDecoder.decodeDtc([]), isNull);
    });

    test('a CAN header and length byte in front change nothing', () {
      expect(
        FreezeFrameDecoder.decodeDtc([0x05, 0x42, 0x02, 0x00, 0x03, 0x01]),
        'P0301',
      );
    });
  });

  group('★ decodeValue', () {
    test('★ the frame byte is stepped over, not read as data', () {
      // 42 0C 00 0B B8: 750 rpm. Reading the frame byte as data would give
      // (0x00 * 256 + 0x0B) / 4 = 2.75 rpm — inside the PID's bounds, and
      // wrong.
      expect(
        FreezeFrameDecoder.decodeValue('010C', [0x42, 0x0C, 0x00, 0x0B, 0xB8]),
        750,
      );
      expect(FreezeFrameDecoder.decodeValue('0105', [0x42, 0x05, 0x00, 0x5A]), 50);
      expect(FreezeFrameDecoder.decodeValue('010D', [0x42, 0x0D, 0x00, 0x00]), 0);
      expect(
        FreezeFrameDecoder.decodeValue('0106', [0x42, 0x06, 0x00, 0x8C]),
        closeTo(9.375, 1e-9),
      );
    });

    test('the same formula and bounds as the live tiles', () {
      // Coolant 0xFF would be 215 °C — the registry's bound refuses it.
      expect(FreezeFrameDecoder.decodeValue('0105', [0x42, 0x05, 0x00, 0xFF]), 215);
      // A reply for another PID, frame or mode is not this value.
      expect(FreezeFrameDecoder.decodeValue('010C', [0x42, 0x0D, 0x00, 0x0B, 0xB8]), isNull);
      expect(FreezeFrameDecoder.decodeValue('010C', [0x42, 0x0C, 0x01, 0x0B, 0xB8]), isNull);
      expect(FreezeFrameDecoder.decodeValue('010C', [0x41, 0x0C, 0x0B, 0xB8]), isNull);
      // Short: one data byte where two are needed.
      expect(FreezeFrameDecoder.decodeValue('010C', [0x42, 0x0C, 0x00, 0x0B]), isNull);
    });

    test('only Mode 01 ids are freeze-frame PIDs', () {
      expect(FreezeFrameDecoder.decodeValue('0902', [0x42, 0x02, 0x00, 0x01]), isNull);
      expect(FreezeFrameDecoder.decodeValue('nope', [0x42, 0x02, 0x00, 0x01]), isNull);
    });
  });

  group('decodeSupportMask', () {
    test('42 00 00 + four bytes, MSB first is PID 01', () {
      final pids = FreezeFrameDecoder.decodeSupportMask([
        0x42, 0x00, 0x00, 0xBE, 0x3F, 0xA8, 0x13,
      ]);
      expect(pids, containsAll(['0101', '0103', '0104', '0105', '0106', '0107']));
      expect(pids, containsAll(['010C', '010D', '010E', '010F', '0110', '0111']));
      expect(pids, containsAll(['011C', '011F', '0120']));
      expect(pids, isNot(contains('0102')));
      expect(pids, isNot(contains('0108')));
      expect(pids, hasLength(18));
    });

    test('anything else is an empty mask', () {
      expect(FreezeFrameDecoder.decodeSupportMask([0x42, 0x00, 0x01, 1, 2, 3, 4]), isEmpty);
      expect(FreezeFrameDecoder.decodeSupportMask([0x41, 0x00, 0xBE, 0x3F, 0xA8, 0x13]), isEmpty);
      expect(FreezeFrameDecoder.decodeSupportMask([]), isEmpty);
    });
  });

  group('pidsToRead', () {
    test('with a mask: the preferred ones the car offers, in order', () {
      final pids = FreezeFrameDecoder.pidsToRead({'010D', '0105', '010C', '0142'});
      expect(pids, ['010C', '010D', '0105', '0142']);
    });

    test('without a mask: the eight most useful, and never more than the cap', () {
      expect(FreezeFrameDecoder.pidsToRead(const {}), hasLength(8));
      expect(FreezeFrameDecoder.pidsToRead(const {}).first, '010C');
      expect(
        FreezeFrameDecoder.pidsToRead(FreezeFrameDecoder.preferredPids.toSet(), limit: 3),
        ['010C', '010D', '0105'],
      );
    });
  });

  group('FreezeFrame JSON', () {
    test('round-trips', () {
      const f = FreezeFrame(dtc: 'P0301', values: {'010C': 750, '0105': 50});
      expect(FreezeFrame.fromJson(f.toJson()), f);
      expect(FreezeFrame.tryParse('{"dtc":"P0301","frame":0,"values":{"010C":750}}'),
          const FreezeFrame(dtc: 'P0301', values: {'010C': 750}));
    });

    test('is tolerant: a bad value is dropped, a bad document is null', () {
      final f = FreezeFrame.fromJson({
        'dtc': 'P0301',
        'values': {'010C': 750, '0105': 'hot', '010D': double.nan, 7: 1},
      });
      expect(f?.values, {'010C': 750});
      expect(FreezeFrame.fromJson({'values': {}}), isNull, reason: 'no code');
      expect(FreezeFrame.fromJson('P0301'), isNull);
      expect(FreezeFrame.tryParse('{not json'), isNull);
    });
  });
}
