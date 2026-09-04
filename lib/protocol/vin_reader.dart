import 'isotp_reassembler.dart';

/// Mode 09 PID 02 — the VIN.
///
/// Decoded entirely on device. **Never call a cloud VIN API**: it would put a
/// vehicle identifier on someone else's server, break the privacy posture the
/// app advertises, and add a network dependency to an app that otherwise has
/// none.
class VinResult {
  const VinResult({
    required this.vin,
    required this.checkDigitValid,
    this.wmi,
    this.modelYear,
  });

  final String vin;

  /// ISO 3779 position 9. A VIN that fails this is stored but **not decoded** —
  /// a corrupt read must not become a confident wrong answer about the car.
  final bool checkDigitValid;

  /// World Manufacturer Identifier, characters 1–3.
  final String? wmi;

  final int? modelYear;

  bool get isTrustworthy => checkDigitValid;
}

class VinReader {
  const VinReader._();

  static const _length = 17;

  /// ISO 3779 forbids I, O and Q precisely because they are confusable with
  /// 1 and 0. Their presence is proof of a bad read, not an unusual VIN.
  static final _forbidden = RegExp('[IOQ]');
  static final _valid = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  /// Transliteration for the check digit, per ISO 3779.
  static const _values = {
    'A': 1,
    'B': 2,
    'C': 3,
    'D': 4,
    'E': 5,
    'F': 6,
    'G': 7,
    'H': 8,
    'J': 1,
    'K': 2,
    'L': 3,
    'M': 4,
    'N': 5,
    'P': 7,
    'R': 9,
    'S': 2,
    'T': 3,
    'U': 4,
    'V': 5,
    'W': 6,
    'X': 7,
    'Y': 8,
    'Z': 9,
  };

  static const _weights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];

  /// Model-year codes run on a 30-year cycle. Character 7 disambiguates:
  /// alphabetic means 2010+, numeric means 1980–2009.
  static const _yearCodes = 'ABCDEFGHJKLMNPRSTVWXY123456789';

  /// Extracts and validates a VIN from a Mode 09 response.
  ///
  /// Returns null when the payload doesn't contain a full 17 characters —
  /// clones routinely truncate the multi-frame reply, and 8 characters is not
  /// a VIN.
  static VinResult? parse(List<String> frames, {int headerChars = 0}) {
    final payload = IsoTpReassembler.reassemble(
      frames,
      headerChars: headerChars,
    );
    return parseBytes(payload);
  }

  static VinResult? parseBytes(List<int> payload) {
    final start = _indexOfSequence(payload, [0x49, 0x02]);
    if (start < 0) return null;

    // A message-count byte follows `49 02` on most implementations. Take
    // everything after and keep only printable ASCII — some ECUs pad with
    // 0x00 or 0x20 to fill the frame.
    final ascii = payload
        .sublist(start + 2)
        .where((b) => b >= 0x30 && b <= 0x5A)
        .map(String.fromCharCode)
        .join();

    if (ascii.length < _length) return null;

    // The count byte can land in range as '1'. Prefer the trailing 17 that
    // form a structurally valid VIN.
    final candidate = ascii.length == _length
        ? ascii
        : ascii.substring(ascii.length - _length);

    return validate(candidate);
  }

  /// Validates a VIN string on its own, for manual entry as well as reads.
  static VinResult? validate(String raw) {
    final vin = raw.toUpperCase().trim();
    if (vin.length != _length) return null;
    if (_forbidden.hasMatch(vin)) return null; // corrupt read, not a real VIN
    if (!_valid.hasMatch(vin)) return null;

    final valid = _checkDigitMatches(vin);
    return VinResult(
      vin: vin,
      checkDigitValid: valid,
      // Only decode a VIN we trust. Deriving a make and year from a corrupt
      // read is worse than showing nothing.
      wmi: valid ? vin.substring(0, 3) : null,
      modelYear: valid ? _modelYear(vin) : null,
    );
  }

  static bool _checkDigitMatches(String vin) {
    var sum = 0;
    for (var i = 0; i < _length; i++) {
      final ch = vin[i];
      final value = _values[ch] ?? int.tryParse(ch);
      if (value == null) return false;
      sum += value * _weights[i];
    }
    final remainder = sum % 11;
    final expected = remainder == 10 ? 'X' : remainder.toString();
    return vin[8] == expected;
  }

  static int? _modelYear(String vin) {
    final index = _yearCodes.indexOf(vin[9]);
    if (index < 0) return null;
    // Character 7 alphabetic ⇒ the 2010+ cycle.
    final isLateCycle = RegExp('[A-Z]').hasMatch(vin[6]);
    return (isLateCycle ? 2010 : 1980) + index;
  }

  /// `WVW••••••••••1234` — the form used everywhere the VIN is displayed or
  /// shared, unless the user explicitly opts to include it.
  static String mask(String vin) => vin.length < 8
      ? vin
      : '${vin.substring(0, 3)}${'•' * (vin.length - 7)}'
            '${vin.substring(vin.length - 4)}';

  static int _indexOfSequence(List<int> haystack, List<int> needle) {
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
