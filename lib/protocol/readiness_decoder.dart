/// Mode 01 PID 01 — MIL status, DTC count, and the readiness monitors.
///
/// The three-state result matters: **"not supported by this vehicle" is not
/// the same as "not complete"**, and collapsing them tells a user their car
/// will fail an emissions test when it won't.
library;

enum MonitorState { complete, notComplete, notSupported }

/// Compression-ignition engines run a different monitor set. Reading this from
/// the wrong branch shows a diesel owner petrol-only monitors that will never
/// complete.
enum IgnitionType { spark, compression }

class ReadinessMonitorResult {
  const ReadinessMonitorResult(this.name, this.state);
  final String name;
  final MonitorState state;
}

class ReadinessReport {
  const ReadinessReport({
    required this.milOn,
    required this.dtcCount,
    required this.ignitionType,
    required this.monitors,
  });

  final bool milOn;

  /// What the ECU claims. Cross-check against the decoded Mode 03 list — a
  /// mismatch means frames were dropped.
  final int dtcCount;

  final IgnitionType ignitionType;
  final List<ReadinessMonitorResult> monitors;

  int get completeCount =>
      monitors.where((m) => m.state == MonitorState.complete).length;
  int get incompleteCount =>
      monitors.where((m) => m.state == MonitorState.notComplete).length;
  int get supportedCount =>
      monitors.where((m) => m.state != MonitorState.notSupported).length;

  /// Most US states allow one incomplete monitor (two on pre-2001 vehicles).
  /// This is **general guidance, never a guarantee** — the UI must carry the
  /// "rules vary by state and country" caveat alongside it.
  bool get likelyPassesEmissions => !milOn && incompleteCount <= 1;
}

class ReadinessDecoder {
  const ReadinessDecoder._();

  /// Continuous monitors, carried in byte B for both ignition types.
  static const _continuous = ['Misfire', 'Fuel system', 'Components'];

  /// Byte C/D bit order for spark ignition (petrol).
  static const _sparkMonitors = [
    'Catalyst',
    'Heated catalyst',
    'Evaporative system',
    'Secondary air system',
    'A/C refrigerant',
    'Oxygen sensor',
    'Oxygen sensor heater',
    'EGR system',
  ];

  /// Byte C/D bit order for compression ignition (diesel). Bits 2 and 4 are
  /// reserved by the standard and are skipped rather than mislabelled.
  static const _compressionMonitors = [
    'NMHC catalyst',
    'NOx / SCR monitor',
    null,
    'Boost pressure',
    null,
    'Exhaust gas sensor',
    'PM filter',
    'EGR / VVT system',
  ];

  /// Decodes the four data bytes that follow `41 01`.
  static ReadinessReport? decode(List<int> payload) {
    final start = _indexOfSequence(payload, [0x41, 0x01]);
    if (start < 0) return null;

    final data = payload.sublist(start + 2);
    if (data.length < 4) return null;

    final a = data[0], b = data[1], c = data[2], d = data[3];

    final ignition = (b & 0x08) != 0
        ? IgnitionType.compression
        : IgnitionType.spark;

    final monitors = <ReadinessMonitorResult>[];

    // Byte B: bits 0-2 availability, bits 4-6 incompleteness.
    for (var i = 0; i < 3; i++) {
      final available = (b & (1 << i)) != 0;
      final incomplete = (b & (1 << (i + 4))) != 0;
      monitors.add(
        ReadinessMonitorResult(
          _continuous[i],
          _stateOf(available: available, incomplete: incomplete),
        ),
      );
    }

    // Bytes C (availability) and D (incompleteness), same bit order.
    final names = ignition == IgnitionType.compression
        ? _compressionMonitors
        : _sparkMonitors;
    for (var i = 0; i < 8; i++) {
      final name = names[i];
      if (name == null) continue; // reserved bit
      final available = (c & (1 << i)) != 0;
      final incomplete = (d & (1 << i)) != 0;
      monitors.add(
        ReadinessMonitorResult(
          name,
          _stateOf(available: available, incomplete: incomplete),
        ),
      );
    }

    return ReadinessReport(
      milOn: (a & 0x80) != 0,
      dtcCount: a & 0x7F,
      ignitionType: ignition,
      monitors: monitors,
    );
  }

  static MonitorState _stateOf({
    required bool available,
    required bool incomplete,
  }) {
    if (!available) return MonitorState.notSupported;
    return incomplete ? MonitorState.notComplete : MonitorState.complete;
  }

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
