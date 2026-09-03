import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../providers/settings_format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

/// E5 — the fuel log. Economy is calculated between full fill-ups only;
/// partial fills are recorded and shown, but excluded from the figure.
class FuelLogScreen extends StatelessWidget {
  const FuelLogScreen({super.key});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    final s = context.watch<SettingsProvider>();

    return Screen(
      title: 'Fuel log',
      backLabel: 'Garage',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            'Add a fill-up',
            onPressed: () => notImplementedHere(
              context,
              'Fill-up entry lands with the next Garage pass.',
            ),
          ),
        ],
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${g.lifetimeConsumption}',
              style: Type.healthScore(T.text).copyWith(fontSize: 52),
            ),
            const SizedBox(width: 8),
            Text('L/100 km · lifetime', style: Type.rowSecondary),
          ],
        ),
        const SizedBox(height: 18),
        TriStat([
          (value: '${g.bestConsumption}', label: 'Best', tone: Tone.ink),
          (value: '${g.worstConsumption}', label: 'Worst', tone: Tone.ink),
          (value: s.formatMoney(g.costPerKm), label: 'Per km', tone: Tone.ink),
        ]),
        const SizedBox(height: 22),
        const _FuelHeader(),
        for (final f in GarageProvider.fuelEntries)
          Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: const BoxDecoration(border: T.hairlineBottom),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    '${f.date.day} ${_months[f.date.month - 1]} · '
                    '${SettingsFormat.group(f.odometerKm)} km',
                    style: Type.rowSecondary,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    f.litres.toStringAsFixed(2),
                    style: Type.inlineValue,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    s.formatMoney(f.cost),
                    style: Type.inlineValue,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    // A part fill has no honest consumption figure, so it
                    // shows the reason instead of a number.
                    f.partFill
                        ? 'part fill'
                        : f.consumption!.toStringAsFixed(1),
                    style: f.partFill
                        ? Type.rowSecondary.copyWith(fontSize: 11.5)
                        : Type.inlineValue,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Economy is calculated between full fill-ups only. Partial fills are '
          'recorded but excluded from the figure — including them is the most '
          'common way fuel logs lie.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

class _FuelHeader extends StatelessWidget {
  const _FuelHeader();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: T.hairlineBottom),
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(flex: 5, child: Text('DATE', style: Type.sectionHeading)),
        Expanded(
          flex: 2,
          child: Text(
            'LITRES',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'COST',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'L/100',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
