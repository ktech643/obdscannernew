import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// B.4 sheets: a tall one can always be left.
void main() {
  Future<void> open(WidgetTester tester, {bool dismissible = true}) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAdaptiveSheet<void>(
                    context,
                    dismissible: dismissible,
                    builder: (_) => ListView(
                      shrinkWrap: true,
                      children: [
                        for (var i = 0; i < 40; i++)
                          ListTile(title: Text('Row $i')),
                      ],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('★ a sheet taller than the screen leaves scrim to tap, and a '
      'handle', (tester) async {
    // Seen on the simulator: a gauge's sheet filled the screen, a drag
    // down scrolled its list, and there was no way out on iOS.
    await open(tester);
    expect(find.text('Row 0'), findsOneWidget);
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    expect(sheetTop, greaterThan(874 * 0.09), reason: 'scrim above');
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsNothing, reason: 'the scrim closes it');
  });

  testWidgets('a sheet that must stay has neither', (tester) async {
    await open(tester, dismissible: false);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsOneWidget);
  });
}
