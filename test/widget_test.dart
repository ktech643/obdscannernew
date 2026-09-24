import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/models/models.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/dashboard_provider.dart';
import 'package:torque_obd2/providers/diagnostics_provider.dart';
import 'package:torque_obd2/providers/garage_provider.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/widgets/gauge_tile.dart';

void main() {
  late Persistence store;
  late AppDatabase db;
  late Directory docs;
  late Directory temp;

  setUp(() async {
    // A clean store per test, so one test's saved layout can't leak into the
    // next.
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
    // In memory: the shell only needs the repositories to exist, and a
    // real file would outlive the test.
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    docs = Directory.systemTemp.createTempSync('torque_widget_');
    addTearDown(() => docs.deleteSync(recursive: true));
    temp = Directory.systemTemp.createTempSync('torque_widget_tmp_');
    addTearDown(() => temp.deleteSync(recursive: true));
  });

  testWidgets('opens on the first-run flow', (tester) async {
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
    expect(find.text('You need an adapter'), findsNothing);
    expect(
      find.text("Read your car's error codes and watch live engine data."),
      findsOneWidget,
    );
  });

  testWidgets('the safety step is reachable and starts unacknowledged', (
    tester,
  ) async {
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

    final o = Provider.of<OnboardingProvider>(
      tester.element(find.text('Next')),
      listen: false,
    );
    o.goTo(3);
    await tester.pumpAndSettle();

    expect(find.text('Before you start'), findsOneWidget);
    expect(find.text('Agree and continue'), findsOneWidget);
    // Non-skippable: no Skip affordance on the final step.
    expect(find.text('Skip'), findsNothing);
    expect(o.safetyAcknowledged, isFalse);
  });

  group('health score', () {
    test('points lost always closes against 100', () {
      final dx = DiagnosticsProvider();
      expect(dx.healthScore + dx.pointsLost, 100);
    });

    test('reports when the itemised weights do not sum to the deduction', () {
      final dx = DiagnosticsProvider();
      // The listed causes overlap, so the raw total exceeds what was taken off.
      // The screen must say so rather than show a contradictory total.
      expect(dx.rawDeductionTotal, greaterThan(dx.pointsLost));
      expect(dx.breakdownIsExact, isFalse);
    });
  });

  group('safety gates', () {
    test('clearing codes is refused while the car is moving', () async {
      final dx = DiagnosticsProvider();
      expect(await dx.clearCodes(stationary: false), isFalse);
      expect(dx.hasFaults, isTrue);
      expect(await dx.clearCodes(stationary: true), isTrue);
      expect(dx.hasFaults, isFalse);
    });

    test('gauge editing is disabled above 5 km/h', () {
      final d = DashboardProvider(store);
      d.setSpeed(68);
      d.setEditing(true);
      expect(d.editing, isFalse);
      d.setSpeed(0);
      d.setEditing(true);
      expect(d.editing, isTrue);
    });
  });

  group('ad placement', () {
    test('never over a fault result, mid-scan, or above 5 km/h', () {
      final e = EntitlementProvider(store);
      expect(
        e.canShowBanner(onFaultResult: true, scanning: false, speedKmh: 0),
        isFalse,
      );
      expect(
        e.canShowBanner(onFaultResult: false, scanning: true, speedKmh: 0),
        isFalse,
      );
      expect(
        e.canShowBanner(onFaultResult: false, scanning: false, speedKmh: 60),
        isFalse,
      );
      expect(
        e.canShowBanner(onFaultResult: false, scanning: false, speedKmh: 0),
        isTrue,
      );
    });

    test('Pro never sees a banner', () {
      final pro = EntitlementProvider(store)..subscribe();
      expect(
        pro.canShowBanner(onFaultResult: false, scanning: false, speedKmh: 0),
        isFalse,
      );
    });
  });

  group('typing rules', () {
    test('zero is a value, not missing data', () {
      final d = DashboardProvider(store)..setScenario(DashboardScenario.hybrid);
      final rpm = d.tiles.firstWhere((t) => t.label == 'Engine RPM');
      expect(rpm.value, 0);
      expect(rpm.state, TileState.live);
      expect(rpm.valueText, '0');
    });

    test('an unsupported PID is distinct from a zero reading', () {
      final d = DashboardProvider(store)
        ..setScenario(DashboardScenario.degraded);
      final oil = d.tiles.firstWhere((t) => t.label == 'Oil temp');
      expect(oil.value, isNull);
      expect(oil.state, TileState.unsupported);
    });
  });

  group('staleness decay — the signature interaction', () {
    final at = DateTime(2026, 9, 4, 9, 41);
    GaugeReading tileAged(Duration age) => GaugeReading(
      pid: '010D',
      label: 'Speed',
      unit: 'km/h',
      value: 68,
      lastUpdated: at.subtract(age),
      expectedInterval: const Duration(milliseconds: 500),
    );

    test('live inside its expected interval', () {
      expect(
        tileAged(const Duration(milliseconds: 400)).stateAt(at),
        TileState.live,
      );
    });

    test('goes stale past 2x its interval and shows its age', () {
      final t = tileAged(const Duration(seconds: 4));
      expect(t.stateAt(at), TileState.stale);
      expect(t.ageNoteAt(at), '4 s ago');
      // The value is still shown — dimmed and dated, not hidden.
      expect(t.valueTextAt(at), '68');
    });

    test('drops to an em dash past 5 s', () {
      final t = tileAged(const Duration(seconds: 7));
      expect(t.stateAt(at), TileState.unavailable);
      expect(t.valueTextAt(at), '—');
    });

    test('a slow poll rate does not make a fresh tile look stale', () {
      // The same 1 s age is live at 2 Hz and stale at 8 Hz. Decay is measured
      // against the tile's own interval, not a fixed wall-clock delay.
      const age = Duration(seconds: 1);
      final slow = GaugeReading(
        pid: 'x',
        label: 'x',
        unit: '',
        value: 1,
        lastUpdated: at.subtract(age),
        expectedInterval: const Duration(seconds: 1),
      );
      final fast = GaugeReading(
        pid: 'x',
        label: 'x',
        unit: '',
        value: 1,
        lastUpdated: at.subtract(age),
        expectedInterval: const Duration(milliseconds: 125),
      );
      expect(slow.stateAt(at), TileState.live);
      expect(fast.stateAt(at), TileState.stale);
    });

    test('an unsupported PID never decays — it was never live', () {
      const t = GaugeReading(
        pid: '015C',
        label: 'Oil temp',
        unit: '°C',
        state: TileState.unsupported,
      );
      expect(t.stateAt(at), TileState.unsupported);
    });
  });

  group('VoiceOver labels speak what colour and opacity show', () {
    final at = DateTime(2026, 9, 4, 9, 41);

    test('a stale tile says so, and says how old it is', () {
      final t = GaugeReading(
        pid: '010D',
        label: 'Speed',
        unit: 'km/h',
        value: 68,
        lastUpdated: at.subtract(const Duration(seconds: 4)),
        expectedInterval: const Duration(milliseconds: 500),
      );
      final label = t.semanticLabelAt(at);
      expect(label, contains('4 s ago'));
      expect(label, contains('not live'));
    });

    test('caution is spoken as a word, never carried by colour alone', () {
      const t = GaugeReading(
        pid: '0105',
        label: 'Coolant',
        unit: '°C',
        value: 112,
        tone: Tone.caution,
      );
      expect(t.semanticLabelAt(at), contains('caution'));
    });

    test('unsupported is distinguished from missing', () {
      const unsupported = GaugeReading(
        pid: '015C',
        label: 'Oil temp',
        unit: '°C',
        state: TileState.unsupported,
      );
      final noData = GaugeReading(
        pid: '0104',
        label: 'Engine load',
        unit: '%',
        value: 34,
        lastUpdated: at.subtract(const Duration(seconds: 7)),
      );
      expect(
        unsupported.semanticLabelAt(at),
        contains('not available on this vehicle'),
      );
      expect(noData.semanticLabelAt(at), contains('no data'));
    });

    test('a live zero reads as a value, not as absent', () {
      const t = GaugeReading(
        pid: '010C',
        label: 'Engine RPM',
        unit: 'rpm',
        value: 0,
        note: 'EV mode',
      );
      expect(t.semanticLabelAt(at), 'Engine RPM, 0 rpm');
    });
  });

  group('tile treatments', () {
    test('figure is the default', () {
      final d = DashboardProvider(store);
      expect(d.defaultTileType, TileType.figure);
      expect(d.typeFor('010C'), TileType.figure);
    });

    test('with no tile selected, a pick retypes every tile', () {
      final d = DashboardProvider(store)..setTileType(TileType.dial);
      expect(d.defaultTileType, TileType.dial);
      for (final t in d.tiles) {
        expect(d.typeFor(t.pid), TileType.dial);
      }
    });

    test('with a tile selected, a pick changes only that tile', () {
      final d = DashboardProvider(store)
        ..selectTile('010C')
        ..setTileType(TileType.trace);
      expect(d.typeFor('010C'), TileType.trace);
      expect(d.typeFor('010D'), TileType.figure);
    });

    test(
      'apply-to-every-tile overrides a selection and clears per-tile types',
      () {
        final d = DashboardProvider(store)
          ..selectTile('010C')
          ..setTileType(TileType.trace)
          ..setApplyToEveryTile(true)
          ..setTileType(TileType.arc);
        // No tile is left on the old override — the grid can't end up
        // half-applied.
        for (final t in d.tiles) {
          expect(d.typeFor(t.pid), TileType.arc);
        }
      },
    );

    test('leaving edit mode drops the selection', () {
      final d = DashboardProvider(store)
        ..setSpeed(0)
        ..setEditing(true)
        ..selectTile('010C');
      expect(d.selectedPid, '010C');
      d.setEditing(false);
      expect(d.selectedPid, isNull);
    });

    test('choosing trace seeds a sample window so it is not a flat line', () {
      final d = DashboardProvider(store)..setTileType(TileType.trace);
      for (final t in d.tiles.where((t) => t.state != TileState.unsupported)) {
        expect(t.samples.length, greaterThan(1));
      }
    });
  });

  group('every treatment prints the number in figures', () {
    // The board's central rule: a dial is a second reading of the same value,
    // never the only one. If a treatment ever drops the numeral, this fails.
    for (final type in TileType.values) {
      testWidgets('${type.label} shows the numeral and its unit', (
        tester,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 180,
                child: GaugeTile(
                  type: type,
                  reading: const GaugeReading(
                    pid: '010D',
                    label: 'Speed',
                    unit: 'km/h',
                    value: 68,
                    position: 42,
                    cautionAt: 80,
                    criticalAt: 94,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('68'), findsOneWidget);
        expect(
          find.text(type.numeralInsideGraphic ? 'KM/H' : 'km/h'),
          findsOneWidget,
        );
      });
    }
  });

  group('persistence — the layout really does save per vehicle', () {
    test('tile types survive a relaunch', () async {
      DashboardProvider(store)
        ..selectTile('010C')
        ..setTileType(TileType.trace);

      // A second provider over the same store stands in for a relaunch.
      final relaunched = DashboardProvider(store);
      expect(relaunched.typeFor('010C'), TileType.trace);
      expect(relaunched.typeFor('010D'), TileType.figure);
    });

    test('tile order survives a relaunch', () async {
      final first = DashboardProvider(store);
      final movedPid = first.tiles[3].pid;
      first.reorder(3, 0);

      final relaunched = DashboardProvider(store);
      expect(relaunched.tiles.first.pid, movedPid);
    });

    test('the stored layout decides membership, not just order', () async {
      // A tile the user removed must stay removed, and one they added must
      // still be there — the stored list is the dashboard, not a sort key.
      store.setStringList(Keys.tileOrder('golf'), ['ATRV', '0105', '010F']);
      final d = DashboardProvider(store);
      expect(d.tiles.map((t) => t.pid), ['ATRV', '0105', '010F']);
    });

    test('adding and removing tiles survives a relaunch', () async {
      final d = DashboardProvider(store)..removeTile('0111');
      d.addTile(DashboardProvider.catalogue.firstWhere((c) => c.pid == '010F'));

      final relaunched = DashboardProvider(store);
      expect(relaunched.tiles.any((t) => t.pid == '0111'), isFalse);
      expect(relaunched.tiles.any((t) => t.pid == '010F'), isTrue);
    });

    test(
      'an unresolvable stored layout falls back rather than emptying',
      () async {
        store.setStringList(Keys.tileOrder('golf'), ['nope', 'also-nope']);
        expect(DashboardProvider(store).tiles, isNotEmpty);
      },
    );

    test('a layout key for another vehicle is not read', () async {
      DashboardProvider(store, vehicleId: 'polo')
        ..selectTile('010C')
        ..setTileType(TileType.dial);
      expect(
        DashboardProvider(store, vehicleId: 'golf').typeFor('010C'),
        TileType.figure,
      );
    });

    test('units and tier survive a relaunch', () async {
      SettingsProvider(store).setDistance(DistanceUnit.mi);
      EntitlementProvider(store).subscribe();
      expect(SettingsProvider(store).distance, DistanceUnit.mi);
      expect(EntitlementProvider(store).isPro, isTrue);
    });

    test('onboarding does not replay once completed', () async {
      OnboardingProvider(store).finish();
      expect(OnboardingProvider(store).complete, isTrue);
    });

    test('service records survive a relaunch', () async {
      final g = GarageProvider(store);
      final before = g.records.length;
      g.addRecord(
        ServiceRecord(
          id: 'new',
          title: 'Brake pads',
          date: DateTime(2026, 9, 4),
          odometerKm: 142500,
          cost: 180,
        ),
      );
      final relaunched = GarageProvider(store);
      expect(relaunched.records.length, before + 1);
      expect(relaunched.records.last.title, 'Brake pads');
    });

    test('a corrupt record costs that row, not the launch', () async {
      store.setString(Keys.serviceRecords, '[{"id":1},{"nope":true}]');
      expect(() => GarageProvider(store), returnsNormally);
      expect(GarageProvider(store).records, isEmpty);
    });
  });

  group('editing the dashboard', () {
    test('a tile can be retargeted, keeping its slot and its treatment', () {
      final d = DashboardProvider(store)
        ..selectTile('010D')
        ..setTileType(TileType.bar);
      final slot = d.tiles.indexWhere((t) => t.pid == '010D');
      final maf = DashboardProvider.catalogue.firstWhere(
        (c) => c.pid == '0110',
      );

      d.replaceTile('010D', maf);

      expect(d.tiles[slot].pid, '0110');
      expect(d.typeFor('0110'), TileType.bar);
      expect(d.tiles.any((t) => t.pid == '010D'), isFalse);
    });

    test('a PID already on the dashboard is not offered again', () {
      final d = DashboardProvider(store);
      final available = d.availablePids().map((p) => p.pid).toSet();
      for (final t in d.tiles) {
        expect(available.contains(t.pid), isFalse);
      }
    });

    test('adding the same PID twice is a no-op', () {
      final d = DashboardProvider(store);
      final before = d.tiles.length;
      d.addTile(d.tiles.first);
      expect(d.tiles.length, before);
    });

    test('removing a tile drops its treatment and its selection', () {
      final d = DashboardProvider(store)
        ..selectTile('010C')
        ..setTileType(TileType.dial);
      d.removeTile('010C');
      expect(d.selectedPid, isNull);
      expect(d.tiles.any((t) => t.pid == '010C'), isFalse);
    });
  });

  test('unknown codes never get a fabricated definition', () {
    final dx = DiagnosticsProvider();
    final unknown = dx.codes.firstWhere((c) => c.code == 'P1602');
    expect(unknown.hasDefinition, isFalse);
    expect(unknown.description, contains("we don't have a definition"));
  });
}
