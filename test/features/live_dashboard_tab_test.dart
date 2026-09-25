import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.6 — the unit toggles in Settings reach the Dashboard tab. The
/// screen itself is proven in dashboard_test.dart; this is the wiring, the
/// part that was missing: `SettingsProvider` stored °F and the tab never
/// asked.
void main() {
  late final ObdTrace trace;
  late Persistence store;

  setUpAll(() {
    trace = ObdTrace.parse(
      File('assets/traces/clean_can.obdtrace').readAsStringSync(),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<SettingsProvider> pumpTab(
    WidgetTester tester,
    LiveSession live,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LiveSession>.value(value: live),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: LiveDashboardTab()),
        ),
      ),
    );
    return settings;
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('timed out');
  }

  Future<void> quiesce(WidgetTester tester, LiveSession live) async {
    unawaited(live.session.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Finder inTile(String pid, String text) => find.descendant(
    of: find.byWidgetPredicate((w) => w is GaugeTile && w.spec.pid == pid),
    matching: find.text(text),
  );

  testWidgets('★ a unit chosen in Settings changes the gauges', (tester) async {
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(live.dispose);
    final settings = await pumpTab(tester, live);

    unawaited(live.session.connect(MockTransport(trace, speed: 100)));
    await pumpUntil(
      tester,
      () => live.session.bus.of('0105').value?.value != null,
    );
    await tester.pump();
    expect(inTile('0105', '89'), findsOneWidget);
    expect(inTile('0105', '°C'), findsOneWidget);
    expect(inTile('010D', 'km/h'), findsOneWidget);

    settings.setTemperature(TemperatureUnit.fahrenheit);
    await tester.pump();
    expect(inTile('0105', '192'), findsOneWidget);
    expect(inTile('0105', '°F'), findsOneWidget);
    expect(inTile('0105', '89'), findsNothing);

    settings.setDistance(DistanceUnit.mi);
    await tester.pump();
    expect(inTile('010D', 'mph'), findsOneWidget);
    expect(inTile('010D', '42'), findsOneWidget);

    await quiesce(tester, live);
  });

  testWidgets('★ no link, not known to be moving — on the live session', (
    tester,
  ) async {
    // The clock stops with the link, so the last Speed reading stayed
    // fresh against it after a reconnect gave up: Edit locked while parked.
    final live = LiveSession(session: ObdSession(timeScale: 0.05));
    addTearDown(live.dispose);
    live.session.bus.of('010D').value = PidSample(
      pid: '010D',
      value: 68,
      at: live.session.clock.value,
    );
    expect(live.session.isLive, isFalse);
    expect(live.speedGate.moving.value, isFalse);
  });
}
