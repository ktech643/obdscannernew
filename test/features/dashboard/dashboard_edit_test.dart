import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/layout_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/dashboard/dashboard_grid.dart';
import 'package:torque_obd2/features/dashboard/dashboard_layout.dart';
import 'package:torque_obd2/features/dashboard/dashboard_screen.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/features/dashboard/speed_gate.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.3 edit mode, B.8's accessibility floor and §7.2–7.3's doors, on
/// the real screen and — where it matters what the car is asked — a real
/// session replaying a recorded car.
void main() {
  late final Map<String, ObdTrace> traces;
  setUpAll(() {
    traces = {
      for (final n in const ['clean_can', 'headers_can', 'dtc_scan_can'])
        n: ObdTrace.parse(File('assets/traces/$n.obdtrace').readAsStringSync()),
    };
  });

  VehicleRow car({
    VehicleFuel fuel = VehicleFuel.petrol,
    List<String>? support,
  }) => VehicleRow(
    id: 'golf',
    nickname: 'Golf',
    vinUnverified: false,
    make: '',
    model: '',
    trim: '',
    fuelType: fuel,
    supportedPidsJson: support == null ? null : jsonEncode(support),
    supportsBatching: false,
    isPrimary: true,
    createdAt: DateTime.utc(2026),
  );

  const six = ['010C', '010D', '0105', '0104', '0111', '0142'];

  ObdSession newSession() {
    final s = ObdSession(timeScale: 0.05);
    addTearDown(s.dispose);
    return s;
  }

  Future<DashboardLayoutController> pumpScreen(
    WidgetTester tester,
    ObdSession session, {
    List<String> tiles = six,
    bool pro = false,
    LayoutTarget? target,
    Size size = const Size(390, 1400),
    double textScale = 1,
    VoidCallback? onUpgrade,
    VoidCallback? onAddVehicle,
    ValueListenable<bool>? moving,
    ValueNotifier<int>? tab,
    LayoutRepository? repository,
  }) async {
    final c = DashboardLayoutController(
      repository: repository,
      publish: session.setVisible,
      moving: moving,
      defaults: [for (final p in tiles) LayoutTile(p)],
    )..isPro = pro;
    c.setTarget(target ?? VehicleTarget(car()));
    addTearDown(c.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dashboard = DashboardScreen(
      session: session,
      layouts: c,
      onUpgrade: onUpgrade,
      onAddVehicle: onAddVehicle,
    );
    final Widget screen = tab == null
        ? dashboard
        : ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (_, i, _) => IndexedStack(
              index: i,
              children: [dashboard, const SizedBox.shrink()],
            ),
          );
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Scaffold(body: screen),
          ),
        ),
      ),
    );
    await tester.pump();
    return c;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  Future<void> quiesce(WidgetTester tester, ObdSession s) async {
    unawaited(s.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> enterEdit(WidgetTester tester) async {
    await tester.tap(find.text('Edit'));
    await settle(tester);
  }

  FinderBase<SemanticsNode> tileNode(String pid) =>
      find.semantics.byLabel(RegExp('^${GaugeCatalog.labelFor(pid)},'));
  SemanticsNode nodeOf(String pid) => tileNode(pid).evaluate().single;

  group('★ into edit mode, and out', () {
    testWidgets('★ three ways in: a long-press, the Edit button, the tile\'s '
        'action', (tester) async {
      final handle = tester.ensureSemantics();
      final session = newSession();
      final c = await pumpScreen(tester, session);
      unawaited(
        session.connect(MockTransport(traces['clean_can']!, speed: 100)),
      );
      await pumpUntil(tester, () => session.bus.of('010C').value != null);
      await tester.pump();

      await tester.longPress(find.byType(GaugeTile).first);
      await settle(tester);
      expect(c.editing, isTrue, reason: 'long-press');
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(c.editing, isFalse);

      await enterEdit(tester);
      expect(c.editing, isTrue, reason: 'the header');
      c.endEditing();
      await settle(tester);

      // VoiceOver has no long-press.
      tester.semantics.customAction(
        tileNode('0105'),
        TileActions.editDashboard,
      );
      await settle(tester);
      expect(c.editing, isTrue, reason: 'the action');
      handle.dispose();
      await quiesce(tester, session);
    });

    testWidgets('★ another tab in front ends edit mode', (tester) async {
      final tab = ValueNotifier(0);
      // No Speed tile, so Speed is asked for only for §8.4's gate.
      final c = await pumpScreen(
        tester,
        newSession(),
        tab: tab,
        tiles: const ['0105', '010C'],
      );
      await enterEdit(tester);
      expect(c.editing, isTrue);
      expect(c.visiblePids, contains('010D'));
      tab.value = 1;
      await settle(tester);
      expect(c.editing, isFalse);
      expect(c.visiblePids.contains('010D'), isFalse, reason: 'Speed let go');
    });

    testWidgets('★ Android back leaves edit mode, and nothing else', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(c.editing, isFalse);
    });

    testWidgets('no car: the way in says why, and offers to add one', (
      tester,
    ) async {
      var adds = 0;
      final c = await pumpScreen(
        tester,
        newSession(),
        target: const NoVehicleTarget(),
        onAddVehicle: () => adds++,
      );
      await enterEdit(tester);
      expect(c.editing, isFalse);
      expect(find.text('Gauges are saved for each car'), findsOneWidget);
      await tester.tap(find.text('Add your car'));
      await settle(tester);
      expect(adds, 1);
    });

    testWidgets('★ moving: the way in is a statement, and a long-press does '
        'nothing', (tester) async {
      final moving = ValueNotifier(true);
      final c = await pumpScreen(tester, newSession(), moving: moving);
      expect(find.text('Edit when parked'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(c.beginEditing(), EditOutcome.moving);
      moving.value = false;
      await settle(tester);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('★ one node per tile, and every gesture an action — B.8', () {
    testWidgets('★ in edit mode each tile is one node, numbered, with only the '
        'actions that do something', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, newSession());
      await enterEdit(tester);
      final ids = <String, int>{
        for (final a in [
          TileActions.moveEarlier,
          TileActions.moveLater,
          TileActions.moveFirst,
          TileActions.moveLast,
          TileActions.changeReading,
          TileActions.remove,
        ])
          a.label!: CustomSemanticsAction.getIdentifier(a),
      };
      Set<String> actionsOf(String pid) {
        final data = nodeOf(pid).getSemanticsData();
        final have = data.customSemanticsActionIds ?? const [];
        return {
          for (final e in ids.entries)
            if (have.contains(e.value)) e.key,
        };
      }

      expect(nodeOf('010C').label, endsWith('Gauge 1 of 6'));
      expect(actionsOf('010C'), {
        'Move later',
        'Move to last',
        'Change reading',
        'Remove',
      });
      expect(actionsOf('0142'), {
        'Move earlier',
        'Move to first',
        'Change reading',
        'Remove',
      });
      // The grip and the × add no stop of their own.
      expect(find.semantics.byLabel('Move'), findsNothing);
      expect(find.semantics.byLabel('Remove'), findsNothing);
      handle.dispose();
    });

    testWidgets('★ a move by action keeps the tile\'s node — focus goes with '
        'it — and is said', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      tester.takeAnnouncements();
      final before = nodeOf('0105').id;
      tester.semantics.customAction(tileNode('0105'), TileActions.moveLater);
      await settle(tester);
      expect(c.tiles.indexWhere((t) => t.pid == '0105'), 3);
      expect(nodeOf('0105').id, before);
      // And into another row: the grid is rows now, and the slot's own key
      // carries it across.
      tester.semantics.customAction(tileNode('0105'), TileActions.moveFirst);
      await settle(tester);
      expect(c.tiles.first.pid, '0105');
      expect(nodeOf('0105').id, before);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Coolant moved to gauge 4 of 6'),
      );
      handle.dispose();
    });

    testWidgets('★ a remove by action is said, with where Undo is', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      tester.takeAnnouncements();
      tester.semantics.customAction(tileNode('0105'), TileActions.remove);
      await settle(tester);
      expect(c.tiles.any((t) => t.pid == '0105'), isFalse);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Coolant removed. Undo is at the top.'),
      );
      expect(find.semantics.byLabel('Undo remove Coolant'), findsOneWidget);
      await tester.tap(find.text('Undo remove Coolant'));
      await settle(tester);
      expect(c.tiles.any((t) => t.pid == '0105'), isTrue);
      handle.dispose();
    });
  });

  group('★ the gestures', () {
    testWidgets('★ a swipe removes past a third of the tile — distance, never '
        'speed', (tester) async {
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      final tile = find.byType(GaugeTile).at(2);
      final width = tester.getSize(tile).width;

      await tester.drag(tile, Offset(-width / 4, 0));
      await settle(tester);
      expect(c.tiles, hasLength(6), reason: 'short: springs back');

      // Fast and short — 45 px in 30 ms, 1,500 px/s, under a third of the
      // tile: Dismissible would take it; this does not. (tester.fling
      // arrived with no velocity at all.)
      await tester.timedDrag(
        tile,
        const Offset(-45, 0),
        const Duration(milliseconds: 30),
        frequency: 300,
      );
      await settle(tester);
      expect(c.tiles, hasLength(6), reason: 'a flick is not a decision');

      await tester.drag(tile, Offset(-width / 2, 0));
      await settle(tester);
      expect(c.tiles, hasLength(5));
    });

    testWidgets('★ the one tile left resists, and says why', (tester) async {
      final c = await pumpScreen(tester, newSession(), tiles: const ['010C']);
      await enterEdit(tester);
      final tile = find.byType(GaugeTile).first;
      await tester.drag(tile, Offset(-tester.getSize(tile).width, 0));
      await settle(tester);
      expect(c.tiles, hasLength(1));
      expect(find.textContaining('Keep at least one gauge'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing, reason: 'no ×');
    });

    testWidgets('★ a vertical drag on a tile scrolls — it neither moves nor '
        'removes; a tap opens the tile', (tester) async {
      final c = await pumpScreen(
        tester,
        newSession(),
        size: const Size(390, 700),
      );
      await enterEdit(tester);
      final order = [...c.tiles];
      await tester.drag(find.byType(GaugeTile).at(1), const Offset(0, -200));
      await settle(tester);
      expect(c.tiles, order);
      await tester.drag(find.byType(GaugeTile).at(3), const Offset(0, 400));
      await settle(tester);
      await tester.tap(find.byType(GaugeTile).first);
      await settle(tester);
      expect(find.text('Show as'), findsOneWidget, reason: 'the tile sheet');
    });

    testWidgets('dragged by its grip onto another slot, a tile moves once', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      final grip = find.byIcon(Icons.drag_indicator).first;
      final target = find.byType(GaugeTile).at(3);
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await settle(tester);
      expect(c.tiles.indexWhere((t) => t.pid == '010C'), 3);
      expect(c.canUndo, isTrue);
    });

    testWidgets('★ Haptics off means none — the drag and the swipe too', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call);
          return null;
        },
      );
      AdaptiveHaptics.enabled = false;
      addTearDown(() => AdaptiveHaptics.enabled = true);
      await pumpScreen(tester, newSession());
      await enterEdit(tester);
      final tile = find.byType(GaugeTile).at(2);
      await tester.drag(tile, Offset(-tester.getSize(tile).width / 2, 0));
      await settle(tester);
      final grip = find.byIcon(Icons.drag_indicator).first;
      await tester.drag(grip, const Offset(0, 180));
      await settle(tester);
      expect(calls, isEmpty);
    });
  });

  group('★ §7.2–7.3 — the plan, and its doors', () {
    testWidgets('★ the 7th tile is a door, and buying lifts it on the open '
        'screen', (tester) async {
      var upgrades = 0;
      final c = await pumpScreen(
        tester,
        newSession(),
        onUpgrade: () => upgrades++,
      );
      await enterEdit(tester);
      await tester.tap(find.text('Add gauge'));
      await settle(tester);
      expect(find.text('6 gauges on the free plan'), findsOneWidget);
      await tester.tap(find.text('See Pro'));
      await settle(tester);
      expect(upgrades, 1);
      expect(c.tiles, hasLength(6), reason: 'nothing added');

      c.isPro = true; // bought
      await settle(tester);
      await tester.tap(find.text('Add gauge'));
      await settle(tester);
      expect(find.text('Add a gauge'), findsOneWidget, reason: 'the picker');
    });

    testWidgets('★ §9.4 — an electric car is never sold more gauges', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        newSession(),
        target: VehicleTarget(car(fuel: VehicleFuel.electric)),
        onUpgrade: () {},
      );
      await enterEdit(tester);
      // Not even a lock: a statement where the door would be.
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(
        find.text(
          'The free plan shows 6 gauges. Tap one to show something '
          'else.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      expect(find.text('Pro'), findsNothing, reason: 'no Pro chips');
      await tester.tap(find.text('New layout'));
      await settle(tester);
      expect(find.text('One layout on the free plan'), findsOneWidget);
      expect(find.text('See Pro'), findsNothing);
    });

    testWidgets('★ after a lapse: six shown, the rest named, nothing sold on '
        'launch', (tester) async {
      await pumpScreen(
        tester,
        newSession(),
        tiles: const [...six, '012F', '0110', '010E'],
      );
      // Edit mode shows the grid whatever the link; the line is a statement.
      await enterEdit(tester);
      expect(find.byType(GaugeTile), findsNWidgets(6));
      expect(
        find.text(
          '3 more gauges are saved on this layout: Fuel, MAF, Timing. The '
          'free plan shows 6.',
        ),
        findsOneWidget,
      );
      expect(find.text('See Pro'), findsNothing);
    });

    testWidgets('★ the second layout is a door on free', (tester) async {
      var upgrades = 0;
      await pumpScreen(tester, newSession(), onUpgrade: () => upgrades++);
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      await tester.tap(find.text('New layout'));
      await settle(tester);
      expect(find.text('Named layouts are part of Pro'), findsOneWidget);
    });
  });

  testWidgets('★ text at 2.0 on a 320-pt phone: one column, nothing '
      'overflows, targets stay 48', (tester) async {
    await pumpScreen(
      tester,
      newSession(),
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(tester.takeException(), isNull, reason: 'normal mode');
    await enterEdit(tester);
    expect(tester.takeException(), isNull, reason: 'edit mode');
    final grid = tester.getSize(find.byType(DashboardGrid)).width;
    final tile = tester.getSize(find.byType(GaugeTile).first).width;
    expect(tile, greaterThan(grid / 2), reason: 'one column');
    final grip = tester.getSize(find.byIcon(Icons.drag_indicator).first);
    expect(grip.height, greaterThanOrEqualTo(20));
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byIcon(Icons.drag_indicator).first,
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(GaugeTile).first);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'the tile sheet');
  });

  group('goldens', () {
    testWidgets('edit mode, 390 pt', (tester) async {
      await pumpScreen(tester, newSession(), size: const Size(390, 1100));
      await enterEdit(tester);
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('goldens/dashboard_editing.png'),
      );
    });

    testWidgets('edit mode, 320 pt at text 2.0', (tester) async {
      await pumpScreen(
        tester,
        newSession(),
        size: const Size(320, 1600),
        textScale: 2,
        tiles: const ['010C', '0105', '0142'],
      );
      await enterEdit(tester);
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('goldens/dashboard_editing_320_x2.png'),
      );
    });
  });

  testWidgets('★ Edit sits at the edge, whatever the car is called', (
    tester,
  ) async {
    // Seen on the simulator: "The Golf" left Edit mid-row.
    await pumpScreen(tester, newSession(), size: const Size(402, 874));
    final edit = tester.getRect(find.text('Edit'));
    expect(edit.right, greaterThan(402 - Space.gutter - Space.x16 - 1));
  });

  testWidgets('★ a row is as tall as its tallest tile — an Arc beside a '
      'Number', (tester) async {
    final c = await pumpScreen(tester, newSession());
    await enterEdit(tester);
    c.setVariant(c.ref, '010D', GaugeVariant.arc);
    await settle(tester);
    // Seen on the simulator: the pair, and their grips, at two heights.
    final a = tester.getSize(find.byType(GaugeTile).at(0)).height;
    final b = tester.getSize(find.byType(GaugeTile).at(1)).height;
    expect(a, b);
    final grips = find.byIcon(Icons.drag_indicator);
    expect(tester.getCenter(grips.at(0)).dy, tester.getCenter(grips.at(1)).dy);
  });

  group('★ the review of slice 16', () {
    testWidgets('★ a tile held for a second can still be swiped, tapped and '
        'scrolled', (tester) async {
      // A long-press recogniser with nothing to do won the arena at 500 ms.
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      final tile = find.byType(GaugeTile).at(2);
      final width = tester.getSize(tile).width;
      final g = await tester.startGesture(tester.getCenter(tile));
      await tester.pump(const Duration(milliseconds: 700));
      // As tester.drag does: past the touch slop, then the rest.
      await g.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(Offset(-width * 0.5, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.up();
      await settle(tester);
      expect(c.tiles, hasLength(5), reason: 'the held swipe removed');

      final h = await tester.startGesture(
        tester.getCenter(find.byType(GaugeTile).first),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await h.up();
      await settle(tester);
      expect(find.text('Show as'), findsOneWidget, reason: 'the held tap');
    });

    testWidgets('★ the Layouts sheet goes when the car starts moving', (
      tester,
    ) async {
      final moving = ValueNotifier(false);
      final c = await pumpScreen(
        tester,
        newSession(),
        pro: true,
        moving: moving,
      );
      c.createLayout(c.ref, 'Two');
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      expect(find.text('New layout'), findsOneWidget);
      moving.value = true;
      await settle(tester);
      expect(find.text('New layout'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
    });

    testWidgets('★ the Layouts sheet goes when the car changes under it', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession(), pro: true);
      c.createLayout(c.ref, 'Two');
      await settle(tester);
      await tester.tap(find.text('Two')); // the header's layout button
      await settle(tester);
      expect(find.text('New layout'), findsOneWidget);
      // Chosen in the Garage while this sheet waited on the Dashboard's tab:
      // it came back offering the new car's layouts from the old car's sheet.
      c.setTarget(VehicleTarget(car().copyWith(id: 'civic')));
      await settle(tester);
      expect(find.text('New layout'), findsNothing);
    });

    testWidgets('★ a tab switch with the Layouts sheet open throws nothing', (
      tester,
    ) async {
      final tab = ValueNotifier(0);
      final c = await pumpScreen(tester, newSession(), tab: tab);
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      tab.value = 1;
      await settle(tester);
      // It rebuilt a sibling route in the middle of the Dashboard's build.
      expect(tester.takeException(), isNull);
      expect(c.editing, isFalse);
    });

    testWidgets('★ a tile sheet whose tile is held after a lapse closes', (
      tester,
    ) async {
      final c = await pumpScreen(
        tester,
        newSession(),
        pro: true,
        tiles: const [...six, '012F'],
      );
      await enterEdit(tester);
      await tester.tap(find.byType(GaugeTile).at(6));
      await settle(tester);
      expect(find.text('Show as'), findsOneWidget);
      c.isPro = false;
      await settle(tester);
      // It went blank and stayed.
      expect(find.text('Show as'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('★ into edit mode, a tile keeps its node — focus stays', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final session = newSession();
      await pumpScreen(tester, session);
      unawaited(
        session.connect(MockTransport(traces['clean_can']!, speed: 100)),
      );
      await pumpUntil(tester, () => session.bus.of('0105').value != null);
      await tester.pump();
      final before = nodeOf('0105').id;
      // Rebuilt, every tile's node went, and VoiceOver's focus with it.
      tester.semantics.customAction(
        tileNode('0105'),
        TileActions.editDashboard,
      );
      await settle(tester);
      expect(nodeOf('0105').id, before);
      handle.dispose();
      await quiesce(tester, session);
    });

    testWidgets('★ the Pro on "New layout" is said, not only shown', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, newSession());
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      expect(
        find.semantics.byLabel(RegExp('^New layout, Pro')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('★ an armed Delete never falls on another layout', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession(), pro: true);
      c.createLayout(c.ref, 'Two');
      await settle(tester);
      await tester.tap(find.text('Two')); // the header's layout button
      await settle(tester);
      await tester.tap(find.text('Delete “Two”'));
      await settle(tester);
      expect(find.text('Tap again to delete “Two”'), findsOneWidget);
      await tester.tap(find.text('Main'));
      await settle(tester);
      // The same armed button, now for Main, deleted it on the next tap.
      await tester.tap(find.textContaining('Delete “Main”'));
      await settle(tester);
      expect(
        c.layouts,
        hasLength(2),
        reason: 'one tap arms, it does not delete',
      );
    });

    testWidgets('★ a failed save is said once, and after Done still has '
        'its way to try again', (tester) async {
      final repo = _RefusingRepo();
      final c = await pumpScreen(tester, newSession(), repository: repo);
      await settle(tester);
      await enterEdit(tester);
      c.remove(c.ref, '0142');
      await settle(tester);
      // The event line and the error line said it twice.
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      // "Tap Done to try again" — with Done gone.
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      repo.refuse = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.textContaining("Couldn't save"), findsNothing);
      expect(repo.rows.values.single.tilesJson, isNot(contains('0142')));
    });

    testWidgets('★ the last Undo going does not hand its node to Layouts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      c.remove(c.ref, '0142');
      await settle(tester);
      final before = tester.getSemantics(find.text('Layouts')).id;
      c.undo();
      await settle(tester);
      // Unkeyed, the focused Undo's node became "Layouts".
      expect(tester.getSemantics(find.text('Layouts')).id, before);
      handle.dispose();
    });

    testWidgets('★ a tile moved first keeps "Move later" on its own node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpScreen(tester, newSession());
      await enterEdit(tester);
      await tester.tap(find.byType(GaugeTile).at(1));
      await settle(tester);
      final before = tester.getSemantics(find.text('Move later')).id;
      await tester.tap(find.text('Move earlier'));
      await settle(tester);
      expect(c.tiles.first.pid, six[1]);
      // Unkeyed, the focused "Move earlier" became "Move later" in place.
      expect(tester.getSemantics(find.text('Move later')).id, before);
      handle.dispose();
    });

    testWidgets('★ a name the database cannot hold says why, and stays', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession(), pro: true);
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      await tester.tap(find.text('Rename “Main”'));
      await settle(tester);
      // Forty characters to the field, 41 to the database: an emoji is two.
      await tester.enterText(find.byType(TextField), '${'x' * 39}🚗');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.textContaining('Keep it to 40 characters'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget, reason: 'still open');
      expect(c.active!.name, 'Main');
    });

    testWidgets('★ the name sheet goes when the car starts moving', (
      tester,
    ) async {
      final moving = ValueNotifier(false);
      await pumpScreen(tester, newSession(), pro: true, moving: moving);
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      await tester.tap(find.text('New layout'));
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      moving.value = true;
      await settle(tester);
      // §8.4: no typing a name above 5 km/h.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('★ the name sheet goes when its layout is not shown any more', (
      tester,
    ) async {
      final c = await pumpScreen(tester, newSession(), pro: true);
      await enterEdit(tester);
      await tester.tap(find.text('Layouts'));
      await settle(tester);
      await tester.tap(find.text('Rename “Main”'));
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      c.setTarget(VehicleTarget(car().copyWith(id: 'civic')));
      await settle(tester);
      // Save was refused as stale, and the sheet closed without a word.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('★ no car, no layout button — even on Pro', (tester) async {
      await pumpScreen(
        tester,
        newSession(),
        pro: true,
        target: const NoVehicleTarget(),
      );
      expect(find.text('Main'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  test('columnsFor: two up while a line of text still fits', () {
    const one = TextScaler.linear(1), big = TextScaler.linear(2);
    expect(DashboardGrid.columnsFor(320, one), 2);
    expect(DashboardGrid.columnsFor(320, const TextScaler.linear(1.35)), 1);
    expect(DashboardGrid.columnsFor(390, const TextScaler.linear(1.5)), 2);
    expect(DashboardGrid.columnsFor(390, big), 1);
    expect(DashboardGrid.columnsFor(768, big), 2);
  });

  group('★ what the car is asked — §B.12, §8.4', () {
    testWidgets('★ a removed tile stops costing a round trip; Speed is asked '
        'while editing', (tester) async {
      final session = newSession();
      final transport = MockTransport(traces['clean_can']!, speed: 100);
      final c = await pumpScreen(
        tester,
        session,
        tiles: const ['0105', '010C'],
      );
      unawaited(session.connect(transport));
      await pumpUntil(tester, () => session.bus.of('0105').value != null);
      c.beginEditing();
      c.remove(c.ref, '0105');
      transport.written.clear();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(transport.written, isNot(contains('0105')));
      expect(transport.written, contains('010D'), reason: '§8.4 while editing');
      await quiesce(tester, session);
    });

    for (final (trace, moving) in [
      ('headers_can', true),
      ('dtc_scan_can', false),
    ]) {
      testWidgets(
        '★ the speed gate on $trace: ${moving ? 'moving' : 'parked'}',
        (tester) async {
          final session = newSession();
          final gate = SpeedGate(
            speed: session.bus.of(SpeedGate.pid),
            clock: session.clock,
          );
          addTearDown(gate.dispose);
          session.setVisible({'010D'});
          unawaited(session.connect(MockTransport(traces[trace]!, speed: 100)));
          await pumpUntil(tester, () => session.bus.of('010D').value != null);
          expect(gate.moving.value, moving);
          await quiesce(tester, session);
        },
      );
    }
  });
}

/// A disk that refuses every write until told otherwise.
class _RefusingRepo implements LayoutRepository {
  bool refuse = true;
  final rows = <String, DashboardLayoutRow>{};

  @override
  Future<List<DashboardLayoutRow>> forVehicle(String vehicleId) async => [
    for (final r in rows.values)
      if (r.vehicleId == vehicleId) r,
  ];

  @override
  Future<void> save(DashboardLayoutRow row) async {
    if (refuse) throw StateError('disk full');
    rows[row.id] = row;
  }

  @override
  Future<void> delete(String id) async {
    if (refuse) throw StateError('disk full');
    rows.remove(id);
  }
}
