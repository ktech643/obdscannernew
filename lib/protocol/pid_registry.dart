/// PID metadata, decoders, and — critically — hard physical bounds.
///
/// A corrupt frame that decodes to 8,000 rpm at idle or 215 °C coolant must be
/// rejected **here**, before it can reach a widget. A user who sees an absurd
/// number panics, and then tells the store about it.
library;

enum PidPriority {
  /// Every scheduler cycle.
  critical,

  /// Every second cycle.
  high,

  /// Every fifth.
  medium,

  /// Every twentieth.
  low,

  /// Read once at handshake — VIN, fuel type, supported-PID bitmasks.
  once,
}

class PidDef {
  const PidDef({
    required this.pid,
    required this.name,
    required this.unit,
    required this.dataBytes,
    required this.min,
    required this.max,
    required this.priority,
    required this.decode,
    this.isEnum = false,
  });

  /// Mode + PID, e.g. `010C`.
  final String pid;
  final String name;
  final String unit;

  /// Expected data bytes after the `41 xx` echo. A short response is
  /// malformed, not a small value.
  final int dataBytes;

  final double min;
  final double max;
  final PidPriority priority;

  /// True for PIDs whose value is a code, not a measurement — fuel type is
  /// 0–23 and a byte outside that is corrupt, whereas a scalar PID's full
  /// byte range is always legitimate.
  final bool isEnum;

  /// Raw data bytes → engineering value.
  final double Function(List<int> d) decode;

  /// The mode byte, e.g. `01`.
  String get mode => pid.substring(0, 2);

  /// The PID byte, e.g. `0C`.
  String get code => pid.substring(2);

  bool inBounds(double v) => v >= min && v <= max;
}

class PidRegistry {
  const PidRegistry._();

  static final Map<String, PidDef> _byPid = {for (final d in all) d.pid: d};

  static PidDef? lookup(String pid) => _byPid[pid.toUpperCase()];

