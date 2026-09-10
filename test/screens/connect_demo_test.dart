import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/providers/connection_provider.dart';
import 'package:torque_obd2/screens/connect/connect_screen.dart';

void main() {
  testWidgets('Demo Mode is reachable from Connect and marks the session', (
    tester,
  ) async {
    final c = ConnectionProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: const MaterialApp(home: Scaffold(body: ConnectScreen())),
      ),
    );

    // The entry point is always present on the Connect screen.
    expect(find.text('Try it without an adapter'), findsOneWidget);

    await tester.tap(find.text('Try it without an adapter'));
    await tester.pump();

    // Entering demo mode marks the session so the Dashboard renders the
    // watermarked demo strip and the app looks connected without hardware.
    expect(c.demoMode, isTrue);
    expect(c.status, ConnectionStatus.connected);

    // Let the confirmation toast's dismiss timer expire so the test teardown
    // isn't flagged for a pending timer.
    await tester.pump(const Duration(seconds: 4));
  });
}
