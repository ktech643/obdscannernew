import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import '../../data/dtc_dictionary.dart';
import '../../design_system/design_system.dart';
import '../../protocol/dtc_decoder.dart';
import 'diagnostics_screen.dart' show toneFor;

/// SPEC §5.4 — one code, in full.
///
/// The page is built around what is *known*. With a dictionary entry it
/// shows the entry; without one it says there is no definition and stops,
/// because the alternative — a plausible-sounding sentence about a code
/// nobody looked up — is the failure hard rule 7 exists to prevent.
///
/// It always ends with [DtcText.disclaimer]. Verbatim, every time.
class CodeDetailScreen extends StatelessWidget {
  const CodeDetailScreen({
    super.key,
    required this.dtc,
    this.definition,
    this.alsoIn = const [],
  });

  final RawDtc dtc;
  final DtcDefinition? definition;

  /// The other lists this same code appears in. A code that is both
  /// stored and permanent is two true facts, and the page says both.
  final List<DtcMode> alsoIn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final def = definition;
    final tone = toneFor(dtc, def);
    return Scaffold(
      backgroundColor: t.surfaceDeep,
      appBar: const AdaptiveTopBar(title: 'Trouble code'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x16,
          Space.gutter,
          Space.x48,
        ),
        children: [
          Row(
            children: [
              Text(
                dtc.code,
                style: TorqueType.readoutMd.copyWith(color: t.inkPrimary),
              ),
              const SizedBox(width: Space.x12),
              TelltaleChip(tone: tone, label: DtcText.statusWord(dtc.mode)),
            ],
          ),
          const SizedBox(height: Space.x12),
          Text(
            DtcText.describe(dtc, def),
            style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
          ),
          const SizedBox(height: Space.x24),

          _Section(
            title: DtcText.statusWord(dtc.mode),
            body: DtcText.statusMeaning(dtc.mode),
          ),
          if (alsoIn.isNotEmpty)
            _Section(
              title: 'Also reported as',
              body:
                  '${alsoIn.map(DtcText.statusWord).join(' and ')}. The same '
                  'fault can sit in more than one list at once.',
            ),

          if (def?.description != null)
            _Section(title: 'What it means', body: def!.description!),

          if (def != null && def.commonCauses.isNotEmpty) ...[
            const SizedBox(height: Space.x8),
            Text(
              'Common causes',
              style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: Space.x8),
            for (final cause in def.commonCauses)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x4),
                child: Text(
                  '· $cause',
                  style: TorqueType.body.copyWith(color: t.inkSecondary),
                ),
              ),
            const SizedBox(height: Space.x16),
          ],

          if (def == null)
            _Section(
              title: dtc.isManufacturerSpecific
                  ? 'Manufacturer-specific'
                  : 'No definition available',
              body: dtc.isManufacturerSpecific
                  ? 'The standard hands codes in this range to the '
                        'carmaker, so the same number means different '
                        'things on different makes. There is no generic '
                        'definition to give, and this app will not invent '
                        'one — a dealer or make-specific manual has it.'
                  : 'This code is not in the bundled definition database, '
                        'so there is nothing accurate to say about what it '
                        'means. The code itself, above, is exactly what the '
                        'car reported.',
            ),

          _Section(
            title: 'System',
            body:
                '${DtcText.systemName(dtc.code)}'
                '${def?.system == null ? '' : ' · ${def!.system}'}',
          ),

          const SizedBox(height: Space.x8),
          Hairline(),
          const SizedBox(height: Space.x16),
          Text(
            DtcText.disclaimer,
            style: TorqueType.meta.copyWith(color: t.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TorqueType.titleMd.copyWith(color: t.inkPrimary)),
          const SizedBox(height: Space.x4),
          Text(body, style: TorqueType.body.copyWith(color: t.inkSecondary)),
        ],
      ),
    );
  }
}
