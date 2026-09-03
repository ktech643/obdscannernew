import 'package:flutter/widgets.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

/// D3 — code detail. Plain-English meaning, ordered causes, the freeze frame,
/// and the fixed honesty line at the foot of every code we explain.
class CodeDetailScreen extends StatelessWidget {
  const CodeDetailScreen({super.key, required this.dtc});

  final Dtc dtc;

  @override
  Widget build(BuildContext context) => Screen(
    backLabel: 'Diagnostics',
    onBack: () => Navigator.of(context).pop(),
    footer: ScreenFooter(
      children: [
        SecondaryButton(
          'Was this fixed? Log a repair',
          onPressed: () => notImplementedHere(
            context,
            'Opens a new service record pre-filled with ${dtc.code}.',
          ),
        ),
      ],
    ),
    children: [
      Row(
        children: [
          Text(dtc.code, style: Type.screenTitle),
          const SizedBox(width: 12),
          TelltaleChip(
            switch (dtc.severity) {
              DtcSeverity.severe => 'Severe',
              DtcSeverity.moderate => 'Moderate',
              DtcSeverity.minor => 'Minor',
              DtcSeverity.unknown => 'Unknown',
            },
            tone: switch (dtc.severity) {
              DtcSeverity.severe => Tone.fault,
              DtcSeverity.moderate => Tone.caution,
              _ => Tone.ink,
            },
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(dtc.description, style: Type.cardTitleLg),
      const SizedBox(height: 18),
      ValueList([
        if (dtc.system != null) (label: 'System', value: dtc.system!),
        if (dtc.statusDetail != null)
          (label: 'Status', value: dtc.statusDetail!),
        if (dtc.firstSeen != null) (label: 'First seen', value: dtc.firstSeen!),
      ]),
      if (dtc.meaning != null) ...[
        const SectionHeading('What this means'),
        Text(dtc.meaning!, style: Type.body16),
      ],
      if (dtc.causes.isNotEmpty) ...[
        const SectionHeading('Common causes · most likely first'),
        for (var i = 0; i < dtc.causes.length; i++)
          NumberedFact(i + 1, dtc.causes[i]),
      ],
      if (dtc.freezeFrame.isNotEmpty) ...[
        const SectionHeading('Conditions when the code set · freeze frame'),
        ValueList(dtc.freezeFrame),
      ],
      const SizedBox(height: 22),
      // Fixed copy. It appears on every code detail, unchanged.
      Text(
        'A code points to a symptom, not always the cause. '
        "A mechanic's diagnosis may differ.",
        style: Type.footnote,
      ),
    ],
  );
}
