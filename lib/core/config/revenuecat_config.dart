/// RevenueCat configuration. SPEC §8.3 (Option B).
///
/// Keys are passed at build time with `--dart-define` so they never sit in
/// source control:
///   --dart-define=REVENUECAT_IOS_API_KEY=...
///   --dart-define=REVENUECAT_ANDROID_API_KEY=...
///
/// When the keys are empty the app runs in an *unconfigured* mode: the paywall
/// shows the bundled fallback prices and purchases are granted locally, so the
/// app stays fully testable without store keys. That is a deliberate dev
/// posture — a release build must pass real keys.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  /// The entitlement that gates Pro. Every product (weekly/monthly/lifetime)
  /// grants this one entitlement.
  static const entitlementId = 'pro';

  /// The product identifiers per SPEC §7.1. Order matches the paywall's plan
  /// order (weekly, monthly, lifetime).
  static const productIds = <String>[
    'torque_pro_weekly',
    'torque_pro_monthly',
    'torque_pro_lifetime',
  ];

  /// Fallback prices shown when RevenueCat isn't configured. Mirrors §7.1.
  static const fallbackPrices = <String>[r'$4.99', r'$9.99', r'$49.99'];

  static const fallbackPeriods = <String>['/week', '/month', 'once'];

  /// The offline grace for a cached Pro entitlement, SPEC §7.5. A user who
  /// verified Pro but launches with no network keeps Pro for this long before
  /// degrading — never silently.
  static const offlineGrace = Duration(days: 7);
}
