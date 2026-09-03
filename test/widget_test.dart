import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/dashboard_provider.dart';
import 'package:torque_obd2/providers/diagnostics_provider.dart';

void main() {
  testWidgets('opens on the first-run flow', (tester) async {
    await tester.pumpWidget(const TorqueApp());
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
    await tester.pumpWidget(const TorqueApp());
    await tester.pump();

    final o = Provider.of<OnboardingProvider>(
      tester.element(find.text('Next')),
      listen: false,
    );
    o.goTo(3);
    await tester.pump();

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
      final d = DashboardProvider();
      d.setSpeed(68);
      d.setEditing(true);
      expect(d.editing, isFalse);
      d.setSpeed(0);
      d.setEditing(true);
      expect(d.editing, isTrue);
    });
  });

  group('ad placement', () {
    final e = EntitlementProvider();

    test('never over a fault result, mid-scan, or above 5 km/h', () {
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
      final pro = EntitlementProvider()..subscribe();
      expect(
        pro.canShowBanner(onFaultResult: false, scanning: false, speedKmh: 0),
        isFalse,
      );
    });
  });

  group('typing rules', () {
    test('zero is a value, not missing data', () {
      final d = DashboardProvider()..setScenario(DashboardScenario.hybrid);
      final rpm = d.tiles.firstWhere((t) => t.label == 'Engine RPM');
      expect(rpm.value, 0);
      expect(rpm.state, TileState.live);
      expect(rpm.valueText, '0');
    });

    test('an unsupported PID is distinct from a zero reading', () {
      final d = DashboardProvider()..setScenario(DashboardScenario.degraded);
      final oil = d.tiles.firstWhere((t) => t.label == 'Oil temp');
      expect(oil.value, isNull);
      expect(oil.state, TileState.unsupported);
    });
  });

  test('unknown codes never get a fabricated definition', () {
    final dx = DiagnosticsProvider();
    final unknown = dx.codes.firstWhere((c) => c.code == 'P1602');
    expect(unknown.hasDefinition, isFalse);
    expect(unknown.description, contains("we don't have a definition"));
  });
}
