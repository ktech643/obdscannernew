import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/monetization/plan_option.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';

/// A scriptable RevenueCat stand-in so the provider's entitlement, purchase
/// and grace logic can be tested without a store or a platform channel.
class _FakeBilling extends RevenueCatService {
  _FakeBilling({
    this.pro = false,
    this.reachable = true,
    this.configuredValue = true,
    this.restoreOk = false,
  }) : super(platform: const FakePlatform(isAndroid: true));

  bool pro;
  bool reachable;
  bool configuredValue;
  bool restoreOk;
  int purchaseCalls = 0;
  List<PlanOption> plansList = const [];

  @override
  bool get configured => configuredValue;

  @override
  Future<void> configure() async {}

  @override
  Future<bool?> isPro() async => reachable ? pro : null;

  @override
  Future<List<PlanOption>> plans() async => plansList;

  @override
  Future<PurchaseOutcome> purchase(PlanOption plan) async {
    purchaseCalls++;
    return PurchaseOutcome.success;
  }

  @override
  Future<bool> restore() async => restoreOk;

  @override
  void Function() addEntitlementListener(void Function(bool) onChanged) =>
      () {};
}

void main() {
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  /// Lets the fire-and-forget `_init()` in the constructor settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts free when nothing is stored', () {
    final e = EntitlementProvider(store, billing: _FakeBilling());
    expect(e.tier, Entitlement.free);
    expect(e.isPro, isFalse);
  });

  test('subscribe grants Pro locally when billing is unconfigured', () async {
    final e = EntitlementProvider(
      store,
      billing: _FakeBilling(configuredValue: false),
    );
    final outcome = await e.subscribe();
    expect(outcome, PurchaseOutcome.success);
    expect(e.isPro, isTrue);
    expect(
      store.enumValue(
        Keys.entitlementTier,
        Entitlement.values,
        Entitlement.free,
      ),
      Entitlement.pro,
    );
  });

  test('configured subscribe calls through and grants on success', () async {
    final billing = _FakeBilling(configuredValue: true)
      ..plansList = const [
        PlanOption(title: 'Weekly', price: r'$4.99', period: '/week'),
      ];
    final e = EntitlementProvider(store, billing: billing);
    await settle(); // let _init populate the plans list
    final outcome = await e.subscribe();
    expect(billing.purchaseCalls, 1);
    expect(outcome, PurchaseOutcome.success);
    expect(e.isPro, isTrue);
  });

  test('restore grants only when the store confirms Pro', () async {
    final billing = _FakeBilling(
      configuredValue: true,
      restoreOk: true,
      pro: true,
    );
    final e = EntitlementProvider(store, billing: billing);
    expect(await e.restore(), isTrue);
    expect(e.isPro, isTrue);
  });

  test('restore with nothing to restore stays free', () async {
    final billing = _FakeBilling(
      configuredValue: true,
      restoreOk: true,
      pro: false,
    );
    final e = EntitlementProvider(store, billing: billing);
    expect(await e.restore(), isFalse);
    expect(e.isPro, isFalse);
  });

  test(
    'offline grace keeps a recently verified Pro when the store is down',
    () async {
      store.setEnum(Keys.entitlementTier, Entitlement.pro);
      store.setInt(
        Keys.entitlementVerifiedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      final e = EntitlementProvider(
        store,
        billing: _FakeBilling(reachable: false),
      );
      await settle();
      expect(e.isPro, isTrue);
    },
  );

  test(
    'confirmed not-Pro within grace keeps Pro (billing grace period)',
    () async {
      store.setEnum(Keys.entitlementTier, Entitlement.pro);
      store.setInt(
        Keys.entitlementVerifiedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      final e = EntitlementProvider(
        store,
        billing: _FakeBilling(pro: false, reachable: true),
      );
      await settle();
      expect(e.isPro, isTrue);
    },
  );

  test('confirmed not-Pro after grace expires revokes', () async {
    store.setEnum(Keys.entitlementTier, Entitlement.pro);
    store.setInt(
      Keys.entitlementVerifiedAt,
      DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
    );
    final e = EntitlementProvider(
      store,
      billing: _FakeBilling(pro: false, reachable: true),
    );
    await settle();
    expect(e.isPro, isFalse);
  });

  test('revocation never deletes the stored garage data', () async {
    store.setEnum(Keys.entitlementTier, Entitlement.pro);
    store.setString('garage.records', '[{"id":"r1"}]');
    final e = EntitlementProvider(
      store,
      billing: _FakeBilling(pro: false, reachable: true),
    );
    await settle();
    expect(e.isPro, isFalse);
    // Only the entitlement key changes; the garage is untouched.
    expect(store.getString('garage.records'), '[{"id":"r1"}]');
  });
}
