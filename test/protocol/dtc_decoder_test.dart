import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/protocol/isotp_reassembler.dart';
import 'package:torque_obd2/protocol/response_parser.dart';

void main() {
  group('SAE J2012 two-byte decode', () {
    test('decodes the canonical example', () {
      expect(DtcDecoder.decodePair(0x03, 0x01), 'P0301');
    });

    test('decodes every system letter', () {
      expect(DtcDecoder.decodePair(0x01, 0x33), 'P0133');
      expect(DtcDecoder.decodePair(0x41, 0x23), 'C0123');
      expect(DtcDecoder.decodePair(0x81, 0x23), 'B0123');
      expect(DtcDecoder.decodePair(0xC1, 0x23), 'U0123');
    });

    test('decodes hex digits in the third and fourth positions', () {
      expect(DtcDecoder.decodePair(0x04, 0x20), 'P0420');
      expect(DtcDecoder.decodePair(0x1A, 0xBC), 'P1ABC');
    });

    test('0x0000 is padding, not code P0000', () {
      expect(DtcDecoder.decodePair(0x00, 0x00), isNull);
    });
  });

  group('single-frame responses', () {
    test('CAN, with the count byte', () {
      // 43 02 → mode, then 2 codes.
      final codes = DtcDecoder.decodeBytes(
        ResponseParser.hexToBytes('4302030104200000'),
        DtcMode.stored,
      );
      expect(codes.map((c) => c.code), containsAll(['P0301', 'P0420']));
    });

    test('legacy, without the count byte', () {
      final codes = DtcDecoder.decodeBytes(
        ResponseParser.hexToBytes('43030104200000'),
        DtcMode.stored,
      );
      expect(codes.map((c) => c.code), containsAll(['P0301', 'P0420']));
    });

    test('padding at the end is dropped', () {
      final codes = DtcDecoder.decodeBytes(
        ResponseParser.hexToBytes('43010301000000000000'),
        DtcMode.stored,
      );
      expect(codes.length, 1);
      expect(codes.single.code, 'P0301');
    });

    test('pending and permanent use their own response bytes', () {
      expect(
        DtcDecoder.decodeBytes(
          ResponseParser.hexToBytes('4701 0133'.replaceAll(' ', '')),
          DtcMode.pending,
        ).single.code,
        'P0133',
      );
      expect(
        DtcDecoder.decodeBytes(
          ResponseParser.hexToBytes('4A010420'),
          DtcMode.permanent,
        ).single.code,
        'P0420',
      );
    });

    test('a stored-mode decode ignores a pending response', () {
      expect(
        DtcDecoder.decodeBytes(
          ResponseParser.hexToBytes('47010133'),
          DtcMode.stored,
        ),
        isEmpty,
      );
    });
  });

  group('★ ISO-TP multi-frame — the classic cheap-app bug', () {
    // 12 stored codes. An app without reassembly shows the first three and
    // tells the user their car is healthier than it is.
    const twelve = [
      'P0101',
      'P0301',
      'P0420',
      'P0133',
      'P0171',
      'P0300',
      'P0455',
      'C0561',
      'B1318',
      'U0100',
      'P2196',
      'P0011',
    ];

    /// Builds a real ISO-TP multi-frame Mode 03 response from a code list, so
    /// the fixture can't drift away from what it claims to contain.
    List<String> framesFor(List<String> codes) {
      final payload = <int>[0x43, codes.length];
      for (final code in codes) {
        payload.addAll(_encodeDtc(code));
      }
      final frames = <String>[
        ResponseParser.bytesToHex([
          0x10 | ((payload.length >> 8) & 0x0F),
          payload.length & 0xFF,
          ...payload.take(6),
        ]),
      ];
      var offset = 6;
      var sequence = 1;
      while (offset < payload.length) {
        final slice = payload.skip(offset).take(7).toList();
        frames.add(
          ResponseParser.bytesToHex([0x20 | (sequence & 0x0F), ...slice]),
        );
        offset += slice.length;
        sequence++;
      }
      return frames;
    }

    test('reassembles all 12 codes, not just the first 3', () {
      final codes = DtcDecoder.decode(framesFor(twelve), DtcMode.stored);
      expect(codes.length, 12, reason: 'ISO-TP reassembly must be complete');
    });

    test('the reported count matches what was decoded', () {
      final payload = IsoTpReassembler.reassemble(framesFor(twelve));
      expect(DtcDecoder.reportedCount(payload, DtcMode.stored), 12);
      expect(DtcDecoder.decodeBytes(payload, DtcMode.stored).length, 12);
    });

    test('decodes the exact codes, in order, across all four frames', () {
      final codes = DtcDecoder.decode(
        framesFor(twelve),
        DtcMode.stored,
      ).map((c) => c.code).toList();
      expect(codes, twelve);
      // Codes from the last frame prove reassembly ran to completion.
      expect(codes, contains('P0011'));
      expect(codes, contains('U0100'));
    });

    test(
      'a dropped consecutive frame yields nothing, never a partial list',
      () {
        // A partial list of plausible codes is worse than none: the user acts
        // on codes their car never reported.
        final full = framesFor(twelve);
        final gapped = [full[0], full[1], full[3]];
        expect(IsoTpReassembler.reassemble(gapped), isEmpty);
      },
    );

    test('a truncated final frame yields nothing', () {
      final truncated = framesFor(twelve).take(2).toList();
      expect(IsoTpReassembler.reassemble(truncated), isEmpty);
    });
  });

  group('ISO-TP framing', () {
    test('single frame respects its declared length', () {
      // 06 = 6 payload bytes; the trailing 00s are padding.
      expect(
        IsoTpReassembler.reassemble(['064100BE3FA81300']),
        ResponseParser.hexToBytes('4100BE3FA813'),
      );
    });

    test('legacy protocols concatenate — they have no ISO-TP layer', () {
      expect(
        IsoTpReassembler.reassemble(['410C1AF8']),
        ResponseParser.hexToBytes('410C1AF8'),
      );
    });

    test('strips CAN headers when ATH1 is on', () {
      final codes = DtcDecoder.decode(
        ['${'7E8064302030104200000'.substring(0, 3)}06430203010420'],
        DtcMode.stored,
        headerChars: 3,
      );
      expect(codes.map((c) => c.code), containsAll(['P0301', 'P0420']));
    });

    test('empty input is empty output, not a crash', () {
      expect(IsoTpReassembler.reassemble([]), isEmpty);
      expect(DtcDecoder.decode([], DtcMode.stored), isEmpty);
    });
  });

  group('code classification', () {
    test('P0/P2 are SAE generic; P1/P3 are manufacturer-specific', () {
      expect(
        const RawDtc('P0301', DtcMode.stored).isManufacturerSpecific,
        isFalse,
      );
      expect(
        const RawDtc('P1602', DtcMode.stored).isManufacturerSpecific,
        isTrue,
      );
      expect(
        const RawDtc('P3497', DtcMode.stored).isManufacturerSpecific,
        isTrue,
      );
    });

    test('the system letter is exposed for the severity bar', () {
      expect(const RawDtc('U0123', DtcMode.stored).system, 'U');
    });
  });
}

/// Inverse of [DtcDecoder.decodePair] — used only to build test fixtures.
List<int> _encodeDtc(String code) {
  const letters = {'P': 0, 'C': 1, 'B': 2, 'U': 3};
  final letter = letters[code[0]]!;
  final first = int.parse(code[1]);
  final second = int.parse(code[2], radix: 16);
  final third = int.parse(code[3], radix: 16);
  final fourth = int.parse(code[4], radix: 16);
  return [(letter << 6) | (first << 4) | second, (third << 4) | fourth];
}
