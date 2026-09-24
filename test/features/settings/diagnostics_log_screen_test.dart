import 'dart:io';

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
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §10.4 — the diagnostics log renders real events, masks every VIN it
/// carried, and copies or shares the same masked text.
///
/// The masking tests use logs built the way the app builds them: a real
/// [ObdSession] replaying a recorded car, so the Mode 09 reply has its
/// decoded column and the log has noted the VIN. An earlier version
/// hand-built a reply with no decoded column and handed the screen the VIN
/// to mask — the one shape that made masking look complete.
void main() {
  const civicVin = '1HGBH41JXMN109186';
  const corruptVin = '1HGBH41JXMN109187'; // vin_reread's first read

  late Persistence store;

  /// Tall enough that the list builds every row, so an assertion that a VIN
  /// is *nowhere* on screen covers every event rather than the first few.
  const tall = Size(390, 8000);
  late ProtocolLog headersCanLog;
  late ProtocolLog rereadLog;

  /// Connects a real session with [log] to [trace] and reads the VIN — the
  /// same path `GarageController.onConnected` takes on every connect.
  /// Outside `testWidgets`, because its clock is fake and replay needs a
  /// real one.
  Future<ProtocolLog> recorded(String trace, {int vinReads = 1}) async {
    final log = ProtocolLog();
    final session = ObdSession(timeScale: 0.05, log: log);
    final source = File('assets/traces/$trace.obdtrace').readAsStringSync();
    expect(
      await session.connect(MockTransport(ObdTrace.parse(source), speed: 100)),
      isTrue,
    );
    // No tiles, so no polling: the log is the handshake and the VIN reads,
    // short enough for the screen to build every row at once.
    session.setVisible({});
    for (var i = 0; i < vinReads; i++) {
      await session.readVin();
    }
    await session.disconnect();
    session.dispose();
    return log;
  }

  setUpAll(() async {
    headersCanLog = await recorded('headers_can');
    rereadLog = await recorded('vin_reread', vinReads: 2);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Persistence.open();
  });

  Future<List<String>> pump(
    WidgetTester tester,
    ProtocolLog log, {
    Size size = const Size(390, 780),
  }) async {
    final shared = <String>[];
    tester.view.physicalSize = size;
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
            home: DiagnosticsLogScreen(
              log: log,
              share: (text, _) async => shared.add(text),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shared;
  }

  /// Every string on screen, joined — so a VIN split over two Text widgets
  /// would still be found.
  String screenText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');

  List<MethodCall> captureClipboard(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return calls;
  }

  String copied(List<MethodCall> calls) =>
      calls
              .firstWhere(
                (c) => c.method == 'Clipboard.setData',
                orElse: () => fail('Clipboard.setData was not called'),
              )
              .arguments['text']
          as String;

  testWidgets('empty log explains what it is', (tester) async {
    await pump(tester, ProtocolLog());
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

  group('★ §10.4 — every VIN the log carried is masked', () {
    test('the session notes the VIN it reads into the log', () {
      expect(headersCanLog.knownVins, contains(civicVin));
    });

    testWidgets('★ both columns of a real Mode 09 reply are masked', (
      tester,
    ) async {
      await pump(tester, headersCanLog, size: tall);
      final text = screenText(tester);
      expect(text, isNot(contains(civicVin)), reason: 'the decoded column');
      expect(text, isNot(contains('42 48 34 31 4A 58 4D')), reason: 'hex');
      expect(text, contains('1HG••••••••••9186'), reason: 'masked, not gone');
      expect(
        find.textContaining('49 02'),
        findsWidgets,
        reason: 'the Mode 09 reply row itself was built and checked',
      );
    });

    testWidgets('★ a clone\'s corrupt first read is masked too', (
      tester,
    ) async {
      // One character off the real VIN is sixteen real characters; masking
      // only exact matches of a known-good VIN showed it almost whole.
      expect(rereadLog.knownVins, containsAll([civicVin, corruptVin]));
      await pump(tester, rereadLog, size: tall);
      final text = screenText(tester);
      expect(text, isNot(contains(corruptVin)));
      expect(text, isNot(contains(civicVin)));
      expect(text, isNot(contains('BH41JXMN10')));
    });

    testWidgets('★ Copy and Share carry the same masked text', (tester) async {
      final shared = await pump(tester, headersCanLog, size: tall);
      final calls = captureClipboard(tester);

      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.pumpAndSettle();

      final clip = copied(calls);
      expect(clip, isNot(contains(civicVin)));
      expect(clip, isNot(contains('42 48 34 31 4A 58 4D')));
      expect(shared, hasLength(1));
      expect(shared.single, clip, reason: 'one rule for both ways out');
    });

    testWidgets('★ opting in shows and sends the VIN whole', (tester) async {
      final shared = await pump(tester, headersCanLog, size: tall);
      expect(find.text('Include the VIN'), findsOneWidget);

      await tester.tap(find.byType(AdaptiveSwitch));
      await tester.pumpAndSettle();
      expect(screenText(tester), contains(civicVin));

      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.pumpAndSettle();
      expect(shared.single, contains(civicVin));
      expect(shared.single, contains('42 48 34 31 4A 58 4D'));
    });
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

  testWidgets('copy puts the rendered log on the clipboard', (tester) async {
    final log = ProtocolLog()..command('010C');
    await pump(tester, log);
    final calls = captureClipboard(tester);

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(copied(calls), contains('010C'));
  });

  testWidgets('the opt-in row fits at text scale 2.0 on a 320 pt phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, headersCanLog, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
  });
}
