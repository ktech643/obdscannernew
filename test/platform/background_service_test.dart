import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/platform/background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ktc.torque/fgs');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isForegroundServiceRunning':
          return true;
        case 'hasNotificationPermission':
          return true;
        case 'batteryOptimizationIntent':
          return {
            'package': 'com.miui.securitycenter',
            'label': 'Xiaomi — Autostart',
            'component':
                'com.miui.securitycenter/'
                'com.miui.permcenter.autostart.AutoStartManagementActivity',
            'action': null,
          };
        case 'openBatterySettings':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start/stop recording invoke the right methods on Android', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    await svc.startRecording();
    await svc.stopRecording();
    expect(calls.map((c) => c.method), ['startRecording', 'stopRecording']);
  });

  test('recording is a no-op on iOS — no channel calls', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: false),
    );
    await svc.startRecording();
    await svc.stopRecording();
    expect(calls, isEmpty);
  });

  test('isRunning reflects the native value', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    expect(await svc.isRunning(), isTrue);
  });

  test('hasNotificationPermission is always granted below API 33', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    expect(await svc.hasNotificationPermission(), isTrue);
  });

  test('batteryOptimization decodes the vendor intent', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    final b = await svc.batteryOptimization();
    expect(b, isNotNull);
    expect(b!.package, 'com.miui.securitycenter');
    expect(b.label, contains('Xiaomi'));
    expect(b.component, contains('AutoStartManagementActivity'));
  });

  test('batteryOptimization is null on iOS', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: false),
    );
    expect(await svc.batteryOptimization(), isNull);
  });

  test('openBatterySettings returns true on Android', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    expect(await svc.openBatterySettings(), isTrue);
  });
}
