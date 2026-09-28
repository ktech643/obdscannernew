import 'dart:io' show Platform;

/// The one place that asks which platform we're on.
///
/// Hard rule 12: feature code never branches on `Platform.isIOS`. It asks
/// this instead, which also means a test can substitute an answer.
abstract interface class PlatformInfo {
  bool get isAndroid;
  bool get isIOS;

  /// Bluetooth Classic SPP — the $8 ELM327 everyone already owns. Android
  /// reaches it over RFCOMM; iOS cannot, and no app can change that.
  bool get supportsBluetoothClassic;

  /// Whether BLE MTU can be negotiated up from the 20-byte default. Android
  /// yes; iOS negotiates it silently and rejects the call.
  bool get supportsMtuNegotiation;

  /// The slowest a trip recording may poll while the app is in the
  /// background: one cycle per interval, or null for no floor. iOS keeps a
  /// BLE link under `bluetooth-central` but kills an app that polls it at
  /// 10 Hz (§9.3), so it gets [iosBackgroundPollInterval]: 0.5 Hz, active
  /// recordings only (§5.3). Android's foreground service has no rate in
  /// the SPEC and keeps the adaptive one.
  Duration? get backgroundPollInterval;

  /// Whether recording past the screen needs a foreground service — and
  /// so a notification, and on API 33+ the permission to post one. Android
  /// yes (`connectedDevice`, §9.3); iOS holds the link without one.
  bool get backgroundNeedsService;

  /// Whether a Wi-Fi adapter's socket survives the app going to the
  /// background. iOS suspends it with the app — `bluetooth-central` covers
  /// Bluetooth only — so a recording over Wi-Fi pauses there instead of
  /// polling a dead socket. `TransportCapabilities.wifi` claims
  /// `supportsBackgroundHold` on every platform, which is why this exists.
  bool get holdsWifiInBackground;

  /// 0.5 Hz: one poll cycle every 2 s (§5.3, §9.3). Shared so the fake
  /// cannot drift from the device.
  static const iosBackgroundPollInterval = Duration(seconds: 2);

  static const PlatformInfo current = _RealPlatform();
}

class _RealPlatform implements PlatformInfo {
  const _RealPlatform();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get supportsBluetoothClassic => Platform.isAndroid;

  @override
  bool get supportsMtuNegotiation => Platform.isAndroid;

  @override
  Duration? get backgroundPollInterval =>
      Platform.isIOS ? PlatformInfo.iosBackgroundPollInterval : null;

  @override
  bool get backgroundNeedsService => Platform.isAndroid;

  @override
  bool get holdsWifiInBackground => !Platform.isIOS;
}

/// For tests and for previewing the other platform's UI.
class FakePlatform implements PlatformInfo {
  const FakePlatform({required this.isAndroid});

  @override
  final bool isAndroid;

  @override
  bool get isIOS => !isAndroid;

  @override
  bool get supportsBluetoothClassic => isAndroid;

  @override
  bool get supportsMtuNegotiation => isAndroid;

  @override
  Duration? get backgroundPollInterval =>
      isAndroid ? null : PlatformInfo.iosBackgroundPollInterval;

  @override
  bool get backgroundNeedsService => isAndroid;

  @override
  bool get holdsWifiInBackground => isAndroid;
}
