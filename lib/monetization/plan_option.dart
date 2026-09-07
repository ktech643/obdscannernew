import 'package:purchases_flutter/purchases_flutter.dart';

/// One purchasable plan shown on the paywall.
///
/// When RevenueCat is configured, [product] is the real `StoreProduct` and
/// [price] comes from the store. When it isn't (dev mode, tests), the bundled
/// fallback values from the spec are used and [product] is null.
class PlanOption {
  const PlanOption({
    required this.title,
    required this.price,
    required this.period,
    this.product,
  });

  /// Display name, e.g. "Weekly".
  final String title;

  /// Price string, e.g. "\$4.99".
  final String price;

  /// Period label, e.g. "/week" or "once".
  final String period;

  /// The store product to purchase, or null in unconfigured mode.
  final StoreProduct? product;

  /// A short line for the primary action, e.g. "Start 3-day free trial".
  String get actionLabel => switch (title.toLowerCase()) {
    'weekly' => 'Start 3-day free trial',
    'monthly' => 'Start monthly',
    'lifetime' => 'Get Pro forever',
    _ => 'Start Pro',
  };
}
