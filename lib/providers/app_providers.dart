import 'package:flutter/foundation.dart';

import '../core/config/revenuecat_config.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../monetization/plan_option.dart';
import '../monetization/revenuecat_service.dart';
import 'persistence.dart';

/// Tier, ads and the free-tier ceilings.
///
/// Pro carries a 7-day offline grace period — entitlement is never re-checked
/// against a network the app otherwise never uses.
class EntitlementProvider extends ChangeNotifier {
  EntitlementProvider(this._store, {RevenueCatService? billing})
    : _billing = billing ?? RevenueCatService() {
    _tier = _store.enumValue(
      Keys.entitlementTier,
      Entitlement.values,
      Entitlement.free,
    );
    _ads = isPro ? AdState.none : AdState.banner;
    _verifiedAt = _store.getInt(Keys.entitlementVerifiedAt);
    _init();
  }

  final Persistence _store;
  final RevenueCatService _billing;

  late Entitlement _tier;
  Entitlement get tier => _tier;
  bool get isPro => _tier == Entitlement.pro;

  /// ms-epoch of the last store-verified Pro grant; backs the 7-day grace.
  int? _verifiedAt;

  ProSource _source = ProSource.direct;
  ProSource get source => _source;

  AdState _ads = AdState.banner;
  AdState get ads => _ads;

  bool get billingConfigured => _billing.configured;

  List<PlanOption> _plans = const [];
  List<PlanOption> get plans => _plans;

  bool _purchaseInFlight = false;
  bool get purchaseInFlight => _purchaseInFlight;

  bool _restoring = false;
  bool get restoring => _restoring;

  PurchaseOutcome? _lastOutcome;
  PurchaseOutcome? get lastOutcome => _lastOutcome;

  /// Configures RevenueCat, loads the plans, and reconciles the entitlement
  /// against the store. Called once from the constructor; safe to fire and
  /// forget because every step degrades to a no-op when unconfigured.
  Future<void> _init() async {
    await _billing.configure();
    _plans = await _billing.plans();
    if (_disposed) return;
    _unlisten = _billing.addEntitlementListener(_onEntitlementChanged);
    final pro = await _billing.isPro();
    if (_disposed) return;
    if (pro == true) {
      _grantPro(ProSource.direct);
    } else if (pro == false) {
      // The store answered and there is no entitlement. Respect the offline
      // grace only when we *couldn't* reach the store (null); a confirmed no
      // means the cached Pro is stale.
      _revokeIfGraceExpired();
    }
    // pro == null (unreachable): keep the cached state — that IS the grace.
    notifyListeners();
  }

