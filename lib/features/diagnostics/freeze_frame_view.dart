import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart' show DistanceUnit, TemperatureUnit;
import '../../protocol/freeze_frame.dart';
import '../../session/gauge_catalog.dart';

/// What the line under the heading may say about where the frame lives.
enum FreezeFrameNote {
  /// Read off the car now, and written to the Garage with the scan.
  kept,

  /// Read off the car now, and *not* written anywhere: no vehicle to file
  /// it under, a §9.6 question open, or Demo Mode. Saying "saved" here
  /// sent people into a clear believing a copy existed.
  notKept,

  /// The copy in a snapshot, read back from the Garage's history.
  snapshot,
}

/// §5.4 — what the engine was doing when the ECU stored its first code, in
/// the user's units through the same specs the gauges use, so the number
/// here and the number on a tile agree.
class FreezeFrameView extends StatelessWidget {
  const FreezeFrameView({
    super.key,
    required this.frame,
    required this.note,
    this.distance = DistanceUnit.km,
    this.temperature = TemperatureUnit.celsius,
  });

  final FreezeFrame frame;
  final FreezeFrameNote note;
  final DistanceUnit distance;
  final TemperatureUnit temperature;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <ValueRow>[
      for (final pid in FreezeFrameDecoder.preferredPids)
        if (frame.values[pid] case final v?)
          if (GaugeCatalog.specFor(
                pid,
                distance: distance,
                temperature: temperature,
              )
              case final spec?)
            ValueRow(
              spec.label,
              spec.unit.isEmpty
                  ? spec.format(v)
                  : '${spec.format(v)} ${spec.unit}',
            ),
    ];
    final line = switch (note) {
      FreezeFrameNote.kept =>
        'What the engine was doing when ${frame.dtc} was stored. The car '
            'keeps one frame and clearing codes erases it; this copy is kept '
            'in the Garage\'s diagnostic history.',
      FreezeFrameNote.notKept =>
        'What the engine was doing when ${frame.dtc} was stored. The car '
            'keeps one frame and clearing codes erases it — and nothing is '
            'being recorded here, so no copy is kept.',
      FreezeFrameNote.snapshot =>
        'What the engine was doing when ${frame.dtc} was stored, as it was '
            'read at the time of this snapshot.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Freeze frame',
          style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
        ),
        const SizedBox(height: Space.x4),
        Text(line, style: TorqueType.body.copyWith(color: t.inkSecondary)),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: Space.x12),
          ValueList(rows: rows),
        ] else ...[
          const SizedBox(height: Space.x8),
          Text(
            'The car reported the code but none of the readings.',
            style: TorqueType.meta.copyWith(color: t.inkTertiary),
          ),
        ],
      ],
    );
  }
}