  /// SPEC §4.3.
  static final List<PidDef> all = [
    PidDef(
      pid: '0104',
      name: 'Engine load',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      priority: PidPriority.high,
      decode: (d) => d[0] * 100 / 255,
    ),
    PidDef(
      pid: '0105',
      name: 'Coolant temp',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 215,
      priority: PidPriority.high,
      decode: (d) => d[0] - 40,
    ),
    PidDef(
      pid: '0106',
      name: 'Short fuel trim B1',
      unit: '%',
      dataBytes: 1,
      min: -100,
      max: 99.21875,
      priority: PidPriority.medium,
      decode: (d) => (d[0] - 128) * 100 / 128,
    ),
    PidDef(
      pid: '0107',
      name: 'Long fuel trim B1',
      unit: '%',
      dataBytes: 1,
      min: -100,
      max: 99.21875,
      priority: PidPriority.medium,
      decode: (d) => (d[0] - 128) * 100 / 128,
    ),
    PidDef(
      pid: '0108',
      name: 'Short fuel trim B2',
      unit: '%',
      dataBytes: 1,
      min: -100,
      max: 99.21875,
      priority: PidPriority.low,
      decode: (d) => (d[0] - 128) * 100 / 128,
    ),
    PidDef(
      pid: '0109',
      name: 'Long fuel trim B2',
      unit: '%',
      dataBytes: 1,
      min: -100,
      max: 99.21875,
      priority: PidPriority.low,
      decode: (d) => (d[0] - 128) * 100 / 128,
    ),
    PidDef(
      pid: '010B',
      name: 'Intake manifold pressure',
      unit: 'kPa',
      dataBytes: 1,
      min: 0,
      max: 255,
      priority: PidPriority.medium,
      decode: (d) => d[0].toDouble(),
    ),
    PidDef(
      pid: '010C',
      name: 'Engine RPM',
      unit: 'rpm',
      dataBytes: 2,
      min: 0,
      max: 16383.75,
      priority: PidPriority.critical,
      decode: (d) => ((d[0] * 256) + d[1]) / 4,
    ),
    PidDef(
      pid: '010D',
      name: 'Vehicle speed',
      unit: 'km/h',
      dataBytes: 1,
      min: 0,
      max: 255,
      priority: PidPriority.critical,
      decode: (d) => d[0].toDouble(),
    ),
    PidDef(
      pid: '010E',
      name: 'Timing advance',
      unit: '°',
      dataBytes: 1,
      min: -64,
      max: 63.5,
      priority: PidPriority.low,
      decode: (d) => (d[0] / 2) - 64,
    ),
    PidDef(
      pid: '010F',
      name: 'Intake air temp',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 215,
      priority: PidPriority.medium,
      decode: (d) => d[0] - 40,
    ),
    PidDef(
      pid: '0110',
      name: 'MAF rate',
      unit: 'g/s',
      dataBytes: 2,
      min: 0,
      max: 655.35,
      priority: PidPriority.high,
      decode: (d) => ((d[0] * 256) + d[1]) / 100,
    ),
    PidDef(
      pid: '0111',
      name: 'Throttle position',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      priority: PidPriority.high,
      decode: (d) => d[0] * 100 / 255,
    ),
    PidDef(
      pid: '011F',
      name: 'Run time since start',
      unit: 's',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.low,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
    PidDef(
      pid: '0121',
      name: 'Distance with MIL on',
      unit: 'km',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
    PidDef(
      pid: '012F',
      name: 'Fuel level',
      unit: '%',
      dataBytes: 1,
      min: 0,
      max: 100,
      priority: PidPriority.medium,
      decode: (d) => d[0] * 100 / 255,
    ),
    PidDef(
      pid: '0130',
      name: 'Warm-ups since clear',
      unit: '',
      dataBytes: 1,
      min: 0,
      max: 255,
      priority: PidPriority.low,
      decode: (d) => d[0].toDouble(),
    ),
    PidDef(
      pid: '0131',
      name: 'Distance since clear',
      unit: 'km',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
    PidDef(
      pid: '0133',
      name: 'Barometric pressure',
      unit: 'kPa',
      dataBytes: 1,
      min: 0,
      max: 255,
      priority: PidPriority.low,
      decode: (d) => d[0].toDouble(),
    ),
    PidDef(
      pid: '013C',
      name: 'Catalyst temp B1S1',
      unit: '°C',
      dataBytes: 2,
      min: -40,
      max: 6513.5,
      priority: PidPriority.low,
      decode: (d) => (((d[0] * 256) + d[1]) / 10) - 40,
    ),
    PidDef(
      pid: '0142',
      name: 'Module voltage',
      unit: 'V',
      dataBytes: 2,
      min: 0,
      max: 65.535,
      priority: PidPriority.high,
      decode: (d) => ((d[0] * 256) + d[1]) / 1000,
    ),
    PidDef(
      pid: '0143',
      name: 'Absolute load',
      unit: '%',
      dataBytes: 2,
      min: 0,
      max: 25700,
      priority: PidPriority.low,
      decode: (d) => ((d[0] * 256) + d[1]) * 100 / 255,
    ),
    PidDef(
      pid: '0144',
      name: 'Lambda',
      unit: 'λ',
      dataBytes: 2,
      min: 0,
      max: 2,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]) / 32768,
    ),
    PidDef(
      pid: '0146',
      name: 'Ambient air temp',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      max: 215,
      priority: PidPriority.low,
      decode: (d) => d[0] - 40,
    ),
    PidDef(
      pid: '014D',
      name: 'Time with MIL on',
      unit: 'min',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
    PidDef(
      pid: '014E',
      name: 'Time since clear',
      unit: 'min',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
    PidDef(
      pid: '0151',
      name: 'Fuel type',
      unit: '',
      dataBytes: 1,
      min: 0,
      max: 23,
      priority: PidPriority.once,
      isEnum: true,
      decode: (d) => d[0].toDouble(),
    ),
    PidDef(
      pid: '015C',
      name: 'Engine oil temp',
      unit: '°C',
      dataBytes: 1,
      min: -40,
      // A−40 over a full byte reaches 215, not the 210 the spec table rounds
      // to. Taking the rounded figure would reject a legitimate reading.
      max: 215,
      priority: PidPriority.medium,
      decode: (d) => d[0] - 40,
    ),
    PidDef(
      pid: '015E',
      name: 'Fuel rate',
      unit: 'L/h',
      dataBytes: 2,
      min: 0,
      // 65535/20 = 3276.75. The spec table's 3212.75 would reject a
      // full-scale reading.
      max: 3276.75,
      priority: PidPriority.medium,
      decode: (d) => ((d[0] * 256) + d[1]) / 20,
    ),
    PidDef(
      pid: '0162',
      name: 'Actual torque',
      unit: '%',
      dataBytes: 1,
      min: -125,
      max: 130,
      priority: PidPriority.low,
      decode: (d) => d[0] - 125,
    ),
    PidDef(
      pid: '0163',
      name: 'Reference torque',
      unit: 'N·m',
      dataBytes: 2,
      min: 0,
      max: 65535,
      priority: PidPriority.low,
      decode: (d) => ((d[0] * 256) + d[1]).toDouble(),
    ),
  ];

  /// Decodes a `41 xx …` response for [pid].
  ///
  /// Returns null — never a sentinel — when the response is for a different
  /// PID, is short, or decodes outside the PID's physical bounds. **Zero is a
  /// valid reading; null is absence.** Callers must keep them distinct.
  static double? decodeResponse(String pid, List<int> payload) {
    final def = lookup(pid);
    if (def == null) return null;

    final modeByte = int.parse(def.mode, radix: 16) + 0x40;
    final pidByte = int.parse(def.code, radix: 16);

    for (var i = 0; i + 1 < payload.length; i++) {
      if (payload[i] != modeByte || payload[i + 1] != pidByte) continue;
      final data = payload.sublist(i + 2);
      if (data.length < def.dataBytes) return null; // short frame
      final value = def.decode(data.sublist(0, def.dataBytes));
      if (value.isNaN || !def.inBounds(value)) return null; // corrupt frame
      return value;
    }
    return null;
  }

  /// The four support-bitmask PIDs. Query all of them at handshake and never
  /// poll anything outside the result — clones answer unpredictably to
  /// unsupported PIDs and it wrecks throughput.
  static const supportQueries = ['0100', '0120', '0140', '0160'];

  /// Unpacks a support bitmask response into the PIDs it declares.
  ///
  /// `0100` covers 01–20, `0120` covers 21–40, and so on. The most significant
  /// bit of the first byte is PID 01.
  static Set<String> decodeSupportMask(String query, List<int> payload) {
    final base = int.parse(query.substring(2), radix: 16);
    final modeByte = int.parse(query.substring(0, 2), radix: 16) + 0x40;

    for (var i = 0; i + 1 < payload.length; i++) {
      if (payload[i] != modeByte || payload[i + 1] != base) continue;
      final data = payload.sublist(i + 2);
      if (data.length < 4) return const {};

      final supported = <String>{};
      for (var byte = 0; byte < 4; byte++) {
        for (var bit = 0; bit < 8; bit++) {
          if ((data[byte] & (0x80 >> bit)) == 0) continue;
          final pidNumber = base + byte * 8 + bit + 1;
          supported.add(
            '01${pidNumber.toRadixString(16).padLeft(2, '0').toUpperCase()}',
          );
        }
      }
      return supported;
    }
    return const {};
  }
}
