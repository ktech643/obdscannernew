import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/session/obd_session.dart';

/// SPEC §5.6 — the connection settings a user sets on the (still Industry)
/// Settings screen actually reach the live session, rather than sitting in
/// `SharedPreferences` unread.
void main() {
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<void> pump(WidgetTester tester, LiveSession live) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LiveSession>.value(value: live),
          ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
        ],
        child: const MaterialApp(
          home: LiveSettingsSync(child: SizedBox.shrink()),
        ),
      ),
    );
  }

  testWidgets('★ auto-reconnect off reaches the session', (tester) async {
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(live.dispose);
    expect(live.session.autoReconnect, isTrue, reason: 'the honest default');

    await pump(tester, live);
    expect(live.session.autoReconnect, isTrue, reason: 'still on by default');

    Provider.of<SettingsProvider>(
      tester.element(find.byType(SizedBox)),
      listen: false,
    ).setAutoReconnect(false);
    await tester.pump();
    expect(live.session.autoReconnect, isFalse);
  });

  testWidgets('★ a polling-rate choice caps the scheduler; Auto lifts it', (
    tester,
  ) async {
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(live.dispose);

    await pump(tester, live);
    expect(live.session.scheduler.maxHz, isNull, reason: 'Auto by default');

    final settings = Provider.of<SettingsProvider>(
      tester.element(find.byType(SizedBox)),
      listen: false,
    );
    settings.setPollingRate('4 Hz');
    await tester.pump();
    expect(live.session.scheduler.maxHz, 4);

    settings.setPollingRate('Auto');
    await tester.pump();
    expect(live.session.scheduler.maxHz, isNull);
  });

  testWidgets('★ haptics off reaches AdaptiveHaptics.enabled', (tester) async {
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(live.dispose);

    await pump(tester, live);
    expect(AdaptiveHaptics.enabled, isTrue, reason: 'the honest default');

    final settings = Provider.of<SettingsProvider>(
      tester.element(find.byType(SizedBox)),
      listen: false,
    );
    settings.setHaptics(false);
    await tester.pump();
    expect(AdaptiveHaptics.enabled, isFalse);

    // Reset so later tests are not surprised.
    addTearDown(() => AdaptiveHaptics.enabled = true);
  });
}
