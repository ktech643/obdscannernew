import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/design_system/design_system.dart';

import 'harness.dart';

void main() {
  group('★ PrimaryButton', () {
    testWidgets('keeps its width while loading', (tester) async {
      await pumpDs(
        tester,
        const PrimaryButton(label: 'Connect', onPressed: _noop, expand: false),
      );
      final idle = tester.getSize(find.byType(PrimaryButton));
      await pumpDs(
        tester,
        const PrimaryButton(
          label: 'Connect',
          onPressed: _noop,
          expand: false,
          loading: true,
        ),
      );
      final busy = tester.getSize(find.byType(PrimaryButton));
      expect(busy.width, idle.width);
      expect(busy.height, PrimaryButton.height);
      expect(find.byType(AdaptiveLoading), findsOneWidget);
    });

    testWidgets('is 56 tall and does not fire while loading', (tester) async {
      var taps = 0;
      await pumpDs(
        tester,
        PrimaryButton(label: 'Go', onPressed: () => taps++, loading: true),
      );
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 0);
      expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    });

    testWidgets('★ a screen reader can activate it', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpDs(
        tester,
        PrimaryButton(label: 'Connect', onPressed: () => taps++),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Connect'));
      expect(node.flagsCollection.isButton, isTrue);
      tester.semantics.tap(find.semantics.byLabel('Connect'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a long label at 2.0 scales down instead of overflowing', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 320,
          child: PrimaryButton(
            label: 'Continue without an adapter',
            onPressed: _noop,
          ),
        ),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    });

    testWidgets('golden', (tester) async {
      await pumpDs(
        tester,
        const PrimaryButton(label: 'Connect', onPressed: _noop),
      );
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button.png'),
      );
    });
  });

  group('★ DestructiveButton', () {
    testWidgets('fires only on the second tap, and disarms if you wait', (
      tester,
    ) async {
      var fired = 0;
      await pumpDs(
        tester,
        DestructiveButton(label: 'Clear codes', onConfirmed: () => fired++),
      );
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      expect(fired, 0);
      expect(find.text('Tap again to confirm'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Clear codes'), findsOneWidget);
      expect(fired, 0);

      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      expect(fired, 1);
      expect(
        find.text('Clear codes'),
        findsOneWidget,
        reason: 'disarmed after firing',
      );
    });

    testWidgets('a screen reader goes through both steps too', (tester) async {
      final handle = tester.ensureSemantics();
      var fired = 0;
      await pumpDs(
        tester,
        DestructiveButton(label: 'Clear codes', onConfirmed: () => fired++),
      );
      tester.semantics.tap(find.semantics.byLabel('Clear codes'));
      await tester.pump();
      expect(fired, 0);
      tester.semantics.tap(
        find.semantics.byLabel(RegExp('Tap again to confirm')),
      );
      await tester.pump();
      expect(fired, 1);
      handle.dispose();
    });

    testWidgets('the armed label at 2.0 fits in 320', (tester) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 320,
          child: DestructiveButton(label: 'Clear codes', onConfirmed: _noop),
        ),
        textScale: 2.0,
        reducedMotion: true,
      );
      final before = tester.getSize(find.byType(DestructiveButton));
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DestructiveButton)), before);
    });

    testWidgets('outline first, solid only when armed — golden', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const DestructiveButton(label: 'Clear codes', onConfirmed: _noop),
        reducedMotion: true,
      );
      await expectLater(
        find.byType(DestructiveButton),
        matchesGoldenFile('goldens/destructive_idle.png'),
      );
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      await expectLater(
        find.byType(DestructiveButton),
        matchesGoldenFile('goldens/destructive_armed.png'),
      );
    });
  });

  testWidgets('GhostButton is exactly 48 tall even inside a tall parent', (
    tester,
  ) async {
    await pumpDs(
      tester,
      const SizedBox(
        height: 200,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GhostButton(label: 'Skip', onPressed: _noop),
        ),
      ),
    );
    final size = tester.getSize(find.byType(GhostButton));
    expect(size.height, Targets.min);
    expect(size.width, greaterThanOrEqualTo(Targets.min));
  });

  group('★ ConnectionBanner', () {
    testWidgets('is 44px and pushes content down rather than covering it', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: BannerHost(
            banner: ConnectionBanner(
              message: 'Reconnecting…',
              tone: Tell.amber,
              busy: true,
            ),
            child: Text('content'),
          ),
        ),
        reducedMotion: true,
      );
      expect(
        tester.getSize(find.byType(ConnectionBanner)).height,
        ConnectionBanner.height,
      );
      final bannerTop = tester.getTopLeft(find.byType(ConnectionBanner)).dy;
      final contentTop = tester.getTopLeft(find.text('content')).dy;
      expect(contentTop - bannerTop, ConnectionBanner.height);
      // Busy adds a pulse; it never replaces the tone's glyph.
      expect(find.byIcon(Tell.amber.glyph), findsOneWidget);
    });

    testWidgets('without a banner the content takes the full height', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: BannerHost(banner: null, child: Text('content')),
        ),
        reducedMotion: true,
      );
      final host = tester.getTopLeft(find.byType(BannerHost)).dy;
      expect(tester.getTopLeft(find.text('content')).dy, host);
    });

    testWidgets('★ the action is a real button for a screen reader, 48 wide', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var retried = 0;
      await pumpDs(
        tester,
        SizedBox(
          width: 328,
          child: ConnectionBanner(
            message: 'Adapter lost',
            tone: Tell.red,
            actionLabel: 'Retry',
            onAction: () => retried++,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Fault. Adapter lost'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('Retry'));
      expect(retried, 1);
      expect(
        tester.getSize(find.text('Retry').first).width + 32,
        greaterThanOrEqualTo(Targets.min),
      );
      handle.dispose();
    });

    testWidgets('golden — fault, busy, with an action', (tester) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 328,
          child: ConnectionBanner(
            message: 'Adapter lost — reconnecting',
            tone: Tell.red,
            busy: true,
            actionLabel: 'Retry',
          ),
        ),
        reducedMotion: true,
      );
      await expectLater(
        find.byType(ConnectionBanner),
        matchesGoldenFile('goldens/banner_fault.png'),
      );
    });
  });

  group('TelltaleChip and DtcRow', () {
    testWidgets('chips: every tone carries a glyph and a word — golden', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TelltaleChip(tone: Tell.none, label: 'Stored'),
            TelltaleChip(tone: Tell.red, label: 'MIL on'),
            TelltaleChip(tone: Tell.amber, label: 'Pending'),
            TelltaleChip(tone: Tell.green, label: 'Ready'),
            TelltaleChip(tone: Tell.blue, label: 'Recording'),
          ],
        ),
      );
      for (final chip in tester.widgetList<TelltaleChip>(
        find.byType(TelltaleChip),
      )) {
        expect(tester.getSize(find.byWidget(chip)).height, TelltaleChip.height);
      }
      expect(find.byIcon(Tell.red.glyph), findsOneWidget);
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/telltale_chips.png'),
      );
    });

    testWidgets('chips grow at 2.0 instead of clipping the word', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const TelltaleChip(tone: Tell.red, label: 'MIL on'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TelltaleChip)).height,
        greaterThanOrEqualTo(32),
      );
    });

    testWidgets(
      'DtcRow: 72 minimum, severity bar, unknown stays unknown — golden',
      (tester) async {
        await pumpDs(
          tester,
          SizedBox(
            width: 328,
            child: Column(
              children: [
                DtcRow(
                  code: 'P0301',
                  description: 'Cylinder 1 misfire detected',
                  severity: Tell.red,
                  status: 'Stored',
                  onTap: _noop,
                ),
                const DtcRow(
                  code: 'P1A2B',
                  description: "Manufacturer-specific — we don't have a definition for this code",
                  severity: Tell.none,
                  status: 'Pending',
                ),
              ],
            ),
          ),
          height: 300,
        );
        for (final row in tester.widgetList<DtcRow>(find.byType(DtcRow))) {
          expect(
            tester.getSize(find.byWidget(row)).height,
            greaterThanOrEqualTo(DtcRow.minHeight),
          );
        }
        expect(find.text('Fault'), findsOneWidget);
        await expectLater(
          find.byType(Column).first,
          matchesGoldenFile('goldens/dtc_rows.png'),
        );
      },
    );

    testWidgets(
      'DtcRow with the long status at 2.0 does not overflow, and is tappable by a reader',
      (tester) async {
        final handle = tester.ensureSemantics();
        var opened = 0;
        await pumpDs(
          tester,
          SizedBox(
            width: 320,
            child: DtcRow(
              code: 'P0301',
              description: 'Cylinder 1 misfire detected',
              severity: Tell.red,
              status: 'Cleared, came back',
              onTap: () => opened++,
            ),
          ),
          textScale: 2.0,
          height: 400,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(DtcRow)).height,
          greaterThanOrEqualTo(DtcRow.minHeight),
        );
        tester.semantics.tap(find.semantics.byLabel(RegExp('^P0301')));
        expect(opened, 1);
        handle.dispose();
      },
    );
  });

  group('StepProgress, EmptyStateView, ValueList, Skeleton', () {
    const steps = [
      'Reset',
      'Echo off',
      'Linefeeds off',
      'Spaces off',
      'Headers on',
      'Protocol auto',
      'First PID',
    ];

    testWidgets('StepProgress names the step; a failure is red and named', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 300,
          child: StepProgress(steps: steps, current: 5),
        ),
      );
      expect(find.text('Protocol auto'), findsOneWidget);
      await expectLater(
        find.byType(StepProgress),
        matchesGoldenFile('goldens/step_progress.png'),
      );

      await pumpDs(
        tester,
        const SizedBox(
          width: 300,
          child: StepProgress(steps: steps, current: 5, failedAt: 5),
        ),
      );
      expect(find.text('Failed: Protocol auto'), findsOneWidget);
    });

    testWidgets('EmptyStateView: what, why, one action', (tester) async {
      var acted = 0;
      await pumpDs(
        tester,
        SizedBox(
          width: 328,
          child: EmptyStateView(
            title: 'No codes stored',
            why: 'Checked 2 minutes ago. Readiness: 6 of 8 monitors complete.',
            tone: Tell.green,
            actionLabel: 'Scan again',
            onAction: () => acted++,
          ),
        ),
        height: 300,
      );
      await tester.tap(find.text('Scan again'));
      expect(acted, 1);
      await expectLater(
        find.byType(EmptyStateView),
        matchesGoldenFile('goldens/empty_state.png'),
      );
    });

    testWidgets('ValueList: partial data says "Not available" and why', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 328,
          child: ValueList(
            rows: [
              ValueRow('Protocol', 'ISO 15765-4 CAN'),
              ValueRow('Battery', '12.6 V', tone: Tell.green),
              ValueRow('VIN', null, reason: 'Not supported by this vehicle'),
            ],
          ),
        ),
        height: 300,
      );
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Not supported by this vehicle'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Not available')).style!.color,
        TorqueTokens.dark.inkSecondary,
      );
      await expectLater(
        find.byType(ValueList),
        matchesGoldenFile('goldens/value_list.png'),
      );
    });

    testWidgets('ValueList wraps a long protocol and a VIN at 2.0', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 320,
          child: ValueList(
            rows: [
              ValueRow('Protocol', 'ISO 15765-4 CAN (11 bit ID, 500 kbaud)'),
              ValueRow('VIN', 'WVWZZZ1KZBW000001'),
            ],
          ),
        ),
        textScale: 2.0,
        height: 500,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('★ ValueList: the value is flush right, not beside its label', (
      tester,
    ) async {
      // Seen on the Garage card: "Petrol" sat just after "Fuel", and each
      // row's value started wherever its own label ended.
      await pumpDs(
        tester,
        const SizedBox(
          width: 328,
          child: ValueList(
            rows: [
              ValueRow('Fuel', 'Petrol'),
              ValueRow('Odometer', '142,380 km'),
            ],
          ),
        ),
        height: 200,
      );
      final list = tester.getRect(find.byType(ValueList));
      for (final v in ['Petrol', '142,380 km']) {
        expect(tester.getRect(find.text(v)).right, closeTo(list.right, 1));
      }
      expect(tester.getRect(find.text('Fuel')).left, closeTo(list.left, 1));
    });

    testWidgets('★ ValueList: a short label leaves a long value the row', (
      tester,
    ) async {
      await pumpDs(
        tester,
        const SizedBox(
          width: 240,
          child: ValueList(rows: [ValueRow('VIN', 'WVWZZZ1KZBW000001')]),
        ),
        height: 200,
      );
      // Two Flexibles held it to half the row beside a three-letter label.
      expect(
        tester.getSize(find.text('WVWZZZ1KZBW000001')).width,
        greaterThan(240 / 2),
      );
    });

    testWidgets('★ the tile skeleton is exactly the live tile\'s height', (
      tester,
    ) async {
      final live = ValueNotifier<PidSample?>(sample(89));
      final clock = DashboardClock(start: t0);
      await pumpDs(
        tester,
        Column(
          children: [
            SizedBox(
              width: 180,
              child: GaugeTile(spec: coolant, sample: live, clock: clock),
            ),
            const SizedBox(height: 8),
            const SizedBox(width: 180, child: GaugeTileSkeleton()),
          ],
        ),
        height: 400,
        reducedMotion: true,
      );
      expect(
        tester.getSize(find.byType(GaugeTileSkeleton)).height,
        tester.getSize(find.byType(GaugeTile)).height,
      );
    });

    testWidgets('Skeleton is static under reduced motion', (tester) async {
      await pumpDs(tester, const GaugeTileSkeleton(), reducedMotion: true);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('★ B.4 — adaptive chrome, decided in one place, and monochrome', () {
    testWidgets('iOS gets Cupertino controls', (tester) async {
      await pumpDs(
        tester,
        Column(
          children: [
            AdaptiveSwitch(value: true, onChanged: (_) {}),
            const AdaptiveLoading(),
            const AdaptiveBackButton(),
          ],
        ),
        ios: true,
      );
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    });

    testWidgets('Android gets Material controls', (tester) async {
      await pumpDs(
        tester,
        Column(
          children: [
            AdaptiveSwitch(value: true, onChanged: (_) {}),
            const AdaptiveLoading(),
            const AdaptiveBackButton(),
          ],
        ),
      );
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no amber on chrome: spinner, switch, tabs are ink', (
      tester,
    ) async {
      const t = TorqueTokens.dark;
      await pumpDs(
        tester,
        Column(
          children: [
            AdaptiveSwitch(value: true, onChanged: (_) {}),
            const AdaptiveLoading(),
          ],
        ),
        ios: true,
      );
      expect(
        tester
            .widget<CupertinoSwitch>(find.byType(CupertinoSwitch))
            .activeTrackColor,
        t.inkPrimary,
      );
      expect(
        tester
            .widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            )
            .color,
        t.inkSecondary,
      );
      expect(torqueTheme().progressIndicatorTheme.color, t.inkPrimary);
    });

    testWidgets('the tab bar changes tabs without animating', (tester) async {
      var picked = -1;
      await pumpDs(
        tester,
        AdaptiveTabBar(
          tabs: const [
            AdaptiveTab(label: 'Connect', icon: Icons.bluetooth),
            AdaptiveTab(label: 'Dashboard', icon: Icons.speed),
          ],
          index: 0,
          onSelected: (i) => picked = i,
        ),
        width: 360,
        height: 120,
      );
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero,
      );
      await tester.tap(find.text('Dashboard'));
      expect(picked, 1);
    });
  });
}

void _noop() {}
