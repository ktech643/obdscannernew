import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// The form fields the Garage logs are built from. A date is picked, not
/// typed, so it is drawn as a box, not a TextField — and must still read
/// as one more field in the column.
void main() {
  testWidgets('★ a date lines up with the text fields above it', (
    tester,
  ) async {
    // Seen on the simulator: "25 Sep 2026" sat 4 pt left of "Oil and
    // filter". Flutter adds 4 inside a filled field's contentPadding; the
    // date box had the same 12 and no such gap.
    final c = TextEditingController(text: 'Oil and filter');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: torqueTheme(),
        home: Scaffold(
          body: Column(
            children: [
              LabelledField(label: 'What was done', controller: c),
              LabelledDateField(
                label: 'Date',
                date: DateTime(2026, 9, 25),
                format: (_) => '25 Sep 2026',
                onPick: () {},
              ),
            ],
          ),
        ),
      ),
    );
    double inset(Finder text, Finder box) =>
        tester.getRect(text).left - tester.getRect(box).left;
    final typed = inset(find.byType(EditableText), find.byType(TextField));
    final picked = inset(
      find.text('25 Sep 2026'),
      find
          .ancestor(
            of: find.text('25 Sep 2026'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(picked, closeTo(typed, 0.5));
    expect(
      tester.getSize(find.byType(TextField)).height,
      closeTo(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('25 Sep 2026'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .height,
        0.5,
      ),
      reason: 'the same height, too',
    );
  });

  Future<void> pump(WidgetTester tester, Widget child, {bool ios = true}) =>
      tester.pumpWidget(
        AdaptiveScope(
          platform: FakePlatform(isAndroid: !ios),
          child: MaterialApp(
            theme: torqueTheme(),
            home: Scaffold(body: ListView(children: [child])),
          ),
        ),
      );

  testWidgets('★ two fields side by side are each named by their own label', (
    tester,
  ) async {
    // Loose labels in a Row merged into one static node, and each field was
    // named by its hint — or by nothing once it held a value.
    final handle = tester.ensureSemantics();
    final litres = TextEditingController(text: '42.5');
    final cost = TextEditingController(text: '61.20');
    addTearDown(litres.dispose);
    addTearDown(cost.dispose);
    await pump(
      tester,
      Row(
        children: [
          Expanded(
            child: LabelledField(label: 'Litres', controller: litres),
          ),
          Expanded(
            child: LabelledField(label: 'Cost (GBP)', controller: cost),
          ),
        ],
      ),
    );
    for (final (label, value) in [
      ('Litres', '42.5'),
      ('Cost (GBP)', '61.20'),
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue, reason: label);
      expect(data.value, value, reason: label);
    }
    handle.dispose();
  });

  testWidgets('★ a date field says its label once', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      LabelledDateField(
        label: 'Date',
        date: DateTime(2026, 9, 25),
        format: (_) => '25 Sep 2026',
        onPick: () {},
      ),
    );
    final data = tester
        .getSemantics(find.bySemanticsLabel(RegExp('25 Sep 2026')))
        .getSemanticsData();
    // It read "Date, Date, 25 Sep 2026".
    expect(RegExp('Date').allMatches(data.label).length, 1, reason: data.label);
    handle.dispose();
  });

  testWidgets('★ an empty date is in hint ink, not tertiary', (tester) async {
    await pump(
      tester,
      LabelledDateField(
        label: 'Next due on',
        date: null,
        format: (_) => '',
        onPick: () {},
      ),
    );
    // Tertiary on the panel is 2.93:1.
    expect(
      tester.widget<Text>(find.text('No date')).style!.color,
      TorqueTokens.dark.inkSecondary,
    );
  });

  testWidgets('★ near its limit a field shows its count', (tester) async {
    // §9.8 "cap 5,000 with a counter": hidden, a pasted note was cut to
    // the limit without a word.
    final c = TextEditingController(text: 'abcde');
    addTearDown(c.dispose);
    await pump(
      tester,
      LabelledField(label: 'Notes', controller: c, maxLength: 10),
    );
    expect(find.text('5/10'), findsNothing, reason: 'far from it');
    c.text = 'abcdefghi';
    await tester.pump();
    expect(find.text('9/10'), findsOneWidget);
  });

  for (final ios in [true, false]) {
    testWidgets('★ the date picker opens on a date past its range '
        '(${ios ? 'iOS' : 'Android'})', (tester) async {
      // A reminder every 240 months is saved 7,305 days out; the form's
      // picker ended at 7,300, and opening it failed an assertion.
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdaptiveDatePicker(
              context,
              initial: DateTime(2046, 10, 1),
              first: DateTime(2021, 9, 25),
              last: DateTime(2046, 9, 25),
            ),
            child: const Text('Pick'),
          ),
        ),
        ios: ios,
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
