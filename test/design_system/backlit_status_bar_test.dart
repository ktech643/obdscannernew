import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// The status bar's icons follow the ground under them. Found by running a
/// fresh install: onboarding paints the dark Part B ground to the top edge,
/// nothing set the overlay style, and the clock and battery drew dark on
/// dark.
///
/// Asserted on `SystemChrome.latestStyle` — what the framework actually
/// sends to the platform after compositing, from whichever annotated region
/// sits at the top of the screen — not on the widget tree.
void main() {
  setUp(() => SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark));

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Backlit(
          platform: const FakePlatform(isAndroid: false),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('★ a full-bleed Backlit screen gets light status-bar icons', (
    tester,
  ) async {
    await pump(tester, const SizedBox.expand());
    final style = SystemChrome.latestStyle;
    expect(style, isNotNull);
    expect(style!.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark, reason: 'iOS reads this');
  });

  testWidgets('a Backlit subtree below a light strip leaves the strip alone', (
    tester,
  ) async {
    // The tab shell's shape: a light strip under the status bar, the dark
    // Part B tab starting below it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: SizedBox(height: 60, width: double.infinity),
            ),
            Expanded(
              child: Backlit(
                platform: const FakePlatform(isAndroid: false),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.dark,
      reason: 'the strip owns the status bar, not the tab below it',
    );
  });
}
