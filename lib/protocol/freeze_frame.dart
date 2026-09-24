import 'dart:convert';

import 'dtc_decoder.dart';
import 'pid_registry.dart';

/// SPEC §5.4 — Mode 02, the freeze frame: the readings the ECU stored the
/// moment it set its first code. It answers the mechanic's first question
/// — *what was the engine doing when this happened?* — and Mode 04 erases
/// it, which is why the clear sheet warns about it and why the snapshot
/// written before a clear is the only copy that survives.
///
/// Values are keyed by the registry's Mode 01 ids (`010C`), in the PID's
/// own metric units, exactly like a live sample. [frame] is the ECU's
/// frame number; frame 0 is the one every car keeps.
class FreezeFrame {
  const FreezeFrame({
    required this.dtc,
    this.frame = 0,
    required this.values,
  });

  /// The code the ECU says this frame belongs to, e.g. `P0301`.
  final String dtc;
  final int frame;
  final Map<String, double> values;

  bool get isEmpty => values.isEmpty;

  Map<String, Object?> toJson() => {
    'dtc': dtc,
    'frame': frame,
    'values': values,
  };

  /// Tolerant: a malformed document is null, a malformed value is dropped.
  /// A snapshot row must never fail to load over one bad number.
  static FreezeFrame? fromJson(Object? json) {
    if (json is! Map) return null;
    final dtc = json['dtc'];
    if (dtc is! String || dtc.isEmpty) return null;
    final frame = json['frame'];
    final raw = json['values'];
    final values = <String, double>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String && v is num && v.isFinite) values[k] = v.toDouble();
      }
    }
    return FreezeFrame(
      dtc: dtc,
      frame: frame is int ? frame : 0,
      values: values,
    );
  }

  static FreezeFrame? tryParse(String source) {
    try {
      return fromJson(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FreezeFrame &&
      other.dtc == dtc &&
      other.frame == frame &&
      other.values.length == values.length &&
      other.values.entries.every((e) => values[e.key] == e.value);

  @override
  int get hashCode => Object.hash(dtc, frame, values.length);

  @override
  String toString() => 'FreezeFrame($dtc #$frame $values)';
}

/// Pure decoding of Mode 02 replies. Hard rule 1: no Flutter here.
///
/// A Mode 02 reply is a Mode 01 reply with one extra byte —
/// `42 <pid> <frame> <data…>`. The frame byte sits exactly where Mode 01's first
/// data byte would, so a decoder that forgot it would read every value
/// one byte off and still land inside the PID's physical bounds most of
/// the time — the wrong number, confidently. Every decoder here consumes
/// the frame byte first and then hands the registry a Mode 01-shaped
/// payload, so the formula and bounds are the same ones the tiles use.
class FreezeFrameDecoder {
  FreezeFrameDecoder._();

  /// The readings worth a round trip each, best first: what a mechanic
  /// reads off a freeze frame to place the fault — engine speed and road
  /// speed (idle misfire or under load?), coolant (cold start?), load,
  /// throttle, manifold pressure, intake temperature, air flow, the two
  /// fuel trims (lean or rich?), module voltage, run time, fuel level,
  /// timing.
  static const preferredPids = [
    '010C',
    '010D',
    '0105',
    '0104',
    '0111',
    '010B',
    '010F',
    '0110',
    '0106',
    '0107',
    '0142',
    '011F',
    '012F',
    '010E',
  ];

  /// `42 02 <frame> A B` → the code that stored the frame, or null when the
  /// ECU reports none (`00 00`) or the reply is not for this frame.
  static String? decodeDtc(List<int> payload, {int frame = 0}) {
    for (var i = 0; i + 4 < payload.length; i++) {
      if (payload[i] != 0x42 || payload[i + 1] != 0x02) continue;
      if (payload[i + 2] != frame) continue;
      final a = payload[i + 3];
      final b = payload[i + 4];
      if (a == 0 && b == 0) return null;
      return DtcDecoder.decodePair(a, b);
    }
    return null;
  }

  /// `42 00 <frame> A B C D` → the Mode 01 ids (`0101`…`0120`) the ECU
  /// says it can give for this frame. Empty when the reply is not a mask.
  static Set<String> decodeSupportMask(List<int> payload, {int frame = 0}) {
    for (var i = 0; i + 6 < payload.length; i++) {
      if (payload[i] != 0x42 || payload[i + 1] != 0x00) continue;
      if (payload[i + 2] != frame) continue;
      final out = <String>{};
      for (var byte = 0; byte < 4; byte++) {
        final bits = payload[i + 3 + byte];
        for (var bit = 0; bit < 8; bit++) {
          if (bits & (0x80 >> bit) != 0) {
            final n = byte * 8 + bit + 1;
            out.add('01${n.toRadixString(16).padLeft(2, '0').toUpperCase()}');
          }
        }
      }
      return out;
    }
    return const {};
  }

  /// The value for [pid] (a Mode 01 id) from a `42 <pid> <frame> …` reply,
  /// decoded with the registry's own formula and bounds. Null — never a
  /// sentinel — when the reply is for another PID or frame, is short, or
  /// decodes outside the physical range.
  static double? decodeValue(String pid, List<int> payload, {int frame = 0}) {
    final def = PidRegistry.lookup(pid);
    if (def == null || def.mode != '01') return null;
    final pidByte = int.parse(def.code, radix: 16);
    for (var i = 0; i + 2 < payload.length; i++) {
      if (payload[i] != 0x42 || payload[i + 1] != pidByte) continue;
      if (payload[i + 2] != frame) continue;
      final data = payload.sublist(i + 3);
      return PidRegistry.decodeResponse(pid, [0x41, pidByte, ...data]);
    }
    return null;
  }

  /// Which PIDs to ask for, in order. With a support mask, the preferred
  /// ones the car offers; without one (a car that does not answer PID 00
  /// in Mode 02), the first eight preferred — each answered `NO DATA` costs
  /// one round trip and nothing else.
  static List<String> pidsToRead(Set<String> supported, {int limit = 12}) {
    final source = supported.isEmpty
        ? preferredPids.take(8)
        : preferredPids.where(supported.contains);
    return source.take(limit).toList();
  }
}
