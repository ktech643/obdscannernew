import '../core/platform/platform_info.dart';
import 'obd_transport.dart';

/// Which transports this device can use.
///
/// The answer differs by platform in one way that matters commercially: iOS
/// cannot reach Bluetooth Classic adapters at all, and no amount of pairing in
/// Settings changes that. The Connect screen's copy and the compatibility gate
/// both key off this.
class TransportRegistry {
  const TransportRegistry({this._platform = PlatformInfo.current});

  final PlatformInfo _platform;

  List<TransportKind> get available => [
    TransportKind.ble,
    if (_platform.supportsBluetoothClassic) TransportKind.spp,
    TransportKind.wifi,
  ];

  bool supports(TransportKind kind) => available.contains(kind);

  /// The sentence the onboarding adapter screen shows. Platform-branched
  /// because the truth is platform-branched.
  String get adapterGuidance => _platform.supportsBluetoothClassic
      ? 'Almost any ELM327 adapter works — Bluetooth, Bluetooth LE, or Wi-Fi.'
      : 'On iPhone it must be a Bluetooth LE or Wi-Fi adapter. The cheap '
            'Bluetooth ones sold for Android won\'t work — Apple gives apps '
            'no access to them.';

  /// The third check on the compatibility gate.
  String get compatibilityGateThirdCheck => _platform.supportsBluetoothClassic
      ? 'For a classic Bluetooth adapter, pair it in Android Settings first — '
            'the PIN is usually 1234 or 0000'
      : 'Your adapter supports Bluetooth LE or Wi-Fi';
}
