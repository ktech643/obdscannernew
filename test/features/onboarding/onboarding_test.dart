import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/onboarding/onboarding_flow.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';

/// SPEC §5.1 — first-run onboarding on the Part B design system.
void main() {
  late Persistence store;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OnboardingProvider(store)),
            ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
            Provider<VehicleRepository>(create: (_) => VehicleRepository(db)),
          ],
          child: MaterialApp(
            theme: torqueTheme(),
            debugShowCheckedModeBanner: false,
            home: const Material(child: OnboardingFlow(onDone: _noop)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('first screen explains the app and Next advances', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.text("Read your car's error codes and watch live engine data."),
      findsOneWidget,
    );
    expect(find.text('1 OF 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await settle(tester);

    expect(find.text('You need an adapter'), findsOneWidget);
    expect(find.text('2 OF 4'), findsOneWidget);
  });

  testWidgets('★ Skip goes to the safety step, never past it', (tester) async {
    // An earlier version of this test asserted the opposite — that Skip
    // finished onboarding — and so certified the bug: three screens of
    // Skip put the user on the Dashboard without the §8.4 warning.
    await pump(tester);
    final onboarding = Provider.of<OnboardingProvider>(
      tester.element(find.byType(OnboardingFlow)),
      listen: false,
    );
    await tester.tap(find.text('Skip'));
    await settle(tester);

    expect(onboarding.complete, isFalse);
    expect(find.text('Before you start'), findsOneWidget);
    expect(find.text('Skip'), findsNothing, reason: 'nowhere left to skip to');
  });

  testWidgets('adapter screen explains iOS adapter limits', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);

    expect(find.text("Can't work"), findsOneWidget);
    expect(find.text('Bluetooth Classic'), findsOneWidget);
    expect(
      find.textContaining('Apple gives no app access to Classic Bluetooth'),
      findsOneWidget,
    );
  });

  testWidgets('add-car screen creates a primary vehicle', (tester) async {
    await pump(tester);
    final onboarding = Provider.of<OnboardingProvider>(
      tester.element(find.text('Next')),
      listen: false,
    );
    onboarding.goTo(2);
    await settle(tester);

    expect(find.text('Add your car'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'The Golf');
    await tester.enterText(fields.at(1), 'Volkswagen');
    await tester.enterText(fields.at(3), 'Golf GTD');
    await tester.enterText(fields.at(2), '2014');
    await tester.tap(find.text('Save and continue'));
    await settle(tester);

    final vehicles = Provider.of<VehicleRepository>(
      tester.element(find.text('Before you start')),
      listen: false,
    );
    final primary = await vehicles.primary();
    expect(primary?.nickname, 'The Golf');
  });

  testWidgets('safety screen requires acknowledgement', (tester) async {
    await pump(tester);
    final onboarding = Provider.of<OnboardingProvider>(
      tester.element(find.text('Next')),
      listen: false,
    );
    onboarding.goTo(3);
    await settle(tester);

    expect(find.text('Before you start'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    // Agree button is disabled until the checkbox is checked.
    final agree = find.text('Agree and continue');
    expect(agree, findsOneWidget);
    await tester.tap(agree);
    await settle(tester);
    // Still on the safety screen because acknowledgement is false.
    expect(find.text('Before you start'), findsOneWidget);

    await tester.tap(
      find.text("I understand and I won't use this while driving"),
    );
    await settle(tester);
    await tester.tap(agree);
    await settle(tester);

    expect(onboarding.complete, isTrue);
  });

  group('★ regressions the 2026-09-24 review found', () {
    Future<OnboardingProvider> atAddCar(WidgetTester tester) async {
      await pump(tester);
      final onboarding = Provider.of<OnboardingProvider>(
        tester.element(find.byType(OnboardingFlow)),
        listen: false,
      );
      onboarding.goTo(2);
      await settle(tester);
      expect(find.text('Add your car'), findsOneWidget);
      return onboarding;
    }

    VehicleRepository vehiclesOf(WidgetTester tester) =>
        Provider.of<VehicleRepository>(
          tester.element(find.byType(OnboardingFlow)),
          listen: false,
        );

    Finder field(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label.toUpperCase()),
        matching: find.byType(Column),
      ).first,
      matching: find.byType(TextField),
    );

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save and continue'));
      await settle(tester);
    }

    testWidgets('★ a comma-decimal odometer is not ten times larger', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.enterText(field('Odometer'), '142380,5');
      await save(tester);

      final primary = await vehiclesOf(tester).primary();
      expect(primary?.odometerKm, closeTo(142380.5, 0.01));
    });

    testWidgets('an odometer in miles is stored in kilometres', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.tap(find.text('mi'));
      await tester.pump();
      await tester.enterText(field('Odometer'), '100,000');
      await save(tester);

      final primary = await vehiclesOf(tester).primary();
      expect(primary?.odometerKm, closeTo(160934.4, 0.1));
    });

    testWidgets('★ an odometer past 2,000,000 km is refused, not saved', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.enterText(field('Odometer'), '2,000,001');
      await save(tester);

      expect(find.text('A reading between 0 and 2,000,000 km.'), findsOneWidget);
      expect(find.text('Add your car'), findsOneWidget, reason: 'still here');
      expect(await vehiclesOf(tester).count(), 0);
    });

    testWidgets('★ a 400-digit odometer is refused without crashing', (
      tester,
    ) async {
      // double.tryParse gives Infinity; the old save stored it and the
      // Garage card's round() then threw.
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.enterText(field('Odometer'), '1' * 400);
      await save(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('A reading between 0 and 2,000,000 km.'), findsOneWidget);
      expect(await vehiclesOf(tester).count(), 0);
    });

    testWidgets('a year outside the form\'s range is refused', (tester) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.enterText(field('Year'), '1979');
      await save(tester);

      final max = DateTime.now().year + 1;
      expect(find.text('A year between 1980 and $max.'), findsOneWidget);
      expect(await vehiclesOf(tester).count(), 0);
    });

    testWidgets('a nickname is cut at the Garage\'s 40 characters', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'x' * 41);
      await save(tester);

      final primary = await vehiclesOf(tester).primary();
      expect(primary?.nickname.length, 40);
    });

    testWidgets('details without a name ask for one instead of vanishing', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Make'), 'Volkswagen');
      await save(tester);

      expect(find.textContaining('Give the car a name'), findsOneWidget);
      expect(find.text('Add your car'), findsOneWidget);
    });

    testWidgets('★ a car already in the garage is shown and updated, not '
        'duplicated — and what was not edited is kept exactly', (tester) async {
      final vehicles = VehicleRepository(db);
      final old = await vehicles.create(
        nickname: 'Old name',
        fuel: VehicleFuel.petrol,
        // Not the fields' own hint texts, which are also "Volkswagen" and
        // "Golf GTD" — a finder would match the hint as well as the value.
        make: 'Mazda',
        model: 'MX-5',
        year: 2014,
        odometerKm: 142380.5,
      );
      await atAddCar(tester);
      await tester.pump();
      expect(find.text('Old name'), findsOneWidget, reason: 'prefilled');
      expect(find.text('Mazda'), findsOneWidget);
      expect(find.text('142,381'), findsOneWidget, reason: 'shown rounded');

      await tester.enterText(field('Nickname'), 'The Golf');
      await save(tester);

      expect(await vehicles.count(), 1);
      final primary = (await vehicles.primary())!;
      expect(primary.nickname, 'The Golf');
      expect(primary.isPrimary, isTrue);
      expect(primary.make, 'Mazda');
      expect(primary.model, 'MX-5');
      expect(primary.year, 2014);
      // The odometer was never edited: not re-saved rounded, not re-dated.
      expect(primary.odometerKm, 142380.5);
      expect(primary.odometerUpdatedAt, old.odometerUpdatedAt);
    });

    testWidgets('★ the unit comes from Settings, and leaving keeps it', (
      tester,
    ) async {
      store.setEnum(Keys.distanceUnit, DistanceUnit.mi);
      final vehicles = VehicleRepository(db);
      await vehicles.create(
        nickname: 'Old name',
        fuel: VehicleFuel.petrol,
        odometerKm: 160934.4,
      );
      await atAddCar(tester);
      await tester.pump();
      expect(find.text('100,000'), findsOneWidget, reason: 'miles, as chosen');

      await tester.tap(find.text("I'll do this later"));
      await settle(tester);
      expect(
        SettingsProvider(store).distance,
        DistanceUnit.mi,
        reason: 'not reset to km by passing through',
      );
    });

    testWidgets('★ an edited prefill stays edited through a unit toggle', (
      tester,
    ) async {
      final vehicles = VehicleRepository(db);
      await vehicles.create(
        nickname: 'Old name',
        fuel: VehicleFuel.petrol,
        odometerKm: 142380.5,
      );
      await atAddCar(tester);
      await tester.pump();
      await tester.enterText(field('Odometer'), '150,000');
      await tester.tap(find.text('mi'));
      await tester.pump();
      await save(tester);

      final primary = (await vehicles.primary())!;
      expect(primary.odometerKm, closeTo(150000, 2), reason: 'the new reading');
    });

    testWidgets('★ toggling the unit converts the figure, never relabels it', (
      tester,
    ) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.enterText(field('Odometer'), '160,934');
      await tester.tap(find.text('mi'));
      await tester.pump();
      expect(find.text('100,000'), findsOneWidget, reason: 'converted');

      await save(tester);
      final primary = await vehiclesOf(tester).primary();
      expect(primary?.odometerKm, closeTo(160934, 1), reason: 'not ×1.609');
    });

    testWidgets('★ tapping Save twice leaves one vehicle', (tester) async {
      await atAddCar(tester);
      await tester.enterText(field('Nickname'), 'The Golf');
      await tester.tap(find.text('Save and continue'));
      await tester.tap(find.text('Save and continue'));
      await settle(tester);

      expect(await vehiclesOf(tester).count(), 1);
    });

    testWidgets('★ the safety checkbox carries a tap action for screen '
        'readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      final onboarding = Provider.of<OnboardingProvider>(
        tester.element(find.byType(OnboardingFlow)),
        listen: false,
      );
      onboarding.goTo(3);
      await settle(tester);

      const label = "I understand and I won't use this while driving";
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(find.semantics.byLabel(label));
      await settle(tester);
      expect(onboarding.safetyAcknowledged, isTrue);
      handle.dispose();
    });

    testWidgets('the footer rises above the keyboard, and a tap outside '
        'dismisses it', (tester) async {
      await atAddCar(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.text('Save and continue')).dy,
        lessThanOrEqualTo(844 - 336),
        reason: 'the footer is above the keyboard',
      );

      await tester.tap(field('Nickname'));
      await tester.pump();
      EditableTextState first() =>
          tester.state(find.byType(EditableText).first);
      expect(first().widget.focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Add your car'));
      await tester.pump();
      expect(first().widget.focusNode.hasFocus, isFalse);
    });

    testWidgets('the add-car and safety copy does not assume an iPhone', (
      tester,
    ) async {
      final onboarding = await atAddCar(tester);
      expect(find.textContaining('iPhone'), findsNothing);
      onboarding.goTo(3);
      await settle(tester);
      expect(find.textContaining('iPhone'), findsNothing);
    });
  });
}

void _noop() {}
