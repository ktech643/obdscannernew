import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/settings/diagnostics_log_screen.dart';
import 'package:torque_obd2/providers/app_providers.dart';
import 'package:torque_obd2/providers/persistence.dart';
import 'package:torque_obd2/protocol/protocol_log.dart';

/// SPEC §10.4 — the diagnostics log renders real events, masks the VIN,
/// and copies to the clipboard.
void main() {
  late Persistence store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<void> pump(
    WidgetTester tester,
    ProtocolLog log, {
    String? vin,
  }) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: ChangeNotifierProvider(
          create: (_) => SettingsProvider(store),
          child: MaterialApp(
            theme: torqueTheme(),
            debugShowCheckedModeBanner: false,
            home: DiagnosticsLogScreen(log: log, vin: vin),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty log explains what it is', (tester) async {
    final log = ProtocolLog();
    await pump(tester, log);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('renders commands and replies', (tester) async {
    final log = ProtocolLog()
      ..command('010C')
      ..reply('41 0C 1B 20', parsed: '1,088 rpm', latencyMs: 112);
    await pump(tester, log);

    expect(find.text('010C'), findsOneWidget);
    expect(find.text('41 0C 1B 20'), findsOneWidget);
    expect(find.text('1,088 rpm · 112 ms'), findsOneWidget);
    expect(find.text('2 events'), findsOneWidget);
  });

  testWidgets('masks the VIN when masking is on', (tester) async {
    final log = ProtocolLog()
      ..reply('49 02 01 31 48 47 42 48 34 31 4A 58 4D 4E 31 30 39 31 38 36');
    const vin = '1HGBH41JXMN109186';
    await pump(tester, log, vin: vin);

    expect(find.textContaining('31 48 47'), findsOneWidget);
    expect(find.textContaining('39 31 38 36'), findsOneWidget);
    expect(find.textContaining('1HGBH41JXMN109186'), findsNothing);
    expect(find.textContaining('••'), findsOneWidget);
  });

  testWidgets('clear removes all events', (tester) async {
    final log = ProtocolLog()..command('010C');
    await pump(tester, log);
    expect(find.text('1 events'), findsOneWidget);

    await tester.tap(find.widgetWithText(GhostButton, 'Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();

    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('copy puts the rendered log on the clipboard', (
    tester,
  ) async {
    final log = ProtocolLog()..command('010C');
    await pump(tester, log);

    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    final copyCall = calls.firstWhere(
      (c) => c.method == 'Clipboard.setData',
      orElse: () => fail('Clipboard.setData was not called'),
    );
    expect(copyCall.arguments['text'], contains('010C'));
  });
}
