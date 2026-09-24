import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/features/onboarding/onboarding_flow.dart';
import 'package:torque_obd2/features/settings/erase_everything.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/monetization/revenuecat_service.dart';
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/screens/settings/privacy_screen.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.6 "Delete all data" and "Export JSON", and the privacy screen's
/// claims about what leaves the phone.
///
/// The earlier Delete cleared the preferences only: the database rows and
/// trip recordings survived, and the providers in memory kept the old
/// settings. Its Export copied a hard-coded sample car. Every fixture here
/// is the user's real data in the real stores — a Drift row, a CSV on disk,
/// a preference, a VIN in the diagnostics log.
void main() {
  const vin = '1HGBH41JXMN109186';

  late AppDatabase db;
  late Directory docs;
  late TripRepository trips;
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
    db = AppDatabase(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('torque_erase_');
    addTearDown(() => docs.deleteSync(recursive: true));
    trips = TripRepository(db, TripFiles(docs));
  });

  /// One real car with a scan, a service record and a trip recording, and
  /// the preferences a user who finished onboarding would have.
  Future<VehicleRow> seed() async {
    final astra = await VehicleRepository(db)
        .create(nickname: 'My Real Astra', fuel: VehicleFuel.petrol, vin: vin);
    await DtcRepository(db).recordScan(
      vehicleId: astra.id,
      codes: const [RawDtc('P0301', DtcMode.stored)],
    );
    await ServiceRepository(db).addRecord(
      vehicleId: astra.id,
      type: ServiceType.maintenance,
      title: 'Oil and filter',
      date: DateTime.utc(2026, 9, 1),
    );
    await trips.start(vehicleId: astra.id);
    store
      ..setBool(Keys.onboardingComplete, true)
      ..setEnum(Keys.distanceUnit, DistanceUnit.mi)
      ..setBool(Keys.maskVin, false)
      ..setEnum(Keys.entitlementTier, Entitlement.pro)
      ..setInt(Keys.entitlementVerifiedAt, 1758700000000);
    return astra;
  }

  Future<void> expectDatabaseEmpty() async {
    expect(await db.select(db.vehicles).get(), isEmpty);
    expect(await db.select(db.dtcSnapshots).get(), isEmpty);
    expect(await db.select(db.serviceRecords).get(), isEmpty);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(await db.select(db.fuelEntries).get(), isEmpty);
    expect(await db.select(db.tripSessions).get(), isEmpty);
  }

  group('★ EraseEverything', () {
    tearDown(() => db.close());

    test('★ erases every row, every recording and every preference', () async {
      await seed();
      expect(await trips.files.listAll(), hasLength(1), reason: 'seeded');
      final live = LiveSession(session: ObdSession(timeScale: 0.05));
      addTearDown(live.dispose);
      live.log
        ..reply('49 02 01 $vin', parsed: vin)
        ..noteVin(vin);
      var restarts = 0;

      await EraseEverything(
        db: db,
        trips: trips,
        store: store,
        live: live,
        onErased: () => restarts++,
      )();

      await expectDatabaseEmpty();
      expect(await trips.files.listAll(), isEmpty, reason: 'the CSV');
      expect(store.getBool(Keys.onboardingComplete), isNull);
      expect(store.getString(Keys.distanceUnit), isNull);
      expect(store.getBool(Keys.maskVin), isNull);
      expect(live.log.isEmpty, isTrue);
      expect(live.log.knownVins, isEmpty, reason: 'the log carried the VIN');
      expect(restarts, 1, reason: 'the app is rebuilt from first run');
    });

    test('a Pro purchase survives it — it is the store account\'s', () async {
      await seed();
      final live = LiveSession(session: ObdSession(timeScale: 0.05));
      addTearDown(live.dispose);

      await EraseEverything(
        db: db,
        trips: trips,
        store: store,
        live: live,
        onErased: () {},
      )();

      expect(EntitlementProvider(store).isPro, isTrue);
      expect(store.getInt(Keys.entitlementVerifiedAt), 1758700000000);
    });

    test('the link to the car is closed before anything is wiped', () async {
      await seed();
      final live = LiveSession(session: ObdSession(timeScale: 0.05));
      addTearDown(live.dispose);
      final source = File('assets/traces/headers_can.obdtrace')
          .readAsStringSync();
      expect(
        await live.session.connect(
          MockTransport(ObdTrace.parse(source), speed: 100),
        ),
        isTrue,
      );
      live.session.setVisible({});

      await EraseEverything(
        db: db,
        trips: trips,
        store: store,
        live: live,
        onErased: () {},
      )();

      expect(live.session.isLive, isFalse);
    });

    test('a failed wipe stops there, keeps the rest, and says so', () async {
      await seed();
      final live = LiveSession(session: ObdSession(timeScale: 0.05));
      addTearDown(live.dispose);
      final broken = _FullDisk();
      addTearDown(broken.close);
      var restarts = 0;

      await expectLater(
        EraseEverything(
          db: broken,
          trips: trips,
          store: store,
          live: live,
          onErased: () => restarts++,
        )(),
        throwsA(anything),
      );

      expect(store.getBool(Keys.onboardingComplete), isTrue);
      expect(restarts, 0, reason: 'never "erased" over data still there');
    });
  });

  group('★ the whole app starts again', () {
    testWidgets('★ every provider is rebuilt from the emptied storage', (
      tester,
    ) async {
      await tester.runAsync(seed);
      // Capped: a test that fails before the drain below leaves drift's
      // cancel timer on the fake clock, and close() would wait on it with
      // nothing left to pump.
      addTearDown(
        () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
      );

      await tester.pumpWidget(
        TorqueApp(
          store: store,
          billing: RevenueCatService(),
          db: db,
          docsDir: docs,
        ),
      );
      await tester.pump();
      final before = tester.element(find.byType(AppShell));
      final oldSettings = before.read<SettingsProvider>();
      final oldLive = before.read<LiveSession>();
      final erase = before.read<EraseEverything>();
      expect(oldSettings.distance, DistanceUnit.mi, reason: 'seeded');

      await tester.runAsync(erase.call);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(OnboardingFlow), findsOneWidget);
      final after = tester.element(find.byType(OnboardingFlow));
      final settings = after.read<SettingsProvider>();
      expect(identical(settings, oldSettings), isFalse);
      expect(settings.distance, DistanceUnit.km, reason: 'the default again');
      expect(settings.maskVin, isTrue, reason: 'the default again');
      expect(identical(after.read<LiveSession>(), oldLive), isFalse);
      expect(after.read<EntitlementProvider>().isPro, isTrue);

      // Reading the new LiveSession built it, and its garage streams. Take
      // the tree down here and *elapse* the fake clock: cancelling a drift
      // stream schedules a Timer.run, and a bare pump() only flushes
      // microtasks — the framework's own end-of-test pump leaves that timer
      // pending, and db.close() in tearDown then waits on it forever.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('★ the privacy screen', () {
    Future<List<(String, String)>> pumpPrivacy(WidgetTester tester) async {
      final shared = <(String, String)>[];
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: db),
            ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
            ChangeNotifierProvider(create: (_) => EntitlementProvider(store)),
          ],
          child: MaterialApp(
            home: PrivacyScreen(
              shareBackup: (json, name) async => shared.add((json, name)),
            ),
          ),
        ),
      );
      await tester.pump();
      return shared;
    }

    testWidgets('★ Export shares the database, not a sample car', (
      tester,
    ) async {
      await tester.runAsync(seed);
      addTearDown(db.close);
      final shared = await pumpPrivacy(tester);

      await tester.tap(find.text('Export everything as JSON'));
      for (var i = 0; i < 20 && shared.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(shared, hasLength(1));
      final (json, name) = shared.single;
      expect(name, matches(RegExp(r'^torque-backup-\d{4}-\d{2}-\d{2}\.json$')));
      final doc = jsonDecode(json) as Map<String, Object?>;
      expect(doc['format'], 'torque-obd2-backup');
      final vehicles = doc['vehicles']! as List;
      expect(vehicles, hasLength(1));
      expect((vehicles.single as Map)['nickname'], 'My Real Astra');
      expect(json, contains(vin), reason: 'a backup restores with its VIN');
      expect(json, isNot(contains('The Golf')), reason: 'the old sample car');
      expect(doc['dtcSnapshots'], hasLength(1));
      expect(doc['serviceRecords'], hasLength(1));
      expect(doc['tripSessions'], hasLength(1));
    });

    testWidgets('names what does leave the phone, and nothing that does not', (
      tester,
    ) async {
      addTearDown(db.close);
      await pumpPrivacy(tester);

      expect(find.textContaining('RevenueCat'), findsOneWidget);
      expect(find.textContaining('iCloud'), findsNothing);
      expect(find.text('Ad requests'), findsNothing);
      expect(find.text('Personalised ads'), findsNothing);
      expect(find.textContaining('iPhone'), findsNothing, reason: 'Android');
    });
  });
}

/// A database whose wipe fails the way a full disk makes SQLite fail.
class _FullDisk extends AppDatabase {
  _FullDisk() : super(NativeDatabase.memory());

  @override
  Future<void> wipe() async =>
      throw const FileSystemException('database or disk is full');
}
