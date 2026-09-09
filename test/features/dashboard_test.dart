import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/dashboard/dashboard_screen.dart';
import 'package:torque_obd2/features/session_banner.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// The Dashboard driven by a real [ObdSession] replaying a recorded car —
/// no fake providers, no stubbed values. What the tiles show is what the
/// protocol engine decoded off the wire.
void main() {
  // Traces are read once, outside the widget tests. Inside `testWidgets`
  // the clock is fake and real file I/O never completes, so loading a
  // fixture there hangs the test instead of failing it.
  late final Map<String, ObdTrace> traces;

  setUpAll(() {
    traces = {
      for (final name in const [
        'clean_can',
        'headers_can',
        'ev_minimal',
        'adapter_unresponsive',
      ])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  MockTransport transportFor(String name) =>
      MockTransport(traces[name]!, speed: 100);

  /// Teardown is deliberately synchronous. Inside `testWidgets` the clock
  /// is fake and only `pump` advances it, so awaiting anything the session
  /// does — connect, disconnect — deadlocks the test rather than failing
  /// it. Everything below drives the session by pumping and observing.
  ObdSession newSession() {
    final s = ObdSession(timeScale: 0.01);
    addTearDown(s.dispose);
    return s;
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    ObdSession session, {
    List<String>? layout,
    VoidCallback? onConnect,
    Size size = const Size(390, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: DashboardScreen(
                session: session,
                layout: layout,
                onConnect: onConnect,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shuts the session down and pumps until nothing is left scheduled.
  /// The poll loop's own delay and the replay's reply timer both outlive
  /// the test body otherwise, and flutter_test fails the test for it.
  Future<void> quiesce(WidgetTester tester, ObdSession session) async {
    unawaited(session.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Pumps until [condition] or the deadline; replay is fast, so a failure
  /// still surfaces quickly.
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

  group('★ live values off the wire', () {
    testWidgets('a connected car fills the grid with decoded readings', (
      tester,
    ) async {
      final session = newSession();
      await pumpDashboard(tester, session);

      unawaited(session.connect(transportFor('clean_can')));
      await pumpUntil(
        tester,
        () => session.bus.of('010C').value?.value != null,
        reason: 'an RPM sample',
      );
      await tester.pump();

      // The numbers on screen are the ones the trace recorded.
      expect(find.text('1726'), findsOneWidget, reason: 'RPM');
      expect(find.text('68'), findsOneWidget, reason: 'km/h');
      expect(find.text('89'), findsOneWidget, reason: 'coolant');
      expect(find.text('RPM'), findsOneWidget, reason: 'the tile label');

      // Six tiles, and the healthy banner is hidden entirely.
      expect(find.byType(GaugeTile), findsNWidgets(6));
      expect(find.byType(ConnectionBanner), findsNothing);
      await quiesce(tester, session);
    });

    testWidgets('headers on the wire change nothing on screen', (tester) async {
      final session = newSession();
      await pumpDashboard(tester, session);
      unawaited(session.connect(transportFor('headers_can')));
      await pumpUntil(
        tester,
        () => session.bus.of('010C').value?.value != null,
      );
      await tester.pump();

      expect(session.headerChars, 3);
      expect(find.text('1726'), findsOneWidget);
      expect(find.text('89'), findsOneWidget);
      await quiesce(tester, session);
    });

    testWidgets('only the PIDs with a tile are ever asked for', (tester) async {
      final session = newSession();
      final transport = transportFor('clean_can');
      await pumpDashboard(tester, session, layout: const ['010C']);
      unawaited(session.connect(transport));
      await pumpUntil(
        tester,
        () => session.bus.of('010C').value?.value != null,
      );

      final from = transport.written.length;
      await tester.pump(const Duration(milliseconds: 100));
      final asked = transport.written
          .skip(from)
          .where((c) => c.startsWith('01') && c.length == 4)
          .toSet();
      expect(asked, everyElement('010C'));
      expect(find.byType(GaugeTile), findsOneWidget);
      await quiesce(tester, session);
    });
  });

  group('★ B.6 — the six states', () {
    testWidgets('Loading: skeletons that match the final geometry', (
      tester,
    ) async {
      final session = newSession();
      await pumpDashboard(tester, session);
      unawaited(session.connect(transportFor('clean_can')));

      await pumpUntil(
        tester,
        () => session.state == SessionState.handshaking,
        reason: 'the handshake to start',
      );
      await tester.pump();
      expect(find.byType(GaugeTileSkeleton), findsNWidgets(6));
      expect(find.textContaining('Setting up — step'), findsOneWidget);
      await quiesce(tester, session);
    });

    testWidgets('Error: names what happened and offers the one action', (
      tester,
    ) async {
      final session = newSession();
      var opened = 0;
      await pumpDashboard(tester, session, onConnect: () => opened++);

      unawaited(session.connect(transportFor('adapter_unresponsive')));
      // Not "state == disconnected": that is already true before the
      // attempt starts, so it would pass instantly and prove nothing.
      await pumpUntil(
        tester,
        () => session.lastError != null,
        reason: 'the handshake to give up with a reason',
      );
      await tester.pump();

      expect(find.text('Could not connect'), findsOneWidget);
      expect(find.byType(GaugeTile), findsNothing);
      await tester.tap(find.text('Choose an adapter'));
      expect(opened, 1);
      await quiesce(tester, session);
    });

    testWidgets('Disconnected: an invitation, not an error', (tester) async {
      final session = newSession();
      await pumpDashboard(tester, session, onConnect: () {});
      await tester.pump();

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Not connected — tap to connect'), findsOneWidget);
      // Offline is never a network error (B.6).
      expect(find.textContaining('network'), findsNothing);
      expect(find.textContaining('internet'), findsNothing);
    });

    testWidgets('Partial: an unsupported PID keeps its tile and says why', (
      tester,
    ) async {
      final session = newSession();
      // ev_minimal supports very little, so most of the layout is absent.
      await pumpDashboard(tester, session);
      unawaited(session.connect(transportFor('ev_minimal')));
      await pumpUntil(
        tester,
        () => session.state == SessionState.connected,
        reason: 'the session to settle',
      );
      await tester.pump();

      expect(find.byType(GaugeTile), findsNWidgets(6), reason: 'no holes');
      expect(find.text('Not supported'), findsWidgets);
      await quiesce(tester, session);
    });

    testWidgets('Stale: the value dims and says its age, and never lies', (
      tester,
    ) async {
      final session = newSession();
      await pumpDashboard(tester, session, layout: const ['010C']);
      unawaited(session.connect(transportFor('clean_can')));
      await pumpUntil(
        tester,
        () => session.bus.of('010C').value?.value != null,
      );

      // Stop the replay answering and let the shared clock run on.
      unawaited(session.disconnect());
      await tester.pump();
      session.clock.tick(DateTime.now().add(const Duration(seconds: 6)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('1726'), findsNothing, reason: 'never stale-as-live');
      await quiesce(tester, session);
    });
  });

  group('the banner — SPEC §2.1', () {
    testWidgets('a healthy link says nothing at all', (tester) async {
      final session = newSession();
      await pumpDashboard(tester, session);
      unawaited(session.connect(transportFor('clean_can')));
      await pumpUntil(tester, () => session.state == SessionState.connected);
      await tester.pump();
      expect(bannerFor(session), isNull);
      expect(find.byType(ConnectionBanner), findsNothing);
      await quiesce(tester, session);
    });

    test('every state has the wording the spec specifies', () {
      // Exercised as a table because the strings are a contract with the
      // user, not an implementation detail.
      final session = ObdSession();
      addTearDown(session.dispose);

      expect(bannerFor(session)!.message, 'Not connected — tap to connect');
      expect(
        bannerFor(session, platform: const FakePlatform(isAndroid: true))!.tone,
        Tell.none,
      );
    });

    testWidgets('the banner pushes the grid down rather than covering it', (
      tester,
    ) async {
      final session = newSession();
      await pumpDashboard(tester, session, onConnect: () {});
      await tester.pump();
      final bannerBottom = tester
          .getBottomLeft(find.byType(ConnectionBanner))
          .dy;
      final bodyTop = tester.getTopLeft(find.byType(EmptyStateView)).dy;
      expect(bodyTop, greaterThanOrEqualTo(bannerBottom));
    });
  });

  group('goldens', () {
    testWidgets('a live dashboard', (tester) async {
      final session = newSession();
      await pumpDashboard(tester, session);
      unawaited(session.connect(transportFor('clean_can')));
      await pumpUntil(
        tester,
        () =>
            session.bus.of('010C').value?.value != null &&
            session.bus.of('0142').value?.value != null,
      );
      await tester.pump();
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('goldens/dashboard_live.png'),
      );
      await quiesce(tester, session);
    });

    testWidgets('not connected', (tester) async {
      final session = newSession();
      await pumpDashboard(tester, session, onConnect: () {});
      await tester.pump();
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('goldens/dashboard_disconnected.png'),
      );
    });
  });
}
