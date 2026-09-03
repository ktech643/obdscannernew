import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/models/models.dart';
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

  test('unknown codes never get a fabricated definition', () {
    final dx = DiagnosticsProvider();
    final unknown = dx.codes.firstWhere((c) => c.code == 'P1602');
    expect(unknown.hasDefinition, isFalse);
    expect(unknown.description, contains("we don't have a definition"));
  });
}
