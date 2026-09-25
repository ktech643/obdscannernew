import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../monetization/revenuecat_service.dart' show PurchaseOutcome;
import '../../providers/app_providers.dart';

/// Pushes the paywall. SPEC §7.3: contextual only — a door the user just
/// tried, never launch.
Future<void> openProPaywall(BuildContext context) => Navigator.of(
  context,
).push(PageRouteBuilder<void>(pageBuilder: (_, _, _) => const PaywallScreen()));

/// SPEC Part 7 — the paywall, on the Part B design system.
///
/// What it says is what §7.2 says: reading and clearing codes is free on
/// both stores, always; Pro lifts limits. There are no ads in this app and
/// there is no account (§8.3), and this screen mentions neither — the
/// Industry paywall it replaces sold "no ads" and a "free with ads" plan
/// that the code never had. The plans are `EntitlementProvider`'s: the
/// store's own prices when RevenueCat is configured, the spec's fallback
/// prices when it is not.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  /// §7.2, row for row — the four that are free on both plans included:
  /// leaving them out understated the free tier to someone deciding
  /// whether to pay. The hard rule is also stated above the table, in
  /// words.
  static const comparison = <({String feature, String free, String pro})>[
    (feature: 'Connect (all transports)', free: 'Yes', pro: 'Yes'),
    (feature: 'Read codes, stored and pending', free: 'Yes', pro: 'Yes'),
    (feature: 'Clear codes', free: 'Yes', pro: 'Yes'),
    (
      feature: 'Live gauges',
      free: '6 tiles, 1 layout',
      pro: 'Unlimited, named layouts',
    ),
    (feature: 'Graph window', free: '60 s', pro: '30 min'),
    (feature: 'Recording', free: '2 min, last 3 trips', pro: 'Unlimited'),
    (
      feature: 'DTC descriptions',
      free: 'Generic SAE',
      pro: '+ manufacturer-specific + ranked causes',
    ),
    (feature: 'Freeze frame, readiness', free: 'Yes', pro: 'Yes'),
    (feature: 'Mode 06, permanent codes', free: '—', pro: 'Yes'),
    (feature: 'Health Score', free: 'Score only', pro: '+ breakdown + trend'),
    (feature: 'Vehicles', free: '1', pro: 'Unlimited'),
    (feature: 'Maintenance entries', free: '10', pro: 'Unlimited'),
    (feature: 'PDF and CSV export', free: '—', pro: 'Yes'),
  ];

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // The plans on hand may be from a launch with no network. Ask again,
    // so what the screen offers is what the store sells now.
    context.read<EntitlementProvider>().refreshPlans();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ent = context.watch<EntitlementProvider>();
    return Backlit(
      child: Scaffold(
        backgroundColor: t.surfaceDeep,
        appBar: const AdaptiveTopBar(title: 'Torque Pro'),
        body: ListView(
          physics: adaptiveScrollPhysics(context),
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x16,
            Space.gutter,
            Space.x48,
          ),
          children: [
            Text(
              ent.isPro
                  ? 'You have Torque Pro.'
                  : 'Everything about your car, without the limits.',
              style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: Space.x12),
            Text(
              'Reading and clearing fault codes is free, and stays free. '
              'Pro lifts the limits on gauges, recording, vehicles and '
              'reports.',
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            ),
            const SizedBox(height: Space.x24),
            _Comparison(rows: PaywallScreen.comparison),
            const SizedBox(height: Space.x24),
            if (ent.isPro) ...[
              GhostButton(
                label: 'Manage subscription',
                onPressed: ent.manageSubscription,
              ),
            ] else ...[
              Text(
                'Choose a plan',
                style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
              ),
              const SizedBox(height: Space.x12),
              for (var i = 0; i < ent.planCount; i++) ...[
                _PlanCard(
                  title: ent.planTitle(i),
                  price: ent.planPrice(i),
                  period: ent.planPeriod(i),
                  note: ent.planTrialDays(i) == null
                      ? null
                      : '${ent.planTrialDays(i)}-day free trial first',
                  selected: ent.selectedPlan == i,
                  onTap: () => ent.selectPlan(i),
                ),
                const SizedBox(height: Space.x8),
              ],
              const SizedBox(height: Space.x8),
              PrimaryButton(
                label: ent.purchaseInFlight
                    ? 'Starting…'
                    : ent.planAction(ent.selectedPlan),
                loading: ent.purchaseInFlight,
                onPressed: ent.purchaseInFlight
                    ? null
                    : () => _buy(context, ent),
              ),
              const SizedBox(height: Space.x8),
              GhostButton(
                label: 'Not now',
                onPressed: () => Navigator.of(context).pop(),
              ),
              GhostButton(
                label: ent.restoring ? 'Restoring…' : 'Restore purchases',
                onPressed: ent.restoring ? null : () => _restore(context, ent),
              ),
              const SizedBox(height: Space.x16),
              if (ent.billingConfigured && !ent.plansFromStore) ...[
                Text(
                  "Couldn't reach the store, so these are the usual prices. "
                  'The store shows the exact price before anything is '
                  'charged.',
                  style: TorqueType.meta.copyWith(color: t.tellAmber),
                ),
                const SizedBox(height: Space.x8),
              ],
              Text(
                'Subscriptions renew automatically until cancelled in your '
                'App Store or Google Play account; the lifetime plan is a '
                'one-time purchase.'
                '${ent.plansFromStore ? " Prices are in your store's currency." : ''} '
                'The store and RevenueCat see an anonymous ID and your '
                'purchases — never your car\'s data.',
                style: TorqueType.meta.copyWith(color: t.inkTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// SPEC §7.5's outcomes, each told as it happened: a pending purchase is
  /// neither granted nor an error; a cancelled one is nothing.
  Future<void> _buy(BuildContext context, EntitlementProvider ent) async {
    final outcome = await ent.subscribe();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        await showAdaptiveAlert(
          context,
          title: 'You have Torque Pro',
          message: 'Every limit is lifted. Nothing else changes.',
          actions: [
            AdaptiveAlertAction(
              label: 'OK',
              isDefault: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      case PurchaseOutcome.pending:
        await showAdaptiveAlert(
          context,
          title: 'Waiting for approval',
          message:
              'The store is holding this purchase for approval. Pro turns '
              'on by itself once it goes through.',
          actions: [
            AdaptiveAlertAction(label: 'OK', isDefault: true, onPressed: () {}),
          ],
        );
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.failed:
      case PurchaseOutcome.unavailable:
        await showAdaptiveAlert(
          context,
          title: "The store didn't complete it",
          message: 'Nothing was charged. Try again in a moment.',
          actions: [
            AdaptiveAlertAction(label: 'OK', isDefault: true, onPressed: () {}),
          ],
        );
    }
  }

  Future<void> _restore(BuildContext context, EntitlementProvider ent) async {
    final ok = await ent.restore();
    if (!context.mounted) return;
    await showAdaptiveAlert(
      context,
      title: ok ? 'Purchases restored' : 'Nothing to restore',
      message: ok
          ? 'Your previous purchase is active again.'
          : 'No purchase was found for this store account.',
      actions: [
        AdaptiveAlertAction(label: 'OK', isDefault: true, onPressed: () {}),
      ],
    );
  }
}

/// §7.2 as three columns. The hard rule sits above the rows, in words.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.rows});
  final List<({String feature, String free, String pro})> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final head = TorqueType.gaugeLabel.copyWith(color: t.inkSecondary);
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading and clearing codes: free on both stores, always.',
            style: TorqueType.body.copyWith(
              color: t.inkPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Space.x16),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(flex: 3, child: Text('FREE', style: head)),
              Expanded(flex: 4, child: Text('PRO', style: head)),
            ],
          ),
          for (final r in rows) ...[
            const SizedBox(height: Space.x12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    r.feature,
                    style: TorqueType.body.copyWith(color: t.inkPrimary),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.free,
                    style: TorqueType.meta.copyWith(color: t.inkSecondary),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    r.pro,
                    style: TorqueType.meta.copyWith(color: t.inkPrimary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One plan. A radio, in effect: selected is a border in the tell colour,
/// and the semantics say which of the group this is.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String title;
  final String price;
  final String period;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title, $price $period${note == null ? '' : ', $note'}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(
                color: selected ? t.tellAmber : t.hairline,
                width: selected ? 2 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.min),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x16,
                  vertical: Space.x12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TorqueType.body.copyWith(
                              color: t.inkPrimary,
                            ),
                          ),
                          if (note != null)
                            Text(
                              note!,
                              style: TorqueType.meta.copyWith(
                                color: t.inkSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.x12),
                    Text(
                      '$price $period',
                      style: TorqueType.body.copyWith(
                        color: selected ? t.tellAmber : t.inkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
