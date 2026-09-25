import 'package:purchases_flutter/purchases_flutter.dart';

/// One purchasable plan shown on the paywall.
///
/// When RevenueCat is configured, [product] is the real `StoreProduct` and
/// [price] comes from the store. When it isn't (dev mode, tests, or the
/// store could not be reached), the bundled fallback values from the spec
/// are used and [product] is null — and nothing about a trial is claimed.
class PlanOption {
  const PlanOption({
    required this.title,
    required this.price,
    required this.period,
    this.product,
    this.freeTrialDays,
  });

  /// Display name, e.g. "Weekly".
  final String title;

  /// Price string, e.g. "\$4.99".
  final String price;

  /// Period label, e.g. "/week" or "once".
  final String period;

  /// The store product to purchase, or null when there is none to buy.
  final StoreProduct? product;

  /// A free trial the store will actually give *this* user, in days — null
  /// when there is none, the user has had it, or the store did not say.
  /// SPEC §7.1 calls the trial optional and Play grants it once; an
  /// earlier paywall promised "3 days free" to everyone, which App Review
  /// guideline 3.1.2 rejects and which charged a returning user at once.
  final int? freeTrialDays;

  bool get fromStore => product != null;

  /// A short line for the primary action.
  String get actionLabel {
    final trial = freeTrialDays;
    if (trial != null) return 'Start $trial-day free trial';
    return switch (title.toLowerCase()) {
      'weekly' => 'Start weekly',
      'monthly' => 'Start monthly',
      'lifetime' => 'Get Pro forever',
      _ => 'Start Pro',
    };
  }
}
