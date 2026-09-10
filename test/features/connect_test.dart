import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/connect/connect_screen.dart';
import 'package:torque_obd2/session/adapter_discovery.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';
import 'package:torque_obd2/transport/wifi_transport.dart';

/// Connect, driven end to end: pick an adapter from a scan, watch the seven
/// named steps, and end with a session that is genuinely talking to a
/// (recorded) car.
/// Replay timing note: `speed: 100` makes recorded replies arrive at a
/// hundredth of their real latency (a 900 ms NO DATA lands in 9 ms), while
/// `timeScale` scales the *timeouts* waiting for them. At 0.01 the deadline
/// was 12 ms against a 9 ms reply — a 3 ms margin, which any machine load
/// blows through, and the suite flaked. 0.05 keeps replay just as fast and
/// gives the deadline 60 ms, which is a margin rather than a coin toss.
void main() {
  // Read outside the widget tests: the fake clock never completes real I/O.
  late final Map<String, ObdTrace> traces;

  setUpAll(() {
    traces = {
      for (final name in const ['clean_can', 'adapter_unresponsive'])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  const good = Adapter(
    id: 'ble:AA:BB',
    name: 'OBDLink MX+',
    kind: AdapterKind.ble,
    rssi: -52,
    rating: AdapterRating.knownGood,
  );
  const clone = Adapter(
    id: 'ble:CC:DD',
    name: 'ELM327 v2.1',
    kind: AdapterKind.ble,
    rssi: -78,
    rating: AdapterRating.limited,
    detail: 'Firmware version is often faked; some commands may be missing',
  );
  const anonymous = Adapter(
    id: 'ble:EE:FF',
    name: '',
    kind: AdapterKind.ble,
    rssi: -60,
  );

  ObdSession newSession() {
    final s = ObdSession(timeScale: 0.05);
    addTearDown(s.dispose);
    return s;
  }

  FakeAdapterDiscovery newDiscovery({
    List<Adapter> results = const [],
    DiscoveryProblem problem = DiscoveryProblem.none,
    String trace = 'clean_can',
  }) {
    final d = FakeAdapterDiscovery(
      results: results,
      problemOnStart: problem,
      transportBuilder: (_) => MockTransport(traces[trace]!, speed: 100),
    );
    addTearDown(d.dispose);
    return d;
  }

  Future<void> pumpConnect(
    WidgetTester tester, {
    required ObdSession session,
    required AdapterDiscovery discovery,
    VoidCallback? onConnected,
    VoidCallback? onDemoMode,
    bool android = false,
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: FakePlatform(isAndroid: android),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: ConnectScreen(
                session: session,
                discovery: discovery,
                onConnected: onConnected,
                onDemoMode: onDemoMode,
                platform: FakePlatform(isAndroid: android),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String? reason,
  }) async {
    for (var i = 0; i < 400; i++) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for ${reason ?? 'condition'}');
  }

  Future<void> quiesce(WidgetTester tester, ObdSession session) async {
    unawaited(session.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('★ the whole flow', () {
    testWidgets('pick an adapter, see the steps, end up connected', (
      tester,
    ) async {
      final session = newSession();
      var connected = 0;
      await pumpConnect(
        tester,
        session: session,
        discovery: newDiscovery(results: const [good]),
        onConnected: () => connected++,
      );

      expect(find.text('OBDLink MX+'), findsOneWidget);
      expect(find.text('Known good'), findsOneWidget);

      await tester.tap(find.text('OBDLink MX+'));
      await tester.pump();

      // The seven steps, by name — not a spinner.
      expect(find.textContaining('Connecting to OBDLink MX+'), findsOneWidget);
      expect(find.byType(StepProgress), findsOneWidget);

      await pumpUntil(
        tester,
        () => session.isLive,
        reason: 'the car to answer',
      );
      await tester.pump();

      expect(connected, greaterThanOrEqualTo(1));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('ISO 15765-4 CAN 11-bit 500k'), findsOneWidget);
      expect(find.textContaining('14.2 V'), findsOneWidget);
      await quiesce(tester, session);
    });

    testWidgets('a failed connect says why and returns to the list', (
      tester,
    ) async {
      final session = newSession();
      await pumpConnect(
        tester,
        session: session,
        discovery: newDiscovery(
          results: const [good],
          trace: 'adapter_unresponsive',
        ),
      );

      await tester.tap(find.text('OBDLink MX+'));
      await pumpUntil(
        tester,
        () => session.lastError != null,
        reason: 'the handshake to give up',
      );
      await tester.pump();

      expect(find.text('That adapter did not answer'), findsOneWidget);
      expect(find.text('OBDLink MX+'), findsOneWidget, reason: 'list is back');
      await quiesce(tester, session);
    });
  });

  group('★ SPEC §9.1 — nothing is ever just a spinner', () {
    testWidgets('Bluetooth off says so, and does not spin', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(problem: DiscoveryProblem.bluetoothOff),
      );
      await tester.pump();
      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.byType(AdaptiveLoading), findsNothing);
    });

    testWidgets('a refused permission explains itself and can be re-asked', (
      tester,
    ) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(problem: DiscoveryProblem.bluetoothDenied),
      );
      await tester.pump();
      expect(find.text('Torque needs Bluetooth access'), findsOneWidget);
      expect(find.textContaining('Nothing is sent anywhere'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
    });

    testWidgets('the Android location trap is named before it bites', (
      tester,
    ) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(problem: DiscoveryProblem.locationOff),
        android: true,
      );
      await tester.pump();
      expect(find.text('Turn on location services'), findsOneWidget);
      expect(
        find.textContaining('never reads your location'),
        findsOneWidget,
        reason: 'the reason it is needed matters',
      );
    });
  });

  group('★ the compatibility gate', () {
    testWidgets('appears only after a full scan finds nothing', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(),
      );
      expect(find.text("Can't find your adapter?"), findsNothing);

      await tester.pump(ConnectScreen.gateAfter);
      await tester.pump();
      expect(find.text("Can't find your adapter?"), findsOneWidget);
    });

    testWidgets('iPhone names the classic-Bluetooth impossibility', (
      tester,
    ) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(),
      );
      await tester.pump(ConnectScreen.gateAfter);
      await tester.pump();
      expect(find.textContaining('cannot work'), findsOneWidget);
      expect(find.textContaining('Apple platform rule'), findsOneWidget);
    });

    testWidgets('Android points at Settings pairing, with the PIN', (
      tester,
    ) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(),
        android: true,
      );
      await tester.pump(ConnectScreen.gateAfter);
      await tester.pump();
      expect(find.textContaining('Android Settings'), findsOneWidget);
      expect(find.textContaining('1234 or 0000'), findsOneWidget);
    });

    testWidgets('it never appears when adapters were found', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(results: const [good]),
      );
      await tester.pump(ConnectScreen.gateAfter);
      await tester.pump();
      expect(find.text("Can't find your adapter?"), findsNothing);
    });
  });

  group('the list', () {
    testWidgets('★ named adapters sort above anonymous ones', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(results: const [anonymous, clone, good]),
      );
      final ys = [
        tester.getTopLeft(find.text('OBDLink MX+')).dy,
        tester.getTopLeft(find.text('ELM327 v2.1')).dy,
        tester.getTopLeft(find.text('Unnamed device')).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    });

    testWidgets('a limited adapter says what the limitation is', (
      tester,
    ) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(results: const [clone]),
      );
      expect(find.text('Limited'), findsOneWidget);
      expect(find.textContaining('often faked'), findsOneWidget);
    });

    testWidgets('an unrated adapter gets no badge at all', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(results: const [anonymous]),
      );
      expect(find.text('Known good'), findsNothing);
      expect(find.text('Limited'), findsNothing);
      expect(find.text('Unnamed device'), findsOneWidget);
    });

    testWidgets('every row is reachable by a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      var tapped = 0;
      final discovery = newDiscovery(results: const [good]);
      final session = newSession();
      await pumpConnect(
        tester,
        session: session,
        discovery: discovery,
        onConnected: () => tapped++,
      );
      final label = find.semantics.byLabel(
        RegExp('OBDLink MX\\+, Bluetooth LE, Known good'),
      );
      expect(label, findsOneWidget);
      tester.semantics.tap(label);
      await tester.pump();
      expect(find.byType(StepProgress), findsOneWidget);
      await quiesce(tester, session);
      handle.dispose();
    });
  });

  group('Demo Mode — SPEC §11.1', () {
    testWidgets('is offered when nothing is connected', (tester) async {
      var demo = 0;
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(),
        onDemoMode: () => demo++,
      );
      await tester.tap(find.text('Try it without an adapter'));
      expect(demo, 1);
    });
  });

  group('discovery', () {
    test('the compatibility list rates by name, and never guesses', () {
      expect(
        AdapterCompatibility.rate('OBDLink MX+').rating,
        AdapterRating.knownGood,
      );
      expect(
        AdapterCompatibility.rate('vGate iCar Pro BLE').rating,
        AdapterRating.knownGood,
      );
      expect(
        AdapterCompatibility.rate('ELM327 v2.1 clone').rating,
        AdapterRating.limited,
      );
      // Not on the list means unknown, not bad.
      expect(
        AdapterCompatibility.rate('Some New Adapter').rating,
        AdapterRating.unknown,
      );
      expect(AdapterCompatibility.rate('').rating, AdapterRating.unknown);
    });

    test('sorting puts known-good first, then signal, then anonymous', () {
      final sorted = sortForDisplay(const [anonymous, clone, good]);
      expect(sorted.map((a) => a.id), [good.id, clone.id, anonymous.id]);
    });

    test('an id round-trips to the right transport', () {
      const spp = Adapter(
        id: 'spp:00:1D:A5:68:98:8B',
        name: 'OBDII',
        kind: AdapterKind.spp,
      );
      expect(buildTransport(spp).id, 'spp:00:1D:A5:68:98:8B');

      const wifi = Adapter(
        id: 'wifi:192.168.0.10:35000',
        name: 'Wi-Fi adapter',
        kind: AdapterKind.wifi,
      );
      final t = buildTransport(wifi) as WifiTransport;
      expect(t.host, '192.168.0.10');
      expect(t.port, 35000);
    });
  });

  group('goldens', () {
    testWidgets('the adapter list', (tester) async {
      await pumpConnect(
        tester,
        session: newSession(),
        discovery: newDiscovery(results: const [good, clone, anonymous]),
        onDemoMode: () {},
      );
      await expectLater(
        find.byType(ConnectScreen),
        matchesGoldenFile('goldens/connect_list.png'),
      );
    });

    testWidgets('connected', (tester) async {
      final session = newSession();
      await pumpConnect(
        tester,
        session: session,
        discovery: newDiscovery(results: const [good]),
      );
      await tester.tap(find.text('OBDLink MX+'));
      await pumpUntil(tester, () => session.isLive);
      await tester.pump();
      await expectLater(
        find.byType(ConnectScreen),
        matchesGoldenFile('goldens/connect_connected.png'),
      );
      await quiesce(tester, session);
    });
  });
}
