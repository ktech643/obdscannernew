import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/icons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

void openPaywall(BuildContext context) => Navigator.of(context)
    .push(PageRouteBuilder(pageBuilder: (_, _, _) => const PaywallScreen()));

/// F1 — the contextual paywall. The close control is visible from the first
/// frame, and the renewal terms are stated in full rather than linked away.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.trigger = 'gauges'});

  final String trigger;

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EntitlementProvider>();

    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Start 3-day free trial',
            onPressed: () {
              e.subscribe();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 6),
          GhostButton(
            'Keep using Torque free with ads',
            onPressed: () {
              e.continueFreeWithAds();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 6),
          const _LegalLinks(),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: T.touchTargetFloor,
                height: T.touchTargetFloor,
                child: Center(child: Icn(Lu.x, size: 20, color: T.neutral700)),
              ),
            ),
          ),
        ),
        Text('Unlock unlimited gauges', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          "You've filled all six free tiles. Pro removes the limit and takes the "
          'ads out.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        const _ComparisonTable(),
        const SizedBox(height: 22),
        _PlanCard(
          index: 0,
          name: 'Weekly',
          price: EntitlementProvider.priceWeekly,
          period: '/week',
        ),
        const SizedBox(height: 10),
        _PlanCard(
          index: 1,
          name: 'Monthly',
          price: EntitlementProvider.priceMonthly,
          period: '/month',
        ),
        const SizedBox(height: 10),
        _PlanCard(
          index: 2,
          name: 'Lifetime',
          price: EntitlementProvider.priceLifetime,
          period: 'once',
        ),
        const SizedBox(height: 18),
        // The full renewal terms, in the flow, not behind a link.
        Text(
          'Free for 3 days, then ${EntitlementProvider.priceWeekly} per week. '
          'Renews automatically until you cancel, any time in your Apple account '
          "settings. Cancel at least 24 hours before the trial ends and you won't "
          'be charged.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = [
    (feature: 'Gauge tiles', free: '6', pro: 'Unlimited'),
    (feature: 'Recording', free: '2 min', pro: 'Unlimited'),
    (feature: 'Vehicles', free: '1', pro: 'Unlimited'),
    (feature: 'Export PDF and CSV', free: 'No', pro: 'Yes'),
    (feature: 'Ads', free: 'Banner', pro: 'None'),
  ];

  @override
  Widget build(BuildContext context) => Blueprint(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Spacer(flex: 5),
            Expanded(
              flex: 3,
              child: Text(
                'FREE',
                style: Type.sectionHeading,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'PRO',
                style: Type.sectionHeading.copyWith(color: T.accent700),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final r in _rows)
          Container(
            decoration: const BoxDecoration(border: T.hairlineTop),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(r.feature, style: Type.rowPrimary),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.free,
                    style: Type.rowSecondary,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.pro,
                    style: Type.inlineValue.copyWith(color: T.accent700),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.index,
    required this.name,
    required this.price,
    required this.period,
  });

  final int index;
  final String name;
  final String price;
  final String period;

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EntitlementProvider>();
    final selected = e.selectedPlan == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => e.selectPlan(index),
      child: Blueprint(
        corners: false,
        borderColor: selected ? T.accent700 : T.divider,
        fill: selected ? T.accentTint : null,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? T.accent700 : T.neutral500,
                  width: 1,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        color: T.accent700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: Type.rowPrimary16)),
            Text(price, style: Type.inlineValueLg),
            const SizedBox(width: 4),
            Text(period, style: Type.rowSecondary),
          ],
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      InlineAction(
        'Restore purchases',
        color: T.neutral700,
        onPressed: () => notImplementedHere(
          context,
          'Checking your Apple ID for existing purchases…',
        ),
      ),
      Text('·', style: Type.rowSecondary),
      InlineAction(
        'Terms',
        color: T.neutral700,
        onPressed: () =>
            notImplementedHere(context, 'Opens the Terms in Safari.'),
      ),
      Text('·', style: Type.rowSecondary),
      InlineAction(
        'Privacy',
        color: T.neutral700,
        onPressed: () =>
            notImplementedHere(context, 'Opens the Privacy Policy in Safari.'),
      ),
    ],
  );
}

/// F2 — subscribe or free-with-ads. Both routes are presented as legitimate
/// choices, with the actual trade stated on each side.
class ChoiceScreen extends StatelessWidget {
  const ChoiceScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final e = context.read<EntitlementProvider>();
    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Start 3-day free trial',
            onPressed: () {
              e.subscribe();
              onDone();
            },
          ),
          const SizedBox(height: 6),
          GhostButton(
            'Continue free with ads',
            onPressed: () {
              e.continueFreeWithAds();
              onDone();
            },
          ),
          const SizedBox(height: 6),
          const _LegalLinks(),
        ],
      ),
      children: [
        const SizedBox(height: 6),
        Text('Two ways to use Torque', style: Type.onboardingHeadline),
        const SizedBox(height: 10),
        Text(
          'Pick either one. Switch whenever you like.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        const _OptionCard(
          title: 'Torque Pro',
          price: 'from ${EntitlementProvider.priceWeekly}',
          accent: true,
          points: [
            'No ads anywhere in the app',
            'Unlimited gauges, layouts, vehicles and recording',
            'Mode 06, permanent codes, PDF and CSV export',
            'Nothing about you leaves your iPhone',
          ],
        ),
        const SizedBox(height: 14),
        const _OptionCard(
          title: 'Free with ads',
          price: r'$0',
          points: [
            'Read and clear fault codes, freeze frame, readiness — all of it',
            'A labelled banner sits above the tab bar',
            'Six gauges, 2-minute recordings, one vehicle',
            'Our ad partner receives your device identifier and app usage',
          ],
        ),
        const SizedBox(height: 18),
        // The disclosure is part of the choice, not buried in a policy page.
        const NoteBlock(
          'Ads never cover a fault result, never interrupt a scan, and never '
          'appear while the car is moving. Your codes and vehicle data are never '
          'shared with advertisers.',
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.price,
    required this.points,
    this.accent = false,
  });

  final String title;
  final String price;
  final List<String> points;
  final bool accent;

  @override
  Widget build(BuildContext context) => Blueprint(
    borderColor: accent ? T.accent700 : T.divider,
    padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Type.cardTitleLg.copyWith(
                  color: accent ? T.accent700 : T.text,
                ),
              ),
            ),
            Text(price, style: Type.inlineValue.copyWith(color: T.neutral700)),
          ],
        ),
        const SizedBox(height: 13),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icn(
                    Lu.check,
                    size: 13,
                    color: accent ? T.accent700 : T.neutral600,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(p, style: Type.body15)),
              ],
            ),
          ),
      ],
    ),
  );
}
