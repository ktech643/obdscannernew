import 'isotp_reassembler.dart';

/// Which list a code came from. These are genuinely different things and the
/// UI must not merge them: a pending code is being watched, a stored code has
/// tripped, a permanent code cannot be cleared until the ECU is satisfied.
enum DtcMode {
  /// Mode 03 — confirmed, MIL-illuminating.
  stored,

  /// Mode 07 — detected this drive cycle, not yet confirmed.
  pending,

  /// Mode 0A — cannot be cleared by a scan tool.
  permanent,
}

extension DtcModeX on DtcMode {
  String get command => switch (this) {
    DtcMode.stored => '03',
    DtcMode.pending => '07',
    DtcMode.permanent => '0A',
  };

  /// The response byte that prefixes this mode's payload.
  int get responseByte => switch (this) {
    DtcMode.stored => 0x43,
    DtcMode.pending => 0x47,
    DtcMode.permanent => 0x4A,
  };
}

/// A decoded trouble code. Carries no human-readable text — that comes from
/// the bundled dictionary, and **is never invented** when the code is absent
/// from it.
class RawDtc {
  const RawDtc(this.code, this.mode);

  /// e.g. `P0301`.
  final String code;
  final DtcMode mode;

  /// P = powertrain, C = chassis, B = body, U = network.
  String get system => code[0];

  /// SAE-defined codes are P0xxx/P2xxx/P34xx-P39xx; the rest are
  /// manufacturer-specific and have no generic meaning.
  bool get isManufacturerSpecific {
    final second = code[1];
    return second == '1' || second == '3';
  }

  @override
  bool operator ==(Object other) =>
      other is RawDtc && other.code == code && other.mode == mode;

  @override
  int get hashCode => Object.hash(code, mode);

  @override
  String toString() => '$code(${mode.name})';
}

class DtcDecoder {
  const DtcDecoder._();

  /// Decodes a Mode 03/07/0A response into codes.
  ///
  /// Handles both response shapes:
  /// * CAN carries a DTC-count byte after the mode byte
  /// * legacy protocols (ISO 9141, KWP, J1850) do not
  ///
  /// The shape is inferred from the payload length rather than assumed, since
  /// a clone may report either regardless of the negotiated protocol.
  static List<RawDtc> decode(
    List<String> frames,
    DtcMode mode, {
    int headerChars = 0,
  }) {
    final payload = IsoTpReassembler.reassemble(
      frames,
      headerChars: headerChars,
    );
    return decodeBytes(payload, mode);
  }

  static List<RawDtc> decodeBytes(List<int> payload, DtcMode mode) {
    final start = payload.indexOf(mode.responseByte);
    if (start < 0) return const [];

    var body = payload.sublist(start + 1);
    if (body.isEmpty) return const [];

    // CAN prefixes a count byte, which leaves an odd number of bytes before
    // the pairs. Legacy does not.
    if (body.length.isOdd) body = body.sublist(1);

    final codes = <RawDtc>[];
    for (var i = 0; i + 1 < body.length; i += 2) {
      final code = decodePair(body[i], body[i + 1]);
      if (code == null) continue; // 0x0000 padding
      codes.add(RawDtc(code, mode));
    }
    // A response can repeat a code across frames on multi-ECU vehicles.
    return codes.toSet().toList();
  }

  /// Two bytes → one code, per SAE J2012.
  ///
  /// ```
  /// byte1 bits 7-6 → letter  00=P 01=C 10=B 11=U
  /// byte1 bits 5-4 → first digit (0-3)
  /// byte1 bits 3-0 → second digit (hex)
  /// byte2 bits 7-4 → third digit
  /// byte2 bits 3-0 → fourth digit
  /// ```
  ///
  /// Returns null for the `0x0000` padding that fills unused slots.
  static String? decodePair(int b1, int b2) {
    if (b1 == 0 && b2 == 0) return null;

    const letters = ['P', 'C', 'B', 'U'];
    final letter = letters[(b1 >> 6) & 0x03];
    final first = (b1 >> 4) & 0x03;
    final second = b1 & 0x0F;
    final third = (b2 >> 4) & 0x0F;
    final fourth = b2 & 0x0F;

    return '$letter$first'
        '${second.toRadixString(16).toUpperCase()}'
        '${third.toRadixString(16).toUpperCase()}'
        '${fourth.toRadixString(16).toUpperCase()}';
  }

  /// The count the ECU reported, where it reported one. Useful as a
  /// cross-check: if this disagrees with the number of codes decoded, frames
  /// were dropped and the list must not be presented as complete.
  static int? reportedCount(List<int> payload, DtcMode mode) {
    final start = payload.indexOf(mode.responseByte);
    if (start < 0) return null;
    final body = payload.sublist(start + 1);
    if (body.isEmpty || body.length.isEven) return null;
    return body.first;
  }
}
