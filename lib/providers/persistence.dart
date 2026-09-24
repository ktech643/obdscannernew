import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first storage.
///
/// Everything the app knows lives on the device: the garage, the layout, the
/// units, the account. Nothing here reaches a network — the privacy screen
/// promises exactly that, and this is the layer that has to keep the promise.
///
/// Reads are synchronous once [open] has completed, so providers can restore
/// their state in their constructors without any screen rendering a default
/// first and then flickering to the stored value.
class Persistence {
  Persistence._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Persistence> open() async =>
      Persistence._(await SharedPreferences.getInstance());

  bool? getBool(String key) => _prefs.getBool(key);
  String? getString(String key) => _prefs.getString(key);
  int? getInt(String key) => _prefs.getInt(key);
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  /// Reads a JSON object. Returns null rather than throwing on malformed
  /// content — a corrupt preference should cost the user a setting, not the
  /// launch.
  Map<String, Object?>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<Object?>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Writes are fire-and-forget. A dropped write costs a preference on the
  /// next launch; blocking a gauge update on disk I/O would cost correctness.
  void setBool(String key, bool value) => _prefs.setBool(key, value);
  void setString(String key, String value) => _prefs.setString(key, value);
  void setInt(String key, int value) => _prefs.setInt(key, value);
  void setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  void setJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));
  void remove(String key) => _prefs.remove(key);

  /// Backs "Delete all data" on the privacy screen.
  Future<void> clear() => _prefs.clear();

  /// Reads an enum by name, falling back when the stored name no longer
  /// exists — an enum value removed in an update must not brick a launch.
  E enumValue<E extends Enum>(String key, List<E> values, E fallback) {
    final name = _prefs.getString(key);
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  void setEnum(String key, Enum value) => _prefs.setString(key, value.name);
}

/// Every key the app stores, in one place so nothing collides and a wipe can
/// be reasoned about.
class Keys {
  Keys._();

  static const onboardingComplete = 'onboarding.complete';
  static const safetyAcknowledged = 'onboarding.safety';

  static const distanceUnit = 'settings.distance';
  static const temperatureUnit = 'settings.temperature';
  static const currency = 'settings.currency';
  static const pollingRate = 'settings.pollingRate';
  static const autoReconnect = 'settings.autoReconnect';
  static const keepScreenOn = 'settings.keepScreenOn';
  static const personalisedAds = 'settings.personalisedAds';
  static const maskVin = 'settings.maskVin';
  static const haptics = 'settings.haptics';

  static const entitlementTier = 'entitlement.tier';

  /// ms-epoch of the last store-verified Pro entitlement, for the §7.5
  /// 7-day offline grace.
  static const entitlementVerifiedAt = 'entitlement.verifiedAt';


  static const serviceRecords = 'garage.records';
  static const notificationsEnabled = 'garage.notifications';

  /// Layouts save per vehicle, so the layout keys are scoped by vehicle id.
  static String tileOrder(String vehicleId) => 'layout.$vehicleId.order';
  static String tileTypes(String vehicleId) => 'layout.$vehicleId.types';
  static String defaultTileType(String vehicleId) =>
      'layout.$vehicleId.defaultType';
}
