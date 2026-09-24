import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/platform/screen_wake.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.6 "Keep screen on" — the setting reaches the platform, and only
/// while a link is live. An earlier version stored the preference and
/// nothing read it.
///
/// Plain tests, not `testWidgets`: connecting a replayed car needs the real
/// clock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ktc.torque/screen');

  /// Every `setKeepAwake` argument the platform side would have received.
  List<Object?> platformHeard() {
    final calls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setKeepAwake');
      calls.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  MockTransport car() => MockTransport(
    ObdTrace.parse(
      File('assets/traces/headers_can.obdtrace').readAsStringSync(),
    ),
    speed: 100,
  );

  /// The channel answers on a later microtask.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('ScreenWake', () {
    test('tells the platform only when the answer changes', () async {
      final heard = platformHeard();
      final wake = ScreenWake(channel: channel);
      await wake.set(true);
      await wake.set(true);
      await wake.set(false);
      await wake.set(false);
      await wake.set(true);
      expect(heard, [true, false, true]);
      expect(wake.isAwake, isTrue);
    });

    test('a missing native side is a no-op, not an error', () async {
      final wake = ScreenWake(channel: channel);
      await expectLater(wake.set(true), completes);
    });
  });

  group('★ the live session', () {
    test('★ the setting holds the screen while the link is live, and lets go '
        'when it drops', () async {
      final heard = platformHeard();
      final live = LiveSession(
        session: ObdSession(timeScale: 0.05),
        screenWake: ScreenWake(channel: channel),
      );
      addTearDown(live.dispose);
      live.applySettings(
        autoReconnect: true,
        haptics: true,
        keepScreenOn: true,
      );
      await settle();
      expect(heard, isEmpty, reason: 'no link, nothing to keep awake for');

      expect(await live.session.connect(car()), isTrue);
      live.session.setVisible({});
      await settle();
      expect(heard, [true]);

      await live.session.disconnect();
      await settle();
      expect(heard, [true, false]);
    });

    test(
      'turning it off mid-link lets the screen sleep; on again holds it',
      () async {
        final heard = platformHeard();
        final live = LiveSession(
          session: ObdSession(timeScale: 0.05),
          screenWake: ScreenWake(channel: channel),
        );
        addTearDown(live.dispose);
        expect(await live.session.connect(car()), isTrue);
        live.session.setVisible({});
        await settle();
        expect(heard, [true]);

        live.applySettings(
          autoReconnect: true,
          haptics: true,
          keepScreenOn: false,
        );
        await settle();
        expect(heard, [true, false]);

        live.applySettings(
          autoReconnect: true,
          haptics: true,
          keepScreenOn: true,
        );
        await settle();
        expect(heard, [true, false, true]);
      },
    );

    test('with the setting off, a live link never holds the screen', () async {
      final heard = platformHeard();
      final live = LiveSession(
        session: ObdSession(timeScale: 0.05),
        screenWake: ScreenWake(channel: channel),
      );
      addTearDown(live.dispose);
      live.applySettings(
        autoReconnect: true,
        haptics: true,
        keepScreenOn: false,
      );
      expect(await live.session.connect(car()), isTrue);
      live.session.setVisible({});
      await settle();
      expect(heard, isEmpty);
      await live.session.disconnect();
    });

    test(
      're-applying unchanged settings every frame costs no platform call',
      () async {
        final heard = platformHeard();
        final live = LiveSession(
          session: ObdSession(timeScale: 0.05),
          screenWake: ScreenWake(channel: channel),
        );
        addTearDown(live.dispose);
        expect(await live.session.connect(car()), isTrue);
        live.session.setVisible({});
        for (var i = 0; i < 60; i++) {
          live.applySettings(
            autoReconnect: true,
            haptics: true,
            keepScreenOn: true,
          );
        }
        await settle();
        expect(heard, [true]);
        await live.session.disconnect();
      },
    );
  });
}
