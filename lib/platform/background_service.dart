import 'package:flutter/services.dart';

import '../core/platform/platform_info.dart';
import 'battery_optimizer.dart';

/// Controls the Android `connectedDevice` foreground service and the OEM
/// battery-optimisation helper. SPEC §9.3.
///
/// The service exists only to keep the adapter connection alive while a trip
/// recording runs with the screen off. All methods are safe no-ops on iOS —
/// iOS holds the BLE link under `bluetooth-central` instead, which needs no
/// foreground service. Feature code never branches on platform directly; it
/// asks this object, which is also how a test can substitute an answer.
///
/// Nothing here throws. A missing native side — a test with no channel
/// handler, an engine MainActivity did not configure — raises
/// [MissingPluginException], which is not a [PlatformException]. Catching
/// only the latter, as this class did, lets it through: into the trip
/// recorder halfway through a start, or out of an unawaited stop as an
/// unhandled error. Both now answer as a refusal would.
class BackgroundService {
  BackgroundService({MethodChannel? channel, PlatformInfo? platform})
    : _channel = channel ?? const MethodChannel('ktc.torque/fgs'),
      _platform = platform ?? PlatformInfo.current;

  final MethodChannel _channel;
  final PlatformInfo _platform;

  /// Starts the foreground service for an active trip recording, and says
  /// whether it did. Android refuses a start from the background (API 31+)
  /// or without the `connectedDevice` prerequisites (API 34+); the plugin
  /// reports that as `fgs_start`, and false here tells the recorder to
  /// pause in the background rather than claim a recording nothing holds.
  /// True off Android, where nothing needs starting.
  Future<bool> startRecording() async {
    if (!_platform.isAndroid) return true;
    return _guard(false, () async {
      await _channel.invokeMethod<void>('startRecording');
      return true;
    });
  }

  /// Stops the foreground service when the recording ends.
  Future<void> stopRecording() =>
      _guard<void>(null, () => _channel.invokeMethod<void>('stopRecording'));

  /// Whether the foreground service is currently up.
  Future<bool> isRunning() => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('isForegroundServiceRunning') ??
        false,
  );

  /// API 33+ requires POST_NOTIFICATIONS before a notification (and therefore
  /// a foreground service) can be shown. Below 33 this is always true.
  Future<bool> hasNotificationPermission() => _guard(
    true,
    () async =>
        await _channel.invokeMethod<bool>('hasNotificationPermission') ?? true,
  );

  /// Raises the system POST_NOTIFICATIONS prompt. Returns the current state.
  Future<bool> requestNotificationPermission() => _guard(
    true,
    () async =>
        await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        true,
  );

  /// The vendor battery-optimisation screen for this device, if one applies.
  Future<BatteryOptimization?> batteryOptimization() => _guard(null, () async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'batteryOptimizationIntent',
    );
    return raw == null ? null : BatteryOptimization.fromMap(raw);
  });

  /// Opens the vendor battery screen. True if a screen was opened.
  Future<bool> openBatterySettings() => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('openBatterySettings') ?? false,
  );

  /// Runs one channel call on Android. Off Android, or when the native side
  /// is missing or refuses, the answer is [otherwise]: the service is
  /// best-effort, and recording continues without it.
  Future<T> _guard<T>(T otherwise, Future<T> Function() call) async {
    if (!_platform.isAndroid) return otherwise;
    try {
      return await call();
    } on PlatformException {
      return otherwise;
    } on MissingPluginException {
      return otherwise;
    }
  }
}
