import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/diagnostics/diagnostics_controller.dart';
import 'package:torque_obd2/features/garage/distance.dart';
import 'package:torque_obd2/features/garage/dtc_history_screen.dart';
import 'package:torque_obd2/features/garage/garage_controller.dart';
import 'package:torque_obd2/features/garage/garage_screen.dart';
import 'package:torque_obd2/features/garage/identity_prompt.dart';
import 'package:torque_obd2/features/garage/vehicle_identity.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/protocol/freeze_frame.dart';
import 'package:torque_obd2/protocol/vin_reader.dart';
import 'package:torque_obd2/session/adapter_discovery.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.5 (the vehicles) and §9.6 (which one is on the wire), driven by
/// a real session replaying recorded cars. The VIN every fixture reports
/// is `1HGBH41JXMN109186` — the ISO 3779 worked example, check digit X.
void main() {
  const civicVin = '1HGBH41JXMN109186';

  late final Map<String, ObdTrace> traces;
  setUpAll(() {
    traces = {
      for (final name in const [
        'headers_can',
        'vin_reread',
        'vin_corrupt',
        'no_dtcs',
      ])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  MockTransport transportFor(String name) =>
      MockTransport(traces[name]!, speed: 100);

  AppDatabase newDb() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  GarageController newGarage(AppDatabase db, {TripRepository? trips}) {
    final g = GarageController(
      vehicles: VehicleRepository(db),
      services: ServiceRepository(db),
      trips: trips,
      dtcs: DtcRepository(db),
    );
    addTearDown(g.dispose);
    return g;
  }

  ObdSession newSession() {
    final s = ObdSession(timeScale: 0.05);
    addTearDown(s.dispose);
    return s;
  }

  Future<VehicleRow> addCar(
    GarageController g,
    String nickname, {
    String? vin,
    bool vinUnverified = false,
  }) => g.add(
    nickname: nickname,
    fuel: VehicleFuel.petrol,
    vin: vin,
    vinUnverified: vinUnverified,
  );

  // ------------------------------------------------------------- pure

  group('★ §9.6 — resolveIdentity, the whole table', () {
    VehicleRow car(String id, {String? vin, bool primary = false}) =>
        VehicleRow(
          id: id,
          nickname: id,
          vinUnverified: false,
          make: '',
          model: '',
          trim: '',
          fuelType: VehicleFuel.petrol,
          supportsBatching: true,
          isPrimary: primary,
          createdAt: DateTime.utc(2026),
          vin: vin,
        );
    final read = VinReader.validate(civicVin)!;

    test('no VIN from the car keeps the primary and asks nothing', () {
      final v = resolveIdentity(
        read: null,
        primary: car('golf', vin: 'X', primary: true),
        garage: [car('golf', vin: 'X', primary: true)],
      );
      expect(v.kind, IdentityKind.noVin);
      expect(v.needsPrompt, isFalse);
    });

    test('the primary\'s own VIN is the primary', () {
      final p = car('civic', vin: civicVin, primary: true);
      final v = resolveIdentity(read: read, primary: p, garage: [p]);
      expect(v.kind, IdentityKind.primary);
      expect(v.needsPrompt, isFalse);
    });

    test('a primary with no VIN on record gets this one attached', () {
      final p = car('civic', primary: true);
      final v = resolveIdentity(read: read, primary: p, garage: [p]);
      expect(v.kind, IdentityKind.attached);
      expect(v.vin, civicVin);
      expect(v.needsPrompt, isFalse);
    });

    test('★ another vehicle\'s VIN names that vehicle and asks', () {
      final p = car('golf', vin: 'WVWZZZ1KZAW000001', primary: true);
      final other = car('civic', vin: civicVin);
      final v = resolveIdentity(read: read, primary: p, garage: [p, other]);
      expect(v.kind, IdentityKind.other);
      expect(v.match?.id, 'civic');
      expect(v.needsPrompt, isTrue);
    });

    test('a VIN the garage has never seen asks', () {
      final p = car('golf', vin: 'WVWZZZ1KZAW000001', primary: true);
      final v = resolveIdentity(read: read, primary: p, garage: [p]);
      expect(v.kind, IdentityKind.unknown);
      expect(v.needsPrompt, isTrue);
    });

    test(
      'an empty garage is unknown too — the car is offered, not assumed',
      () {
        final v = resolveIdentity(read: read, primary: null, garage: const []);
        expect(v.kind, IdentityKind.unknown);
        expect(v.vin, civicVin);
      },
    );

    test('an untrusted VIN is still compared, and says it is untrusted', () {
      final bad = VinReader.validate('1HGBH41JXMN109187')!;
      expect(bad.checkDigitValid, isFalse);
      final p = car('civic', vin: '1HGBH41JXMN109187', primary: true);
      final v = resolveIdentity(read: bad, primary: p, garage: [p]);
      expect(v.kind, IdentityKind.primary);
      expect(v.trusted, isFalse);
    });
  });

  group('★ Distance — the 2026-09-24 review', () {
    test('★ display survives a non-finite reading', () {
      expect(Distance.display(double.infinity, DistanceUnit.km), '\u2014');
      expect(Distance.display(double.nan, DistanceUnit.mi), '\u2014');
    });

    test('parse refuses what double.tryParse accepts but no odometer reads', () {
      expect(Distance.parse('Infinity'), isNull);
      expect(Distance.parse('NaN'), isNull);
      expect(Distance.parse('1' * 400), isNull);
      expect(Distance.parse('142380,5'), 142380.5, reason: 'still a number');
    });
  });

  group('Distance — kilometres on disk, the user\'s unit on screen', () {
    test('display groups thousands', () {
      expect(Distance.display(142380, DistanceUnit.km), '142,380');
      expect(Distance.display(999, DistanceUnit.km), '999');
      expect(Distance.display(0, DistanceUnit.km), '0');
    });

    test('miles convert both ways and round-trip', () {
      expect(Distance.display(160934.4, DistanceUnit.mi), '100,000');
      final km = Distance.toKm(100000, DistanceUnit.mi);
      expect(km, closeTo(160934.4, 0.01));
    });

    test('★ parse takes what people type, comma-decimal included (§9.7)', () {
      expect(Distance.parse('142,380'), 142380);
      expect(Distance.parse('142 380'), 142380);
      expect(Distance.parse('142380.5'), 142380.5);
      expect(Distance.parse('142380,5'), 142380.5);
      expect(Distance.parse('12,5'), 12.5);
      expect(Distance.parse('abc'), isNull);
      expect(Distance.parse(''), isNull);
    });
  });

  // ------------------------------------------------------ the controller

  group('★ the garage on disk', () {
    test('the first vehicle is primary; the rest are not', () async {
      final g = newGarage(newDb());
      await g.ready;
      expect(g.hasVehicle, isFalse);

      final a = await addCar(g, 'The Golf');
      final b = await addCar(g, 'The Civic');
      await Future<void>.delayed(Duration.zero);
      expect(g.primary?.id, a.id);
      expect(g.others.map((v) => v.id), [b.id]);

      await g.setPrimary(b.id);
      await Future<void>.delayed(Duration.zero);
      expect(g.primary?.id, b.id);
      expect(g.others.map((v) => v.id), [a.id]);
    });

    test('★ deleting a vehicle takes its trip files with it', () async {
      final dir = Directory.systemTemp.createTempSync('torque_garage_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final db = newDb();
      final trips = TripRepository(db, TripFiles(dir));
      final g = newGarage(db, trips: trips);
      await g.ready;

      final car = await addCar(g, 'The Golf');
      final trip = await trips.start(vehicleId: car.id);
      final file = File('${dir.path}/${trip.samplesFilePath}');
      expect(file.existsSync(), isTrue, reason: 'the trip file was written');

      await g.delete(car.id);
      await Future<void>.delayed(Duration.zero);
      expect(
        file.existsSync(),
        isFalse,
        reason: 'the cascade cannot reach files',
      );
      expect(g.hasVehicle, isFalse);
      expect(await trips.recent(car.id), isEmpty);
    });

    test(
      '★ overdue counts by date or by odometer; paused and done do not',
      () async {
        final db = newDb();
        final g = newGarage(db);
        await g.ready;
        final car = await addCar(g, 'The Golf');
        final s = ServiceRepository(db);
        final now = DateTime.utc(2026, 9, 12);

        await s.addReminder(
          vehicleId: car.id,
          title: 'Oil',
          dueDate: DateTime.utc(2026, 9, 1),
        );
        await s.addReminder(
          vehicleId: car.id,
          title: 'Tyres',
          dueOdometerKm: 150000,
        );
        await s.addReminder(
          vehicleId: car.id,
          title: 'Not yet',
          dueDate: DateTime.utc(2027, 1, 1),
        );
        final paused = await s.addReminder(
          vehicleId: car.id,
          title: 'Paused',
          dueDate: DateTime.utc(2026, 1, 1),
        );
        await s.setPaused(paused.id, true);
        final done = await s.addReminder(
          vehicleId: car.id,
          title: 'Done',
          dueDate: DateTime.utc(2026, 1, 1),
        );
        await s.complete(done.id, now: now);

        expect(await g.overdueCount(car.id, now: now), 1, reason: 'date only');
        expect(
          await g.overdueCount(car.id, odometerKm: 151000, now: now),
          2,
          reason: 'and the odometer one once we know the reading',
        );
      },
    );
  });

  group('★ §9.6 — which car is on the wire', () {
    Future<ObdSession> connected(String trace) async {
      final s = newSession();
      expect(await s.connect(transportFor(trace)), isTrue);
      addTearDown(s.disconnect);
      return s;
    }

    test('an empty garage: the car is offered, nothing is recorded', () async {
      final db = newDb();
      final g = newGarage(db);
      final s = await connected('headers_can');
      final v = await g.onConnected(s);

      expect(v.kind, IdentityKind.unknown);
      expect(v.vin, civicVin);
      expect(g.pendingIdentity, isNotNull, reason: 'the question is open');

      final car = await addCar(g, 'The Civic', vin: civicVin);
      await g.answerIdentity(car.id, session: s);
      await Future<void>.delayed(Duration.zero);
      expect(g.pendingIdentity, isNull);
      expect(g.primary?.id, car.id);
      // §4.2: what the handshake learned is cached on the vehicle.
      final row = await VehicleRepository(db).byId(car.id);
      expect(row?.cachedProtocol, 6);
      expect(row?.supportedPidsJson, isNotNull);
    });

    test('★ a primary with no VIN gets this one, and the cache', () async {
      final db = newDb();
      final g = newGarage(db);
      final car = await addCar(g, 'The Civic');
      final s = await connected('headers_can');
      final v = await g.onConnected(s);

      expect(v.kind, IdentityKind.attached);
      expect(g.pendingIdentity, isNull);
      final row = (await VehicleRepository(db).byId(car.id))!;
      expect(row.vin, civicVin);
      expect(row.vinUnverified, isFalse);
      expect(row.cachedProtocol, 6);
    });

    test('the primary\'s own VIN: no question, cache refreshed', () async {
      final db = newDb();
      final g = newGarage(db);
      final car = await addCar(g, 'The Civic', vin: civicVin);
      final s = await connected('headers_can');
      final v = await g.onConnected(s);
      expect(v.kind, IdentityKind.primary);
      expect(g.pendingIdentity, isNull);
      expect((await VehicleRepository(db).byId(car.id))!.cachedProtocol, 6);
    });

    test(
      '★ another vehicle\'s VIN: asked, and nothing cached until answered',
      () async {
        final db = newDb();
        final g = newGarage(db);
        final golf = await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
        final civic = await addCar(g, 'The Civic', vin: civicVin);
        final s = await connected('headers_can');
        final v = await g.onConnected(s);

        expect(v.kind, IdentityKind.other);
        expect(v.match?.id, civic.id);
        expect(g.pendingIdentity, isNotNull);
        final vehicles = VehicleRepository(db);
        expect((await vehicles.byId(golf.id))!.cachedProtocol, isNull);
        expect((await vehicles.byId(civic.id))!.cachedProtocol, isNull);

        await g.answerIdentity(civic.id, session: s);
        await Future<void>.delayed(Duration.zero);
        expect(g.primary?.id, civic.id);
        expect((await vehicles.byId(civic.id))!.cachedProtocol, 6);
      },
    );

    test(
      '★ a bad check digit is re-read once, and the second read wins',
      () async {
        final db = newDb();
        final g = newGarage(db);
        final car = await addCar(g, 'The Civic');
        final s = newSession();
        final t = transportFor('vin_reread');
        expect(await s.connect(t), isTrue);
        addTearDown(s.disconnect);

        final v = await g.onConnected(s);
        expect(t.written.where((c) => c == '0902').length, 2);
        expect(v.trusted, isTrue);
        final row = (await VehicleRepository(db).byId(car.id))!;
        expect(row.vin, civicVin);
        expect(row.vinUnverified, isFalse);
      },
    );

    test(
      '★ bad twice: stored flagged, compared as read, never decoded',
      () async {
        final db = newDb();
        final g = newGarage(db);
        final car = await addCar(g, 'The Civic');
        final s = newSession();
        final t = transportFor('vin_corrupt');
        expect(await s.connect(t), isTrue);
        addTearDown(s.disconnect);

        final v = await g.onConnected(s);
        expect(
          t.written.where((c) => c == '0902').length,
          2,
          reason: 'once more, not forever',
        );
        expect(v.kind, IdentityKind.attached);
        expect(v.trusted, isFalse);
        final row = (await VehicleRepository(db).byId(car.id))!;
        expect(row.vin, '1HGBH41JXMN109187');
        expect(row.vinUnverified, isTrue);
      },
    );

    test('a car with no Mode 09 (pre-2008) blocks nothing', () async {
      final db = newDb();
      final g = newGarage(db);
      final car = await addCar(g, 'The Old Corolla');
      final s = await connected('no_dtcs');
      final v = await g.onConnected(s);
      expect(v.kind, IdentityKind.noVin);
      expect(g.pendingIdentity, isNull);
      final row = (await VehicleRepository(db).byId(car.id))!;
      expect(row.vin, isNull, reason: 'nothing invented');
      expect(row.cachedProtocol, 6, reason: 'the cache still lands');
    });

    test('★ a connect cannot outrun the first read of the garage', () async {
      // A primary is on disk before the controller exists. Judging the VIN
      // against the not-yet-loaded (empty) list would call this car a
      // stranger and put the question up for a vehicle already there.
      final db = newDb();
      final seed = VehicleRepository(db);
      await seed.create(
        nickname: 'The Civic',
        fuel: VehicleFuel.petrol,
        vin: civicVin,
      );
      final s = await connected('headers_can');
      final g = newGarage(db);
      final v = await g.onConnected(s); // no `await g.ready` here on purpose
      expect(v.kind, IdentityKind.primary);
      expect(g.pendingIdentity, isNull);
    });

    test('★ LiveSession records nothing while the question is open', () async {
      final db = newDb();
      final vehicles = VehicleRepository(db);
      final golf = await vehicles.create(
        nickname: 'The Golf',
        fuel: VehicleFuel.diesel,
        vin: 'WVWZZZ1KZAW000001',
      );
      final civic = await vehicles.create(
        nickname: 'The Civic',
        fuel: VehicleFuel.petrol,
        vin: civicVin,
      );
      final discovery = FakeAdapterDiscovery(
        results: const [],
        transportBuilder: (_) => transportFor('headers_can'),
      );
      final live = LiveSession(
        session: ObdSession(timeScale: 0.05),
        discovery: discovery,
        dtcs: DtcRepository(db),
        vehicles: vehicles,
        services: ServiceRepository(db),
      );
      addTearDown(live.dispose);
      await live.garage!.ready;
      await Future<void>.delayed(Duration.zero);
      expect(live.diagnostics.vehicleId, golf.id, reason: 'the primary');

      expect(await live.session.connect(transportFor('headers_can')), isTrue);
      // The live edge fires the VIN read; give it the round trips.
      for (var i = 0; i < 50 && live.garage!.pendingIdentity == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(live.garage!.pendingIdentity?.kind, IdentityKind.other);
      expect(live.diagnostics.vehicleId, isNull, reason: 'nothing recorded');

      await live.garage!.answerIdentity(civic.id, session: live.session);
      await Future<void>.delayed(Duration.zero);
      expect(live.diagnostics.vehicleId, civic.id);
      await live.session.disconnect();
    });
  });

  // ---------------------------------------------------------- the screen

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String? reason,
  }) async {
    for (var i = 0; i < 600; i++) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for ${reason ?? 'condition'}');
  }

  Future<void> pumpGarage(
    WidgetTester tester, {
    required GarageController garage,
    required ObdSession session,
    bool isPro = false,
    DistanceUnit unit = DistanceUnit.km,
    VoidCallback? onUpgrade,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: IdentityPromptHost(
            garage: garage,
            session: session,
            unit: unit,
            isPro: isPro,
            onUpgrade: onUpgrade,
            child: Scaffold(
              backgroundColor: TorqueTokens.dark.surfaceDeep,
              body: SafeArea(
                child: GarageScreen(
                  controller: garage,
                  session: session,
                  isPro: isPro,
                  unit: unit,
                  onUpgrade: onUpgrade,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpUntil(tester, () => garage.loaded, reason: 'the first read');
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Finder field(int index) => find.byType(TextField).at(index);
  const nameField = 0, yearField = 4, odometerField = 5, vinField = 7;

  group('★ the vehicle form — §9.8, everything typed', () {
    testWidgets('an empty garage invites, and the form refuses a blank name', (
      tester,
    ) async {
      final g = newGarage(newDb());
      await pumpGarage(tester, garage: g, session: newSession());

      expect(find.text('No vehicle yet'), findsOneWidget);
      await tester.tap(find.text('Add a vehicle'));
      await settle(tester);
      expect(find.text('Add vehicle'), findsOneWidget, reason: 'the form');

      await tester.tap(find.text('Add vehicle'));
      await settle(tester);
      expect(find.text('Give the car a name.'), findsOneWidget);
      expect(g.hasVehicle, isFalse);
    });

    testWidgets(
      '★ a VIN is refused with the reason, and a bad check digit is allowed flagged',
      (tester) async {
        final g = newGarage(newDb());
        await pumpGarage(tester, garage: g, session: newSession());
        await tester.tap(find.text('Add a vehicle'));
        await settle(tester);
        await tester.enterText(field(nameField), 'The Civic');

        await tester.enterText(field(vinField), '1HGBH41JXMN10918');
        await tester.pump();
        expect(find.text('A VIN is exactly 17 characters.'), findsOneWidget);

        await tester.enterText(field(vinField), '1HGBH41JXMN1O9186');
        await tester.pump();
        expect(find.textContaining('never contains I, O or Q'), findsOneWidget);

        await tester.enterText(field(vinField), '1HGBH41JXMN109187');
        await tester.pump();
        expect(
          find.textContaining('check digit does not match'),
          findsOneWidget,
        );

        await tester.tap(find.text('Add vehicle'));
        await pumpUntil(tester, () => g.hasVehicle, reason: 'the save');
        await settle(tester);
        final row = g.primary!;
        expect(row.vin, '1HGBH41JXMN109187');
        expect(row.vinUnverified, isTrue);
        // Back on the garage: the card says so, and never shows the VIN whole.
        expect(find.text('The Civic'), findsOneWidget);
        expect(find.textContaining('failed its check digit'), findsOneWidget);
        // Typed, not read: the card must not claim a re-read that never
        // happened.
        expect(find.textContaining('twice'), findsNothing);
        // The fuel has its own row; with no make, model or year there is no
        // subtitle, rather than the fuel twice.
        expect(find.text('Petrol'), findsOneWidget);
        expect(find.text('1HGBH41JXMN109187'), findsNothing);
        expect(find.text(VinReader.mask('1HGBH41JXMN109187')), findsOneWidget);
      },
    );

    testWidgets('year and odometer are bounded; the odometer takes commas', (
      tester,
    ) async {
      final g = newGarage(newDb());
      await pumpGarage(tester, garage: g, session: newSession());
      await tester.tap(find.text('Add a vehicle'));
      await settle(tester);
      await tester.enterText(field(nameField), 'The Golf');
      await tester.enterText(field(yearField), '1900');
      await tester.enterText(field(odometerField), '3000000');
      await tester.tap(find.text('Add vehicle'));
      await settle(tester);
      expect(find.textContaining('A year between'), findsOneWidget);
      expect(find.textContaining('A reading between 0 and'), findsOneWidget);
      expect(g.hasVehicle, isFalse);

      await tester.enterText(field(yearField), '2014');
      await tester.enterText(field(odometerField), '142,380');
      await tester.tap(find.text('Add vehicle'));
      await pumpUntil(tester, () => g.hasVehicle);
      await settle(tester);
      expect(g.primary!.odometerKm, 142380);
      expect(g.primary!.year, 2014);
      expect(find.text('142,380 km'), findsOneWidget);
    });

    testWidgets('★ one vehicle on the free plan; Pro adds more', (
      tester,
    ) async {
      final g = newGarage(newDb());
      await addCar(g, 'The Golf');
      await pumpGarage(tester, garage: g, session: newSession());
      await settle(tester);

      await tester.tap(find.text('Add a vehicle'));
      await settle(tester);
      expect(find.text('One vehicle on the free plan'), findsOneWidget);
      expect(find.text('Add vehicle'), findsNothing, reason: 'no form');
      await tester.tap(find.text('Not now'));
      await settle(tester);

      await pumpGarage(tester, garage: g, session: newSession(), isPro: true);
      await tester.tap(find.text('Add a vehicle'));
      await settle(tester);
      expect(find.text('Add vehicle'), findsOneWidget, reason: 'the form');
    });

    testWidgets('★ §7.3 — the locked door opens the paywall', (tester) async {
      final g = newGarage(newDb());
      await addCar(g, 'The Golf');
      var upgrades = 0;
      await pumpGarage(
        tester,
        garage: g,
        session: newSession(),
        onUpgrade: () => upgrades++,
      );
      await settle(tester);

      await tester.tap(find.text('Add a vehicle'));
      await settle(tester);
      await tester.tap(find.text('See Pro'));
      await settle(tester);
      expect(upgrades, 1);
      expect(find.text('Add vehicle'), findsNothing, reason: 'still no form');
    });

    testWidgets('delete is two steps and names what goes with it', (
      tester,
    ) async {
      final g = newGarage(newDb());
      await addCar(g, 'The Golf');
      await pumpGarage(tester, garage: g, session: newSession());
      await settle(tester);

      await tester.tap(find.text('The Golf'));
      await settle(tester);
      await tester.tap(find.text('Delete…'));
      await settle(tester);
      expect(find.text('Delete The Golf?'), findsOneWidget);
      expect(find.textContaining('trip recorded for it goes too'), findsOne);
      await tester.tap(find.text('Delete'));
      await pumpUntil(tester, () => !g.hasVehicle, reason: 'the delete');
      await settle(tester);
      expect(find.text('No vehicle yet'), findsOneWidget);
    });
  });

  group('★ the counts on the card follow the database', () {
    testWidgets('a scan on another tab shows up as a scan here', (
      tester,
    ) async {
      // Found by running it: the tab stays mounted, and a count read on
      // first build is the count for ever unless something re-reads it.
      final db = newDb();
      final g = newGarage(db);
      final car = await addCar(g, 'The Civic');
      await pumpGarage(tester, garage: g, session: newSession());
      await pumpUntil(tester, () => find.text('0 scans').evaluate().isNotEmpty);

      await DtcRepository(db)
          .recordScan(vehicleId: car.id, codes: const [], milOn: false);
      await pumpUntil(
        tester,
        () => find.text('1 scan').evaluate().isNotEmpty,
        reason: 'the count to follow the scan',
      );
    });
  });

  group('★ §9.6 on screen', () {
    testWidgets(
      'another vehicle\'s VIN puts the question up; Switch answers it',
      (tester) async {
        final db = newDb();
        final g = newGarage(db);
        await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
        final civic = await addCar(g, 'The Civic', vin: civicVin);
        final session = newSession();
        await pumpGarage(tester, garage: g, session: session);
        await settle(tester);

        unawaited(session.connect(transportFor('headers_can')));
        await pumpUntil(tester, () => session.isLive, reason: 'the link');
        unawaited(g.onConnected(session));
        await pumpUntil(
          tester,
          () => g.pendingIdentity != null,
          reason: 'the verdict',
        );
        await settle(tester);

        expect(find.text('This is The Civic'), findsOneWidget);
        expect(find.byType(IdentitySheet), findsOneWidget);
        await tester.tap(find.text('Switch to The Civic'));
        await pumpUntil(
          tester,
          () => g.primary?.id == civic.id,
          reason: 'the switch',
        );
        await settle(tester);
        expect(g.pendingIdentity, isNull);
        expect(find.byType(IdentitySheet), findsNothing);
        // And the card now shows the car on the wire as connected.
        expect(find.text('Connected'), findsOneWidget);

        unawaited(session.disconnect());
        await settle(tester);
      },
    );

    testWidgets('an unknown VIN offers the form with the VIN filled in', (
      tester,
    ) async {
      final g = newGarage(newDb());
      final session = newSession();
      await pumpGarage(tester, garage: g, session: session);

      unawaited(session.connect(transportFor('headers_can')));
      await pumpUntil(tester, () => session.isLive);
      unawaited(g.onConnected(session));
      await pumpUntil(tester, () => g.pendingIdentity != null);
      await settle(tester);

      expect(find.text('Add this car?'), findsOneWidget);
      await tester.tap(find.text('Add a vehicle').last);
      await settle(tester);
      expect(find.text('Add vehicle'), findsOneWidget, reason: 'the form');
      final vin = tester.widget<TextField>(field(vinField));
      expect(vin.controller!.text, civicVin);

      await tester.enterText(field(nameField), 'The Civic');
      await tester.tap(find.text('Add vehicle'));
      await pumpUntil(
        tester,
        () => g.pendingIdentity == null,
        reason: 'answered',
      );
      await settle(tester);
      expect(g.primary?.vin, civicVin);
      expect(find.byType(IdentitySheet), findsNothing);

      unawaited(session.disconnect());
      await settle(tester);
    });
  });

  group('★ §9.6 meets §7.2', () {
    Future<(GarageController, ObdSession)> unknownCarOnTheWire(
      WidgetTester tester, {
      required bool isPro,
      VoidCallback? onUpgrade,
    }) async {
      final g = newGarage(newDb());
      await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
      final session = newSession();
      await pumpGarage(
        tester,
        garage: g,
        session: session,
        isPro: isPro,
        onUpgrade: onUpgrade,
      );
      unawaited(session.connect(transportFor('headers_can')));
      await pumpUntil(tester, () => session.isLive);
      unawaited(g.onConnected(session));
      await pumpUntil(tester, () => g.pendingIdentity != null);
      await settle(tester);
      expect(find.text('A car the garage does not know'), findsOneWidget);
      return (g, session);
    }

    testWidgets('★ the prompt is not a way round the one-vehicle plan', (
      tester,
    ) async {
      final (g, session) = await unknownCarOnTheWire(tester, isPro: false);
      expect(find.text('Add it as a new vehicle'), findsNothing);
      expect(find.text(IdentitySheet.proNote), findsOneWidget);
      await tester.tap(find.text('Record under The Golf anyway'));
      await pumpUntil(tester, () => g.pendingIdentity == null);
      await settle(tester);
      expect(g.all, hasLength(1));
      // The session's timers must be gone before the body ends.
      unawaited(session.disconnect());
      await settle(tester);
    });

    testWidgets('★ §7.3 — the locked answer opens the paywall too', (
      tester,
    ) async {
      var upgrades = 0;
      final (g, session) = await unknownCarOnTheWire(
        tester,
        isPro: false,
        onUpgrade: () => upgrades++,
      );
      await tester.tap(find.text('See Pro'));
      await settle(tester);
      expect(upgrades, 1);
      // The question is still open — Pro was only shown, not bought.
      expect(g.pendingIdentity, isNotNull);
      await tester.tap(find.text('Record under The Golf anyway'));
      await pumpUntil(tester, () => g.pendingIdentity == null);
      await settle(tester);
      unawaited(session.disconnect());
      await settle(tester);
    });

    testWidgets('★ bought Pro while the sheet is open: it offers the new '
        'vehicle at once', (tester) async {
      // The sheet was built once with the free plan's answer; after a
      // purchase from its own "See Pro" it still offered only "record
      // under the other car".
      final g = newGarage(newDb());
      await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
      final session = newSession();
      final pro = ValueNotifier(false);
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AdaptiveScope(
          platform: const FakePlatform(isAndroid: false),
          child: MaterialApp(
            theme: torqueTheme(),
            home: ValueListenableBuilder<bool>(
              valueListenable: pro,
              builder: (_, isPro, _) => IdentityPromptHost(
                garage: g,
                session: session,
                isPro: isPro,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await pumpUntil(tester, () => g.loaded);
      unawaited(session.connect(transportFor('headers_can')));
      await pumpUntil(tester, () => session.isLive);
      unawaited(g.onConnected(session));
      await pumpUntil(tester, () => g.pendingIdentity != null);
      await settle(tester);
      expect(find.text('Add it as a new vehicle'), findsNothing);

      pro.value = true;
      await settle(tester);
      expect(find.text('Add it as a new vehicle'), findsOneWidget);
      unawaited(session.disconnect());
      await settle(tester);
    });

    testWidgets('Pro is offered the new vehicle', (tester) async {
      final (g, session) = await unknownCarOnTheWire(tester, isPro: true);
      expect(find.text('Add it as a new vehicle'), findsOneWidget);
      await tester.tap(find.text('Add it as a new vehicle'));
      await settle(tester);
      expect(find.text('Add vehicle'), findsOneWidget, reason: 'the form');
      expect(find.byType(IdentitySheet), findsNothing, reason: 'not re-shown');
      expect(g.pendingIdentity, isNotNull, reason: 'open until saved');
      unawaited(session.disconnect());
      await settle(tester);
    });
  });

  group('diagnostic history', () {
    testWidgets('lists every snapshot as what it was', (tester) async {
      final db = newDb();
      final repo = DtcRepository(db);
      final car = await VehicleRepository(db)
          .create(nickname: 'The Civic', fuel: VehicleFuel.petrol);
      await repo.recordScan(
        vehicleId: car.id,
        codes: const [RawDtc('P0301', DtcMode.stored)],
        milOn: true,
        now: DateTime.utc(2026, 9, 1, 10, 0),
      );
      await repo.beginClear(
        vehicleId: car.id,
        codes: const [RawDtc('P0301', DtcMode.stored)],
        milOn: true,
        now: DateTime.utc(2026, 9, 2, 10, 0),
      );

      await tester.pumpWidget(
        AdaptiveScope(
          platform: const FakePlatform(isAndroid: false),
          child: MaterialApp(
            theme: torqueTheme(),
            home: DtcHistoryScreen(vehicle: car, dtcs: repo),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Before clear · never verified'), findsOneWidget);
      expect(find.text('1 code · light on'), findsNWidgets(2));
      expect(find.text('P0301'), findsNWidgets(2));
    });

    testWidgets('★ the freeze frame a snapshot kept can be opened, in the '
        'user\'s units', (tester) async {
      // §B.22 says the snapshot keeps the copy; the review found no screen
      // ever showed it again.
      final db = newDb();
      final repo = DtcRepository(db);
      final car = await VehicleRepository(db)
          .create(nickname: 'The Civic', fuel: VehicleFuel.petrol);
      await repo.beginClear(
        vehicleId: car.id,
        codes: const [RawDtc('P0301', DtcMode.stored)],
        freezeFrame: const FreezeFrame(
          dtc: 'P0301',
          values: {'010C': 750, '0105': 50},
        ),
        now: DateTime.utc(2026, 9, 2, 10, 0),
      );
      await tester.pumpWidget(
        AdaptiveScope(
          platform: const FakePlatform(isAndroid: false),
          child: MaterialApp(
            theme: torqueTheme(),
            home: DtcHistoryScreen(
              vehicle: car,
              dtcs: repo,
              temperature: TemperatureUnit.fahrenheit,
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.textContaining('freeze frame at P0301'), findsOneWidget);

      await tester.tap(find.text('Show the freeze frame'));
      await settle(tester);
      expect(find.text('Freeze frame'), findsOneWidget);
      expect(find.text('750 rpm'), findsOneWidget);
      expect(find.text('122 °F'), findsOneWidget, reason: '50 °C, in °F');
    });
  });

  // ------------------------------------ what the slice 8/9 review found

  group('★ regressions the 2026-09-24 review found', () {
    test('★ a VIN-less primary does not take another vehicle\'s VIN', () async {
      // 'attached' used to be checked before the rest of the garage, so the
      // onboarding-created Golf (no VIN) took the Civic's VIN the first
      // time the adapter went into the Civic.
      final db = newDb();
      final g = newGarage(db);
      final golf = await addCar(g, 'The Golf');
      final civic = await addCar(g, 'The Civic', vin: civicVin);
      final s = newSession();
      expect(await s.connect(transportFor('headers_can')), isTrue);
      addTearDown(s.disconnect);

      final v = await g.onConnected(s);
      expect(v.kind, IdentityKind.other);
      expect(v.match?.id, civic.id);
      final vehicles = VehicleRepository(db);
      expect((await vehicles.byId(golf.id))!.vin, isNull);
      expect((await vehicles.byId(golf.id))!.cachedProtocol, isNull);
    });

    test('★ a new primary under a live link is judged again', () async {
      // "Make primary" while connected used to keep the old verdict: the
      // new primary showed "Connected" and the next scan went under it.
      final db = newDb();
      final g = newGarage(db);
      final civic = await addCar(g, 'The Civic', vin: civicVin);
      final golf = await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
      final s = newSession();
      expect(await s.connect(transportFor('headers_can')), isTrue);
      addTearDown(s.disconnect);
      expect((await g.onConnected(s)).kind, IdentityKind.primary);

      await g.setPrimary(golf.id);
      for (var i = 0; i < 50 && g.pendingIdentity == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(g.pendingIdentity?.kind, IdentityKind.other);
      expect(g.pendingIdentity?.match?.id, civic.id);
      expect(g.lastIdentity?.kind, isNot(IdentityKind.primary));
    });

    test('a verdict does not outlive its link', () async {
      final g = newGarage(newDb());
      await addCar(g, 'The Civic', vin: civicVin);
      final s = newSession();
      expect(await s.connect(transportFor('headers_can')), isTrue);
      addTearDown(s.disconnect);
      expect((await g.onConnected(s)).kind, IdentityKind.primary);

      g.onDisconnected();
      expect(g.lastIdentity, isNull, reason: 'no wire, no car to describe');
      expect(g.pendingIdentity, isNull);
    });

    test(
      'a VIN read that lands after the link dropped is not applied',
      () async {
        final g = newGarage(newDb());
        await addCar(g, 'The Golf', vin: 'WVWZZZ1KZAW000001');
        final s = newSession();
        expect(await s.connect(transportFor('headers_can')), isTrue);
        addTearDown(s.disconnect);

        final pending = g.onConnected(s); // would judge 'unknown' and ask
        g.onDisconnected();
        expect((await pending).kind, IdentityKind.unknown);
        expect(g.pendingIdentity, isNull, reason: 'the car is gone');
        expect(g.lastIdentity, isNull);
      },
    );

    test('★ Demo Mode never touches the real garage', () async {
      // The demo car's VIN is the ISO 3779 example; judging it against the
      // real garage wrote it onto the user's VIN-less car, cached the
      // recording's protocol on it, and saved demo scans in its history.
      TestWidgetsFlutterBinding.ensureInitialized(); // the recording is an asset
      final db = newDb();
      final vehicles = VehicleRepository(db);
      final dtcs = DtcRepository(db);
      final golf = await vehicles.create(
        nickname: 'The Golf',
        fuel: VehicleFuel.petrol,
      );
      // Real timeouts: Demo Mode replays at speed 4, slower than the suite's
      // usual 100, and a compressed timeout would fail its handshake.
      final live = LiveSession(
        session: ObdSession(),
        discovery: FakeAdapterDiscovery(results: const []),
        dtcs: dtcs,
        vehicles: vehicles,
        services: ServiceRepository(db),
      );
      addTearDown(live.dispose);
      await live.garage!.ready;
      await Future<void>.delayed(Duration.zero);
      expect(live.diagnostics.vehicleId, golf.id);

      await live.startDemo();
      expect(live.session.isLive, isTrue);
      expect(live.diagnostics.vehicleId, isNull, reason: 'nothing recorded');
      expect(live.diagnostics.notRecording, NotRecording.demo);

      await live.diagnostics.scan();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final row = (await vehicles.byId(golf.id))!;
      expect(row.vin, isNull, reason: 'the demo VIN is not the user\'s');
      expect(row.cachedProtocol, isNull);
      expect(live.garage!.lastIdentity, isNull);
      expect(await dtcs.history(golf.id), isEmpty, reason: 'no demo scan');

      await live.stopDemo();
      expect(live.diagnostics.vehicleId, golf.id, reason: 'recording resumes');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('updateDetails writes what it is given and nothing else', () async {
      final db = newDb();
      final vehicles = VehicleRepository(db);
      final a = await vehicles.create(nickname: 'A', fuel: VehicleFuel.petrol);
      await vehicles.cacheConnection(
        a.id,
        protocol: 6,
        supportedPids: ['010C'],
      );
      await vehicles.updateDetails(a.id, nickname: const Value('B'));
      final row = (await vehicles.byId(a.id))!;
      expect(row.nickname, 'B');
      expect(row.isPrimary, isTrue, reason: 'untouched');
      expect(row.cachedProtocol, 6, reason: 'untouched');
    });

    testWidgets('★ saving an open edit form keeps exactly one primary', (
      tester,
    ) async {
      // The form wrote back the whole row as it was when it opened. The
      // §9.6 sheet can switch the primary behind an open form, and the
      // stale copy then left the garage with no primary (or two).
      final db = newDb();
      final g = newGarage(db);
      final golf = await addCar(g, 'The Golf');
      final civic = await addCar(g, 'The Civic');
      await pumpGarage(tester, garage: g, session: newSession(), isPro: true);
      await settle(tester);

      await tester.tap(find.text('The Civic'));
      await settle(tester);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      expect(find.text('Edit vehicle'), findsOneWidget);

      await g.setPrimary(civic.id); // what "Switch to The Civic" does
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final vehicles = VehicleRepository(db);
      expect((await vehicles.byId(civic.id))!.isPrimary, isTrue);
      expect((await vehicles.byId(golf.id))!.isPrimary, isFalse);
    });
  });
}

const findsOne = findsOneWidget;
