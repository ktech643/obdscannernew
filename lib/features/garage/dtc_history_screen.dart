import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/widgets.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/dtc_repository.dart';
import '../../design_system/design_system.dart';

/// The diagnostic snapshots recorded for one vehicle — every scan, and
/// every clear as the pair it was: what was there before, what the re-read
/// found after, and how it ended.
///
/// This is the record §9.5 exists to keep. It is deliberately plain: a
/// list, newest first, with the facts and nothing inferred from them.
class DtcHistoryScreen extends StatelessWidget {
  const DtcHistoryScreen({
    super.key,
    required this.vehicle,
    required this.dtcs,
  });

  final VehicleRow vehicle;
  final DtcRepository dtcs;

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: const AdaptiveTopBar(title: 'Diagnostic history'),
          body: FutureBuilder<List<DtcSnapshotRow>>(
            future: dtcs.history(vehicle.id, limit: 200),
            builder: (context, snap) {
              final rows = snap.data;
              if (rows == null) {
                return const Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 200, height: 20),
                      SizedBox(height: Space.x12),
                      Skeleton(height: 48),
                      SizedBox(height: Space.x8),
                      Skeleton(height: 48),
                    ],
                  ),
                );
              }
              if (rows.isEmpty) {
                return const EmptyStateView(
                  title: 'No scans recorded yet',
                  why:
                      'Every scan and every clear on this vehicle is kept '
                      'here, with what the car reported at the time.',
                  icon: Icons.history,
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: Space.x48),
                children: [for (final r in rows) _SnapshotRow(row: r)],
              );
            },
          ),
        );
      },
    ),
  );
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.row});
  final DtcSnapshotRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final codes = row.codes;
    final (String purpose, Tell tone) = switch (row.purpose) {
      SnapshotPurpose.scan => ('Scan', Tell.none),
      SnapshotPurpose.beforeClear => switch (row.clearOutcome) {
        ClearOutcome.cleared => ('Before clear · cleared', Tell.green),
        ClearOutcome.codesReturned => (
          'Before clear · codes came back',
          Tell.amber,
        ),
        ClearOutcome.refused => ('Before clear · refused', Tell.amber),
        ClearOutcome.pending => ('Before clear · never verified', Tell.amber),
        ClearOutcome.unknown || null => ('Before clear', Tell.none),
      },
      SnapshotPurpose.afterClear => ('After clear', Tell.none),
    };
    final when = row.takenAt.toLocal();
    final stamp =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
    final summary = [
      codes.isEmpty
          ? 'No codes'
          : '${codes.length} code${codes.length == 1 ? '' : 's'}',
      if (row.milOn == true) 'light on',
      if (row.milOn == false) 'light off',
      if (row.freezeFrame != null) 'freeze frame at ${row.freezeFrame!.dtc}',
    ].join(' · ');

    return Semantics(
      label: '$stamp, $purpose, $summary',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Space.x12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stamp,
                      style: TorqueType.label.copyWith(color: t.inkPrimary),
                    ),
                  ),
                  if (tone != Tell.none)
                    TelltaleChip(tone: tone, label: purpose)
                  else
                    Text(
                      purpose,
                      style: TorqueType.meta.copyWith(color: t.inkSecondary),
                    ),
                ],
              ),
              const SizedBox(height: Space.x4),
              Text(
                summary,
                style: TorqueType.body.copyWith(color: t.inkSecondary),
              ),
              if (codes.isNotEmpty) ...[
                const SizedBox(height: Space.x4),
                Text(
                  codes.map((c) => c.code).toSet().join('  '),
                  style: TorqueType.meta.copyWith(color: t.inkTertiary),
                ),
              ],
              const SizedBox(height: Space.x12),
              const Hairline(),
            ],
          ),
        ),
      ),
    );
  }
}
