import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/pro/paywall_screen.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';

/// SPEC Part 7 — the paywall says what §7.2 says, sells the plans the
/// provider has, and never mentions ads or an account, because the app has
/// neither.
void main() {
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<EntitlementProvider> pump(
    WidgetTester tester, {
    Size size = const Size(390, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Unconfigured RevenueCat: the spec's fallback plans, and a purchase
    // that grants locally — the whole flow, with no store keys.
    final ent = EntitlementProvider(store);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: ChangeNotifierProvider<EntitlementProvider>.value(
          value: ent,
          child: MaterialApp(
            theme: torqueTheme(),
            debugShowCheckedModeBanner: false,
            home: const PaywallScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    return ent;
  }

  String allText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');

  testWidgets('★ says what §7.2 says, and nothing about ads or accounts', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.text('Reading and clearing codes: free on both stores, always.'),
      findsOneWidget,
    );
    for (final row in PaywallScreen.comparison) {
      expect(find.text(row.feature), findsOneWidget, reason: row.feature);
    }
    final text = allText(tester).toLowerCase();
    expect(text, isNot(contains(' ads')));
    expect(text, isNot(contains('banner')));
    // The store account is real and named; an app account is not.
    expect(text, isNot(contains('sign in')));
    expect(text, isNot(contains('create an account')));
    expect(text, isNot(contains('your account')));
  });

  testWidgets('the three plans, at the provider\'s prices', (tester) async {
    final ent = await pump(tester);
    expect(ent.planCount, 3);
    for (var i = 0; i < 3; i++) {
      expect(find.text(ent.planTitle(i)), findsOneWidget);
      expect(
        find.text('${ent.planPrice(i)} ${ent.planPeriod(i)}'),
        findsOneWidget,
      );
    }
    expect(find.text('3-day free trial first'), findsOneWidget);
    expect(find.text(ent.planAction(0)), findsOneWidget, reason: 'the CTA');
  });

  testWidgets('choosing a plan changes the action', (tester) async {
    final ent = await pump(tester);
    await tester.tap(find.text('Lifetime'));
    await tester.pump();
    expect(ent.selectedPlan, 2);
    expect(find.text(ent.planAction(2)), findsOneWidget);
    expect(find.text(ent.planAction(0)), findsNothing);
  });

  testWidgets('★ buying grants Pro and says so', (tester) async {
    final ent = await pump(tester);
    expect(ent.isPro, isFalse);
    await tester.tap(find.text(ent.planAction(0)));
    await tester.pumpAndSettle();
    expect(find.text('You have Torque Pro'), findsOneWidget);
    expect(ent.isPro, isTrue);
  });

  testWidgets('Not now leaves the plan as it was', (tester) async {
    final ent = await pump(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(ent.isPro, isFalse);
  });

  testWidgets('a restore with nothing behind it says so', (tester) async {
    final ent = await pump(tester);
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to restore'), findsOneWidget);
    expect(ent.isPro, isFalse);
  });

  testWidgets('already Pro: no plans to buy, manage instead', (tester) async {
    store.setEnum(Keys.entitlementTier, Entitlement.pro);
    await pump(tester);
    expect(find.text('You have Torque Pro.'), findsOneWidget);
    expect(find.text('Manage subscription'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Lifetime'), findsNothing);
  });

  testWidgets('fits at text scale 2.0 on a 320 pt phone', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
  });
}