  /// Removes [_onEntitlementChanged] from the shared RevenueCat instance.
  /// "Delete all data" rebuilds every provider while the SDK lives on; a
  /// listener left behind would write the old tier into the emptied store
  /// and notify a disposed provider on the next customer-info change.
  void Function()? _unlisten;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _unlisten?.call();
    super.dispose();
  }

  /// Fired on every customer-info change: purchase, refund, revocation,
  /// billing retry. A `false` here is a real store answer, so it revokes.
  void _onEntitlementChanged(bool pro) {
    if (pro) {
      _grantPro(ProSource.direct);
    } else {
      _setTier(Entitlement.free); // never deletes user data
    }
    notifyListeners();
  }

  void _grantPro(ProSource source) {
    _source = source;
    _setTier(Entitlement.pro);
    _verifiedAt = DateTime.now().millisecondsSinceEpoch;
    _store.setInt(Keys.entitlementVerifiedAt, _verifiedAt!);
  }

  void _setTier(Entitlement t) {
    _tier = t;
    _ads = t == Entitlement.pro ? AdState.none : AdState.banner;
    _store.setEnum(Keys.entitlementTier, t);
  }

  void _revokeIfGraceExpired() {
    final v = _verifiedAt;
    if (v == null) {
      _setTier(Entitlement.free);
      return;
    }
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(v),
    );
    if (age > RevenueCatConfig.offlineGrace) {
      _setTier(Entitlement.free);
    }
  }

  /// Ads never cover a fault result, never interrupt a scan, and never appear
  /// while the car is moving. Callers pass the current context here rather
  /// than the widget deciding on its own.
  bool canShowBanner({
    required bool onFaultResult,
    required bool scanning,
    required double? speedKmh,
  }) {
    if (isPro) return false;
    if (onFaultResult || scanning) return false;
    if ((speedKmh ?? 0) > 5) return false;
    return _ads == AdState.banner;
  }

  bool _rewardedOffered = true;
  bool get rewardedOffered => _rewardedOffered && !isPro;

  static const priceWeekly = r'$4.99';
  static const priceMonthly = r'$9.99';
  static const priceLifetime = r'$49.99';

  int _selectedPlan = 0; // 0 weekly, 1 monthly, 2 lifetime
  int get selectedPlan => _selectedPlan;
  void selectPlan(int i) {
    _selectedPlan = i;
    notifyListeners();
  }

  /// Display helpers that prefer the store's real plan data and fall back to
  /// the bundled spec prices until RevenueCat reports in.
  String planPrice(int i) => i < _plans.length
      ? _plans[i].price
      : const [priceWeekly, priceMonthly, priceLifetime][i];

  String planPeriod(int i) => i < _plans.length
      ? _plans[i].period
      : const ['/week', '/month', 'once'][i];

  String planAction(int i) =>
      i < _plans.length ? _plans[i].actionLabel : 'Start Pro';

  /// Purchases the selected plan. In unconfigured (dev/test) mode this grants
  /// locally so the app stays testable without store keys.
  Future<PurchaseOutcome> subscribe() async {
    if (_purchaseInFlight) return PurchaseOutcome.failed;
    if (!_billing.configured) {
      _grantPro(ProSource.direct);
      _lastOutcome = PurchaseOutcome.success;
      notifyListeners();
      return PurchaseOutcome.success;
    }
    final plan = _selectedPlan < _plans.length ? _plans[_selectedPlan] : null;
    if (plan == null) {
      _lastOutcome = PurchaseOutcome.unavailable;
      notifyListeners();
      return PurchaseOutcome.unavailable;
    }
    // The service maps a null product to `unavailable`; the provider only
    // cares that a plan was selected.
    _purchaseInFlight = true;
    notifyListeners();
    final outcome = await _billing.purchase(plan);
    _purchaseInFlight = false;
    _lastOutcome = outcome;
    if (outcome == PurchaseOutcome.success) _grantPro(ProSource.direct);
    notifyListeners();
    return outcome;
  }

  /// Restores purchases against the store account. Must work with no app
  /// account — Play restores by Google account, iOS by Apple ID. SPEC §7.5.
  Future<bool> restore() async {
    if (_restoring) return false;
    _restoring = true;
    notifyListeners();
    final ok = await _billing.restore();
    final pro = await _billing.isPro();
    _restoring = false;
    if (ok && pro == true) _grantPro(ProSource.direct);
    notifyListeners();
    return ok && pro == true;
  }

  /// Opens the store's manage-subscription sheet.
  Future<void> manageSubscription() => _billing.manageSubscription();

  void continueFreeWithAds() {
    _setTier(Entitlement.free);
    notifyListeners();
  }

  void dismissRewardedOffer() {
    _rewardedOffered = false;
    notifyListeners();
  }

  void setAdState(AdState s) {
    _ads = s;
    notifyListeners();
  }
}

/// Sign-in, verification and sync. The app is fully usable signed out —
/// reading codes and live data needs no account, no sign-in and no internet.
class AccountProvider extends ChangeNotifier {
  AccountProvider(this._store) {
    _status = _store.enumValue(
      Keys.accountStatus,
      AccountStatus.values,
      AccountStatus.signedOut,
    );
    _email = _store.getString(Keys.accountEmail) ?? _email;
    _displayName = _store.getString(Keys.accountName) ?? _displayName;
    _verified = _store.getBool(Keys.accountVerified) ?? false;
  }

  final Persistence _store;

  late AccountStatus _status;
  AccountStatus get status => _status;

  String _email = 'muzaffar@ktechclans.com';
  String get email => _email;

  String _displayName = 'Muzaffar Ali';
  String get displayName => _displayName;

  String get initials => _displayName
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  late bool _verified;
  bool get verified => _verified;

  void _persist() {
    _store.setEnum(Keys.accountStatus, _status);
    _store.setString(Keys.accountEmail, _email);
    _store.setString(Keys.accountName, _displayName);
    _store.setBool(Keys.accountVerified, _verified);
  }

  SyncStatus _sync = SyncStatus.paused;
  SyncStatus get sync => _sync;

  int get vehicleCount => 1;
  int get recordCount => 9;
  int get scanCount => 14;
  int get signedInDevices => 2;

  final int _resendSeconds = 42;
  int get resendSeconds => _resendSeconds;

