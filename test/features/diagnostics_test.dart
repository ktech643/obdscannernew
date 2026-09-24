import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/dtc_dictionary.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/design_system/design_system.dart';
import 'package:torque_obd2/features/diagnostics/clear_codes_sheet.dart';
import 'package:torque_obd2/features/diagnostics/code_detail_screen.dart';
import 'package:torque_obd2/features/diagnostics/diagnostics_controller.dart';
import 'package:torque_obd2/features/diagnostics/diagnostics_screen.dart';
import 'package:torque_obd2/models/enums.dart'
    show DistanceUnit, TemperatureUnit, VehicleFuel;
import 'package:torque_obd2/protocol/dtc_decoder.dart';
import 'package:torque_obd2/protocol/readiness_decoder.dart';
import 'package:torque_obd2/session/health_score.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.4 and §9.5 — Diagnostics, driven by a real session replaying a
/// recorded car. Nothing here stubs a DTC: every code on screen was
/// decoded off the wire by the same path the app uses.
void main() {
  // Traces load outside `testWidgets`: inside it the clock is fake and
  // real file I/O never completes, so a fixture read there hangs.
  late final Map<String, ObdTrace> traces;

  setUpAll(() {
    traces = {
      for (final name in const [
        'dtc_scan_can',
        'no_dtcs',
        'headers_can',
        'clear_refused',
        'twelve_dtc',
      ])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  MockTransport transportFor(String name) =>
      MockTransport(traces[name]!, speed: 100);

  ObdSession newSession({DtcRepository? dtcs}) {
    final s = ObdSession(timeScale: 0.05, dtcs: dtcs);
    addTearDown(s.dispose);
    return s;
  }

  DiagnosticsController newController(
    ObdSession session, {
    DtcDictionary dictionary = const EmptyDtcDictionary(),
    DtcRepository? dtcs,
    String? vehicleId,
  }) {
    final c = DiagnosticsController(
      session: session,
      dictionary: dictionary,
      dtcs: dtcs,
      vehicleId: vehicleId,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    DiagnosticsController controller, {
    VoidCallback? onConnect,
    DistanceUnit distance = DistanceUnit.km,
    TemperatureUnit temperature = TemperatureUnit.celsius,
  }) async {
    // Tall enough for the whole result page — codes, freeze frame,
    // monitors, score — so an unscrolled assertion still sees the bottom.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdaptiveScope(
        platform: const FakePlatform(isAndroid: false),
        child: MaterialApp(
          theme: torqueTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: TorqueTokens.dark.surfaceDeep,
            body: SafeArea(
              child: DiagnosticsScreen(
                controller: controller,
                onConnect: onConnect,
                distance: distance,
                temperature: temperature,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String? reason,
  }) async {
    for (var i = 0; i < 600; i++) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for ${reason ?? 'condition'}');
  }

  /// Shuts the session down and pumps until nothing is left scheduled —
  /// the poll loop's delay and the replay's reply timer both outlive the
  /// test body otherwise, and flutter_test fails the test for it.
  Future<void> quiesce(WidgetTester tester, ObdSession session) async {
    unawaited(session.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Runs [action] to completion while pumping.
  ///
  /// Awaiting anything the session does directly inside `testWidgets`
  /// deadlocks: the clock is fake and only `pump` advances it, so the
  /// replay's reply timer never fires and the future never completes.
  Future<T> pumping<T>(WidgetTester tester, Future<T> action) async {
    Object? result;
    Object? error;
    var done = false;
    unawaited(
      action.then(
        (v) {
          result = v;
          done = true;
        },
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
    await pumpUntil(tester, () => done, reason: 'the action to finish');
    if (error != null) throw error!;
    return result as T;
  }

  Future<DiagnosticsController> connectedAndScanned(
    WidgetTester tester,
    String trace, {
    DtcDictionary dictionary = const EmptyDtcDictionary(),
    DtcRepository? dtcs,
    String? vehicleId,
    DistanceUnit distance = DistanceUnit.km,
    TemperatureUnit temperature = TemperatureUnit.celsius,
  }) async {
    final session = newSession(dtcs: dtcs);
    final c = newController(
      session,
      dictionary: dictionary,
      dtcs: dtcs,
      vehicleId: vehicleId,
    );
    await pumpScreen(tester, c, distance: distance, temperature: temperature);
    unawaited(session.connect(transportFor(trace)));
    await pumpUntil(tester, () => session.isLive, reason: 'the link');
    unawaited(c.scan());
    await pumpUntil(
      tester,
      () => c.phase == ScanPhase.done,
      reason: 'the scan to finish',
    );
    await tester.pump();
    return c;
  }

  // ------------------------------------------------------------ the table

  group('★ §5.4 — the headline table, reproduced literally', () {
    RawDtc p(String code, DtcMode mode) => RawDtc(code, mode);

    test('MIL off, no codes → "No problems found", pass', () {
      final h = headlineFor(
        const DtcReadResult(
          stored: [],
          pending: [],
          permanent: [],
          milOn: false,
        ),
      );
      expect(h.title, 'No problems found');
      expect(h.tone, Tell.green);
    });

    test('MIL off, pending only → "1 pending code — being monitored"', () {
      final h = headlineFor(
        DtcReadResult(
          stored: const [],
          pending: [p('P0133', DtcMode.pending)],
          permanent: const [],
          milOn: false,
        ),
      );
      expect(h.title, '1 pending code — being monitored');
      expect(h.tone, Tell.amber);
    });

    test('MIL on, codes → "Check Engine light is on — 2 codes", fault', () {
      final h = headlineFor(
        DtcReadResult(
          stored: [p('P0301', DtcMode.stored), p('P0420', DtcMode.stored)],
          pending: const [],
          permanent: const [],
          milOn: true,
        ),
      );
      expect(h.title, 'Check Engine light is on — 2 codes');
      expect(h.tone, Tell.red);
    });

    test('one fault in two lists is one code, not two', () {
      // P0420 stored and permanent is two true facts about one fault.
      final h = headlineFor(
        DtcReadResult(
          stored: [p('P0420', DtcMode.stored)],
          pending: const [],
          permanent: [p('P0420', DtcMode.permanent)],
          milOn: true,
        ),
      );
      expect(h.title, 'Check Engine light is on — 1 code');
    });

    test('★ an unanswered mode is never reported as a clean car', () {
      final h = headlineFor(
        const DtcReadResult(
          stored: [],
          pending: [],
          permanent: [],
          milOn: false,
          failedModes: {'07'},
        ),
      );
      expect(h.tone, isNot(Tell.green));
      expect(h.title, 'Scan incomplete');
    });

    test('MIL on with nothing stored says so rather than inventing a code', () {
      final h = headlineFor(
        const DtcReadResult(
          stored: [],
          pending: [],
          permanent: [],
          milOn: true,
        ),
      );
      expect(h.title, contains('no codes stored'));
      expect(h.tone, Tell.red);
    });

    test('an unreported warning light is not assumed to be off', () {
      final h = headlineFor(
        const DtcReadResult(stored: [], pending: [], permanent: []),
      );
      expect(h.title, 'No codes found');
      expect(h.note, contains('did not report the warning light'));
    });
  });

  // ------------------------------------------------------ hard rule 7

  group('★ hard rule 7 — never fabricate a definition', () {
    test('a manufacturer code gets the required wording, not a guess', () {
      final text = DtcText.describe(
        const RawDtc('P1349', DtcMode.stored),
        null,
      );
      expect(text, DtcText.manufacturerSpecific);
    });

    test('an unknown generic code is named as unknown', () {
      final text = DtcText.describe(
        const RawDtc('P0301', DtcMode.stored),
        null,
      );
      expect(text, contains('no definition available'));
      expect(text, startsWith('Powertrain'));
    });

    test('a dictionary entry is used verbatim', () async {
      final dict = InMemoryDtcDictionary(const [
        DtcDefinition(
          code: 'P0301',
          title: 'Cylinder 1 misfire detected',
          severity: DtcSeverity.high,
        ),
      ]);
      final def = await dict.lookup('p0301');
      expect(
        DtcText.describe(const RawDtc('P0301', DtcMode.stored), def),
        'Cylinder 1 misfire detected',
      );
    });

    test('an unrated code is treated as a fault, not as harmless', () {
      // "We have no severity" must not colour a confirmed code green.
      expect(toneFor(const RawDtc('P0301', DtcMode.stored), null), Tell.red);
      expect(toneFor(const RawDtc('P0133', DtcMode.pending), null), Tell.amber);
    });

    testWidgets('the detail page always ends with the §5.4 disclaimer', (
      tester,
    ) async {
      await tester.pumpWidget(
        AdaptiveScope(
          platform: const FakePlatform(isAndroid: false),
          child: MaterialApp(
            theme: torqueTheme(),
            home: const CodeDetailScreen(
              dtc: RawDtc('P0420', DtcMode.stored),
              alsoIn: [DtcMode.permanent],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(DtcText.disclaimer), findsOneWidget);
      expect(find.text('P0420'), findsOneWidget);
      // No definition bundled, so the page says so instead of describing it.
      expect(find.text('No definition available'), findsOneWidget);
      expect(find.textContaining('Permanent'), findsWidgets);
    });
  });

  // -------------------------------------------------------- the live scan

  group('★ a real scan off the wire', () {
    testWidgets('runs §5.4\'s modes in order, and says which one it is on', (
      tester,
    ) async {
      final session = newSession();
      final c = newController(session);
      await pumpScreen(tester, c);
      final transport = transportFor('dtc_scan_can');
      unawaited(session.connect(transport));
      await pumpUntil(tester, () => session.isLive);

      final from = transport.written.length;
      unawaited(c.scan());
      await pumpUntil(tester, () => c.phase == ScanPhase.running);
      await tester.pump();
      expect(find.text('Scanning'), findsOneWidget);

      await pumpUntil(tester, () => c.phase == ScanPhase.done);
      final asked = transport.written
          .skip(from)
          .where((cmd) => const ['03', '07', '0A', '0101', '0902'].contains(cmd))
          .toList();
      expect(asked.take(5), ['03', '07', '0A', '0101', '0902']);
      await quiesce(tester, session);
    });

    testWidgets('shows the codes, their lists, and the warning light', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');

      expect(find.text('Check Engine light is on — 3 codes'), findsOneWidget);
      expect(find.byType(DtcRow), findsNWidgets(4)); // P0420 is in two lists
      expect(find.text('P0301'), findsOneWidget);
      expect(find.text('P0133'), findsOneWidget);
      expect(find.text('P0420'), findsNWidgets(2));
      expect(find.text('Stored'), findsNWidgets(2));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Permanent'), findsOneWidget);
      await quiesce(tester, c.session);
    });

    testWidgets('a clean car gets the positive empty state with a time', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'no_dtcs');

      expect(find.text('No problems found'), findsOneWidget);
      expect(find.byType(DtcRow), findsNothing);
      expect(find.textContaining('Read '), findsOneWidget);
      expect(c.result!.complete, isTrue);
      await quiesce(tester, c.session);
    });

    testWidgets('★ twelve codes arrive whole, not the first three', (
      tester,
    ) async {
      // The ISO-TP reassembly the spec calls mandatory, seen from the UI.
      final c = await connectedAndScanned(tester, 'twelve_dtc');
      expect(c.result!.stored, hasLength(12));
      expect(find.text('P0301'), findsOneWidget);
      await quiesce(tester, c.session);
    });

    testWidgets('headers on the wire change nothing on screen', (tester) async {
      final c = await connectedAndScanned(tester, 'headers_can');
      expect(c.session.headerChars, 3);
      expect(find.text('Check Engine light is on — 2 codes'), findsOneWidget);
      expect(find.text('P0301'), findsOneWidget);
      await quiesce(tester, c.session);
    });

    testWidgets('readiness keeps its three states apart (§4.7)', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      expect(find.text('Readiness monitors'), findsOneWidget);
      // "Not supported by this car" is a reason on an absent row, never
      // the word "Not finished" — merging them fails a car that is fine.
      expect(find.text('Not supported by this car'), findsWidgets);
      expect(find.textContaining('rules vary by state and country'), findsOne);
      await quiesce(tester, c.session);
    });

    testWidgets('the score is never shown without its breakdown', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      expect(find.text('Health score'), findsOneWidget);
      expect(find.text('${c.health!.value}'), findsOneWidget);
      for (final d in c.health!.deductions) {
        expect(find.text(d.reason), findsOneWidget, reason: d.reason);
      }
      expect(c.health!.deductions, isNotEmpty);
      await quiesce(tester, c.session);
    });

    testWidgets('disconnected invites a connection, never a network error', (
      tester,
    ) async {
      final session = newSession();
      final c = newController(session);
      var opened = 0;
      await pumpScreen(tester, c, onConnect: () => opened++);
      await tester.pump();

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('network'), findsNothing);
      expect(find.textContaining('internet'), findsNothing);
      await tester.tap(find.text('Choose an adapter'));
      expect(opened, 1);
    });
  });

  // ------------------------------------------------------------ the clear


  group('★ §5.4 — the freeze frame', () {
    Future<void> reveal(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Freeze frame'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    testWidgets('★ a scan shows what the engine was doing when the code set', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      expect(c.freezeFrame?.dtc, 'P0301');
      await reveal(tester);
      expect(find.textContaining('when P0301 was stored'), findsOne);
      expect(find.text('50 °C'), findsOne, reason: 'coolant, warming up');
      expect(find.text('0 km/h'), findsOne, reason: 'parked');
      expect(
        find.descendant(of: find.byType(ValueList), matching: find.text('750 rpm')),
        findsOne,
        reason: 'idle',
      );
      await quiesce(tester, c.session);
    });

    testWidgets('the readings follow the unit settings (§5.6)', (tester) async {
      final c = await connectedAndScanned(
        tester,
        'dtc_scan_can',
        distance: DistanceUnit.mi,
        temperature: TemperatureUnit.fahrenheit,
      );
      await reveal(tester);
      expect(find.text('122 °F'), findsOne);
      expect(find.text('0 mph'), findsOne);
      expect(find.text('50 °C'), findsNothing);
      await quiesce(tester, c.session);
    });

    testWidgets('a clean car shows no frame and was not asked for one', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'no_dtcs');
      expect(c.freezeFrame, isNull);
      expect(find.text('Freeze frame'), findsNothing);
      await quiesce(tester, c.session);
    });
  });

  group('★ §9.5 — clearing, guarded', () {
    /// Scrolls the screen to the clear action and opens the sheet, then
    /// pumps past the sheet animation and the gate's speed read.
    Future<void> openSheet(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Clear codes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible stops as soon as the widget is *built*, which
      // includes the ListView's cache extent below the fold — tapping
      // there lands outside the view and does nothing.
      await tester.ensureVisible(find.text('Clear codes'));
      await tester.pump();
      await tester.tap(find.text('Clear codes'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
    }

    testWidgets('the consequences are stated uncollapsed, before the button', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      await openSheet(tester);
      expect(find.byType(ClearCodesSheet), findsOneWidget);

      // All four, on screen, with no disclosure control to expand.
      expect(find.textContaining('Turns off the Check Engine light'), findsOne);
      expect(find.textContaining('freeze-frame data'), findsOne);
      expect(
        find.textContaining('fail an emissions test until it has been '
            'driven 50–100 miles'),
        findsOne,
      );
      expect(find.textContaining('Does not fix the fault'), findsOne);
      // And the permanent code that will survive it.
      expect(find.textContaining('P0420'), findsWidgets);
      await quiesce(tester, c.session);
    });

    testWidgets('★ the gate reads the car, and a moving car cannot clear', (
      tester,
    ) async {
      // headers_can reports 68 km/h, so the button must not be reachable.
      final c = await connectedAndScanned(tester, 'headers_can');
      await openSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('moving at 68 km/h'), findsOne);
      expect(find.byType(DestructiveButton), findsNothing);
      await quiesce(tester, c.session);
    });

    testWidgets('★ the gate quotes the speed in the user\'s unit (§5.6)', (
      tester,
    ) async {
      final c = await connectedAndScanned(
        tester,
        'headers_can',
        distance: DistanceUnit.mi,
      );
      await openSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('moving at 42 mph'), findsOne);
      expect(find.textContaining('km/h'), findsNothing);
      await quiesce(tester, c.session);
    });

    testWidgets('a stopped car reaches the two-step button', (tester) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      await openSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DestructiveButton), findsOneWidget);
      // One tap arms, it does not clear.
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      expect(find.text('Tap again to clear'), findsOneWidget);
      expect(c.lastClear, isNull);
      await quiesce(tester, c.session);
    });

    testWidgets('★ a permanent code surviving is not "the code came back"', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      final outcome = await pumping(tester, c.clear());

      expect(outcome, ClearResult.cleared);
      expect(c.result!.stored, isEmpty);
      expect(c.result!.pending, isEmpty);
      expect(c.result!.permanent.single.code, 'P0420');
      await quiesce(tester, c.session);
    });

    testWidgets('a refusal says engine off, ignition ON — and changes nothing', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'clear_refused');
      final outcome = await pumping(tester, c.clear());
      expect(outcome, ClearResult.refused);
      await tester.pump();
      expect(
        find.textContaining('Turn the engine off and the ignition'),
        findsOne,
      );
      await quiesce(tester, c.session);
    });

    testWidgets('★ the snapshot is written before Mode 04 goes out', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DtcRepository(db);
      final vehicle = await VehicleRepository(db).create(
        nickname: 'The Mazda',
        fuel: VehicleFuel.petrol,
        make: 'Mazda',
        model: '3',
        year: 2015,
      );

      final c = await connectedAndScanned(
        tester,
        'dtc_scan_can',
        dtcs: repo,
        vehicleId: vehicle.id,
      );
      await pumping(tester, c.clear());

      final history = await repo.history(vehicle.id);
      final before = history.firstWhere(
        (r) => r.purpose == SnapshotPurpose.beforeClear,
      );
      final after = history.firstWhere(
        (r) => r.purpose == SnapshotPurpose.afterClear,
      );
      // The pre-clear codes are on disk, and the row is settled rather
      // than left pending.
      expect(before.takenAt.isAfter(after.takenAt), isFalse);
      expect(before.clearOutcome, isNot(ClearOutcome.pending));
      expect(await repo.unreconciledClears(vehicle.id), isEmpty);
      await quiesce(tester, c.session);
    });

    testWidgets('★ a clear left pending on disk is surfaced, not hidden', (
      tester,
    ) async {
      // The app died between the snapshot and the verifying re-read.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DtcRepository(db);
      final vehicle = await VehicleRepository(db).create(
        nickname: 'The Mazda',
        fuel: VehicleFuel.petrol,
        make: 'Mazda',
        model: '3',
        year: 2015,
      );
      await repo.beginClear(
        vehicleId: vehicle.id,
        codes: const [RawDtc('P0301', DtcMode.stored)],
        milOn: true,
      );

      final c = await connectedAndScanned(
        tester,
        'dtc_scan_can',
        dtcs: repo,
        vehicleId: vehicle.id,
      );
      await c.refreshUnreconciled();
      await tester.pump();

      expect(c.unreconciled, hasLength(1));
      expect(find.text('A clear was never verified'), findsOneWidget);

      // And it can be settled from the car rather than by assumption.
      expect(await pumping(tester, c.reconcile()), isTrue);
      await tester.pump();
      expect(c.unreconciled, isEmpty);
      await quiesce(tester, c.session);
    });
  });

  // ------------------------------------------- what the review turned up

  group('★ regressions the adversarial review found', () {
    testWidgets('★ the screen never denies the codes listed under it', (
      tester,
    ) async {
      // `cleared` means no stored and no pending. A permanent code is
      // *expected* to survive Mode 04, so the line above the list must not
      // say the car came back empty while P0420 sits directly beneath it.
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      expect(await pumping(tester, c.clear()), ClearResult.cleared);
      await tester.pump();

      expect(find.textContaining('came back empty'), findsNothing);
      expect(
        find.textContaining('P0420 is permanent and stays'),
        findsOneWidget,
      );
      expect(find.text('P0420'), findsWidgets, reason: 'still listed');
      await quiesce(tester, c.session);
    });

    testWidgets('★ reconcile moves the score with the codes, not apart', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DtcRepository(db);
      final vehicle = await VehicleRepository(db).create(
        nickname: 'The Mazda',
        fuel: VehicleFuel.petrol,
        make: 'Mazda',
        model: '3',
        year: 2015,
      );
      await repo.beginClear(
        vehicleId: vehicle.id,
        codes: const [RawDtc('P0301', DtcMode.stored)],
        milOn: true,
      );

      final c = await connectedAndScanned(
        tester,
        'dtc_scan_can',
        dtcs: repo,
        vehicleId: vehicle.id,
      );
      // The scan found three codes, so the score is well under 100.
      final before = c.health!;
      expect(before.deductions, isNotEmpty);

      await pumping(tester, c.reconcile());
      await tester.pump();

      // The re-read is clean of stored and pending, so the breakdown must
      // not still itemise them.
      expect(c.result!.stored, isEmpty);
      expect(
        c.health!.deductions.map((d) => d.reason),
        isNot(contains('Confirmed code P0301')),
      );
      expect(c.health!.value, greaterThan(before.value));
      for (final d in c.health!.deductions) {
        expect(find.text(d.reason), findsOneWidget, reason: d.reason);
      }
      await quiesce(tester, c.session);
    });

    testWidgets('★ a new scan drops the previous clear\'s verdict', (
      tester,
    ) async {
      final c = await connectedAndScanned(tester, 'dtc_scan_can');
      await pumping(tester, c.clear());
      await tester.pump();
      expect(find.textContaining('permanent and stays'), findsOneWidget);

      await pumping(tester, c.scan());
      await tester.pump();
      expect(c.lastClear, isNull);
      expect(find.textContaining('permanent and stays'), findsNothing);
      await quiesce(tester, c.session);
    });

    testWidgets('★ the clear sheet reflows at text scale 2.0', (tester) async {
      // Both progress lines were a bare Text inside a Row, so they ran off
      // the edge instead of wrapping. 320pt is an iPhone with Display Zoom
      // on — the narrowest real phone this has to survive.
      final session = newSession();
      final c = newController(session);
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Connected first: the sheet reads the speed in initState, and with
      // no link that read returns null and the gate never opens.
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(session.connect(transportFor('dtc_scan_can')));
      await pumpUntil(tester, () => session.isLive);

      await tester.pumpWidget(
        AdaptiveScope(
          platform: const FakePlatform(isAndroid: false),
          child: MaterialApp(
            theme: torqueTheme(),
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(body: ClearCodesSheet(controller: c)),
              ),
            ),
          ),
        ),
      );
      // The very first frame is _Stage.checking — "Checking the car is
      // stopped…", the line that used to overflow by 155 pixels here.
      expect(tester.takeException(), isNull, reason: 'checking');

      // Through the gate, the two-step button and the clear itself.
      await pumpUntil(
        tester,
        () => find.byType(DestructiveButton).evaluate().isNotEmpty,
        reason: 'the gate to open on a stopped car',
      );
      // At scale 2.0 the consent copy is taller than the viewport, so the
      // button has to be scrolled to — which is the real user's path too.
      await tester.ensureVisible(find.byType(DestructiveButton));
      await tester.pump();
      await tester.tap(find.byType(DestructiveButton));
      await tester.pump();
      await tester.ensureVisible(find.byType(DestructiveButton));
      await tester.pump();
      await tester.tap(find.byType(DestructiveButton));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull, reason: 'clearing');
      }
      expect(find.textContaining('permanent and stays'), findsOneWidget);
      await quiesce(tester, session);
    });

    testWidgets('★ a pushed detail page brings its own dark ground', (
      tester,
    ) async {
      // A pushed route is a *sibling* of the widget that pushed it, so it
      // inherits MaterialApp.theme — which in the real app is still the
      // old light Industry theme. The shell is replicated here exactly.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF2F2F3)),
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Theme(
                data: torqueTheme(),
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CodeDetailScreen(
                              dtc: RawDtc('P0420', DtcMode.stored),
                            ),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.text('Trouble code'));
      expect(
        Theme.of(ctx).extension<TorqueTokens>(),
        isNotNull,
        reason: 'the Part B tokens reached the pushed route',
      );
      expect(
        Theme.of(ctx).appBarTheme.backgroundColor,
        TorqueTokens.dark.surfaceDeep,
      );
    });

    testWidgets('★ a scan interrupted by a reconnect reports unanswered', (
      tester,
    ) async {
      // The reply that lands after the link was replaced belongs to a
      // different conversation. Folding it in would mix two cars.
      final session = newSession();
      await pumpScreen(tester, newController(session));
      unawaited(session.connect(transportFor('dtc_scan_can')));
      await pumpUntil(tester, () => session.isLive);

      DtcReadResult? result;
      unawaited(
        session
            .readDtcs(
              onStep: (mode) {
                // Drop the link while the first mode is on the wire. A
                // microtask, so the command already sent is not written
                // to a transport that is closing underneath it.
                if (mode == '03') {
                  Future.microtask(() => unawaited(session.disconnect()));
                }
              },
            )
            .then((r) => result = r),
      );
      await pumpUntil(
        tester,
        () => result != null,
        reason: 'the interrupted scan to give up',
      );

      expect(result!.complete, isFalse, reason: 'modes went unanswered');
      expect(result!.failedModes, containsAll(<String>['07', '0A', '0101']));
      expect(result!.all, isEmpty, reason: 'nothing merged from two links');
      await quiesce(tester, session);
    });
  });

  // ------------------------------------------------------ the health score

  group('★ §5.4 — the health score and its breakdown', () {
    const stored = RawDtc('P0301', DtcMode.stored);
    const pending = RawDtc('P0133', DtcMode.pending);
    const permanent = RawDtc('P0420', DtcMode.permanent);

    test('a clean car with everything measured scores 100', () {
      final s = HealthScore.compute(
        stored: const [],
        pending: const [],
        permanent: const [],
        milOn: false,
        readiness: const ReadinessReport(
          milOn: false,
          dtcCount: 0,
          ignitionType: IgnitionType.spark,
          monitors: [ReadinessMonitorResult('Misfire', MonitorState.complete)],
        ),
        batteryVolts: 12.6,
        coolantC: 90,
        fuelTrims: const [1.5],
        overdueReminders: 0,
      );
      expect(s.value, 100);
      expect(s.deductions, isEmpty);
      expect(s.isComplete, isTrue);
    });

    test('every line in §5.4\'s table costs what it says', () {
      final s = HealthScore.compute(
        stored: const [stored],
        pending: const [pending],
        permanent: const [permanent],
        milOn: true,
        readiness: const ReadinessReport(
          milOn: true,
          dtcCount: 3,
          ignitionType: IgnitionType.spark,
          monitors: [
            ReadinessMonitorResult('Catalyst', MonitorState.notComplete),
          ],
        ),
        batteryVolts: 11.9,
        coolantC: 118,
        fuelTrims: const [-14.0],
        overdueReminders: 2,
      );
      // 25 + 20 + 15 + 10 + 10 + 8 + 8 + 10 + 3 = 109, clamped at 0.
      expect(s.pointsLost, 109);
      expect(s.value, 0);
      expect(
        s.deductions.map((d) => d.points),
        containsAll(<int>[25, 20, 15, 10, 8, 3]),
      );
    });

    test('severity weights the −25, and an unrated code costs the full 25', () {
      int lostFor(DtcSeverity? severity) => HealthScore.compute(
        stored: const [stored],
        pending: const [],
        permanent: const [],
        milOn: false,
        severities: {'P0301': severity},
      ).pointsLost;

      expect(lostFor(DtcSeverity.high), 25);
      expect(lostFor(DtcSeverity.low), 10);
      expect(lostFor(null), 25, reason: 'unknown is not treated as mild');
    });

    test('★ a cold engine is not a fault, an overheating one is', () {
      int lostFor(double c) => HealthScore.compute(
        stored: const [],
        pending: const [],
        permanent: const [],
        milOn: false,
        coolantC: c,
      ).pointsLost;

      expect(lostFor(12), 0, reason: 'a winter morning is not a fault');
      expect(lostFor(118), 8);
    });

    test('★ what could not be read is named, never scored as fine', () {
      final s = HealthScore.compute(
        stored: const [],
        pending: const [],
        permanent: const [],
        failedModes: const {'07'},
      );
      expect(s.value, 100);
      expect(s.isComplete, isFalse);
      expect(s.notMeasured, contains('Pending codes — the car did not answer'));
      expect(
        s.notMeasured.any((g) => g.startsWith('Battery voltage')),
        isTrue,
        reason: 'an unread battery must not read as a healthy one',
      );
      expect(
        s.notMeasured,
        contains('Service reminders — no vehicle selected'),
        reason: 'no garage to ask is not the same as none overdue',
      );
    });
  });
}

/// Reads better than `findsNWidgets(1)` in an expectation about wording.
const findsOne = findsOneWidget;
