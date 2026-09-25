import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/monetization/plan_option.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';

/// SPEC Part 7 — what the store returned, turned into plans the paywall can
/// sell. No store is reachable from a test, so the matching is pure and
/// the provider is driven through a stand-in for the service.
void main() {
  StoreProduct product(
    String id, {
    ProductCategory category = ProductCategory.subscription,
    IntroductoryPrice? intro,
    SubscriptionOption? option,
  }) => StoreProduct(
    id,
    'Torque Pro',
    'Torque Pro',
    4.99,
    '£4.99',
    'GBP',
    productCategory: category,
    introductoryPrice: intro,
    defaultOption: option,
  );

  SubscriptionOption withFreeDays(int days) => SubscriptionOption(
    'weekly:trial',
    'torque_pro_weekly:weekly',
    'torque_pro_weekly',
    const [],
    const [],
    false,
    null,
    false,
    null,
    PricingPhase(
      Period(PeriodUnit.day, days, 'P${days}D'),
      null,
      1,
      const Price('Free', 0, 'GBP'),
      null,
    ),
    null,
    null,
    null,
  );

  group('★ what the store returned', () {
    test('★ Android: `id:basePlan` subscriptions and the one-time lifetime '
        'all match', () {
      // getProducts defaults to subscriptions, and Play names them
      // "{subscription}:{basePlan}"; matching the plain id found nothing.
      final products = [
        product('torque_pro_weekly:weekly'),
        product('torque_pro_monthly:monthly'),
        product(
          'torque_pro_lifetime',
          category: ProductCategory.nonSubscription,
        ),
      ];
      for (var i = 0; i < 3; i++) {
        final plan = RevenueCatService.planFor(products, i, isAndroid: true);
        expect(plan.product, isNotNull, reason: plan.title);
        expect(plan.price, '£4.99', reason: 'the store\'s price, not ours');
      }
    });

    test('a product the store did not return has none to buy', () {
      final plan = RevenueCatService.planFor(
        [product('torque_pro_weekly')],
        2,
        isAndroid: false,
      );
      expect(plan.product, isNull);
      expect(plan.fromStore, isFalse);
    });
  });

  group('★ a trial only when the store will give one', () {
    const threeDaysFree = IntroductoryPrice(
      0,
      'Free',
      'P3D',
      1,
      PeriodUnit.day,
      3,
    );

    test('★ iOS: an eligible user with a free intro gets its length', () {
      final plan = RevenueCatService.planFor(
        [product('torque_pro_weekly', intro: threeDaysFree)],
        0,
        isAndroid: false,
        trialEligible: {'torque_pro_weekly'},
      );
      expect(plan.freeTrialDays, 3);
      expect(plan.actionLabel, 'Start 3-day free trial');
    });

    test('★ iOS: a user who has had it is offered no trial', () {
      final plan = RevenueCatService.planFor(
        [product('torque_pro_weekly', intro: threeDaysFree)],
        0,
        isAndroid: false,
      );
      expect(plan.freeTrialDays, isNull);
      expect(plan.actionLabel, 'Start weekly');
    });

    test('Android: the free phase Play offered is the trial', () {
      final plan = RevenueCatService.planFor(
        [product('torque_pro_weekly:weekly', option: withFreeDays(3))],
        0,
        isAndroid: true,
      );
      expect(plan.freeTrialDays, 3);
    });

    test('the bundled fallback plans promise no trial', () {
      const fallback = PlanOption(
        title: 'Weekly',
        price: r'$4.99',
        period: '/week',
      );
      expect(fallback.freeTrialDays, isNull);
      expect(fallback.actionLabel, 'Start weekly');
    });
  });

  group('★ plans are asked for again', () {
    late Persistence store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await Persistence.open();
    });

    test(
      '★ a purchase after an offline launch reloads the plans and buys',
      () async {
        final billing = _Billing(
          answers: [
            // Launch: the store could not be reached.
            const [
              PlanOption(title: 'Weekly', price: r'$4.99', period: '/week'),
              PlanOption(title: 'Monthly', price: r'$9.99', period: '/month'),
              PlanOption(title: 'Lifetime', price: r'$49.99', period: 'once'),
            ],
            // Later: it can.
            [
              RevenueCatService.planFor(
                [product('torque_pro_weekly')],
                0,
                isAndroid: false,
              ),
            ],
          ],
        );
        final ent = EntitlementProvider(store, billing: billing);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(ent.plansFromStore, isFalse);

        final outcome = await ent.subscribe();
        expect(outcome, PurchaseOutcome.success);
        expect(billing.purchased, hasLength(1), reason: 'the reloaded plan');
        expect(ent.plansFromStore, isTrue);
        ent.dispose();
      },
    );
  });
}

/// A configured store that answers `plans()` from a script and records
/// what was bought.
class _Billing extends RevenueCatService {
  _Billing({required this.answers});

  final List<List<PlanOption>> answers;
  final purchased = <PlanOption>[];
  var _asked = 0;

  @override
  bool get configured => true;

  @override
  Future<void> configure() async {}

  @override
  Future<List<PlanOption>> plans() async =>
      answers[_asked < answers.length ? _asked++ : answers.length - 1];

  @override
  Future<bool?> isPro() async => null;

  @override
  void Function() addEntitlementListener(void Function(bool isPro) onChanged) =>
      () {};

  @override
  Future<PurchaseOutcome> purchase(PlanOption plan) async {
    if (plan.product == null) return PurchaseOutcome.unavailable;
    purchased.add(plan);
    return PurchaseOutcome.success;
  }
}
