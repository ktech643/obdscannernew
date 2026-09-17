import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/onboarding/onboarding_flow.dart';
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

  testWidgets('Skip on the first screen finishes onboarding', (tester) async {
    await pump(tester);
    final onboarding = Provider.of<OnboardingProvider>(
      tester.element(find.byType(OnboardingFlow)),
      listen: false,
    );
    await tester.tap(find.text('Skip'));
    await settle(tester);

    expect(onboarding.complete, isTrue);
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
}

void _noop() {}
