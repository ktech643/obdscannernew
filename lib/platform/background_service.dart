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
class BackgroundService {
  BackgroundService({MethodChannel? channel, PlatformInfo? platform})
    : _channel = channel ?? const MethodChannel('ktc.torque/fgs'),
      _platform = platform ?? PlatformInfo.current;

  final MethodChannel _channel;
  final PlatformInfo _platform;

  /// Starts the foreground service for an active trip recording.
  Future<void> startRecording() => _invoke('startRecording');

  /// Stops the foreground service when the recording ends.
  Future<void> stopRecording() => _invoke('stopRecording');

  /// Whether the foreground service is currently up.
  Future<bool> isRunning() async {
    if (!_platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isForegroundServiceRunning') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// API 33+ requires POST_NOTIFICATIONS before a notification (and therefore
  /// a foreground service) can be shown. Below 33 this is always true.
  Future<bool> hasNotificationPermission() async {
    if (!_platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          true;
    } on PlatformException {
      return true;
    }
  }

  /// Raises the system POST_NOTIFICATIONS prompt. Returns the current state.
  Future<bool> requestNotificationPermission() async {
    if (!_platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          true;
    } on PlatformException {
      return true;
    }
  }

  /// The vendor battery-optimisation screen for this device, if one applies.
  Future<BatteryOptimization?> batteryOptimization() async {
    if (!_platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'batteryOptimizationIntent',
      );
      if (raw == null) return null;
      return BatteryOptimization.fromMap(raw);
    } on PlatformException {
      return null;
    }
  }

  /// Opens the vendor battery screen. True if a screen was opened.
  Future<bool> openBatterySettings() async {
    if (!_platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _invoke(String method) async {
    if (!_platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // The service is best-effort: recording continues without it.
    }
  }
}
