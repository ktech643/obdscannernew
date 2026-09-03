import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// K3 — a rewarded ad. Offered, never required; it unlocks two extra gauge
/// tiles for 60 minutes and nothing else is gated behind it.
class RewardedAdScreen extends StatefulWidget {
  const RewardedAdScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<RewardedAdScreen> createState() => _RewardedAdScreenState();
}

class _RewardedAdScreenState extends State<RewardedAdScreen> {
  int _remaining = 4;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining == 0) {
        t.cancel();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: T.neutral900,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: T.gutter,
              vertical: 12,
            ),
            child: Row(
              children: [
                const Badge('AD', color: T.neutral400),
                const Spacer(),
                if (_remaining > 0)
                  Text('Skip in 0:0$_remaining', style: Type.chip(T.neutral400))
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onComplete?.call();
                      Navigator.of(context).pop();
                    },
                    child: const SizedBox(
                      width: T.touchTargetFloor,
                      height: T.touchTargetFloor,
                      child: Center(
                        child: Icn(Lu.x, size: 20, color: T.neutral200),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(T.gutter),
              child: _CreativePlate(
                label: 'A third-party sponsor spot renders here',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(T.gutter, 0, T.gutter, 14),
            child: Column(
              children: [
                SecondaryButton('Learn more', onPressed: () {}),
                const SizedBox(height: 12),
                Text(
                  'Never shown mid-scan, over a fault result, or above '
                  '5 km/h — rewarded ads only, offered, never required',
                  style: Type.footnote.copyWith(color: T.neutral400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// K4 — an interstitial. Closable after 5 s, and never inside the diagnostics
/// flow.
class InterstitialAdScreen extends StatelessWidget {
  const InterstitialAdScreen({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: T.neutral900,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: T.gutter,
              vertical: 12,
            ),
            child: Row(
              children: [
                const Badge('AD', color: T.neutral400),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: T.touchTargetFloor,
                    height: T.touchTargetFloor,
                    child: Center(
                      child: Icn(Lu.x, size: 20, color: T.neutral200),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(T.gutter),
              child: _CreativePlate(
                label: 'Static or video creative from the ad network',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(T.gutter, 0, T.gutter, 18),
            child: Text(
              'Closable after 5 s · never appears over a scan or fault result',
              style: Type.footnote.copyWith(color: T.neutral400),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreativePlate extends StatelessWidget {
  const _CreativePlate({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Blueprint(
    corners: false,
    borderColor: T.neutral700,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          label,
          style: Type.rowSecondary.copyWith(color: T.neutral400),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// K1 — the EV / pre-OBD2 dead end.
///
/// We deliberately do **not** offer Pro from this screen. Selling live-data
/// features to someone whose car cannot provide live data is the single
/// fastest way to earn a refund and a 1★ review.
class EvDeadEndScreen extends StatelessWidget {
  const EvDeadEndScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Screen(
    title: 'This looks like an electric vehicle',
    footer: ScreenFooter(
      children: [SecondaryButton('Continue anyway', onPressed: onContinue)],
    ),
    children: [
      Text(
        'The adapter connected fine, but fewer than 6 standard PIDs answered '
        "and there's no RPM or airflow reading. Standard OBD2 covers very "
        'little on EVs — most manufacturers use proprietary data Torque '
        "can't read.",
        style: Type.body16Muted,
      ),
      const SectionHeading('What still works'),
      const _WorksRow('Fault codes, if the vehicle reports any', true),
      const _WorksRow('Garage, maintenance log, reminders', true),
      const _WorksRow('Live gauges — most will read "not available"', false),
      const SizedBox(height: 18),
      Text(
        "We won't offer Pro from this screen — see the next card if you "
        'already subscribed.',
        style: Type.footnote,
      ),
    ],
  );
}

class _WorksRow extends StatelessWidget {
  const _WorksRow(this.label, this.works);

  final String label;
  final bool works;

  @override
  Widget build(BuildContext context) => AppListRow(
    title: label,
    leading: Icn(
      works ? Lu.circleCheck : Lu.circleX,
      size: 17,
      color: works ? T.passText : T.neutral500,
    ),
    titleStyle: Type.rowPrimary.copyWith(color: works ? T.text : T.neutral700),
  );
}

/// K2 — the proactive refund card. We can't process it ourselves, so we point
/// at the party who can and say how long it takes.
class RefundCardScreen extends StatelessWidget {
  const RefundCardScreen({super.key});

  @override
  Widget build(BuildContext context) => Screen(
    title: "This might not have been worth subscribing for",
    footer: ScreenFooter(
      children: [
        PrimaryButton(
          'Request a refund from Apple',
          onPressed: () {},
          icon: Lu.externalLink,
        ),
        const SizedBox(height: 8),
        GhostButton(
          'Keep my subscription anyway',
          color: T.neutral700,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
    children: [
      Text(
        'You subscribed to Pro, and your car is reading as an electric '
        "vehicle with almost no standard data available. Pro's live-data "
        "features won't do much here.",
        style: Type.body16Muted,
      ),
      const SizedBox(height: 18),
      const NoteBlock(
        "A refund for a subscription you can't use is a fair ask. We can't "
        'process it ourselves — Apple holds the purchase — but their form '
        'takes about two minutes.',
      ),
    ],
  );
}
