import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/features/settings/diagnostics_log_screen.dart';
import 'package:torque_obd2/features/settings/settings_screen.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/session/obd_session.dart';

/// SPEC §5.6 — Settings on the Part B design system.
void main() {
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<void> pump(
    WidgetTester tester, {
    LiveSession? live,
  }) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = live ?? LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(session.dispose);

    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<LiveSession>.value(value: session),
            ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
            ChangeNotifierProvider(
              create: (_) => EntitlementProvider(store),
            ),
            ChangeNotifierProvider(create: (_) => AccountProvider(store)),
          ],
          child: MaterialApp(
            theme: torqueTheme(),
            debugShowCheckedModeBanner: false,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title and every section', (tester) async {
    await pump(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Polling rate'), findsOneWidget);
    for (final section in ['Units', 'Connection', 'Subscription', 'Account', 'Your data']) {
      await tester.scrollUntilVisible(find.text(section), 100);
      expect(find.text(section), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Diagnostics log'), 100);
    expect(find.text('Diagnostics log'), findsOneWidget);
  });

  testWidgets('distance row opens a sheet and updates the unit', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Distance'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mi'), findsOneWidget);
    await tester.tap(find.text('mi'));
    await tester.pumpAndSettle();

    final settings = Provider.of<SettingsProvider>(
      tester.element(find.byType(SettingsScreen)),
      listen: false,
    );
    expect(settings.distance.label, 'mi');
    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('mi'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('haptics switch writes the preference', (tester) async {
    await pump(tester);
    expect(find.text('Haptics'), findsOneWidget);

    final settings = Provider.of<SettingsProvider>(
      tester.element(find.byType(SettingsScreen)),
      listen: false,
    );
    expect(settings.haptics, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Haptics'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.haptics, isFalse);
  });

  testWidgets('diagnostics log row opens the real log screen', (
    tester,
  ) async {
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    live.log.command('010C');
    await pump(tester, live: live);

    await tester.scrollUntilVisible(find.text('Diagnostics log'), 100);
    await tester.tap(find.text('Diagnostics log'));
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticsLogScreen), findsOneWidget);
    expect(find.text('1 events'), findsOneWidget);
    expect(find.text('010C'), findsOneWidget);
  });
}
