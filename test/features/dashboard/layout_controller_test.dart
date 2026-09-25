import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/layout_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/widgets/gauge_tile.dart';
import 'package:torque_obd2/features/dashboard/dashboard_layout.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/session/gauge_catalog.dart';

/// SPEC §5.3 layouts per vehicle and §7.2's "6 tiles, 1 layout", on a real
/// database: the controller is the one writer and the one publisher.
void main() {
  late AppDatabase db;
  late LayoutRepository repo;
  late VehicleRow golf;
  late List<Set<String>> published;
  final moving = ValueNotifier<bool>(false);

  const nine = [
    '010C', '010D', '0105', '0104', '0111', '0142', '012F', '0110', '010E', //
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LayoutRepository(db);
    golf = await VehicleRepository(db)
        .create(nickname: 'Golf', fuel: VehicleFuel.petrol);
    published = [];
    moving.value = false;
  });
  tearDown(() => db.close());

  DashboardLayoutController controller({bool withRepo = true}) {
    final c = DashboardLayoutController(
      repository: withRepo ? repo : null,
      publish: published.add,
      moving: moving,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<DashboardLayoutController> forGolf({bool pro = false}) async {
    final c = controller()..isPro = pro;
    c.setTarget(VehicleTarget(golf));
    await Future<void>.delayed(Duration.zero);
    await c.idle;
    expect(c.loaded, isTrue);
    return c;
  }

  Future<List<DashboardLayoutRow>> rows() => repo.forVehicle(golf.id);

  Future<void> storeLayout(List<String> pids, {String id = 'l1', int at = 0}) =>
      repo.save(
        DashboardLayoutRow(
          id: id.padRight(32, '0'),
          vehicleId: golf.id,
          name: 'Main',
          tilesJson: encodeTiles([for (final p in pids) LayoutTile(p)]),
          createdAt: DateTime.utc(2026, 9, 1),
          selectedAt: DateTime.utc(2026, 9, 1, 0, at),
        ),
      );

  List<String> pids(List<LayoutTile> t) => [for (final x in t) x.pid];

  group('★ LayoutPlan — §7.2', () {
    test('★ free shows the first six by position; Pro shows all', () {
      final tiles = [for (final p in nine) LayoutTile(p)];
      expect(pids(LayoutPlan.shown(tiles, isPro: false)), nine.take(6));
      expect(pids(LayoutPlan.held(tiles, isPro: false)), nine.skip(6));
      expect(LayoutPlan.shown(tiles, isPro: true), tiles);
    });

    test('★ the cap counts tiles stored, not shown', () {
      expect(LayoutPlan.canAddTile(5, isPro: false), isTrue);
      expect(LayoutPlan.canAddTile(6, isPro: false), isFalse, reason: '7th');
      expect(LayoutPlan.canAddTile(9, isPro: false), isFalse);
      expect(LayoutPlan.canAddTile(30, isPro: true), isTrue);
      expect(LayoutPlan.canHaveAnotherLayout(1, isPro: false), isFalse);
      expect(LayoutPlan.canHaveAnotherLayout(3, isPro: true), isTrue);
    });
  });

  test('★ the 7th tile is a door on free, and nothing is written', () async {
    final c = await forGolf();
    expect(c.beginEditing(), EditOutcome.done);
    expect(c.add(c.ref, '015C'), EditOutcome.needsPro);
    await c.idle;
    expect(await rows(), isEmpty, reason: 'nothing saved');
    c.isPro = true;
    expect(c.add(c.ref, '015C'), EditOutcome.done);
    await c.idle;
    expect(decodeTiles((await rows()).single.tilesJson), hasLength(7));
  });

  test('★ after a lapse: six shown and polled, the rest kept; a removal '
      'saves the rest, never trims', () async {
    await storeLayout(nine);
    final c = await forGolf();
    expect(pids(c.shown), nine.take(6));
    expect(published.last, nine.take(6).toSet(), reason: 'held not polled');

    c.beginEditing();
    expect(c.remove(c.ref, '0105'), EditOutcome.done);
    expect(c.lastEvent!.revealed, GaugeCatalog.labelFor('012F'));
    await c.idle;
    expect(decodeTiles((await rows()).single.tilesJson), hasLength(8));
    expect(c.shown.map((t) => t.pid), contains('012F'), reason: 'now shown');

    expect(c.undo(), EditOutcome.done);
    await c.idle;
    expect(pids(decodeTiles((await rows()).single.tilesJson)), nine);

    // Moves stay among the six shown.
    c.moveToEdge(c.ref, '010C', first: false);
    expect(c.tiles.indexWhere((t) => t.pid == '010C'), 5);
    await c.idle;
    final before = (await rows()).single.tilesJson;
    c.isPro = true;
    c.isPro = false;
    await c.idle;
    expect(
      (await rows()).single.tilesJson,
      before,
      reason: 'a flip writes nothing',
    );
  });

  test(
    '★ never the last tile — an empty set would bring back the defaults',
    () async {
      await storeLayout(['010C']);
      final c = await forGolf();
      c.beginEditing();
      expect(c.remove(c.ref, '010C'), EditOutcome.lastTile);
      expect(published.every((s) => s.isNotEmpty), isTrue);
    },
  );

  test(
    '★ undo restores the exact list, several deep, and clears on Done',
    () async {
      final c = await forGolf();
      c.beginEditing();
      final original = c.tiles;
      c.move(c.ref, '0105', 0);
      c.setVariant(c.ref, '010C', GaugeVariant.arc);
      c.replace(c.ref, '0142', '015C');
      c.remove(c.ref, '0111');
      expect(c.undoLabel, 'Undo remove ${GaugeCatalog.labelFor('0111')}');
      for (var i = 0; i < 4; i++) {
        expect(c.undo(), EditOutcome.done);
      }
      expect(c.tiles, original);
      c.remove(c.ref, '0111');
      c.endEditing();
      expect(c.canUndo, isFalse);
    },
  );

  test(
    '★ a ref from before the car changed is stale, and changes nothing',
    () async {
      final civic = await VehicleRepository(db)
          .create(nickname: 'Civic', fuel: VehicleFuel.petrol);
      final c = await forGolf();
      c.beginEditing();
      final golfRef = c.ref;
      c.setTarget(VehicleTarget(civic));
      await Future<void>.delayed(Duration.zero);
      expect(c.editing, isFalse, reason: 'the change ends edit mode');
      c.beginEditing();
      expect(c.remove(golfRef, '0105'), EditOutcome.stale);
      await c.idle;
      expect(await rows(), isEmpty);
      expect(await repo.forVehicle(civic.id), isEmpty);
    },
  );

  test(
    '★ a ref from before a reload is stale — same layout, other tiles',
    () async {
      await storeLayout(['0105', '010C']);
      final c = await forGolf();
      c.beginEditing();
      final before = c.ref;
      await storeLayout(['0105', '015C']); // written behind its back
      await c.reload();
      c.beginEditing();
      expect(c.remove(before, '0105'), EditOutcome.stale);
      expect(pids(c.tiles), ['0105', '015C']);
    },
  );

  test('★ a save queued before the switch lands on its own car', () async {
    final civic = await VehicleRepository(db)
        .create(nickname: 'Civic', fuel: VehicleFuel.petrol);
    final c = await forGolf();
    c.beginEditing();
    c.remove(c.ref, '0105');
    c.setTarget(VehicleTarget(civic));
    await c.idle;
    await Future<void>.delayed(Duration.zero);
    expect(
      pids(decodeTiles((await rows()).single.tilesJson)),
      isNot(contains('0105')),
    );
    expect(await repo.forVehicle(civic.id), isEmpty);
    expect(pids(c.tiles), GaugeCatalog.defaultLayout, reason: 'Civic defaults');
  });

  test('★ Demo edits live in memory; the table is untouched', () async {
    await storeLayout(['010C', '0105']);
    final c = await forGolf();
    c.setTarget(const DemoTarget());
    expect(c.beginEditing(), EditOutcome.done);
    c.remove(c.ref, '0105');
    c.setVariant(c.ref, '010C', GaugeVariant.bar);
    await c.idle;
    expect(pids(decodeTiles((await rows()).single.tilesJson)), [
      '010C',
      '0105',
    ]);
    c.setTarget(VehicleTarget(golf));
    await Future<void>.delayed(Duration.zero);
    expect(pids(c.tiles), ['010C', '0105'], reason: 'the stored layout');
  });

  test('★ no vehicle: the defaults, refused editing, no row', () async {
    final c = controller();
    c.setTarget(const NoVehicleTarget());
    expect(c.loaded, isTrue);
    expect(published.last, GaugeCatalog.defaultLayout.toSet());
    expect(c.beginEditing(), EditOutcome.noVehicle);
    expect(await db.select(db.dashboardLayouts).get(), isEmpty);
  });

  test('the first edit writes one row, "Main", from the defaults', () async {
    final c = await forGolf();
    expect(await rows(), isEmpty, reason: 'nothing until an edit');
    c.beginEditing();
    c.remove(c.ref, '0142');
    await c.idle;
    final row = (await rows()).single;
    expect(row.name, 'Main');
    expect(
      pids(decodeTiles(row.tilesJson)),
      GaugeCatalog.defaultLayout.where((p) => p != '0142'),
    );
  });

  test('★ while the car\'s layout is read, nothing is published', () async {
    await storeLayout(['0105', '015C']);
    final c = controller();
    c.setTarget(VehicleTarget(golf));
    // A plan change mid-read: an empty set here would bring back the
    // session's own default six under a car whose layout says otherwise.
    c.isPro = true;
    expect(published, isEmpty, reason: 'never the default six first');
    await Future<void>.delayed(Duration.zero);
    expect(published, [
      {'0105', '015C'},
    ]);
  });

  test('★ what was removed stays removed across a cold launch', () async {
    final dir = await Directory.systemTemp.createTemp('layout_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    var fileDb = AppDatabase(NativeDatabase(file));
    final car = await VehicleRepository(fileDb)
        .create(nickname: 'Golf', fuel: VehicleFuel.petrol);
    var c = DashboardLayoutController(
      repository: LayoutRepository(fileDb),
      publish: (_) {},
    );
    c.setTarget(VehicleTarget(car));
    await Future<void>.delayed(Duration.zero);
    c.beginEditing();
    c.remove(c.ref, '0105');
    await c.idle;
    c.dispose();
    await fileDb.close();

    fileDb = AppDatabase(NativeDatabase(file));
    addTearDown(fileDb.close);
    c = DashboardLayoutController(
      repository: LayoutRepository(fileDb),
      publish: (_) {},
    );
    addTearDown(c.dispose);
    c.setTarget(VehicleTarget(car));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(pids(c.tiles), isNot(contains('0105')));
    expect(c.tiles, hasLength(5));
  });

  test('named layouts: a door on free; on Pro, copy, select, delete', () async {
    final c = await forGolf();
    expect(c.createLayout(c.ref, 'Track'), EditOutcome.needsPro);
    c.isPro = true;
    expect(c.createLayout(c.ref, '  '), EditOutcome.invalidName);
    expect(c.createLayout(c.ref, 'Track'), EditOutcome.done);
    expect(c.active!.name, 'Track');
    await c.idle;
    expect(await rows(), hasLength(2), reason: 'Main saved too');
    final main = c.layouts.firstWhere((l) => l.name == 'Main');
    expect(c.select(c.ref, main.id), EditOutcome.done);
    expect(c.active!.name, 'Main');
    expect(c.deleteLayout(c.ref, main.id), EditOutcome.done);
    expect(c.active!.name, 'Track');
    expect(c.deleteLayout(c.ref, c.active!.id), EditOutcome.lastTile);
    expect(c.rename(c.ref, c.active!.id, 'x' * 41), EditOutcome.invalidName);
    c.isPro = false;
    expect(c.rename(c.ref, c.active!.id, 'Daily'), EditOutcome.done);
    await c.idle;
    expect((await rows()).single.name, 'Daily');
  });

  group('★ what is polled — §B.12, §8.4', () {
    test('★ Speed is asked for while the phone\'s car is edited, and not '
        'after', () async {
      await storeLayout(['0105']);
      final c = await forGolf();
      expect(published.last, {'0105'});
      c.beginEditing();
      expect(published.last, {'0105', '010D'});
      c.endEditing();
      expect(published.last, {'0105'});
    });

    test('★ Demo is not the phone\'s car: no Speed, no gate', () async {
      // The default six include Speed; a layout without it shows whether
      // editing adds it.
      final c = DashboardLayoutController(
        publish: published.add,
        moving: moving,
        defaults: const [LayoutTile('0105')],
      );
      addTearDown(c.dispose);
      c.setTarget(const DemoTarget());
      moving.value = true;
      expect(c.beginEditing(), EditOutcome.done);
      expect(published.last, {'0105'});
      expect(c.gated, isFalse);
    });

    test('★ moving: editing is refused, and an open edit ends, kept', () async {
      final c = await forGolf();
      c.beginEditing();
      c.remove(c.ref, '0142');
      moving.value = true;
      expect(c.editing, isFalse);
      expect(c.lastEvent!.reason, EndReason.moving);
      expect(c.beginEditing(), EditOutcome.moving);
      await c.idle;
      expect(
        pids(decodeTiles((await rows()).single.tilesJson)),
        isNot(contains('0142')),
      );
    });

    test('a reorder or a style change publishes nothing new', () async {
      final c = await forGolf();
      c.beginEditing();
      final n = published.length;
      c.move(c.ref, '0105', 0);
      c.setVariant(c.ref, '0105', GaugeVariant.arc);
      expect(published.length, n);
    });
  });

  test('a failed save is said, and Done tries again', () async {
    final c = await forGolf();
    c.beginEditing();
    await db.close(); // the disk goes away
    c.remove(c.ref, '0142');
    await c.idle;
    expect(c.saveError, isTrue);
    expect(c.lastEvent!.kind, LayoutEventKind.saveFailed);
  });

  test('reload shows a row written behind the controller\'s back', () async {
    final c = await forGolf();
    await storeLayout(['015C'], at: 5);
    await c.reload();
    expect(pids(c.tiles), ['015C']);
  });

  group('decodeTiles never throws', () {
    test('bad input gives nothing, and what is readable is kept', () {
      expect(decodeTiles('not json'), isEmpty);
      expect(decodeTiles('{"a":1}'), isEmpty);
      expect(decodeTiles(null), isEmpty);
      expect(
        decodeTiles(
          '[1, {"pid": 5}, {"pid":"010C","variant":"warp"}, '
          '{"pid":"010C","variant":"arc"}, {"pid":"ZZZZ"}, '
          '{"pid":"0105","variant":"bar"}]',
        ),
        const [LayoutTile('010C'), LayoutTile('0105', GaugeVariant.bar)],
      );
    });

    test('encode then decode keeps order and styles', () {
      const tiles = [
        LayoutTile('0105', GaugeVariant.sparkline),
        LayoutTile('010C', GaugeVariant.arc),
      ];
      expect(decodeTiles(encodeTiles(tiles)), tiles);
    });
  });
}