  /// Password rules, checked live under the field.
  static List<({String rule, bool Function(String) test})> passwordRules = [
    (rule: 'At least 10 characters', test: (p) => p.length >= 10),
    (
      rule: 'Upper and lower case',
      test: (p) => p.contains(RegExp('[a-z]')) && p.contains(RegExp('[A-Z]')),
    ),
    (rule: 'One symbol', test: (p) => p.contains(RegExp(r'[^A-Za-z0-9]'))),
  ];

  static int strengthOf(String p) {
    var score = 0;
    if (p.length >= 10) score++;
    if (p.contains(RegExp('[a-z]')) && p.contains(RegExp('[A-Z]'))) score++;
    if (p.contains(RegExp('[0-9]'))) score++;
    if (p.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score;
  }

  static String strengthLabel(int score) => switch (score) {
    0 || 1 => 'Weak',
    2 => 'Fair',
    3 => 'Strong',
    _ => 'Very strong',
  };

  void signIn({String? email}) {
    if (email != null && email.isNotEmpty) _email = email;
    _status = AccountStatus.signedIn;
    _verified = true;
    _persist();
    notifyListeners();
  }

  void createAccount(String email) {
    _email = email;
    _status = AccountStatus.pendingVerification;
    _persist();
    notifyListeners();
  }

  void verify() {
    _verified = true;
    _status = AccountStatus.signedIn;
    _persist();
    notifyListeners();
  }

  void setDisplayName(String name) {
    _displayName = name;
    _persist();
    notifyListeners();
  }

  /// Signing out leaves everything on this iPhone. The garage, codes and
  /// receipts are local first, always.
  void signOut() {
    _status = AccountStatus.signedOut;
    _persist();
    notifyListeners();
  }

  /// Removes the email and synced copies from the server within 30 days. The
  /// local garage is untouched, and Pro belongs to the Apple ID.
  void deleteAccount() {
    _status = AccountStatus.signedOut;
    _sync = SyncStatus.off;
    _verified = false;
    _persist();
    notifyListeners();
  }

  void setSync(SyncStatus s) {
    _sync = s;
    notifyListeners();
  }
}

/// Units, connection preferences and privacy toggles.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._store) {
    // Units default from the locale on first run, then follow the user.
    _distance = _store.enumValue(
      Keys.distanceUnit,
      DistanceUnit.values,
      DistanceUnit.km,
    );
    _temperature = _store.enumValue(
      Keys.temperatureUnit,
      TemperatureUnit.values,
      TemperatureUnit.celsius,
    );
    _currency = _store.getString(Keys.currency) ?? _currency;
    _pollingRate = _store.getString(Keys.pollingRate) ?? _pollingRate;
    _autoReconnect = _store.getBool(Keys.autoReconnect) ?? true;
    _keepScreenOn = _store.getBool(Keys.keepScreenOn) ?? true;
    _personalisedAds = _store.getBool(Keys.personalisedAds) ?? false;
    _maskVin = _store.getBool(Keys.maskVin) ?? true;
    _haptics = _store.getBool(Keys.haptics) ?? true;
  }

  final Persistence _store;

  late DistanceUnit _distance;
  DistanceUnit get distance => _distance;

  late TemperatureUnit _temperature;
  TemperatureUnit get temperature => _temperature;

  String _currency = 'GBP £';
  String get currency => _currency;

  String _pollingRate = 'Auto';
  String get pollingRate => _pollingRate;

  late bool _autoReconnect;
  bool get autoReconnect => _autoReconnect;

  late bool _keepScreenOn;
  bool get keepScreenOn => _keepScreenOn;

  /// Off by default. Turning it on asks iOS for tracking permission first.
  late bool _personalisedAds;
  bool get personalisedAds => _personalisedAds;

  late bool _maskVin;
  bool get maskVin => _maskVin;

  late bool _haptics;
  bool get haptics => _haptics;

  /// The choices offered by the polling-rate row. "Auto" lets the app drop
  /// the rate when the adapter is slow, which is the honest default.
  static const pollingRates = ['Auto', '10 Hz', '8 Hz', '4 Hz', '2 Hz'];

  static const currencies = ['GBP £', 'USD \$', 'EUR €', 'JPY ¥', 'AUD \$'];

  bool _lowPowerMode = false;
  bool get lowPowerMode => _lowPowerMode;

  bool _storageFull = false;
  bool get storageFull => _storageFull;

  /// Units are independent toggles, defaulted from Locale.
  void setDistance(DistanceUnit u) {
    _distance = u;
    _store.setEnum(Keys.distanceUnit, u);
    notifyListeners();
  }

  void setTemperature(TemperatureUnit u) {
    _temperature = u;
    _store.setEnum(Keys.temperatureUnit, u);
    notifyListeners();
  }

  void setCurrency(String c) {
    _currency = c;
    _store.setString(Keys.currency, c);
    notifyListeners();
  }

  void setPollingRate(String r) {
    _pollingRate = r;
    _store.setString(Keys.pollingRate, r);
    notifyListeners();
  }

  void setAutoReconnect(bool v) {
    _autoReconnect = v;
    _store.setBool(Keys.autoReconnect, v);
    notifyListeners();
  }

  void setKeepScreenOn(bool v) {
    _keepScreenOn = v;
    _store.setBool(Keys.keepScreenOn, v);
    notifyListeners();
  }

  void setPersonalisedAds(bool v) {
    _personalisedAds = v;
    _store.setBool(Keys.personalisedAds, v);
    notifyListeners();
  }

  void setMaskVin(bool v) {
    _maskVin = v;
    _store.setBool(Keys.maskVin, v);
    notifyListeners();
  }

  void setHaptics(bool v) {
    _haptics = v;
    _store.setBool(Keys.haptics, v);
    notifyListeners();
  }

  void setLowPower(bool v) {
    _lowPowerMode = v;
    notifyListeners();
  }

  void setStorageFull(bool v) {
    _storageFull = v;
    notifyListeners();
  }

  /// The last 500 things Torque said to the adapter and heard back. This is
  /// the whole support system — nothing is uploaded unless the user sends it.
  static const logEvents = <LogEvent>[
    LogEvent(time: '09:41:02.1', frame: '010C', outbound: true),
    LogEvent(
      time: '09:41:02.2',
      frame: '41 0C 26 C0 → 2,480 rpm',
      ms: 118,
      outbound: false,
    ),
    LogEvent(time: '09:41:02.3', frame: '0105', outbound: true),
    LogEvent(
      time: '09:41:02.4',
      frame: '41 05 81 → 89 °C',
      ms: 104,
      outbound: false,
    ),
    LogEvent(
      time: '09:41:02.6',
      frame: 'NO DATA · 015C dropped (3/3)',
      ms: 1204,
      outbound: false,
      tone: Tone.caution,
    ),
    LogEvent(time: '09:41:03.9', frame: '010C0D11 · batch', outbound: true),
    LogEvent(
      time: '09:41:04.0',
      frame: '41 0C 26 C0 0D 44 11 1F',
      ms: 126,
      outbound: false,
    ),
    LogEvent(
      time: '09:41:06.2',
      frame: 'BUFFER FULL · rate halved to 4 Hz',
      outbound: false,
      tone: Tone.caution,
    ),
    LogEvent(time: '09:41:06.4', frame: 'ATWS', outbound: true),
    LogEvent(
      time: '09:41:07.1',
      frame: 'ELM327 v1.5 · resumed',
      ms: 712,
      outbound: false,
    ),
  ];
}

