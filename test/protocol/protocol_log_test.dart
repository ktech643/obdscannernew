import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/protocol/protocol_log.dart';

/// SPEC §10.4 — the last 500 protocol events, masked unless opted in.
void main() {
  const vin = '1HGBH41JXMN109186';

  /// The Mode 09 reply exactly as `headers_can.obdtrace` records it: three
  /// ISO-TP frames, the VIN as hex-encoded ASCII split 3 / 7 / 7.
  const mode09 =
      '7E8 10 14 49 02 01 31 48 47\r'
      '7E8 21 42 48 34 31 4A 58 4D\r'
      '7E8 22 4E 31 30 39 31 38 36\r\r>';

  group('the ring', () {
    test('keeps the last N and counts what fell off', () {
      final log = ProtocolLog(capacity: 3);
      for (var i = 0; i < 5; i++) {
        log.command('cmd$i', at: DateTime.utc(2026, 1, 1, 0, 0, i));
      }
      expect(log.events.map((e) => e.raw), ['cmd2', 'cmd3', 'cmd4']);
      expect(log.dropped, 2);
      expect(log.render(), startsWith('… 2 earlier events not kept'));
    });

    test('clear empties it and forgets the drop count', () {
      final log = ProtocolLog(capacity: 1);
      log.command('a');
      log.command('b');
      expect(log.dropped, 1);
      log.clear();
      expect(log.isEmpty, isTrue);
      expect(log.dropped, 0);
    });

    test('listeners hear every add and the clear', () {
      final log = ProtocolLog();
      var n = 0;
      log.addListener(() => n++);
      log.command('a');
      log.reply('OK', latencyMs: 12);
      log.clear();
      expect(n, 3);
    });

    test('a line carries time, direction, raw, parsed and latency', () {
      final log = ProtocolLog();
      log.command('010C', at: DateTime.utc(2026, 1, 1, 9, 41, 2, 100));
      log.reply(
        '41 0C 1A F8\r\r>',
        parsed: '1726 rpm',
        latencyMs: 88,
        at: DateTime.utc(2026, 1, 1, 9, 41, 2, 200),
      );
      final lines = log.render().split('\n');
      expect(lines[0], endsWith('  →  010C'));
      expect(lines[1], contains('←  41 0C 1A F8⏎⏎>  · 1726 rpm  88 ms'));
    });
  });

  group('★ §10.4 — the VIN is masked, in the hex too', () {
    test('the plain VIN is masked to prefix and suffix', () {
      expect(ProtocolLog.maskVinIn('VIN $vin here', vin), 'VIN 1HG••••••••••9186 here');
    });

    test('★ the raw Mode 09 reply no longer contains the VIN in hex', () {
      final log = ProtocolLog();
      log.command('0902');
      log.reply(mode09, parsed: vin, latencyMs: 160);
      final text = log.render(vin: vin);

      expect(text, isNot(contains(vin)), reason: 'the parsed column');
      // The middle ten characters, "BH41JXMN10", as they sit in the frames.
      expect(text, isNot(contains('42 48 34 31 4A 58 4D')), reason: 'frame 21');
      expect(text, isNot(contains('4E 31 30')), reason: 'frame 22, first three');
      // The kept prefix and suffix survive in both forms.
      expect(text, contains('31 48 47'), reason: '"1HG" stays');
      expect(text, contains('39 31 38 36'), reason: '"9186" stays');
      expect(text, contains('1HG••••••••••9186'));
    });

    test('opting in sends it whole', () {
      final log = ProtocolLog();
      log.reply(mode09, parsed: vin);
      final text = log.render(vin: vin, includeVin: true);
      expect(text, contains(vin));
      expect(text, contains('42 48 34 31 4A 58 4D'));
    });

    test('unrelated bytes that share a value with one VIN character are left alone', () {
      // "41 0C" — the RPM reply prefix — contains 0x41 ('A'), which is not in
      // this VIN, and 0x31 ('1') on its own must not be touched either.
      final log = ProtocolLog();
      log.reply('41 0C 1A F8\r\r>', parsed: '1726 rpm');
      log.reply('41 31 31\r\r>');
      final text = log.render(vin: vin);
      expect(text, contains('41 0C 1A F8'));
      expect(text, contains('41 31 31'));
    });

    test('a short or unknown VIN masks nothing', () {
      expect(ProtocolLog.maskVinIn('abc', 'abc'), 'abc');
      final log = ProtocolLog();
      log.reply(mode09);
      expect(log.render(), contains('42 48 34 31 4A 58 4D'));
    });

    test(
      '★ a repeated substring cannot make an interior fragment reveal itself',
      () {
        // "HGB" occurs at index 1-3 (straddling the disclosed prefix, so a
        // window ending there is correctly allowed a partial reveal) and
        // again at index 6-8 (entirely inside the always-masked interior).
        // Both spans hex-encode to the identical byte run "48 47 42" — an
        // adversarial-review find: an earlier version let whichever window
        // ran first stamp its replacement onto both occurrences, so a
        // fragmented reply carrying only the interior "HGB" leaked two real
        // VIN characters as "48 47 ••" instead of masking all three.
        const repeatVin = '1HGBXXHGBMN109186';
        expect(repeatVin.substring(1, 4), 'HGB');
        expect(repeatVin.substring(6, 9), 'HGB');

        // Exactly the isolated K-line-style fragment the class's own docs
        // anticipate: a header/PCI byte, the three-character VIN fragment,
        // a trailer byte — nothing else in the log to coincidentally match.
        final text = ProtocolLog.maskVinIn(
          '48 6B 10 49 02 03 48 47 42 F1',
          repeatVin,
        );
        expect(
          text,
          contains('48 6B 10 49 02 03 •• •• •• F1'),
          reason: 'the interior fragment is masked in full, not "48 47 ••"',
        );
      },
    );
  });
}
