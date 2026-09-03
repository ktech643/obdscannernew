import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';

/// J1 — report export. Generated on the device: no upload, no server render.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _format = 0;
  final _include = {
    'Maintenance log': true,
    'Fuel economy': true,
    'Diagnostic snapshot history': false,
  };

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    final e = context.watch<EntitlementProvider>();

    return Screen(
      backLabel: 'Garage',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [PrimaryButton('Generate and share', onPressed: () {})],
      ),
      children: [
        Row(
          children: [
            Text('Reports', style: Type.screenTitle),
            const SizedBox(width: 10),
            if (!e.isPro) const Badge('PRO'),
          ],
        ),
        const SectionHeading('Export as', topPadding: 18),
        RadioRow(
          label: 'PDF — formatted report',
          selected: _format == 0,
          onSelect: () => setState(() => _format = 0),
        ),
        RadioRow(
          label: 'CSV — raw records',
          selected: _format == 1,
          onSelect: () => setState(() => _format = 1),
        ),
        const SectionHeading('Include'),
        for (final key in _include.keys)
          AppListRow(
            title: key,
            trailing: AppSwitch(
              value: _include[key]!,
              onChanged: (v) => setState(() => _include[key] = v),
            ),
          ),
        const SectionHeading('Preview'),
        Blueprint(
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${g.active.nickname} — service report',
                style: Type.cardTitle,
              ),
              const SizedBox(height: 7),
              Text(
                'Jan 2026 – Sep 2026 · ${g.recordCount} records · generated on '
                'this iPhone',
                style: Type.rowSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
