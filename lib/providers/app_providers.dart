import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// Tier, ads and the free-tier ceilings.
///
/// Pro carries a 7-day offline grace period — entitlement is never re-checked
/// against a network the app otherwise never uses.
class EntitlementProvider extends ChangeNotifier {
  Entitlement _tier = Entitlement.free;
  Entitlement get tier => _tier;
  bool get isPro => _tier == Entitlement.pro;

  ProSource _source = ProSource.direct;
  ProSource get source => _source;

  AdState _ads = AdState.banner;
  AdState get ads => _ads;

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

  void subscribe({ProSource source = ProSource.direct}) {
    _tier = Entitlement.pro;
    _source = source;
    _ads = AdState.none;
    notifyListeners();
  }

  void continueFreeWithAds() {
    _tier = Entitlement.free;
    _ads = AdState.banner;
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
  AccountStatus _status = AccountStatus.signedOut;
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

  bool _verified = false;
  bool get verified => _verified;

  SyncStatus _sync = SyncStatus.paused;
  SyncStatus get sync => _sync;

  int get vehicleCount => 1;
  int get recordCount => 9;
  int get scanCount => 14;
  int get signedInDevices => 2;

  int _resendSeconds = 42;
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
    notifyListeners();
  }

  void createAccount(String email) {
    _email = email;
    _status = AccountStatus.pendingVerification;
    notifyListeners();
  }

  void verify() {
    _verified = true;
    _status = AccountStatus.signedIn;
    notifyListeners();
  }

  void setDisplayName(String name) {
    _displayName = name;
    notifyListeners();
  }

  /// Signing out leaves everything on this iPhone. The garage, codes and
  /// receipts are local first, always.
  void signOut() {
    _status = AccountStatus.signedOut;
    notifyListeners();
  }

  /// Removes the email and synced copies from the server within 30 days. The
  /// local garage is untouched, and Pro belongs to the Apple ID.
  void deleteAccount() {
    _status = AccountStatus.signedOut;
    _sync = SyncStatus.off;
    notifyListeners();
  }

  void setSync(SyncStatus s) {
    _sync = s;
    notifyListeners();
  }
}

/// Units, connection preferences and privacy toggles.
class SettingsProvider extends ChangeNotifier {
  DistanceUnit _distance = DistanceUnit.km;
  DistanceUnit get distance => _distance;

  TemperatureUnit _temperature = TemperatureUnit.celsius;
  TemperatureUnit get temperature => _temperature;

  String _currency = 'GBP £';
  String get currency => _currency;

  String _pollingRate = 'Auto';
  String get pollingRate => _pollingRate;

  bool _autoReconnect = true;
  bool get autoReconnect => _autoReconnect;

  bool _keepScreenOn = true;
  bool get keepScreenOn => _keepScreenOn;

  /// Off by default. Turning it on asks iOS for tracking permission first.
  bool _personalisedAds = false;
  bool get personalisedAds => _personalisedAds;

  bool _maskVin = true;
  bool get maskVin => _maskVin;

  bool _lowPowerMode = false;
  bool get lowPowerMode => _lowPowerMode;

  bool _storageFull = false;
  bool get storageFull => _storageFull;

  /// Units are independent toggles, defaulted from Locale.
  void setDistance(DistanceUnit u) {
    _distance = u;
    notifyListeners();
  }

  void setTemperature(TemperatureUnit u) {
    _temperature = u;
    notifyListeners();
  }

  void setCurrency(String c) {
    _currency = c;
    notifyListeners();
  }

  void setPollingRate(String r) {
    _pollingRate = r;
    notifyListeners();
  }

  void setAutoReconnect(bool v) {
    _autoReconnect = v;
    notifyListeners();
  }

  void setKeepScreenOn(bool v) {
    _keepScreenOn = v;
    notifyListeners();
  }

  void setPersonalisedAds(bool v) {
    _personalisedAds = v;
    notifyListeners();
  }

  void setMaskVin(bool v) {
    _maskVin = v;
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
  int _step = 0;
  int get step => _step;
  int get totalSteps => 4;

  bool _safetyAcknowledged = false;
  bool get safetyAcknowledged => _safetyAcknowledged;

  bool _complete = false;
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
    notifyListeners();
  }

  void finish() {
    _complete = true;
    _drivingWarningShownToday = true;
    notifyListeners();
  }

  void skip() => finish();
}
