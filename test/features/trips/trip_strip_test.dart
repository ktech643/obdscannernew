import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/dashboard/dashboard_layout.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_store.dart';
import 'package:torque_obd2/features/trips/trip_strip.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/session/obd_session.dart' show SessionState;
import 'package:torque_obd2/transport/obd_transport.dart' show TransportKind;

import 'support.dart';

/// SPEC §5.3's trip strip on screen, over the recorder and its fakes: the
/// §7.3 door that only a tap opens, B.8's one node and one announcement
/// per event, §B.26's statements in place of dimmed buttons, AC-16 at
/// large text, §9.7's comma decimals and B.3's stillness. What each state
/// *says* is proven as tables in trip_strip_content_test.dart.
///
/// Everything here runs on the fake clock with fakes only: no file, no
/// database, no timer (the rig has none; [drive] ticks by hand).
void main() {
  const capLine = "Stopped at 2 minutes, the free plan's limit. Trip saved.";

  VehicleRow golfRow() => VehicleRow(
    id: 'golf',
    nickname: 'Golf',
    vinUnverified: false,
    make: '',
    model: '',
    trim: '',
    fuelType: VehicleFuel.petrol,
    supportsBatching: false,
    isPrimary: true,
    createdAt: DateTime.utc(2026),
  );

  RecorderRig newRig({
    bool isPro = false,
    TransportKind transport = TransportKind.ble,
  }) {
    final rig = RecorderRig(isPro: isPro, transport: transport);
    addTearDown(rig.dispose);
    return rig;
  }

  /// The strip where the Dashboard puts it: full width, above the grid,
  /// in the app's theme and on its platform.
  Future<void> pumpStrip(
    WidgetTester tester,
    RecorderRig rig, {
    TripRecorder? recorder,
    DistanceUnit distance = DistanceUnit.km,
    bool electric = false,
    VoidCallback? onUpgrade,
    VoidCallback? onAddVehicle,
    Size size = const Size(390, 844),
    double textScale = 1,
    NavigatorObserver? observer,
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
          navigatorObservers: [?observer],
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TripStrip(
                    recorder: recorder ?? rig.recorder,
                    layouts: rig.dashboard,
                    distance: distance,
                    electric: () => electric,
                    onUpgrade: onUpgrade,
                    onAddVehicle: onAddVehicle,
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// [seconds] of recording: each second the clocks move, the car answers
  /// Speed at [kph] (and Fuel rate at [lph], when given) and the recorder
  /// ticks, as its 1 s timer would.
  Future<void> drive(
    WidgetTester tester,
    RecorderRig rig,
    int seconds, {
    TripRecorder? recorder,
    double kph = 41.2,
    double? lph,
  }) async {
    for (var i = 0; i < seconds; i++) {
      rig.clock.advance(const Duration(seconds: 1));
      rig.link.publish('010D', kph);
      if (lph != null) rig.link.publish('015E', lph);
      (recorder ?? rig.recorder).debugTick();
    }
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump();
  }

  Future<void> link(
    WidgetTester tester,
    RecorderRig rig,
    SessionState s, {
    String? error,
  }) async {
    rig.link.set(s, error: error);
    await tester.pump();
    await tester.pump();
  }

  List<String> said(WidgetTester tester) => [
    for (final a in tester.takeAnnouncements()) a.message,
  ];

  /// Every node a screen reader stops at: (its words, whether it is a
  /// button).
  List<(String, bool)> stops() => [
    for (final n
        in find.semantics
            .byPredicate(
              (n) => n.label.isNotEmpty || n.flagsCollection.isButton,
            )
            .evaluate())
      (n.label, n.flagsCollection.isButton),
  ];

  group('★ §7.3/§9.4 the cap door opens only on a tap, never for an '
      'electric car', () {
    testWidgets('★ at 2:00 nothing opens; a tap on the statement opens the '
        'door, and See Pro is the way to Pro', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = newRig();
      final pushes = _Pushes();
      var upgrades = 0;
      await pumpStrip(
        tester,
        rig,
        onUpgrade: () => upgrades++,
        observer: pushes,
      );
      expect(pushes.routes, hasLength(1), reason: 'the home route');

      await tapText(tester, 'Record');
      await drive(tester, rig, 120);
      await tester.pumpAndSettle();
      expect(rig.store.rows.values.single.endReason, TripEnd.freeCap);

      // The limit is reached while driving: no modal, no route, no
      // paywall (§7.3 "contextual only"; §B.29 doors open only by a tap).
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(pushes.routes, hasLength(1));
      expect(upgrades, 0);
      expect(find.text(capLine), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final door = find.semantics.byLabel(capLine).evaluate().single;
      expect(door.flagsCollection.isButton, isTrue);
      expect(door.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.text(capLine));
      await tester.pumpAndSettle();
      expect(pushes.routes, hasLength(2));
      expect(find.text('2-minute recordings on the free plan'), findsOneWidget);
      expect(
        find.text('Longer recordings are part of Pro. This trip is saved.'),
        findsOneWidget,
      );
      expect(find.text('Not now'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(upgrades, 0, reason: 'Not now is not a way to Pro');
      expect(find.text('2-minute recordings on the free plan'), findsNothing);

      await tester.tap(find.text(capLine));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See Pro'));
      await tester.pumpAndSettle();
      expect(upgrades, 1);
      expect(find.text('2-minute recordings on the free plan'), findsNothing);
      handle.dispose();
    });

    testWidgets('★ an electric car hears the same limit as a statement: '
        'no button, no See Pro', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = newRig();
      final pushes = _Pushes();
      var upgrades = 0;
      await pumpStrip(
        tester,
        rig,
        electric: true,
        onUpgrade: () => upgrades++,
        observer: pushes,
      );
      await tapText(tester, 'Record');
      await drive(tester, rig, 120);
      await tester.pumpAndSettle();

      // The free plan still stops at 2:00 — that is the plan — but §9.4
      // blocks the paywall from an electric car.
      expect(find.text(capLine), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final node = find.semantics
          .byPredicate((n) => n.label.startsWith(capLine))
          .evaluate()
          .single;
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      await tester.tap(find.text(capLine), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pushes.routes, hasLength(1));
      expect(find.text('2-minute recordings on the free plan'), findsNothing);
      expect(find.text('See Pro'), findsNothing);
      expect(upgrades, 0);
      handle.dispose();
    });
  });

  testWidgets('★ hard rule 11 / B.3: Recording is a blue glyph and a word, '
      'Paused a glyph and a word — never colour alone, never red', (
    tester,
  ) async {
    final rig = newRig();
    await pumpStrip(tester, rig);
    final t = tester.element(find.byType(TripStrip)).tokens;
    await tapText(tester, 'Record');
    await drive(tester, rig, 3);

    // B.3: "informational, recording" — the blue telltale. A red REC is a
    // fault colour; amber is the controls' ink.
    expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
    expect(find.text('Recording'), findsOneWidget, reason: 'a word, not a dot');
    final dot = tester.widget<Icon>(find.byIcon(Icons.fiber_manual_record));
    final word = tester.widget<Text>(find.text('Recording'));
    expect(dot.color, t.tellBlue);
    expect(word.style?.color, t.tellBlue);
    for (final c in [dot.color, word.style?.color]) {
      expect(c, isNot(t.tellRed));
      expect(c, isNot(t.tellAmber));
    }

    await link(tester, rig, SessionState.lost);
    expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    final paused = tester.widget<Icon>(find.byIcon(Icons.pause_circle_outline));
    expect(paused.color, isNot(t.tellRed));
    expect(paused.color, isNot(t.tellAmber));
    expect(find.text('Waiting for the car to reconnect.'), findsOneWidget);
  });

  testWidgets('★ B.8 one node for the status and one per control; each '
      'event said once, never a tick', (tester) async {
    final handle = tester.ensureSemantics();
    final rig = newRig();
    await pumpStrip(tester, rig);
    said(tester);

    void noLiveRegion(String state) => expect(
      find.semantics.byPredicate((n) => n.flagsCollection.isLiveRegion),
      findsNothing,
      reason: state,
    );

    expect(stops(), [
      (
        'Not recording Records distance, speed and the gauges on screen. '
            'The free plan records 2 minutes per trip.',
        false,
      ),
      ('Record a trip', true),
    ]);
    noLiveRegion('idle');

    await tapText(tester, 'Record');
    expect(said(tester), [
      'Recording started. The free plan records 2 minutes.',
    ]);
    expect(stops(), [
      ('Recording, 0 seconds of 2 minutes.', false),
      ('Stop recording', true),
    ]);
    noLiveRegion('recording');

    // The meter moves every second; nothing is said for it.
    await drive(tester, rig, 10);
    await tester.pump(const Duration(milliseconds: 1));
    expect(said(tester), isEmpty, reason: '10 ticks');
    expect(stops(), [
      ('Recording, 10 seconds of 2 minutes. 0.1 kilometres.', false),
      ('Stop recording', true),
    ]);

    await link(tester, rig, SessionState.lost);
    expect(said(tester), [
      'Recording paused. Waiting for the car to reconnect.',
    ]);
    expect(stops(), [
      (
        'Paused, waiting for the car to reconnect. 10 seconds recorded. 0.1 '
            'kilometres.',
        false,
      ),
      ('Stop recording', true),
    ]);
    noLiveRegion('paused');

    await link(tester, rig, SessionState.connected);
    expect(said(tester), ['Recording again.']);

    await drive(tester, rig, 10);
    expect(said(tester), isEmpty, reason: '10 more ticks');

    await tapText(tester, 'Stop');
    expect(said(tester), ['Recording stopped. Trip saved.']);
    expect(stops(), hasLength(2));
    expect(stops().first.$1, startsWith('Trip saved. '));
    expect(stops().last, ('Record a trip', true));
    noLiveRegion('saved');
    handle.dispose();
  });

  testWidgets('★ §B.26 never a disabled control: starting, saving, '
      'checking the car and Demo are statements', (tester) async {
    final handle = tester.ensureSemantics();
    final rig = newRig();
    final store = _GatedStore();
    final recorder = _recorderOver(rig, store);
    await pumpStrip(tester, rig, recorder: recorder);

    void onlyStatements(String state) {
      expect(find.text(state), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (n) => n.flagsCollection.isEnabled == Tristate.isFalse,
        ),
        findsNothing,
        reason: '"$state": a dimmed control',
      );
      expect(
        tester
            .widgetList<GhostButton>(find.byType(GhostButton))
            .where((b) => b.onPressed == null),
        isEmpty,
        reason: '"$state"',
      );
      expect(stops(), [(state, false)], reason: '"$state": one statement');
    }

    store.startGate = Completer<void>();
    await tapText(tester, 'Record');
    onlyStatements('Starting the recording…');
    store.startGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(recorder.view.phase, RecorderPhase.recording);
    // A trip with a reading is saved; one with none is simply dropped.
    rig.link.publish('010D', 30);

    store.finishGate = Completer<void>();
    await tapText(tester, 'Stop');
    onlyStatements('Saving the trip…');
    store.finishGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(recorder.view.phase, RecorderPhase.idle);

    recorder.follow(const OwnerPending('golf'));
    await tester.pump();
    onlyStatements('Checking which car this is…');

    recorder.follow(const OwnerDemo());
    await tester.pump();
    onlyStatements("Demo Mode doesn't record trips.");
    expect(store.starts, 1, reason: 'Demo never reached the store');
    handle.dispose();
  });

  group('★ AC-16 the strip at large text and on a narrow phone', () {
    // (width, text scale, stacked): 320 × 2.0 is the spec's case; the
    // other two each keep one reason for stacking, so neither can go
    // unnoticed behind the other.
    for (final (width, scale, stacked) in [
      (320.0, 2.0, true),
      (390.0, 1.0, false),
      (320.0, 1.0, true),
      (390.0, 2.0, true),
    ]) {
      testWidgets('★ $width pt × $scale: nothing overflows, nothing is cut, '
          '${stacked ? 'stacked' : 'in a row'}', (tester) async {
        final rig = newRig(transport: TransportKind.wifi);
        await pumpStrip(
          tester,
          rig,
          onUpgrade: () {},
          size: Size(width, 900),
          textScale: scale,
        );
        final strip = find.byType(TripStrip);

        void check(String state, {bool always = false}) {
          expect(tester.takeException(), isNull, reason: state);
          final buttons = find
              .descendant(of: strip, matching: find.byType(GhostButton))
              .evaluate()
              .toList();
          final inButtons = find
              .descendant(
                of: find.descendant(
                  of: strip,
                  matching: find.byType(GhostButton),
                ),
                matching: find.byType(RichText),
              )
              .evaluate()
              .toSet();
          var statusBottom = 0.0;
          for (final e
              in find
                  .descendant(of: strip, matching: find.byType(RichText))
                  .evaluate()) {
            final text = e.widget as RichText;
            final box = e.renderObject! as RenderParagraph;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            expect(text.maxLines, isNull, reason: '$state: ${text.text}');
            expect(
              text.overflow,
              isNot(TextOverflow.ellipsis),
              reason: '$state: ${text.text}',
            );
            expect(box.didExceedMaxLines, isFalse, reason: state);
            expect(rect.left, greaterThanOrEqualTo(0), reason: state);
            expect(
              rect.right,
              lessThanOrEqualTo(width + 0.01),
              reason: '$state: ${text.text.toPlainText()}',
            );
            if (!inButtons.contains(e) && rect.bottom > statusBottom) {
              statusBottom = rect.bottom;
            }
          }
          expect(buttons, isNotEmpty, reason: state);
          for (final b in buttons) {
            final r = tester.getRect(find.byWidget(b.widget));
            expect(r.height, greaterThanOrEqualTo(48), reason: state);
            expect(r.width, greaterThanOrEqualTo(48), reason: state);
            if (stacked || always) {
              expect(
                r.top,
                greaterThanOrEqualTo(statusBottom - 0.01),
                reason: '$state: the controls go under the status',
              );
            } else {
              expect(
                r.top,
                lessThan(statusBottom),
                reason: '$state: the controls sit beside the status',
              );
            }
          }
        }

        check('idle, Free');

        await tapText(tester, 'Record');
        await drive(tester, rig, 60, lph: 3.6);
        check('recording');

        await link(tester, rig, SessionState.lost);
        check('paused');

        await link(tester, rig, SessionState.connected);
        await drive(tester, rig, 60, lph: 3.6);
        expect(find.text(capLine), findsOneWidget);
        check('capped');

        await tapText(tester, 'Record');
        await drive(tester, rig, 10);
        await link(
          tester,
          rig,
          SessionState.disconnected,
          error: 'Could not reconnect',
        );
        await link(tester, rig, SessionState.connected);
        expect(find.text('Resume trip?'), findsOneWidget);
        check('the offer', always: true);
      });
    }
  });

  group('★ §9.7 the phone\'s number convention and the unit setting', () {
    for (final (unit, line) in [
      (DistanceUnit.km, '12,4 km · avg 41 km/h'),
      (DistanceUnit.mi, '7,7 mi · avg 26 mph'),
    ]) {
      testWidgets('★ a German phone reads $line', (tester) async {
        // The app sets no Intl.defaultLocale: the strip must ask the
        // platform, where a German phone says de_DE.
        tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        final rig = newRig(isPro: true);
        await pumpStrip(tester, rig, distance: unit);
        await tapText(tester, 'Record');
        // 18 minutes at 41.2 km/h: 12.36 km — 7.68 mi at 25.6 mph.
        await drive(tester, rig, 1081);
        expect(find.text(line), findsOneWidget);
        expect(find.text('18:01'), findsOneWidget);

        // The file stays metric and locale-free, whatever is on screen.
        final speeds = {
          for (final l in rig.sink.content.split('\n'))
            if (l.contains(',010D,')) l.split(',').last,
        };
        expect(speeds, {'41.2'});
      });
    }
  });

  testWidgets('★ B.3 no motion: recording, paused and saving are still', (
    tester,
  ) async {
    final rig = newRig();
    final store = _GatedStore();
    final recorder = _recorderOver(rig, store);
    await pumpStrip(tester, rig, recorder: recorder);

    await tapText(tester, 'Record');
    expect(find.text('Recording'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse, reason: 'recording');
    await drive(tester, rig, 5, recorder: recorder);
    expect(tester.hasRunningAnimations, isFalse, reason: 'the meter');

    await link(tester, rig, SessionState.lost);
    expect(find.text('Paused'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse, reason: 'paused');

    await link(tester, rig, SessionState.connected);
    store.finishGate = Completer<void>();
    await tapText(tester, 'Stop');
    expect(find.text('Saving the trip…'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse, reason: 'saving');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse, reason: 'still saving');
    store.finishGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Trip saved.'), findsOneWidget);
  });

  testWidgets('edit mode keeps a recording\'s status and Stop, and hides '
      'the rest', (tester) async {
    final rig = newRig();
    rig.dashboard.setTarget(VehicleTarget(golfRow()));
    await pumpStrip(tester, rig);
    expect(find.text('Not recording'), findsOneWidget);

    rig.dashboard.beginEditing();
    await tester.pump();
    expect(rig.dashboard.editing, isTrue);
    expect(find.text('Not recording'), findsNothing);
    expect(find.text('Record'), findsNothing);
    expect(tester.getSize(find.byType(TripStrip)).height, 0);

    rig.dashboard.endEditing();
    await tester.pump();
    await tapText(tester, 'Record');
    await drive(tester, rig, 5);
    rig.dashboard.beginEditing();
    await tester.pump();
    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('0:05 of 2:00'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // Stopped from edit mode: saved, and the strip steps aside again.
    await tapText(tester, 'Stop');
    expect(rig.recorder.view.phase, RecorderPhase.idle);
    expect(find.text('Trip saved.'), findsNothing);
    expect(tester.getSize(find.byType(TripStrip)).height, 0);
    rig.dashboard.endEditing();
    await tester.pump();
    expect(find.text('Trip saved.'), findsOneWidget);
  });

  testWidgets('times follow the phone\'s 24-hour setting: 14:32 or 2:32 PM', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    for (final (use24h, at) in [(true, '14:32'), (false, '2:32 PM')]) {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = use24h;
      final rig = newRig();
      // 10 s before 14:32 on this phone's clock.
      rig.clock.utc = DateTime(2026, 9, 28, 14, 31, 50).toUtc();
      await pumpStrip(tester, rig);
      await tapText(tester, 'Record');
      await drive(tester, rig, 10);
      // The ladder gave up: saved up to the last sample, 14:32.
      await link(
        tester,
        rig,
        SessionState.disconnected,
        error: 'Could not reconnect',
      );
      expect(
        find.text(
          'Stopped — the connection was lost. The trip is saved up to $at.',
        ),
        findsOneWidget,
        reason: 'use24h: $use24h',
      );
      // The same car again, within 30 minutes: the offer says when.
      await link(tester, rig, SessionState.connected);
      expect(
        find.text(
          'The connection was lost at $at. The trip is saved up to then.',
        ),
        findsOneWidget,
        reason: 'use24h: $use24h',
      );
    }
  });
}

/// Every route pushed, the home route first.
class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

/// The rig's store, with a start and a finish that wait for a gate — so
/// the strip can be seen while a recording starts and while it saves.
class _GatedStore extends FakeTripStore {
  Completer<void>? startGate;
  Completer<void>? finishGate;

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async {
    final gate = startGate;
    if (gate != null) await gate.future;
    return super.start(vehicleId: vehicleId, startedAt: startedAt);
  }

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) async {
    final gate = finishGate;
    if (gate != null) await gate.future;
    return super.finish(trip, end, now: now);
  }
}

/// A recorder over the rig's link, clock, layouts and service, and over
/// [store] — the rig's own recorder stays idle beside it.
TripRecorder _recorderOver(RecorderRig rig, TripStore store) {
  final r = TripRecorder(
    link: rig.link,
    store: store,
    dashboard: rig.dashboard,
    background: rig.background,
    platform: const FakePlatform(isAndroid: false),
    clock: rig.clock,
    tickEvery: null,
  )..follow(RecorderRig.golf);
  // Registered after the rig's, so it is let go first.
  addTearDown(r.dispose);
  return r;
}
