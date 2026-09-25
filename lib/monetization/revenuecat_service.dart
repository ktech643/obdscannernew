import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/revenuecat_config.dart';
import '../core/platform/platform_info.dart';
import 'plan_option.dart';

/// The outcome of a purchase attempt. SPEC §7.5.
enum PurchaseOutcome { success, pending, cancelled, failed, unavailable }

/// A thin wrapper around RevenueCat (`purchases_flutter`). SPEC §8.3 Option B.
///
/// The app has no backend, so RevenueCat is the only outbound dependency for
/// entitlements. Everything here degrades gracefully when the SDK keys are
/// absent (dev mode, tests): [configured] is false, [isPro] returns null, and
/// [plans] returns the bundled fallback prices — so the whole app stays
/// testable without store keys and a release build is forced to pass real keys.
class RevenueCatService {
  RevenueCatService({PlatformInfo? platform})
    : _platform = platform ?? PlatformInfo.current;

  final PlatformInfo _platform;

  bool _configured = false;
  bool get configured => _configured;

  Future<void> configure() async {
    if (_configured) return;
    final key = _platform.isAndroid
        ? RevenueCatConfig.androidApiKey
        : RevenueCatConfig.iosApiKey;
    if (key.isEmpty) return; // unconfigured dev/test mode
    try {
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
    } catch (_) {
      _configured = false;
    }
  }

  /// Whether the `pro` entitlement is active.
  ///
  /// Returns **null** when the store is unreachable (offline or error) so the
  /// caller can keep its cached grace entitlement instead of wrongly
  /// downgrading a paying user. SPEC §7.5.
  Future<bool?> isPro() async {
    if (!_configured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(
        RevenueCatConfig.entitlementId,
      );
    } catch (_) {
      return null;
    }
  }

  /// The plans to display, in paywall order (weekly, monthly, lifetime).
  /// The three plans, from the store when it answers.
  ///
  /// Both product categories are asked for: `getProducts` defaults to
  /// subscriptions only, and the lifetime plan is a one-time purchase that
  /// query never returns. An earlier version asked once, matched the plain
  /// id, and so on Android — where a subscription's id is
  /// `{subscription}:{basePlan}` — matched nothing: every plan had no
  /// product, and nothing could be bought.
  Future<List<PlanOption>> plans() async {
    if (!_configured) return _fallbackPlans();
    try {
      final ids = RevenueCatConfig.productIds;
      final products = [
        ...await Purchases.getProducts(
          ids,
          productCategory: ProductCategory.subscription,
        ),
        ...await Purchases.getProducts(
          ids,
          productCategory: ProductCategory.nonSubscription,
        ),
      ];
      if (products.isEmpty) return _fallbackPlans();
      // iOS says who may have the trial; Play only offers a free phase to
      // a user who is eligible, so its answer is in the product itself.
      var eligible = const <String>{};
      if (!_platform.isAndroid) {
        try {
          final map = await Purchases.checkTrialOrIntroductoryPriceEligibility(
            ids,
          );
          eligible = {
            for (final e in map.entries)
              if (e.value.status ==
                  IntroEligibilityStatus.introEligibilityStatusEligible)
                e.key,
          };
        } catch (_) {
          // Unknown eligibility claims no trial.
        }
      }
      return [
        for (var i = 0; i < ids.length; i++)
          planFor(
            products,
            i,
            isAndroid: _platform.isAndroid,
            trialEligible: eligible,
          ),
      ];
    } catch (_) {
      return _fallbackPlans();
    }
  }

  /// Pure: the plan at [index] from what the store returned. Public for
  /// the tests, which cannot reach a store.
  static PlanOption planFor(
    List<StoreProduct> products,
    int index, {
    required bool isAndroid,
    Set<String> trialEligible = const {},
  }) {
    final id = RevenueCatConfig.productIds[index];
    final product = products
        .where((p) => p.identifier == id || p.identifier.startsWith('$id:'))
        .firstOrNull;
    return PlanOption(
      title: _titles[index],
      price: product?.priceString ?? RevenueCatConfig.fallbackPrices[index],
      period: RevenueCatConfig.fallbackPeriods[index],
      product: product,
      freeTrialDays: product == null
          ? null
          : isAndroid
          ? _days(product.defaultOption?.freePhase?.billingPeriod)
          : trialEligible.contains(id) &&
                product.introductoryPrice != null &&
                product.introductoryPrice!.price == 0
          ? _introDays(product.introductoryPrice!)
          : null,
    );
  }

  static int? _days(Period? p) => p == null ? null : _toDays(p.unit, p.value);

  static int? _introDays(IntroductoryPrice p) =>
      _toDays(p.periodUnit, p.periodNumberOfUnits);

  static int? _toDays(PeriodUnit unit, int n) => switch (unit) {
    PeriodUnit.day => n,
    PeriodUnit.week => n * 7,
    PeriodUnit.month => n * 30,
    PeriodUnit.year => n * 365,
    PeriodUnit.unknown => null,
  };

  /// Attempts to buy the given plan. Mapped to SPEC §7.5's outcome vocabulary.
  Future<PurchaseOutcome> purchase(PlanOption plan) async {
    final product = plan.product;
    if (!_configured || product == null) return PurchaseOutcome.unavailable;
    try {
      await Purchases.purchaseStoreProduct(product);
      return PurchaseOutcome.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        // Ask to Buy, SCA, or Play pending — do not grant, do not error. The
        // entitlement listener grants the moment the store resolves it.
        return PurchaseOutcome.pending;
      }
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        // Already owned: the entitlement should be active; treat as success.
        return PurchaseOutcome.success;
      }
      return PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }

  /// Restores purchases against the store account. SPEC §7.5: must work with
  /// no app account (Play restores by Google account, iOS by Apple ID).
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      await Purchases.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Registers a callback fired whenever customer info changes (purchase,
  /// refund, revocation, billing retry). Returns an unsubscribe function.
  void Function() addEntitlementListener(void Function(bool isPro) onChanged) {
    if (!_configured) return () {};
    void listener(CustomerInfo info) {
      final pro = info.entitlements.active.containsKey(
        RevenueCatConfig.entitlementId,
      );
      onChanged(pro);
    }

    Purchases.addCustomerInfoUpdateListener(listener);
    return () => Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Opens the store's manage-subscription page. SPEC §5.6.
  ///
  /// The SDK doesn't expose a manage-subscription sheet in this version, so
  /// the platform's own subscriptions page is opened — the same destination
  /// RevenueCat's `manageSubscriptions` deep link points at.
  Future<void> manageSubscription() async {
    if (!_configured) return;
    final url = _platform.isAndroid
        ? 'https://play.google.com/store/account/subscriptions'
        : 'https://apps.apple.com/account/subscriptions';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  List<PlanOption> _fallbackPlans() => [
    for (var i = 0; i < _titles.length; i++)
      PlanOption(
        title: _titles[i],
        price: RevenueCatConfig.fallbackPrices[i],
        period: RevenueCatConfig.fallbackPeriods[i],
      ),
  ];

  static const _titles = <String>['Weekly', 'Monthly', 'Lifetime'];
}
