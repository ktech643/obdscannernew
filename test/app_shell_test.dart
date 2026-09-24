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
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/providers/persistence.dart';

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

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
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

  testWidgets('★ the shell is Part B chrome, opening on the Dashboard', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AdaptiveTabBar), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    for (final tab in AppShellTabs.labels) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    // No debug strip, no Industry bar.
    expect(find.text('STATES'), findsNothing);
    expect(find.byType(Container).evaluate().where((e) {
      final c = e.widget as Container;
      return c.decoration is BoxDecoration &&
          (c.decoration! as BoxDecoration).color == const Color(0xFFF2F2F5);
    }), isEmpty, reason: 'nothing painted in the old light neutral');
    await drain(tester);
  });

  testWidgets('the status bar is claimed light over the dark ground', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.light,
    );
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
}
