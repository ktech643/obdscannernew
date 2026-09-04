import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/response_parser.dart';

void main() {
  ElmResponse parse(String cmd, String raw) => ResponseParser.parse(cmd, raw);

  group('the failure taxonomy — SPEC §4.4', () {
    // Every one of these strings appears in production on real hardware.
    const cases = <String, ElmStatus>{
      'NO DATA\r\r>': ElmStatus.noData,
      'NODATA\r>': ElmStatus.noData,
      '?\r\r>': ElmStatus.badCommand,
      'UNABLE TO CONNECT\r\r>': ElmStatus.noEcu,
      'BUS INIT: ERROR\r>': ElmStatus.busInitError,
      'BUS INIT: ...ERROR\r>': ElmStatus.busInitError,
      'CAN ERROR\r>': ElmStatus.canError,
      'BUS BUSY\r>': ElmStatus.busBusy,
      'BUFFER FULL\r>': ElmStatus.bufferFull,
      'STOPPED\r>': ElmStatus.stopped,
      'LV RESET\r>': ElmStatus.lowVoltage,
      'ERR94\r>': ElmStatus.internalError,
      'DATA ERROR\r>': ElmStatus.malformed,
    };

    cases.forEach((raw, expected) {
      test('${raw.trim().replaceAll('\r', ' ')} → ${expected.name}', () {
        expect(parse('010C', raw).status, expected);
      });
    });

    test('every taxonomy entry is handled without throwing', () {
      for (final raw in cases.keys) {
        expect(() => parse('0100', raw), returnsNormally);
      }
    });
  });

  group('clone quirks', () {
    test('strips the echo that survives ATE0', () {
      final r = parse('010C', '010C\r41 0C 1A F8\r\r>');
      expect(r.isOk, isTrue);
      expect(r.frames, ['410C1AF8']);
    });

    test('strips SEARCHING... prepended to the first real response', () {
      final r = parse('0100', 'SEARCHING...\r41 00 BE 3F A8 13\r\r>');
      expect(r.isOk, isTrue);
      expect(r.frames.single, '4100BE3FA813');
    });

    test('SEARCHING with nothing behind it is not a result', () {
      expect(parse('0100', 'SEARCHING...\r>').status, ElmStatus.searching);
    });

    test('removes spaces that survive ATS0', () {
      expect(parse('010C', '41 0C 1A F8\r>').frames.single, '410C1AF8');
      expect(parse('010C', '410C1AF8\r>').frames.single, '410C1AF8');
    });

    test('keeps multiple ECU frames as separate frames', () {
      final r = parse('010C', '41 0C 1A F8\r41 0C 1A F9\r\r>');
      expect(r.frames, ['410C1AF8', '410C1AF9']);
    });

    test('an odd-length frame is kept — it may carry a CAN header', () {
      // With ATH1 on, '7E8 04 41 0C 1A F8' squashes to 17 characters. That
      // is a header, not corruption, and the reassembler strips it.
      final r = parse('010C', '7E8 04 41 0C 1A F8\r>');
      expect(r.isOk, isTrue);
      expect(r.frames.single, '7E804410C1AF8');
      expect(
        ResponseParser.stripHeader(r.frames.single, headerChars: 3),
        '04410C1AF8',
      );
    });

    test('BUS INIT: OK is chatter before the real reply, like SEARCHING', () {
      final r = parse('0100', 'BUS INIT: OK\r41 00 BE 1E B8 11\r\r>');
      expect(r.isOk, isTrue);
      expect(r.frames.single, '4100BE1EB811');
    });

    test('OK is a valid non-hex reply', () {
      expect(parse('ATE0', 'OK\r\r>').isOk, isTrue);
    });

    test('an identity string is a valid non-hex reply', () {
      expect(parse('ATI', 'ELM327 v1.5\r\r>').isOk, isTrue);
    });

    test('a voltage reply is not treated as corruption', () {
      expect(parse('ATRV', '14.2V\r\r>').isOk, isTrue);
    });
  });

  group('hex helpers', () {
    test('round-trips bytes', () {
      expect(ResponseParser.hexToBytes('410C1AF8'), [0x41, 0x0C, 0x1A, 0xF8]);
      expect(ResponseParser.bytesToHex([0x41, 0x0C]), '410C');
    });

    test('strips an 11-bit CAN header when ATH1 is on', () {
      // 7E8 is the header; without stripping, 0x10 reads as payload.
      expect(
        ResponseParser.stripHeader('7E81014430A', headerChars: 3),
        '1014430A',
      );
    });
  });

  test('status classification drives recovery, not just display', () {
    expect(ElmStatus.lowVoltage.requiresRehandshake, isTrue);
    expect(ElmStatus.canError.requiresRehandshake, isTrue);
    // Per-PID noise must never reach the user.
    expect(ElmStatus.noData.isUserFacing, isFalse);
    expect(ElmStatus.bufferFull.isUserFacing, isFalse);
    expect(ElmStatus.noEcu.isUserFacing, isTrue);
  });
}
