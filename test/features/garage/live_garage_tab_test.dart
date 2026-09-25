import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/garage/fuel_log_screen.dart';
import 'package:torque_obd2/features/garage/maintenance_screen.dart';
import 'package:torque_obd2/features/garage/reminders_screen.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/session/obd_session.dart';

/// SPEC §5.5 — the Garage tab offers its three logs, for the primary
/// vehicle, in the user's units and currency. §B.16 left the slots empty;
/// this is the wiring the screens' own tests cannot see.
void main() {
  late Persistence store;
  late SettingsProvider settings;
  late EntitlementProvider ent;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
    store.setString(Keys.currency, 'GBP £');
  });

  Future<(LiveSession, VehicleRepository)> pumpTab(
    WidgetTester tester, {
    VehicleFuel fuel = VehicleFuel.petrol,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    final vehicles = VehicleRepository(db);
    await vehicles.create(nickname: 'The Golf', fuel: fuel, odometerKm: 1000);
    final live = LiveSession(
      session: ObdSession(timeScale: 0.05),
      vehicles: vehicles,
      services: ServiceRepository(db),
      dtcs: DtcRepository(db),
    );
    addTearDown(live.dispose);
    settings = SettingsProvider(store);
    ent = EntitlementProvider(store);
    addTearDown(ent.dispose);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<LiveSession>.value(value: live),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: ent),
          ],
          child: MaterialApp(
            theme: torqueTheme(),
            home: const Scaffold(body: LiveGarageTab()),
          ),
        ),
      ),
    );
    for (var i = 0; i < 100 && live.garage!.primary == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await settle(tester);
    return (live, vehicles);
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('★ the Garage offers its three logs, and each opens', (
    tester,
  ) async {
    await pumpTab(tester);
    for (final (row, screen) in [
      ('Maintenance log', MaintenanceScreen),
      ('Reminders', RemindersScreen),
      ('Fuel log', FuelLogScreen),
    ]) {
      await tester.scrollUntilVisible(find.text(row), 200);
      await tester.tap(find.text(row));
      await settle(tester);
      expect(find.byType(screen), findsOneWidget, reason: row);
      Navigator.of(tester.element(find.byType(screen))).pop();
      await settle(tester);
    }
    await drain(tester);
  });

  testWidgets('the maintenance log writes in the currency Settings holds', (
    tester,
  ) async {
    await pumpTab(tester);
    await tester.tap(find.text('Maintenance log'));
    await settle(tester);
    final screen = tester.widget<MaintenanceScreen>(
      find.byType(MaintenanceScreen),
    );
    expect(screen.currencyCode, 'GBP', reason: "from 'GBP £'");
    await drain(tester);
  });

  testWidgets('★ Pro bought through the log\'s own door lifts the cap on '
      'that same screen', (tester) async {
    final (live, _) = await pumpTab(tester);
    final car = live.garage!.primary!;
    for (var i = 0; i < 10; i++) {
      await live.garage!.services!.addRecord(
        vehicleId: car.id,
        type: ServiceType.maintenance,
        title: 'Record $i',
        date: DateTime.utc(2026, 9, 1),
      );
    }
    await tester.tap(find.text('Maintenance log'));
    await settle(tester);
    expect(find.text('10 of 10 records on the free plan.'), findsOneWidget);

    await ent.subscribe(); // unconfigured: granted at once
    await settle(tester);
    // Read once when the log opened, the plan stayed free on this screen:
    // the user who had just paid met the cap again.
    expect(
      tester.widget<MaintenanceScreen>(find.byType(MaintenanceScreen)).isPro,
      isTrue,
    );
    expect(find.text('10 of 10 records on the free plan.'), findsNothing);
    await tester.tap(find.text('Add a record'));
    await settle(tester);
    expect(find.text('What was done'), findsOneWidget, reason: 'the form');
    await drain(tester);
  });

  testWidgets('★ the unit and currency chosen in Settings reach a log that '
      'is open', (tester) async {
    await pumpTab(tester);
    await tester.tap(find.text('Maintenance log'));
    await settle(tester);
    settings.setDistance(DistanceUnit.mi);
    settings.setCurrency('EUR €');
    await settle(tester);
    final screen = tester.widget<MaintenanceScreen>(
      find.byType(MaintenanceScreen),
    );
    expect(screen.unit, DistanceUnit.mi);
    expect(screen.currencyCode, 'EUR');
    await drain(tester);
  });

  testWidgets('★ a log opened for one car stays that car\'s when another '
      'becomes primary', (tester) async {
    final (live, vehicles) = await pumpTab(tester);
    final civic = await vehicles.create(
      nickname: 'The Civic',
      fuel: VehicleFuel.petrol,
      odometerKm: 50000,
    );
    await tester.tap(find.text('Maintenance log'));
    await settle(tester);
    await live.garage!.setPrimary(civic.id);
    settings.setHaptics(false); // any change the log's route listens to
    await settle(tester);
    // Rebuilt, it read garage.primary again and became the Civic's, while
    // a form already open still wrote to the Golf.
    expect(
      tester
          .widget<MaintenanceScreen>(find.byType(MaintenanceScreen))
          .vehicle
          .nickname,
      'The Golf',
    );
    await drain(tester);
  });

  testWidgets('★ an electric car has no fuel log; a hybrid does', (
    tester,
  ) async {
    await pumpTab(tester, fuel: VehicleFuel.electric);
    expect(find.text('Maintenance log'), findsOneWidget);
    expect(find.text('Fuel log'), findsNothing);
    await drain(tester);
  });
}

/// Long enough for a route's exit transition, so a finder never sees the
/// page being left.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}
