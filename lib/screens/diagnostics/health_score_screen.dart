import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_providers.dart';
import '../../providers/diagnostics_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';

/// D6 — the health score.
///
/// **Never show a score without the breakdown.** Every point lost is itemised
/// with its cause and its remedy; a number on its own isn't information, it's
/// a mood.
class HealthScoreScreen extends StatelessWidget {
  const HealthScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    final e = context.watch<EntitlementProvider>();
    final score = dx.healthScore;
    final color = score >= 85
        ? T.passText
        : score >= 60
        ? T.cautionText
        : T.fault;

    return Screen(
      title: 'Health score',
      backLabel: 'Diagnostics',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$score', style: Type.healthScore(color)),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('out of 100', style: Type.rowSecondary),
                  const SizedBox(height: 4),
                  Text(
                    dx.scoreVerdict,
                    style: Type.rowPrimary.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SplitBar(score: score, lost: dx.pointsLost, color: color),
        const SectionHeading('What cost points'),
        for (final d in DiagnosticsProvider.deductions)
          AppListRow(
            title: d.title,
            subtitle: d.remedy,
            value: '−${d.points}',
            valueStyle: Type.inlineValueLg.copyWith(color: T.fault),
          ),
        const SizedBox(height: 16),
        Text(
          dx.breakdownIsExact
              ? "Every point is accounted for above. A score without its "
                    "breakdown isn't information."
              : 'The causes above overlap — the Check Engine light is on only '
                    'because of P0301 — so their weights add up to '
                    '${dx.rawDeductionTotal}, more than the ${dx.pointsLost} '
                    'actually deducted. Nothing is hidden: every cause is listed, '
                    'and a score without its breakdown isn\'t information.',
          style: Type.footnote,
        ),
        const SizedBox(height: 18),
        AppListRow(
          title: 'Score history',
          trailing: e.isPro ? null : const Badge('PRO'),
          chevron: true,
          onTap: () {},
        ),
      ],
    );
  }
}

/// The 62/38 split bar — score kept against points lost.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.score,
    required this.lost,
    required this.color,
  });

  final int score;
  final int lost;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Blueprint(
        corners: false,
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              Expanded(
                flex: score,
                child: SizedBox.expand(child: ColoredBox(color: color)),
              ),
              Expanded(
                flex: lost,
                child: CustomPaint(
                  painter: HatchPainter(color: T.neutral400),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Text('0', style: Type.sectionHeading),
          const Spacer(),
          Text(
            '$lost POINTS LOST',
            style: Type.sectionHeading.copyWith(color: T.fault),
          ),
          const Spacer(),
          Text('100', style: Type.sectionHeading),
        ],
      ),
    ],
  );
}
