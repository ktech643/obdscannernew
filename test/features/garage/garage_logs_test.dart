import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/service_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/garage/fuel_log_screen.dart';
import 'package:torque_obd2/features/garage/garage_controller.dart';
import 'package:torque_obd2/features/garage/maintenance_screen.dart';
import 'package:torque_obd2/features/garage/reminders_screen.dart';
import 'package:torque_obd2/features/garage/service_intervals.dart';
import 'package:torque_obd2/models/enums.dart';

/// SPEC §5.5 — the maintenance log, reminders and fuel log, on a real
/// in-memory database through the Garage's own controller. What the list
/// shows is what the form wrote.
void main() {
  late AppDatabase db;
  late GarageController garage;
  late ServiceRepository services;
  late VehicleRow car;

  Future<double?> odometer() async =>
      (await VehicleRepository(db).byId(car.id))?.odometerKm;

  /// Everything built inside the test body, under its fake clock: a
  /// database opened on the real clock and then used under the fake one
  /// deadlocks on drift's lock.
  Future<void> seed(WidgetTester tester) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    services = ServiceRepository(db);
    garage = GarageController(
      vehicles: VehicleRepository(db),
      services: services,
      dtcs: DtcRepository(db),
    );
    addTearDown(garage.dispose);
    car = await garage.add(
      nickname: 'The Golf',
      fuel: VehicleFuel.diesel,
      odometerKm: 142380,
    );
    // The screens read "the car now" from the controller's rows.
    for (var i = 0; i < 100 && garage.all.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(garage.all, isNotEmpty, reason: 'the garage loaded');
  }

  /// Drift answers on microtasks and its streams on a zero timer; the
  /// clock is fake here, so elapse it.
  /// Long enough for a route's or a sheet's exit transition to finish, so
  /// a finder never sees the page being left as well as the one arrived at.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  /// Unmount so every stream is cancelled, and elapse the cancel timers
  /// inside the test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  group('★ maintenance log', () {
    testWidgets('★ a record written on the form is on the list, and moves '
        'the odometer', (tester) async {
      await seed(tester);
      await pumpScreen(
        tester,
        MaintenanceScreen(garage: garage, vehicle: car, currencyCode: 'GBP'),
      );
      expect(find.text('Nothing recorded yet'), findsOneWidget);

      await tester.tap(find.text('Add a record'));
      await settle(tester);
      await tester.enterText(field('What was done'), 'Oil and filter');
      await tester.enterText(field('Odometer (km)'), '150,000');
      await tester.enterText(field('Cost (GBP)'), '89,90');
      await tester.tap(find.text('Add record'));
      await settle(tester);

      expect(find.text('Oil and filter'), findsOneWidget);
      expect(find.text('£89.90'), findsOneWidget, reason: 'comma-decimal');
      expect(find.textContaining('150,000 km'), findsOneWidget);
      final rows = await services.records(car.id);
      expect(rows.single.cost, 89.9);
      expect(rows.single.currencyCode, 'GBP');
      expect(await odometer(), 150000, reason: 'a newer reading');
      await drain(tester);
    });

    testWidgets('what the form refuses is said under the field, and nothing '
        'is saved', (tester) async {
      await seed(tester);
      await pumpScreen(tester, MaintenanceScreen(garage: garage, vehicle: car));
      await tester.tap(find.text('Add a record'));
      await settle(tester);
      await tester.enterText(field('Odometer (km)'), '2,000,001');
      await tester.enterText(field('Cost (USD)'), 'lots');
      await tester.tap(find.text('Add record'));
      await settle(tester);

      expect(find.text('Say what was done.'), findsOneWidget);
      expect(
        find.text('A reading between 0 and 2,000,000 km.'),
        findsOneWidget,
      );
      expect(find.text('An amount, like 42.50.'), findsOneWidget);
      expect(await services.records(car.id), isEmpty);
      await drain(tester);
    });

    testWidgets('★ §7.2 — the eleventh record is a §7.3 door, not a wall', (
      tester,
    ) async {
      await seed(tester);
      for (var i = 0; i < MaintenanceScreen.freeRecords; i++) {
        await services.addRecord(
          vehicleId: car.id,
          type: ServiceType.maintenance,
          title: 'Record $i',
          date: DateTime.utc(2026, 1, 1 + i),
        );
      }
      var upgrades = 0;
      await pumpScreen(
        tester,
        MaintenanceScreen(
          garage: garage,
          vehicle: car,
          onUpgrade: () => upgrades++,
        ),
      );
      expect(find.text('10 of 10 records on the free plan.'), findsOneWidget);

      await tester.tap(find.text('Add a record'));
      await settle(tester);
      expect(find.text('10 records on the free plan'), findsOneWidget);
      await tester.tap(find.text('See Pro'));
      await settle(tester);
      expect(upgrades, 1);
      expect(find.text('What was done'), findsNothing, reason: 'no form');

      // The ten already there stay editable.
      await tester.tap(find.text('Record 3'));
      await settle(tester);
      expect(find.text('Edit record'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Pro has no cap', (tester) async {
      await seed(tester);
      for (var i = 0; i < MaintenanceScreen.freeRecords; i++) {
        await services.addRecord(
          vehicleId: car.id,
          type: ServiceType.maintenance,
          title: 'Record $i',
          date: DateTime.utc(2026, 1, 1 + i),
        );
      }
      await pumpScreen(
        tester,
        MaintenanceScreen(garage: garage, vehicle: car, isPro: true),
      );
      await tester.tap(find.text('Add a record'));
      await settle(tester);
      expect(find.text('What was done'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('★ an edit keeps what the form does not show', (tester) async {
      await seed(tester);
      await services.addRecord(
        vehicleId: car.id,
        type: ServiceType.repair,
        title: 'Coil pack',
        date: DateTime.utc(2026, 9, 1),
        linkedDtcs: const ['P0301'],
      );
      await pumpScreen(tester, MaintenanceScreen(garage: garage, vehicle: car));
      await tester.tap(find.text('Coil pack'));
      await settle(tester);
      await tester.enterText(field('What was done'), 'Coil pack, cylinder 1');
      await tester.tap(find.text('Save'));
      await settle(tester);

      final row = (await services.records(car.id)).single;
      expect(row.title, 'Coil pack, cylinder 1');
      expect(row.linkedDtcs, ['P0301'], reason: 'not on the form, still kept');
      expect(row.type, ServiceType.repair);
      await drain(tester);
    });

    testWidgets('delete is two taps', (tester) async {
      await seed(tester);
      await services.addRecord(
        vehicleId: car.id,
        type: ServiceType.tyres,
        title: 'Front pair',
        date: DateTime.utc(2026, 9, 1),
      );
      await pumpScreen(tester, MaintenanceScreen(garage: garage, vehicle: car));
      await tester.tap(find.text('Front pair'));
      await settle(tester);
      await tester.tap(find.text('Delete this record'));
      await settle(tester);
      expect(await services.records(car.id), hasLength(1), reason: 'armed');
      await tester.tap(find.text('Tap again to delete it'));
      await settle(tester);
      expect(await services.records(car.id), isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await drain(tester);
    });
  });

  group('★ reminders', () {
    final today = DateTime(2026, 9, 25);
    DateTime now() => today;

    testWidgets('★ a §5.5 preset sets the next one from today and the car\'s '
        'reading, and says to check the manual', (tester) async {
      await seed(tester);
      await pumpScreen(
        tester,
        RemindersScreen(garage: garage, vehicle: car, now: now),
      );
      await tester.tap(find.text('Add a reminder'));
      await settle(tester);
      expect(find.text(ServicePreset.manualNote), findsOneWidget);
      await tester.tap(find.text('Oil and filter'));
      await settle(tester);

      expect(
        find.text(ServicePreset.manualNote),
        findsOneWidget,
        reason: 'form',
      );
      expect(find.text('152,380'), findsOneWidget, reason: 'odometer + 10,000');
      expect(find.text('10,000'), findsOneWidget);
      expect(find.text('6'), findsOneWidget, reason: 'months');
      await tester.tap(find.text('Add reminder'));
      await settle(tester);

      final r = (await services.reminders(car.id)).single;
      expect(r.dueOdometerKm, 152380);
      expect(r.repeatEveryKm, 10000);
      expect(ServicePreset.monthsForDays(r.repeatEveryDays!), 6);
      expect(find.text('Coming up'), findsOneWidget, reason: 'the heading');
      expect(find.text('Due in 10,000 km'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('★ overdue first, then due soon, and a paused one is never '
        'overdue', (tester) async {
      await seed(tester);
      await services.addReminder(
        vehicleId: car.id,
        title: 'Timing belt',
        dueOdometerKm: 140000,
        critical: true,
      );
      await services.addReminder(
        vehicleId: car.id,
        title: 'Inspection',
        dueDate: today.add(const Duration(days: 10)),
      );
      final paused = await services.addReminder(
        vehicleId: car.id,
        title: 'Battery',
        dueDate: today.subtract(const Duration(days: 90)),
      );
      await services.setPaused(paused.id, true);
      await pumpScreen(
        tester,
        RemindersScreen(garage: garage, vehicle: car, now: now),
      );

      final order = [
        'Overdue',
        'Timing belt',
        'Due soon',
        'Inspection',
        'Paused',
        'Battery',
      ];
      // A heading and the word on its row can be the same word
      // ("Overdue"); the heading is the first, higher on the screen.
      final ys = [
        for (final s in order) tester.getTopLeft(find.text(s).first).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()), reason: 'sections in order');
      expect(
        await garage.overdueCount(
          car.id,
          odometerKm: car.odometerKm,
          now: today,
        ),
        1,
        reason: 'the Garage card counts what this screen calls overdue',
      );
      await drain(tester);
    });

    testWidgets('mark done rolls a repeating reminder forward', (tester) async {
      await seed(tester);
      await services.addReminder(
        vehicleId: car.id,
        title: 'Oil and filter',
        dueOdometerKm: 140000,
        repeatEveryKm: 10000,
      );
      await pumpScreen(
        tester,
        RemindersScreen(garage: garage, vehicle: car, now: now),
      );
      await tester.tap(find.text('Oil and filter'));
      await settle(tester);
      await tester.tap(find.text('Mark as done'));
      await settle(tester);

      final r = (await services.reminders(car.id)).single;
      expect(r.dueOdometerKm, 152380, reason: 'from the current reading');
      expect(find.text('Overdue'), findsNothing);
      await drain(tester);
    });

    testWidgets('a reminder with nothing to be due by is refused, and says '
        'why', (tester) async {
      await seed(tester);
      await pumpScreen(
        tester,
        RemindersScreen(garage: garage, vehicle: car, now: now),
      );
      await tester.tap(find.text('Add a reminder'));
      await settle(tester);
      await tester.tap(find.text('Something else'));
      await settle(tester);
      await tester.enterText(field('Reminder'), 'Wiper blades');
      await tester.tap(find.text('Add reminder'));
      await settle(tester);

      expect(find.textContaining('it can never be due'), findsOneWidget);
      expect(await services.reminders(car.id), isEmpty);
      await drain(tester);
    });
  });

  group('★ fuel log', () {
    testWidgets('★ economy between full fill-ups only, and every row says '
        'why it has a figure or not', (tester) async {
      await seed(tester);
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 1),
        odometerKm: 10000,
        litres: 40,
      );
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 8),
        odometerKm: 10300,
        litres: 10,
        partFill: true,
      );
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 15),
        odometerKm: 10600,
        litres: 30,
      );
      await pumpScreen(tester, FuelLogScreen(garage: garage, vehicle: car));

      expect(find.text('Starts the count'), findsOneWidget);
      expect(find.text('Counted in the next full tank'), findsOneWidget);
      // (10 + 30) L over 600 km.
      expect(find.text('6.7 L/100 km'), findsNWidgets(2), reason: 'row + avg');
      expect(find.textContaining('Over 600 km'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('miles users get both gallons', (tester) async {
      await seed(tester);
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 1),
        odometerKm: 10000,
        litres: 40,
      );
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 15),
        odometerKm: 10600,
        litres: 40,
      );
      await pumpScreen(
        tester,
        FuelLogScreen(garage: garage, vehicle: car, unit: DistanceUnit.mi),
      );
      expect(find.textContaining('mpg US'), findsWidgets);
      expect(find.textContaining('mpg UK'), findsWidgets);
      await drain(tester);
    });

    testWidgets('★ the reading hint is the car\'s now, not an example', (
      tester,
    ) async {
      await seed(tester);
      // A service record moved it after this screen's vehicle was read.
      await garage.updateOdometer(car.id, 150100);
      for (var i = 0; i < 100 && garage.all.first.odometerKm != 150100; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await pumpScreen(tester, FuelLogScreen(garage: garage, vehicle: car));
      await tester.tap(find.text('Add a fill-up'));
      await settle(tester);
      final hint = tester
          .widget<TextField>(field('Odometer (km)'))
          .decoration
          ?.hintText;
      expect(hint, 'Now 150,100');
      await drain(tester);
    });

    testWidgets('★ a fill-up needs its reading and its litres; an older '
        'reading is a caution, not a refusal', (tester) async {
      await seed(tester);
      await services.addFuel(
        vehicleId: car.id,
        date: DateTime.utc(2026, 9, 1),
        odometerKm: 142000,
        litres: 40,
      );
      await pumpScreen(tester, FuelLogScreen(garage: garage, vehicle: car));
      await tester.tap(find.text('Add a fill-up'));
      await settle(tester);
      await tester.tap(find.text('Add fill-up'));
      await settle(tester);
      expect(find.text('The reading at this fill-up.'), findsOneWidget);
      expect(find.text('How many litres went in.'), findsOneWidget);

      await tester.enterText(field('Odometer (km)'), '141,500');
      await tester.enterText(field('Litres'), '38,5');
      await settle(tester);
      expect(find.textContaining('fine if this is an older receipt'), findsOne);
      await tester.tap(find.text('Add fill-up'));
      await settle(tester);

      final all = await services.fuel(car.id);
      expect(all, hasLength(2));
      final added = all.singleWhere((f) => f.litres == 38.5);
      expect(added.odometerKm, 141500, reason: 'saved despite the caution');
      expect(await odometer(), 142380, reason: 'older: not moved');
      await drain(tester);
    });
  });
}
