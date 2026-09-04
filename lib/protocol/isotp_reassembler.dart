import 'response_parser.dart';

/// ISO 15765-2 (ISO-TP) frame reassembly.
///
/// Any response longer than 7 payload bytes arrives split across frames:
///
/// ```
/// 10 14 43 0A 01 43 01 96      first frame: 0x1_ + 12-bit total length
/// 21 02 34 03 01 04 55 06      consecutive: 0x2_ + sequence number
/// 22 66 00 00 00 00 00 00
/// ```
///
/// **Skipping this is the classic cheap-app bug**: a car with 12 stored codes
/// shows 3, and the user is told their car is healthier than it is. Tested
/// against a 12-DTC trace.
class IsoTpReassembler {
  const IsoTpReassembler._();

  /// Reassembles [frames] into a single payload.
  ///
  /// Handles single frames, first+consecutive sequences, and the legacy
  /// protocols (ISO 9141, KWP, J1850) which have no ISO-TP layer at all and
  /// simply concatenate.
  ///
  /// [headerChars] strips a CAN header when `ATH1` is in effect — 3 for
  /// 11-bit, 8 for 29-bit. Without it the first payload byte is read as part
  /// of the header and every decode is silently wrong.
  static List<int> reassemble(List<String> frames, {int headerChars = 0}) {
    if (frames.isEmpty) return const [];

    final stripped = [
      for (final f in frames)
        ResponseParser.stripHeader(f, headerChars: headerChars),
    ].where((f) => f.length >= 2).toList();

    if (stripped.isEmpty) return const [];

    final firstByte = int.parse(stripped.first.substring(0, 2), radix: 16);
    final pci = firstByte >> 4;

    return switch (pci) {
      0 => _single(stripped.first),
      1 => _multi(stripped),
      // Not ISO-TP framed. Legacy protocols and header-less clone output land
      // here; concatenating is correct for both.
      _ => [for (final f in stripped) ...ResponseParser.hexToBytes(f)],
    };
  }

  /// `0L dd dd …` — low nibble is the payload length.
  static List<int> _single(String frame) {
    final bytes = ResponseParser.hexToBytes(frame);
    if (bytes.isEmpty) return const [];
    final length = bytes.first & 0x0F;
    final payload = bytes.skip(1).toList();
    return payload.length <= length ? payload : payload.sublist(0, length);
  }

  /// `1L LL …` then `2N …`. The 12-bit length spans the first two bytes.
  static List<int> _multi(List<String> frames) {
    final first = ResponseParser.hexToBytes(frames.first);
    if (first.length < 2) return const [];

    final totalLength = ((first[0] & 0x0F) << 8) | first[1];
    final out = <int>[...first.skip(2)];

    var expectedSequence = 1;
    for (final frame in frames.skip(1)) {
      final bytes = ResponseParser.hexToBytes(frame);
      if (bytes.isEmpty) continue;

      final pci = bytes.first >> 4;
      if (pci != 2) continue; // flow control or noise between frames

      // Sequence numbers run 1..15 then wrap to 0. A gap means a dropped
      // frame, and a partially reassembled payload is worse than none —
      // it decodes into plausible but wrong codes.
      final sequence = bytes.first & 0x0F;
      if (sequence != expectedSequence % 16) return const [];
      expectedSequence++;

      out.addAll(bytes.skip(1));
    }

    if (out.length < totalLength) return const []; // truncated, don't guess
    return out.sublist(0, totalLength);
  }
}
