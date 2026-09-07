import 'package:flutter_test/flutter_test.dart';

import 'package:torque_obd2/core/config/revenuecat_config.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';

void main() {
  // Without SDK keys the service runs in unconfigured mode: every call is a
  // safe no-op and the paywall shows the bundled fallback prices. This is
  // exactly the behaviour a dev build (and every test) relies on.
  final svc = RevenueCatService(platform: const FakePlatform(isAndroid: true));

  test('starts unconfigured when no keys are set', () async {
    await svc.configure();
    expect(svc.configured, isFalse);
  });

  test('isPro returns null (unknown) when unconfigured', () async {
    expect(await svc.isPro(), isNull);
  });

  test('plans fall back to the spec prices in paywall order', () async {
    final plans = await svc.plans();
    expect(plans, hasLength(3));
    expect(plans[0].title, 'Weekly');
    expect(plans[0].price, RevenueCatConfig.fallbackPrices[0]);
    expect(plans[1].title, 'Monthly');
    expect(plans[2].title, 'Lifetime');
    // No store product behind a fallback plan.
    expect(plans.every((p) => p.product == null), isTrue);
  });

  test('purchase is unavailable when unconfigured', () async {
    final plans = await svc.plans();
    expect(await svc.purchase(plans[0]), PurchaseOutcome.unavailable);
  });

  test('restore is a no-op when unconfigured', () async {
    expect(await svc.restore(), isFalse);
  });
}
