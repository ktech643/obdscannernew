import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';

/// M3 — iCloud sync conflict.
///
/// A union merge: nothing is deleted, both sets of service records are kept,
/// and the user is asked only about the fields that genuinely disagree.
class SyncConflictScreen extends StatelessWidget {
  const SyncConflictScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.read<AccountProvider>();
    return Screen(
      title: 'Sync conflict',
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            "Keep this iPhone's odometer",
            onPressed: () {
              a.setSync(SyncStatus.synced);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      children: [
        const NoteBlock(
          'Local writes never blocked',
          tone: Tone.caution,
          title: 'Sync paused',
        ),
        const SizedBox(height: 18),
        Text(
          '"The Golf" was edited on two devices. We keep both service records — '
          'nothing is deleted in a merge — and ask you only about the fields '
          'that actually disagree.',
          style: Type.body16Muted,
        ),
        const SectionHeading('Odometer'),
        const _ConflictOption(
          value: '142,380 km',
          source: 'This iPhone · today 09:12',
          selected: true,
        ),
        const _ConflictOption(
          value: '141,905 km',
          source: 'iPhone 11 · 3 days ago',
          selected: false,
        ),
        const SectionHeading('Merged automatically'),
        Text(
          '11 service records kept from both devices. Two looked like the same '
          'job — same type, within a day and 50 km — so we flagged them rather '
          'than merging blind.',
          style: Type.bodyMuted,
        ),
        const SizedBox(height: 14),
        AppListRow(
          title: 'Review 2 possible duplicates',
          subtitle: 'Oil change · 3 Feb',
          chevron: true,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ConflictOption extends StatelessWidget {
  const _ConflictOption({
    required this.value,
    required this.source,
    required this.selected,
  });

  final String value;
  final String source;
  final bool selected;

  @override
  Widget build(BuildContext context) => RadioRow(
    label: value,
    subtitle: source,
    selected: selected,
    onSelect: () {},
  );
}

/// M4 — resume an interrupted trip. Either choice keeps the data already
/// recorded; the screen says so before the user picks.
class ResumeTripScreen extends StatelessWidget {
  const ResumeTripScreen({super.key});

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Resume your trip?',
    backLabel: 'Dashboard',
    onBack: () => Navigator.of(context).pop(),
    footer: ScreenFooter(
      children: [
        PrimaryButton(
          'Resume recording',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
        SecondaryButton(
          'Start a new trip',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
    children: [
      Text(
        'iOS closed Torque while you were recording. We flushed everything '
        'up to the last five seconds.',
        style: Type.body16Muted,
      ),
      const SectionHeading('Evening drive'),
      ValueList(const [
        (label: 'Recorded', value: '8.2 km · 14 min'),
        (label: 'Stopped', value: '30 Aug, 19:41 — app terminated'),
        (label: 'Samples lost', value: '≈ 4 s'),
        (label: 'Status', value: 'Interrupted'),
      ]),
      const SizedBox(height: 18),
      Text(
        'Resuming appends to the same trip. Starting fresh keeps the '
        "interrupted one in your trip list either way — we don't discard "
        'data you recorded.',
        style: Type.footnote,
      ),
    ],
  );
}

/// N3 — a new adapter fingerprint. Car parks are full of other people's
/// adapters; this asks once, per adapter, before logging anything to a vehicle.
class NewAdapterPromptScreen extends StatelessWidget {
  const NewAdapterPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    final g = context.watch<GarageProvider>();

    return Screen(
      title: 'Is this your car?',
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            'Yes, this is my car',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
          GhostButton(
            'No — disconnect',
            color: T.fault,
            onPressed: () {
              c.disconnect();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      children: [
        Text(
          "We haven't seen this adapter before. Car parks are full of other "
          "people's adapters — worth checking once.",
          style: Type.body16Muted,
        ),
        const SizedBox(height: 20),
        ValueList([
          (label: 'Adapter', value: '${c.adapterName} · ${c.adapterAddress}'),
          (label: 'Firmware', value: c.firmwareLine),
          (label: 'Battery', value: '${c.batteryVolts.toStringAsFixed(1)} V'),
          (label: 'Protocol', value: 'CAN 11-bit / 500 kbaud'),
          (label: 'VIN', value: g.active.maskedVin),
        ]),
        const SizedBox(height: 18),
        Text(
          "If the voltage looks right for a car that's switched on and the VIN "
          "ends the way yours does, it's yours. We'll only ask once per adapter.",
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// N4 — VIN mismatch. Nothing is recorded until the right vehicle is picked,
/// which is why this blocks rather than warning after the fact.
class VinMismatchScreen extends StatelessWidget {
  const VinMismatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    final e = context.watch<EntitlementProvider>();

    return Screen(
      backLabel: 'Dashboard',
      onBack: () => Navigator.of(context).pop(),
      title: "This isn't ${g.active.nickname}",
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            "Switch to Wife's Polo",
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      children: [
        Text(
          "The VIN on this car doesn't match your active vehicle. Nothing has "
          'been recorded yet — pick the right one first.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 20),
        AppListRow(
          title: "Wife's Polo",
          subtitle: 'VIN matches · WVW••••••••••8871',
          severityBar: T.pass,
          chevron: true,
          onTap: () {},
        ),
        AppListRow(
          title: 'Add it as a new vehicle',
          subtitle: "We'll prefill from the VIN",
          trailing: e.isPro ? null : const Badge('PRO'),
          chevron: true,
          onTap: () {},
        ),
        AppListRow(
          title: 'Stay on ${g.active.nickname}',
          subtitle: "Readings won't be logged to any vehicle",
          chevron: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
