import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// F6 — the protocol log. 500 events with a latency column, `BUFFER FULL` and
/// `NO DATA` rows tinted, and a VIN-masking toggle before anything is shared.
class DiagnosticsLogScreen extends StatelessWidget {
  const DiagnosticsLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final g = context.watch<GarageProvider>();

    return Screen(
      title: 'Diagnostics log',
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton('Copy', onPressed: () {}, icon: Lu.copy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  'Share .txt',
                  onPressed: () {},
                  icon: Lu.share,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton('Clear', color: T.fault, onPressed: () {}),
              ),
            ],
          ),
        ],
      ),
      children: [
        Text(
          'The last 500 things Torque said to your adapter and heard back. This '
          'is our whole support system — nothing is uploaded unless you send it.',
          style: Type.bodyMuted,
        ),
        const SizedBox(height: 20),
        const _LogHeader(),
        for (final e in SettingsProvider.logEvents) _LogRow(event: e),
        const SizedBox(height: 18),
        // The VIN identifies the car and, through it, the owner. Masking is on
        // by default and stated before the Share button, not after.
        AppListRow(
          title: 'Include the VIN when sharing',
          subtitle: s.maskVin
              ? 'Currently masked: ${g.active.maskedVin}'
              : 'Currently included: ${g.active.vin}',
          trailing: AppSwitch(
            value: !s.maskVin,
            onChanged: (v) => s.setMaskVin(!v),
          ),
        ),
      ],
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: T.hairlineBottom),
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 78, child: Text('TIME', style: Type.sectionHeading)),
        Expanded(child: Text('FRAME', style: Type.sectionHeading)),
        SizedBox(
          width: 44,
          child: Text(
            'MS',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final LogEvent event;

  @override
  Widget build(BuildContext context) {
    final tinted = event.tone == Tone.caution;
    return Container(
      color: tinted ? T.cautionTint : null,
      decoration: const BoxDecoration(border: T.hairlineBottom),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              event.time,
              style: Type.mono.copyWith(color: T.neutral700, fontSize: 11),
            ),
          ),
          Text(
            event.outbound ? '→' : '←',
            style: Type.mono.copyWith(color: T.neutral600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.frame,
              style: Type.mono.copyWith(color: tinted ? T.cautionText : T.text),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              event.ms?.toString() ?? '—',
              style: Type.mono.copyWith(color: T.neutral700),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
