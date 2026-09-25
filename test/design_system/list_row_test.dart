import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsData;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/share_file.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// ListRow's three kinds: a link, a statement, a disabled control — and
/// ShareFile's anchor, which must lie inside the screen.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: torqueTheme(),
      home: Scaffold(body: ListView(children: [child])),
    ),
  );

  SemanticsData node(WidgetTester tester, String label) => tester
      .getSemantics(find.bySemanticsLabel(RegExp('^$label')))
      .getSemanticsData();

  testWidgets('★ a row with no tap is a statement, not a disabled control', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const ListRow(title: 'Purchases', subtitle: 'The store sees an ID.'),
    );
    final data = node(tester, 'Purchases');
    // VoiceOver read the privacy screen's facts as "dimmed" before.
    expect(data.flagsCollection.isEnabled, Tristate.none);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    final title = tester.widget<Text>(find.text('Purchases'));
    expect(
      title.style?.color,
      TorqueTokens.dark.inkPrimary,
      reason: 'not 3.97:1',
    );
    handle.dispose();
  });

  testWidgets('a disabled row says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, ListRow(title: 'History', enabled: false, onTap: () {}));
    final data = node(tester, 'History');
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('a link is a button with a chevron', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, ListRow(title: 'Export', onTap: () => taps++));
    final data = node(tester, 'Export');
    expect(data.flagsCollection.isButton, isTrue);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Export'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('★ a short value leaves the chevron at the edge and the title '
      'its width', (tester) async {
    // Seen on the simulator: "0 scans ›" sat mid-row, and a reminder's
    // subtitle wrapped in half the width beside "Due in 10,000 km".
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      ListRow(
        title: 'Diagnostic history',
        subtitle: 'Every 10,000 km or 6 months · next at 152,380 km',
        value: '0 scans',
        onTap: () {},
      ),
    );
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(chevron.right, closeTo(390 - Space.gutter, 1));
    final value = tester.getRect(find.text('0 scans'));
    expect(value.right, closeTo(chevron.left - Space.x8, 1));
    final subtitle = tester.getRect(
      find.text('Every 10,000 km or 6 months · next at 152,380 km'),
    );
    expect(subtitle.width, greaterThan(390 * 0.5), reason: 'not half');
  });

  testWidgets('★ in a narrow sheet a long value still leaves the title room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const width = 240.0;
    await pump(
      tester,
      Center(
        child: SizedBox(
          width: width,
          child: ListRow(
            title: 'Oil and filter',
            value: 'Due in 10,000 km or 6 months',
            onTap: () {},
          ),
        ),
      ),
    );
    const inner = width - Space.gutter * 2;
    // Sized from the screen, the value took 161 of these 208 and left the
    // title seven pixels.
    expect(
      tester.getSize(find.text('Due in 10,000 km or 6 months')).width,
      lessThanOrEqualTo(inner * 0.45 + 0.5),
    );
    expect(
      tester.getSize(find.text('Oil and filter')).width,
      greaterThan(inner * 0.3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('★ a toned value carries its glyph, not colour alone', (
    tester,
  ) async {
    // Hard rule 11: "Overdue" in amber had the word and the colour, and
    // not the glyph every other toned value draws.
    await pump(
      tester,
      ListRow(title: 'Oil', value: 'Overdue', tone: Tell.amber, onTap: () {}),
    );
    expect(find.byIcon(Tell.amber.glyph), findsOneWidget);
    await pump(tester, ListRow(title: 'Oil', value: 'Due', onTap: () {}));
    expect(find.byIcon(Tell.amber.glyph), findsNothing, reason: 'no tone');
  });

  testWidgets('★ the share anchor is clipped to the screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext row;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 780, // half under the bottom edge
              height: 48,
              child: Builder(
                builder: (c) {
                  row = c;
                  return const ColoredBox(color: Colors.black);
                },
              ),
            ),
          ],
        ),
      ),
    );
    final origin = ShareFile.originOf(row)!;
    expect(origin.bottom, lessThanOrEqualTo(800));
    expect(origin.top, 780);
    expect(origin.height, 20);
  });
}
