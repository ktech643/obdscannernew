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
}