/// Onboarding progress and the non-skippable safety acknowledgement.
class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this._store) {
    _complete = _store.getBool(Keys.onboardingComplete) ?? false;
    _safetyAcknowledged = _store.getBool(Keys.safetyAcknowledged) ?? false;
  }

  final Persistence _store;

  int _step = 0;
  int get step => _step;
  int get totalSteps => 4;

  late bool _safetyAcknowledged;
  bool get safetyAcknowledged => _safetyAcknowledged;

  late bool _complete;
  bool get complete => _complete;

  /// The driving warning appears at onboarding and on the first Dashboard
  /// session of each day.
  bool _drivingWarningShownToday = false;
  bool get drivingWarningShownToday => _drivingWarningShownToday;

  void next() {
    if (_step < totalSteps - 1) _step++;
    notifyListeners();
  }

  void back() {
    if (_step > 0) _step--;
    notifyListeners();
  }

  void goTo(int i) {
    _step = i.clamp(0, totalSteps - 1);
    notifyListeners();
  }

  void setSafetyAcknowledged(bool v) {
    _safetyAcknowledged = v;
    _store.setBool(Keys.safetyAcknowledged, v);
    notifyListeners();
  }

  void finish() {
    _complete = true;
    _drivingWarningShownToday = true;
    _store.setBool(Keys.onboardingComplete, true);
    notifyListeners();
  }

  /// Backs "Delete all data" — the next launch starts at first run again.
  void reset() {
    _complete = false;
    _safetyAcknowledged = false;
    _step = 0;
    _store.setBool(Keys.onboardingComplete, false);
    _store.setBool(Keys.safetyAcknowledged, false);
    notifyListeners();
  }

  void skip() => finish();
}
