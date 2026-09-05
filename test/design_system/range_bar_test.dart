import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/design_system/design_system.dart';

import 'harness.dart';

void main() {
  testWidgets('★ marker moves in 120 ms easeOut; the track never repaints', (
    tester,
  ) async {
    final pos = ValueNotifier<double?>(0.2);
    await pumpDs(
      tester,
      SizedBox(
        width: 200,
        child: RangeBar(position: pos, bandLow: 0.5, bandHigh: 0.7),
      ),
    );
    final x0 = tester
        .getCenter(
          find
              .descendant(
                of: find.byType(RangeBar),
                matching: find.byType(ColoredBox),
              )
              .last,
        )
        .dx;

    pos.value = 0.8;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester
        .getCenter(
          find
              .descendant(
                of: find.byType(RangeBar),
                matching: find.byType(ColoredBox),
              )
              .last,
        )
        .dx;
    expect(mid, greaterThan(x0));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 120));
    final x1 = tester
        .getCenter(
          find
              .descendant(
                of: find.byType(RangeBar),
                matching: find.byType(ColoredBox),
              )
              .last,
        )
        .dx;
    expect(x1, greaterThan(mid));
    expect(tester.hasRunningAnimations, isFalse);
    // The static half sits in its own RepaintBoundary.
    expect(
      find.descendant(
        of: find.byType(RangeBar),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('under reduced motion the marker jumps', (tester) async {
    final pos = ValueNotifier<double?>(0.2);
    await pumpDs(
      tester,
      SizedBox(width: 200, child: RangeBar(position: pos)),
      reducedMotion: true,
    );
    pos.value = 0.8;
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('no reading, no marker', (tester) async {
    final pos = ValueNotifier<double?>(null);
    await pumpDs(tester, SizedBox(width: 200, child: RangeBar(position: pos)));
    expect(
      find.descendant(
        of: find.byType(RangeBar),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });

  testWidgets('golden — in band, out of band', (tester) async {
    await pumpDs(
      tester,
      Column(
        children: [
          SizedBox(
            width: 200,
            child: RangeBar(
              position: ValueNotifier(0.6),
              bandLow: 0.5,
              bandHigh: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            child: RangeBar(
              position: ValueNotifier(0.9),
              bandLow: 0.5,
              bandHigh: 0.7,
              tone: Tell.amber,
            ),
          ),
        ],
      ),
      reducedMotion: true,
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/range_bar.png'),
    );
  });
}
