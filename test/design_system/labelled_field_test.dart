import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
