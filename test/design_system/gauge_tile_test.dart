import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/design_system/design_system.dart';

import 'harness.dart';

void main() {
  late ValueNotifier<PidSample?> live;
  late DashboardClock clock;

  setUp(() {
    live = ValueNotifier<PidSample?>(sample(89));
    clock = DashboardClock(start: t0);
  });

  Widget tile({
    GaugeSpec spec = coolant,
    GaugeVariant variant = GaugeVariant.numeric,
    ValueListenable<List<double>>? history,
    bool primary = false,
    double width = 180,
    VoidCallback? onTap,
    ValueListenable<Duration?>? expectedInterval,
  }) => SizedBox(
    width: width,
    child: GaugeTile(
      spec: spec,
      sample: live,
      clock: clock,
      expectedInterval: expectedInterval,
      variant: variant,
      history: history,
      primary: primary,
      onTap: onTap,
    ),
  );

  group('★ the five states — goldens', () {
    testWidgets('live', (tester) async {
      await pumpDs(tester, tile());
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_live.png'),
      );
    });

    testWidgets('out of range — amber, and it says so in one word', (
      tester,
    ) async {
      live.value = sample(118);
      await pumpDs(tester, tile());
      expect(find.text('Caution'), findsOneWidget);
      expect(
        find.text('CAUTION'),
        findsNothing,
        reason: 'uppercase is the label only',
      );
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_out_of_range.png'),
      );
    });

    testWidgets('stale — the readout dims, the word does not', (tester) async {
      live.value = sample(89, age: const Duration(seconds: 2));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(find.text('2 s ago'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      // The dimming wraps only the readout; the header sits outside it.
      final dim = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(dim.opacity, GaugeTile.dimmedOpacity);
      expect(
        find.descendant(
          of: find.byType(AnimatedOpacity),
          matching: find.text('2 s ago'),
        ),
        findsNothing,
      );
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_stale.png'),
      );
    });

    testWidgets('unavailable — a dash at full strength, not a stale number', (
      tester,
    ) async {
      live.value = sample(89, age: const Duration(seconds: 6));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('89'), findsNothing);
      expect(find.text('No data'), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_unavailable.png'),
      );
    });

    testWidgets('unsupported', (tester) async {
      await pumpDs(
        tester,
        tile(spec: coolant.copyWith(supported: false)),
        reducedMotion: true,
      );
      expect(find.text('Not supported'), findsOneWidget);
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_unsupported.png'),
      );
    });
  });

  group('variants — goldens', () {
    testWidgets('arc', (tester) async {
      await pumpDs(tester, tile(variant: GaugeVariant.arc), height: 300);
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_arc.png'),
      );
    });

    testWidgets('bar', (tester) async {
      await pumpDs(tester, tile(variant: GaugeVariant.bar));
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_bar.png'),
      );
    });

    testWidgets('sparkline', (tester) async {
      final history = ValueNotifier<List<double>>([80, 84, 88, 91, 89, 90, 89]);
      await pumpDs(
        tester,
        tile(variant: GaugeVariant.sparkline, history: history),
        height: 300,
      );
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_sparkline.png'),
      );
    });

    testWidgets('primary readout at text scale 2.0 still fits', (tester) async {
      await pumpDs(
        tester,
        tile(primary: true, width: 328),
        textScale: 2.0,
        height: 360,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_primary_2x.png'),
      );
    });

    testWidgets('high contrast', (tester) async {
      live.value = sample(118);
      await pumpDs(tester, tile(), highContrast: true);
      // The flag must reach the tile through context.tokens, not just the
      // harness: the numeral takes the high-contrast amber.
      expect(
        tester.widget<Text>(find.text('118')).style!.color,
        TorqueTokens.highContrast.tellAmber,
      );
      await expectLater(
        find.byType(GaugeTile),
        matchesGoldenFile('goldens/gauge_high_contrast.png'),
      );
    });
  });

  group('★ B.8 — nothing overflows at large text', () {
    for (final (name, spec, value, variant, width, scale) in [
      (
        '4-digit RPM, 2-up tile, 1.5',
        rpm,
        6500.0,
        GaugeVariant.numeric,
        154.0,
        1.5,
      ),
      (
        '4-digit RPM, 2-up tile, 2.0',
        rpm,
        6500.0,
        GaugeVariant.numeric,
        154.0,
        2.0,
      ),
      (
        '4-digit RPM, arc, 2-up, 2.0',
        rpm,
        6500.0,
        GaugeVariant.arc,
        154.0,
        2.0,
      ),
      ('6-digit max, 2-up, 1.0', rpm, 655350.0, GaugeVariant.bar, 154.0, 1.0),
      (
        'long label, sparkline, 1-up, 2.0',
        rpm,
        6500.0,
        GaugeVariant.sparkline,
        328.0,
        2.0,
      ),
    ]) {
      testWidgets(name, (tester) async {
        live.value = PidSample(pid: spec.pid, value: value, at: t0);
        await pumpDs(
          tester,
          tile(spec: spec, variant: variant, width: width),
          textScale: scale,
          height: 400,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(spec.format(value)), findsOneWidget);
      });
    }

    testWidgets('the hero with a 5-digit pressure at 2.0', (tester) async {
      const kpa = GaugeSpec(
        pid: '23',
        label: 'Fuel rail pressure',
        unit: 'kPa',
        min: 0,
        max: 655350,
      );
      live.value = PidSample(pid: '23', value: 35000, at: t0);
      await pumpDs(
        tester,
        tile(spec: kpa, primary: true, width: 328),
        textScale: 2.0,
        height: 400,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('★ hard rule 3 — rendering model', () {
    testWidgets('the numeral is swapped in the same frame, never tweened', (
      tester,
    ) async {
      await pumpDs(tester, tile());
      expect(find.text('89'), findsOneWidget);
      live.value = sample(93);
      await tester.pump();
      expect(find.text('93'), findsOneWidget);
      expect(find.text('89'), findsNothing);
    });

    testWidgets('the tile root is a RepaintBoundary; one readout builder', (
      tester,
    ) async {
      await pumpDs(tester, tile());
      expect(
        tester.renderObject(find.byType(GaugeTile)).isRepaintBoundary,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(GaugeTile),
          matching: find.byType(ListenableBuilder),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the chrome is not rebuilt when a sample arrives', (
      tester,
    ) async {
      await pumpDs(tester, tile());
      final label = find.text('COOLANT');
      // A rebuilt chrome would create a new Text widget instance; a reused
      // Element proves nothing, the widget identity does.
      final before = tester.widget<Text>(label);
      live.value = sample(95);
      await tester.pump();
      live.value = sample(96);
      await tester.pump();
      expect(identical(tester.widget<Text>(label), before), isTrue);
    });

    testWidgets('a stale transition does not re-inflate the readout', (
      tester,
    ) async {
      await pumpDs(tester, tile());
      final before = tester.element(find.byType(RangeBar));
      clock.tick(t0.add(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      live.value = sample(90, age: Duration.zero);
      clock.tick(t0.add(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      expect(identical(tester.element(find.byType(RangeBar)), before), isTrue);
    });
  });

  group('★ hard rule 4 — staleness is a state', () {
    testWidgets('decays through the shared clock with no new sample', (
      tester,
    ) async {
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(find.text('89'), findsOneWidget);

      clock.tick(t0.add(const Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('1 s ago'), findsOneWidget);
      expect(
        find.text('89'),
        findsOneWidget,
        reason: 'stale still shows, dimmed',
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        GaugeTile.dimmedOpacity,
      );

      clock.tick(t0.add(const Duration(seconds: 6)));
      await tester.pump();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('the fade takes 400 ms, and 0 ms under reduced motion', (
      tester,
    ) async {
      await pumpDs(tester, tile());
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        Motion.stalenessDecay,
      );
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        Duration.zero,
      );
    });

    testWidgets(
      'while stale, amber drops to ink — desaturation by colour, not filter',
      (tester) async {
        live.value = sample(118, age: const Duration(seconds: 2));
        await pumpDs(tester, tile(), reducedMotion: true);
        final numeral = tester.widget<Text>(find.text('118'));
        expect(numeral.style!.color, TorqueTokens.dark.inkSecondary);
        expect(find.byType(ColorFiltered), findsNothing);
      },
    );
  });

  group('★ stale against how often the session asks — SPEC §5.3', () {
    // Load on a 45 ms adapter, recording a trip: asked every 940 ms and
    // measured against its tier's 200 ms, it read "0 s ago" at 40 % for
    // most of every second while it updated normally.
    // Seen on the simulator: beside a trip recording's extra PIDs, and on
    // any slow adapter, a reading is asked every half second or more.
    // Judged against its spec's 125 ms it dimmed and undimmed — a clock and
    // "0 s ago" — between answers, and the Dashboard jerked.
    Future<void> at(WidgetTester tester, int ms, {bool sample = false}) async {
      final when = t0.add(Duration(milliseconds: ms));
      if (sample) live.value = PidSample(pid: '05', value: 89, at: when);
      clock.tick(when);
      await tester.pump();
    }

    bool staleNow() => find.byIcon(Icons.schedule).evaluate().isNotEmpty;

    ValueNotifier<Duration?> askedEvery(int ms) {
      final n = ValueNotifier<Duration?>(Duration(milliseconds: ms));
      addTearDown(n.dispose);
      return n;
    }

    testWidgets('★ a reading asked every 600 ms, answered on time, never '
        'reads as stale', (tester) async {
      await pumpDs(
        tester,
        tile(expectedInterval: askedEvery(600)),
        reducedMotion: true,
      );
      var stale = 0;
      for (var ms = 0; ms <= 6000; ms += 100) {
        await at(tester, ms, sample: ms % 600 == 0);
        if (staleNow()) stale++;
      }
      expect(stale, 0, reason: 'dimmed between on-time readings');
    });

    testWidgets('a reading that stops is stale at twice the cadence, then '
        'No data', (tester) async {
      await pumpDs(
        tester,
        tile(expectedInterval: askedEvery(600)),
        reducedMotion: true,
      );
      for (var ms = 0; ms <= 1800; ms += 600) {
        await at(tester, ms, sample: true);
      }
      await at(tester, 1800 + 1100);
      expect(staleNow(), isFalse, reason: 'not yet late');
      await at(tester, 1800 + 1300);
      expect(staleNow(), isTrue);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        GaugeTile.dimmedOpacity,
      );
      await at(tester, 1800 + 5100);
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('what the answers do never moves the line', (tester) async {
      // Hard rule 4: the tile learns nothing from arrivals. An outage, or a
      // run of slow answers, cannot stretch what it counts as on time.
      await pumpDs(
        tester,
        tile(expectedInterval: askedEvery(600)),
        reducedMotion: true,
      );
      for (final ms in [0, 600, 3600, 6600, 7200]) {
        await at(tester, ms, sample: true);
      }
      await at(tester, 7200 + 1300);
      expect(staleNow(), isTrue);
    });

    testWidgets('★ a cadence that shortens re-judges the tile at once', (
      tester,
    ) async {
      final cadence = ValueNotifier<Duration?>(const Duration(seconds: 1));
      addTearDown(cadence.dispose);
      live.value = sample(89, age: const Duration(milliseconds: 400));
      await pumpDs(
        tester,
        tile(expectedInterval: cadence),
        reducedMotion: true,
      );
      expect(find.byIcon(Icons.schedule), findsNothing);

      // The session stopped asking: no new sample, and no clock tick.
      cadence.value = null;
      await tester.pump();
      expect(
        find.byIcon(Icons.schedule),
        findsOneWidget,
        reason: "back on the spec's 125 ms",
      );
    });

    testWidgets('★ under a second it says so — never "0 s ago"', (
      tester,
    ) async {
      live.value = sample(89, age: const Duration(milliseconds: 400));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(find.text('<1 s ago'), findsOneWidget);
      expect(find.text('0 s ago'), findsNothing);
    });

    testWidgets('★ and in words: less than a second, then one second', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      live.value = sample(89, age: const Duration(milliseconds: 400));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(
        find.bySemanticsLabel(
          'Coolant, 89 °C, less than a second ago. This reading is not live',
        ),
        findsOneWidget,
      );

      live.value = sample(89, age: const Duration(milliseconds: 1500));
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          'Coolant, 89 °C, 1 second ago. This reading is not live',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    test('the age in the header and in words', () {
      expect(GaugeTile.ageNote(Duration.zero), '<1 s ago');
      expect(GaugeTile.ageNote(const Duration(milliseconds: 999)), '<1 s ago');
      expect(GaugeTile.ageNote(const Duration(seconds: 1)), '1 s ago');
      expect(GaugeTile.ageNote(const Duration(milliseconds: 4200)), '4 s ago');
      expect(
        GaugeTile.ageSpoken(const Duration(milliseconds: 999)),
        'less than a second ago',
      );
      expect(GaugeTile.ageSpoken(const Duration(seconds: 1)), '1 second ago');
      expect(GaugeTile.ageSpoken(const Duration(seconds: 3)), '3 seconds ago');
    });
  });

  group('★ B.8 — one Semantics node, words for every colour', () {
    testWidgets(
      'live: exactly one node, with label, value, unit, range position',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpDs(tester, tile());
        expect(
          find.bySemanticsLabel('Coolant, 89 °C, mid-range'),
          findsOneWidget,
        );
        // The chrome contributes nothing of its own.
        expect(find.bySemanticsLabel(RegExp('COOLANT')), findsNothing);
        expect(find.bySemanticsLabel(RegExp(r'^°C$')), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('stale and unavailable words never leak as separate nodes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      live.value = sample(89, age: const Duration(seconds: 2));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(
        find.bySemanticsLabel(
          'Coolant, 89 °C, 2 seconds ago. This reading is not live',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 s ago'), findsNothing);

      live.value = sample(89, age: const Duration(seconds: 6));
      await pumpDs(tester, tile(), reducedMotion: true);
      expect(find.bySemanticsLabel('Coolant, no data'), findsOneWidget);
      expect(find.bySemanticsLabel('No data'), findsNothing);

      await pumpDs(
        tester,
        tile(spec: coolant.copyWith(supported: false)),
        reducedMotion: true,
      );
      expect(
        find.bySemanticsLabel('Coolant, not available on this vehicle'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a tappable tile is a button a screen reader can activate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpDs(tester, tile(onTap: () => taps++));
      final node = tester.getSemantics(
        find.bySemanticsLabel('Coolant, 89 °C, mid-range'),
      );
      expect(node.flagsCollection.isButton, isTrue);
      tester.semantics.tap(find.semantics.byLabel('Coolant, 89 °C, mid-range'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('★ a tile built already at Caution has crossed nothing', (
      tester,
    ) async {
      // Edit mode and a reorder build tiles anew; a Caution already there
      // was re-announced as a new fault each time.
      final handle = tester.ensureSemantics();
      live.value = sample(118);
      await pumpDs(tester, tile());
      expect(
        _hasLiveRegion(
          tester,
          'Coolant, 118 °C, caution, outside its normal range',
        ),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('liveRegion fires on the threshold crossing, not per sample', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDs(tester, tile());
      live.value = sample(118);
      await tester.pump();
      expect(
        _hasLiveRegion(
          tester,
          'Coolant, 118 °C, caution, outside its normal range',
        ),
        isTrue,
      );

      live.value = sample(119);
      await tester.pump();
      expect(
        _hasLiveRegion(
          tester,
          'Coolant, 119 °C, caution, outside its normal range',
        ),
        isFalse,
      );

      live.value = sample(90);
      await tester.pump();
      expect(_hasLiveRegion(tester, 'Coolant, 90 °C, mid-range'), isTrue);
      handle.dispose();
    });
  });

  group('GaugeSpec', () {
    test('position, band and format', () {
      expect(coolant.position(75), closeTo(0.5, 1e-9));
      expect(coolant.position(-10), 0);
      expect(coolant.position(999), 1);
      expect(coolant.bandLow, closeTo(0.5, 1e-9));
      expect(coolant.bandHigh, closeTo(0.7, 1e-9));
      expect(coolant.inRange(105), isTrue);
      expect(coolant.inRange(105.1), isFalse);
      expect(coolant.format(null), '—');
      expect(coolant.format(0), '0', reason: 'zero is a value');
      expect(
        const GaugeSpec(
          pid: 'x',
          label: 'x',
          unit: '',
          min: 0,
          max: 100,
          decimals: 1,
        ).format(12.34),
        '12.3',
      );
    });

    test('stateFor covers all five states', () {
      final now = t0;
      expect(
        GaugeTile.stateFor(coolant.copyWith(supported: false), sample(89), now),
        GaugeState.unsupported,
      );
      expect(GaugeTile.stateFor(coolant, null, now), GaugeState.unavailable);
      expect(
        GaugeTile.stateFor(coolant, sample(null), now),
        GaugeState.unavailable,
      );
      expect(
        GaugeTile.stateFor(
          coolant,
          sample(89, age: const Duration(seconds: 6)),
          now,
        ),
        GaugeState.unavailable,
      );
      expect(
        GaugeTile.stateFor(
          coolant,
          sample(89, age: const Duration(milliseconds: 300)),
          now,
        ),
        GaugeState.stale,
      );
      expect(
        GaugeTile.stateFor(
          coolant,
          sample(89, age: const Duration(milliseconds: 200)),
          now,
        ),
        GaugeState.live,
      );
      expect(
        GaugeTile.stateFor(coolant, sample(120), now),
        GaugeState.outOfRange,
      );
    });
  });

  group('PidBus', () {
    test(
      'one notifier per PID, created on first use, cleared on disconnect',
      () {
        final bus = PidBus();
        final n = bus.of('0C');
        expect(identical(bus.of('0C'), n), isTrue);
        bus.publish(PidSample(pid: '0C', value: 850, at: t0));
        expect(n.value?.value, 850);
        bus.clear();
        expect(n.value, isNull);
        bus.dispose();
      },
    );
  });
}

bool _hasLiveRegion(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  return node.flagsCollection.isLiveRegion;
}
