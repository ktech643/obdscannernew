import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/app.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// AC-16 on the tab bar: at text scale 2.0 no label wraps and no icon is
/// squeezed. The iOS bar is `CupertinoTabBar`, whose label shares a fixed
/// 46 pt item with its icon; unclamped, "Diagnostics" at 20 pt wrapped and
/// the icon above it was squashed out of its slot. Android's
/// `NavigationBar` clamps its own labels, which is why only iOS broke.
void main() {
  /// A label wrapped (or was cut) when it needs more width on one line than
  /// it was given.
  bool wrapped(RenderParagraph p) =>
      p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5;

  for (final android in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('★ ${android ? 'Android' : 'iOS'} at ${width.toInt()} pt, '
          'text scale 2.0: every label one line, every icon whole', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          AdaptiveScope(
            platform: FakePlatform(isAndroid: android),
            child: MaterialApp(
              theme: torqueTheme(),
              home: Scaffold(
                bottomNavigationBar: AdaptiveTabBar(
                  tabs: AppShell.tabs,
                  index: 1,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final tab in AppShell.tabs) {
          final label = tester.renderObject<RenderParagraph>(
            find.text(tab.label),
          );
          expect(wrapped(label), isFalse, reason: '${tab.label} wrapped');
        }
        for (final tab in AppShell.tabs) {
          final icon = find.byIcon(tab.icon);
          if (icon.evaluate().isEmpty) continue; // the selected one
          expect(tester.getSize(icon).height, greaterThanOrEqualTo(22));
        }
      });
    }
  }
}
