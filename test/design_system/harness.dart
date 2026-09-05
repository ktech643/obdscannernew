import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// Renders [child] inside the app theme at a fixed size, with the knobs
/// the accessibility floor cares about.
Future<void> pumpDs(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double height = 240,
  double textScale = 1.0,
  bool reducedMotion = false,
  bool ios = false,
  bool highContrast = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AdaptiveScope(
      platform: FakePlatform(isAndroid: !ios),
      child: MaterialApp(
        theme: torqueTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
            highContrast: highContrast,
          ),
          child: app!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(Space.x16),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

/// An RPM spec: four digits at the top of its range.
const rpm = GaugeSpec(
  pid: '0C',
  label: 'Engine speed',
  unit: 'rpm',
  min: 0,
  max: 8000,
  normalLow: 600,
  normalHigh: 6500,
);

/// A coolant-temperature spec: 0–150 °C, normal 75–105.
const coolant = GaugeSpec(
  pid: '05',
  label: 'Coolant',
  unit: '°C',
  min: 0,
  max: 150,
  normalLow: 75,
  normalHigh: 105,
);

final t0 = DateTime.utc(2026, 9, 5, 12);

PidSample sample(double? v, {Duration age = Duration.zero}) =>
    PidSample(pid: '05', value: v, at: t0.subtract(age));
