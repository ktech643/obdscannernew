import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/diagnostics_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// D4 — the clear-codes sheet.
///
/// This is the app's trust exhibit. Four consequences, each led by an amber
/// caution glyph, none of them collapsible and none of them scrolled past by
/// default. The destructive action is outlined, not filled, and Cancel is
/// plain text — clearing must never be the path of least resistance.
Future<void> showClearCodesSheet(BuildContext context) =>
    showAppSheet<void>(context, (context) => const _ClearCodesSheet());

class _ClearCodesSheet extends StatelessWidget {
  const _ClearCodesSheet();

  static const _consequences = [
    'Turns off the Check Engine light',
    'Erases the freeze-frame data a mechanic may need',
    'Resets all readiness monitors — your car will likely fail an emissions '
        "test until you've driven it 50–100 miles",
    "Does not fix the fault. If it's still there, the code comes back",
  ];

  @override
  Widget build(BuildContext context) {
    final dx = context.read<DiagnosticsProvider>();
    final d = context.watch<DashboardProvider>();
    final stationary = d.stationary;

    return SheetBody(
      eyebrow: 'Diagnostics',
      title: 'Clear these codes?',
      children: [
        for (final c in _consequences)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icn(Lu.triangleAlert, size: 15, color: T.cautionText),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(c, style: Type.body15)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // A DTCSnapshot is always written before Mode 04 is issued.
        const NoteBlock(
          "We'll save a copy of every code, freeze frame and monitor state in "
          'your Garage first — before anything is erased.',
        ),
        const SizedBox(height: 18),
        DestructiveButton(
          'Clear codes',
          enabled: stationary,
          onPressed: () async {
            final navigator = Navigator.of(context);
            // Re-read after clearing and report the true result.
            await dx.clearCodes(stationary: stationary);
            navigator.pop();
          },
        ),
        const SizedBox(height: 4),
        GhostButton(
          'Cancel',
          color: T.neutral700,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icn(
              stationary ? Lu.circleCheck : Lu.circleAlert,
              size: 14,
              color: stationary ? T.passText : T.cautionText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stationary
                    ? 'Car must be stationary. Speed reads 0 km/h.'
                    : 'Car must be stationary. Speed reads '
                          '${d.speedKmh?.toStringAsFixed(0) ?? '—'} km/h.',
                style: Type.footnote.copyWith(
                  color: stationary ? T.neutral700 : T.cautionText,
                ),
              ),
            ),
          ],
        ),
        if (!stationary) ...[
          const SizedBox(height: 10),
          // The gate is real, but the demo has to be reachable without a car.
          GhostButton(
            'Park the car (demo)',
            color: T.neutral700,
            onPressed: () => d.setSpeed(0),
          ),
        ],
      ],
    );
  }
}
