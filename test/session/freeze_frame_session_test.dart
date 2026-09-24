import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/dtc_repository.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/protocol/freeze_frame.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

/// SPEC §5.4 — the freeze frame off a recorded car, and its capture into
/// the §9.5 snapshot *before* Mode 04 erases it.
///
/// Plain tests: replay needs the real clock.
void main() {
  late final Map<String, ObdTrace> traces;

  setUpAll(() {
    traces = {
      for (final name in const ['dtc_scan_can', 'clear_ok', 'clean_can', 'no_dtcs'])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  MockTransport transportFor(String name) =>
      MockTransport(traces[name]!, speed: 100);

  Future<ObdSession> connected(String trace, {DtcRepository? dtcs}) async {
    final s = ObdSession(timeScale: 0.05, dtcs: dtcs);
    addTearDown(s.dispose);
    expect(await s.connect(transportFor(trace)), isTrue, reason: trace);
    s.setVisible({});
    return s;
  }

  group('readFreezeFrame', () {
    test('★ reads the code and the readings the ECU kept, in metric', () async {
      final s = await connected('dtc_scan_can');
      final f = await s.readFreezeFrame();
      expect(f, isNotNull);
      expect(f!.dtc, 'P0301');
      expect(f.frame, 0);
      expect(f.values['010C'], 750, reason: 'idle');
      expect(f.values['010D'], 0, reason: 'parked');
      expect(f.values['0105'], 50, reason: 'warming up');
      expect(f.values['0104'], closeTo(25.1, 0.1));
      expect(f.values['0107'], closeTo(12.5, 0.01), reason: 'lean');
      expect(f.values, hasLength(10));
      await s.disconnect();
    });

    test('a car with no codes keeps no frame', () async {
      final s = await connected('no_dtcs');
      expect(await s.readFreezeFrame(), isNull);
      await s.disconnect();
    });

    test('a car that never answers Mode 02 is null, not an error', () async {
      // clean_can has no Mode 02 exchanges; the mock answers NO DATA.
      final s = await connected('clean_can');
      expect(await s.readFreezeFrame(), isNull);
      await s.disconnect();
    });

    test('disconnected: null', () async {
      final s = ObdSession(timeScale: 0.05);
      addTearDown(s.dispose);
      expect(await s.readFreezeFrame(), isNull);
    });
  });

  group('★ the clear keeps the frame', () {
    late AppDatabase db;
    late DtcRepository dtcs;
    late String vehicleId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      dtcs = DtcRepository(db);
      vehicleId = (await VehicleRepository(
        db,
      ).create(nickname: 'Focus', fuel: VehicleFuel.petrol)).id;
    });

    test('★ the freeze frame is in the beforeClear snapshot, read before '
        'Mode 04 went out', () async {
      final transport = transportFor('clear_ok');
      final s = ObdSession(timeScale: 0.05, dtcs: dtcs);
      addTearDown(s.dispose);
      expect(await s.connect(transport), isTrue);
      s.setVisible({});

      expect(await s.clearDtcs(vehicleId: vehicleId), ClearResult.cleared);

      final rows = await dtcs.history(vehicleId);
      final before = rows.singleWhere(
        (r) => r.purpose == SnapshotPurpose.beforeClear,
      );
      final frame = before.freezeFrame;
      expect(frame, isNotNull, reason: 'kept in the snapshot');
      expect(frame!.dtc, 'P0301');
      expect(frame.values['010C'], 750);
      // This ECU answers NO DATA to the Mode 02 support mask, so the
      // session asked for the eight usual PIDs instead of giving up.
      expect(frame.values, hasLength(8));
      expect(frame.values.containsKey('0106'), isFalse);

      // Hard rule 8, extended: everything the snapshot holds was read
      // before the one command that erases it.
      final written = transport.written.map(ObdTrace.normalise).toList();
      final frameAt = written.indexOf('020200');
      final clearAt = written.indexOf('04');
      expect(frameAt, greaterThanOrEqualTo(0));
      expect(frameAt, lessThan(clearAt), reason: '0202 before 04');
      expect(
        written.lastIndexWhere((c) => RegExp(r'^02..00$').hasMatch(c)),
        lessThan(clearAt),
        reason: 'every frame PID read before 04',
      );
      await s.disconnect();
    });

    test('the afterClear row carries no frame — the ECU erased it', () async {
      final s = ObdSession(timeScale: 0.05, dtcs: dtcs);
      addTearDown(s.dispose);
      expect(await s.connect(transportFor('clear_ok')), isTrue);
      s.setVisible({});
      await s.clearDtcs(vehicleId: vehicleId);
      final after = (await dtcs.history(vehicleId)).singleWhere(
        (r) => r.purpose == SnapshotPurpose.afterClear,
      );
      expect(after.freezeFrame, isNull);
      await s.disconnect();
    });

    test('a recorded frame survives a round trip through the row', () async {
      const f = FreezeFrame(dtc: 'P0420', values: {'010C': 2400, '0105': 92});
      await dtcs.recordScan(vehicleId: vehicleId, codes: const [], freezeFrame: f);
      final row = await dtcs.latest(vehicleId);
      expect(row?.freezeFrame, f);
    });
  });
}
