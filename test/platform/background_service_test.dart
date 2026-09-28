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
    expect(await svc.startRecording(), isTrue);
    await svc.stopRecording();
    expect(calls.map((c) => c.method), ['startRecording', 'stopRecording']);
  });

  test(
    'recording is a no-op on iOS — no channel calls, nothing refused',
    () async {
      final svc = BackgroundService(
        channel: channel,
        platform: const FakePlatform(isAndroid: false),
      );
      // True: iOS holds the link under bluetooth-central, so there is no
      // service to be refused and nothing to pause for.
      expect(await svc.startRecording(), isTrue);
      await svc.stopRecording();
      expect(calls, isEmpty);
    },
  );

  test(
    '★ startRecording says false when Android refuses the service',
    () async {
      // What BackgroundPlugin sends when startForegroundService throws —
      // a start from the background on API 31+, or a missing connectedDevice
      // prerequisite on API 34+. Reading it as started, the recorder would
      // claim a background recording that nothing holds.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(
              code: 'fgs_start',
              message:
                  'startForegroundService() not allowed due to '
                  'mAllowStartForeground false',
            );
          });
      final svc = BackgroundService(
        channel: channel,
        platform: const FakePlatform(isAndroid: true),
      );
      expect(await svc.startRecording(), isFalse);
      expect(calls.map((c) => c.method), ['startRecording']);
    },
  );

  test(
    '★ no native side: every method answers as a refusal, none throws',
    () async {
      // No handler at all — a test, or an engine MainActivity never
      // configured — raises MissingPluginException, which is not a
      // PlatformException. It must not reach the recorder.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final svc = BackgroundService(
        channel: channel,
        platform: const FakePlatform(isAndroid: true),
      );
      expect(await svc.startRecording(), isFalse, reason: 'no service started');
      await expectLater(svc.stopRecording(), completes);
      expect(await svc.isRunning(), isFalse);
      expect(await svc.hasNotificationPermission(), isTrue);
      expect(await svc.requestNotificationPermission(), isTrue);
      expect(await svc.batteryOptimization(), isNull);
      expect(await svc.openBatterySettings(), isFalse);
    },
  );

  test('the platform refusing answers as before', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'refused');
        });
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: true),
    );
    await expectLater(svc.stopRecording(), completes);
    expect(await svc.isRunning(), isFalse);
    expect(await svc.hasNotificationPermission(), isTrue);
    expect(await svc.requestNotificationPermission(), isTrue);
    expect(await svc.batteryOptimization(), isNull);
    expect(await svc.openBatterySettings(), isFalse);
    expect(calls, hasLength(6));
  });

  test('off Android nothing reaches the channel', () async {
    final svc = BackgroundService(
      channel: channel,
      platform: const FakePlatform(isAndroid: false),
    );
    expect(await svc.isRunning(), isFalse);
    expect(await svc.hasNotificationPermission(), isTrue);
    expect(await svc.requestNotificationPermission(), isTrue);
    expect(await svc.openBatterySettings(), isFalse);
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
