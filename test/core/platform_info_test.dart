import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';

/// Hard rule 12: the background answers come from [PlatformInfo], so a
/// test can ask as either phone. The fake derives them from `isAndroid`
/// the way the device does, or a recorder test on the fake would prove a
/// platform that does not exist.
void main() {
  test('iOS: 0.5 Hz in the background, no service, Wi-Fi does not hold', () {
    const ios = FakePlatform(isAndroid: false);
    expect(ios.backgroundPollInterval, const Duration(seconds: 2));
    expect(ios.backgroundNeedsService, isFalse);
    expect(ios.holdsWifiInBackground, isFalse);
  });

  test(
    'Android: the adaptive rate under a foreground service; Wi-Fi holds',
    () {
      const android = FakePlatform(isAndroid: true);
      expect(android.backgroundPollInterval, isNull);
      expect(android.backgroundNeedsService, isTrue);
      expect(android.holdsWifiInBackground, isTrue);
    },
  );

  test('the host answers the same way from its own isAndroid / isIOS', () {
    const p = PlatformInfo.current;
    expect(p.backgroundNeedsService, p.isAndroid);
    expect(p.holdsWifiInBackground, !p.isIOS);
    expect(
      p.backgroundPollInterval,
      p.isIOS ? PlatformInfo.iosBackgroundPollInterval : isNull,
    );
  });
}
