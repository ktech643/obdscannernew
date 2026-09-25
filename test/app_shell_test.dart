import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/dashboard/dashboard_screen.dart';
import 'package:torque_obd2/features/garage/garage_screen.dart';
import 'package:torque_obd2/features/settings/settings_screen.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/widgets/chrome.dart' show AppTabBar;

/// The tab shell on Part B: the last piece of chrome that was still the
/// older design under every rebuilt screen.
void main() {
  late Persistence store;
  late AppDatabase db;
  late Directory docs;
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.onboardingComplete: true,
      Keys.safetyAcknowledged: true,
    });
    store = await Persistence.open();
    db = AppDatabase(NativeDatabase.memory());
    // The shell builds LiveSession, whose garage watches drift streams;
    // a test that fails before the drain below would leave close() waiting
    // on the fake clock.
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    docs = Directory.systemTemp.createTempSync('torque_shell_');
    addTearDown(() => docs.deleteSync(recursive: true));
    temp = Directory.systemTemp.createTempSync('torque_shell_tmp_');
    addTearDown(() => temp.deleteSync(recursive: true));
  });

  /// A phone with a notch: the status bar is 47 pt tall, the home
  /// indicator 34. With the padding left at zero — as an earlier version of
  /// this test did — the status bar sits *inside* the tabs' own regions and
  /// nothing the shell does under it can be seen.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TorqueApp(
        store: store,
        billing: RevenueCatService(),
        db: db,
        docsDir: docs,
        tempDir: temp,
      ),
    );
    await tester.pump();
  }

  /// Unmounts and elapses the fake clock so drift's stream-cancel timers
  /// fire inside the test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The box painted at the very top of the screen — under the status bar.
  Color? groundAtTop(WidgetTester tester) {
    for (final e in find.byType(ColoredBox).evaluate()) {
      final box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final color = (e.widget as ColoredBox).color;
      // Transparent boxes (a barrier, a spacer) paint nothing.
      if (color.a == 0) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= 0 && box.size.height > 47) return color;
    }
    return null;
  }

  NavigatorState tabNavigator(WidgetTester tester, Type screen) =>
      Navigator.of(tester.element(find.byType(screen, skipOffstage: false)));

  testWidgets('★ the shell is Part B chrome, opening on the Dashboard', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AdaptiveTabBar), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'the Industry bar');
    expect(find.byType(DashboardScreen), findsOneWidget);
    for (final tab in AppShellTabs.labels) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    // The strip under the status bar is the Part B ground, not the light
    // root Material the Industry shell left showing there.
    expect(groundAtTop(tester), TorqueTokens.dark.surfaceDeep);
    await drain(tester);
  });

  testWidgets('★ the status bar is claimed light over the dark ground', (
    tester,
  ) async {
    // Start from dark, so a light answer can only come from this app.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    await tester.pump();
    await pumpApp(tester);
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    await drain(tester);
  });

  testWidgets('tapping a tab switches it, with no animation to wait for', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Garage'));
    await tester.pump();
    expect(find.byType(GarageScreen), findsOneWidget);
    // Offstage in the IndexedStack, but still there: the finder must be
    // told to look.
    expect(
      find.byType(DashboardScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'kept alive',
    );
    await drain(tester);
  });

  testWidgets('★ the tab bar fits at text scale 2.0 on a 320 pt phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull, reason: 'no overflow (AC-16)');
    await drain(tester);
  });

  testWidgets('★ Android back: a tab root goes to the Dashboard, and the '
      'Dashboard leaves the app', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpApp(tester);
    await tester.tap(find.text('Garage'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byType(DashboardScreen),
      findsOneWidget,
      reason: 'to Dashboard',
    );
    expect(calls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, contains('SystemNavigator.pop'), reason: 'out of the app');
    await drain(tester);
  });

  testWidgets('★ neither back nor a re-tapped tab removes a route that '
      'refuses to go', (tester) async {
    // The Delete-all sheet while it erases is such a route; the review
    // found the shell called pop and popUntil, which ignore the refusal.
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    tabNavigator(tester, SettingsScreen).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            const PopScope(canPop: false, child: Center(child: Text('Locked'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Locked'), findsOneWidget);

    // The stack is the claim: a page mid-exit is still on screen for a
    // frame, so "Locked" alone would pass while it was being removed.
    final nav = tabNavigator(tester, SettingsScreen);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nav.canPop(), isTrue, reason: 'back left it');
    expect(find.text('Locked'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nav.canPop(), isTrue, reason: 'a re-tapped tab left it');
    expect(find.text('Locked'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('★ high contrast: the tabs and the ground under the status '
      'bar are one colour', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    expect(groundAtTop(tester), TorqueTokens.highContrast.surfaceDeep);
    final grounds = find
        .byType(ColoredBox)
        .evaluate()
        .map((e) => (e.widget as ColoredBox).color)
        .toSet();
    expect(
      grounds.contains(TorqueTokens.dark.surfaceDeep),
      isFalse,
      reason: 'no Backlit still on the normal tokens',
    );
    await drain(tester);
  });
}
