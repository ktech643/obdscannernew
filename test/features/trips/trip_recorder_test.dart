import 'dart:async';
import 'dart:io' show FileSystemException, OSError;

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart' show TripSessionRow;
import 'package:torque_obd2/data/db/tables.dart' show TripEnd;
import 'package:torque_obd2/data/trips/trip_sink.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/features/trips/trip_plan.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_store.dart';
import 'package:torque_obd2/session/obd_session.dart' show SessionState;

import 'support.dart';

/// SPEC §5.3 "Record", §7.2 "Recording 2 min", §9.2 and §9.6: how a trip
/// is recorded, paused and ended, over fakes and a hand-driven clock — every
/// row here is what the file would hold, read back from the sink.
void main() {
  const android = FakePlatform(isAndroid: true);

  group('★ §7.2 the free plan\'s 2:00', () {
    test('★ free stops at 2:00 of recorded time', () async {
      // Two checks enforce the cap: each sample, before its row is written,
      // and each tick, for a trip that has gone quiet. A cap checked after
      // the write leaves a row at 2:00 in a free trip's file; one checked
      // only per sample never ends a trip whose car stopped answering.
      final rig = RecorderRig(platform: android);
      addTearDown(rig.dispose);
      final id = await record(rig);
      await drive(rig, const Duration(seconds: 130));

      final rows = rowsIn(rig.store.sinks[id]!.content);
      expect(rows, isNotEmpty);
      expect(
        rows.where((r) => r.t >= TripPlan.freeMs),
        isEmpty,
        reason: 'nothing at or past 2:00 is written',
      );
      expect(rows.last.t, 119500, reason: 'the last sample before 2:00');
      final saved = rig.store.rows[id]!;
      expect(saved.endReason, TripEnd.freeCap);
      expect(saved.recordedMs, TripPlan.freeMs);
      expect(saved.interrupted, isFalse, reason: 'saved, not cut short');
      expect(rig.recorder.view.phase, RecorderPhase.idle);
      expect(rig.recorder.view.result!.end, TripEnd.freeCap);
      // Hard rule 9: wherever the app is, the car stops being polled for
      // the trip and the Android service goes.
      expect(rig.link.recordingCalls.last, isFalse);
      expect(rig.dashboard.recordingPids, isEmpty);
      expect(rig.background.calls, contains('stopRecording'));
      expect(
        rig.recorder.refusal,
        isNull,
        reason: 'Record stays there for another 2-minute trip',
      );

      // No sample after 1:50 — the poll loop stalled, or the car went
      // quiet. The tick still ends the trip at 2:00.
      final quiet = await record(rig);
      await drive(rig, const Duration(seconds: 110));
      await rig.tick(9);
      expect(rig.recorder.view.phase, RecorderPhase.recording);
      await rig.tick();
      expect(rig.recorder.view.phase, RecorderPhase.idle);
      expect(rig.store.rows[quiet]!.endReason, TripEnd.freeCap);
      expect(rig.store.rows[quiet]!.recordedMs, TripPlan.freeMs);
      expect(rig.link.recordingCalls.last, isFalse);

      // The same drive on Pro keeps recording past 2:00.
      final pro = RecorderRig(platform: android, isPro: true);
      addTearDown(pro.dispose);
      final long = await record(pro);
      await drive(pro, const Duration(seconds: 130));
      expect(pro.recorder.view.phase, RecorderPhase.recording);
      expect(pro.recorder.reading.value!.capMs, isNull);
      expect(rowsIn(pro.store.sinks[long]!.content).last.t, 130000);
      await pro.recorder.stop();
      expect(pro.store.rows[long]!.recordedMs, 130000);
    });

    test('★ the cap is on the monotonic clock', () async {
      // §9.7 "DST/clock change: monotonic Stopwatch, store UTC". Recorded
      // time taken from the wall clock would run backwards an hour when
      // the clock is set back, and the free trip would record for an hour.
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      final id = await record(rig);
      final startedAt = rig.store.rows[id]!.startedAt;
      await drive(rig, const Duration(seconds: 60));
      rig.clock.stepWall(const Duration(hours: -1));
      await drive(rig, const Duration(seconds: 70));

      final rows = rowsIn(rig.store.sinks[id]!.content);
      final speed = [
        for (final r in rows)
          if (r.pid == '010D') r.t,
      ];
      expect(speed, orderedEquals([for (var t = 500; t < 120000; t += 500) t]));
      final saved = rig.store.rows[id]!;
      expect(saved.endReason, TripEnd.freeCap);
      expect(saved.recordedMs, TripPlan.freeMs);
      expect(saved.endedAt!.isUtc, isTrue);
      expect(
        saved.endedAt!.isBefore(startedAt),
        isFalse,
        reason: 'a clock set back never ends a trip before it began',
      );
    });

    test('★ Pro bought mid-trip lifts the cap; a lapse never cuts a running '
        'trip', () async {
      // §7.5: a trip is capped only if it was free when it started and is
      // free now. Read only at the start, a purchase through the door does
      // nothing for the drive it was bought in; read only live, a refund
      // cuts a Pro drive off at 2:00.
      final bought = RecorderRig();
      addTearDown(bought.dispose);
      final a = await record(bought);
      await drive(bought, const Duration(seconds: 60));
      expect(bought.recorder.reading.value!.capMs, TripPlan.freeMs);
      bought.recorder.isPro = true;
      await drive(bought, const Duration(seconds: 70));
      expect(bought.recorder.view.phase, RecorderPhase.recording);
      expect(bought.recorder.reading.value!.capMs, isNull);
      expect(rowsIn(bought.store.sinks[a]!.content).last.t, 130000);
      await bought.recorder.stop();
      expect(bought.store.rows[a]!.endReason, TripEnd.stopped);
      expect(bought.store.rows[a]!.recordedMs, 130000);

      final lapsed = RecorderRig(isPro: true);
      addTearDown(lapsed.dispose);
      final b = await record(lapsed);
      await drive(lapsed, const Duration(seconds: 60));
      lapsed.recorder.isPro = false;
      await drive(lapsed, const Duration(seconds: 70));
      expect(lapsed.recorder.view.phase, RecorderPhase.recording);
      expect(
        lapsed.recorder.reading.value!.capMs,
        isNull,
        reason: 'no "2:00 of 2:00" on a trip that runs on',
      );
      expect(rowsIn(lapsed.store.sinks[b]!.content).last.t, 130000);
      await lapsed.recorder.stop();
      expect(lapsed.store.rows[b]!.endReason, TripEnd.stopped);

      // The next trip is a free one.
      final c = await record(lapsed);
      await drive(lapsed, const Duration(seconds: 130));
      expect(lapsed.store.rows[c]!.endReason, TripEnd.freeCap);
      expect(lapsed.store.rows[c]!.recordedMs, TripPlan.freeMs);
    });
  });

  group('★ every end path stops background polling and the service', () {
    // Hard rule 9. The summary after an end runs in an isolate and takes a
    // moment; the car must not be polled, nor the Android service kept up,
    // while it does. Each path is checked at the moment the store is first
    // asked to save (or drop) the trip — a path that skips the one end
    // funnel, or stops polling only after the save, leaves the app polling
    // in the background with nothing recording.
    final paths = <(String, TripEnd?, Future<void> Function(_Rig))>[
      ('stopped', TripEnd.stopped, (r) => r.recorder.stop()),
      (
        'notification',
        TripEnd.notification,
        (r) async {
          await r.tick(5);
          r.background.running = false;
          await r.tick(5);
        },
      ),
      (
        'disconnected',
        TripEnd.disconnected,
        (r) async {
          r.link.set(SessionState.disconnected);
        },
      ),
      ('freeCap', TripEnd.freeCap, (r) => r.tick(120)),
      (
        'linkLost',
        TripEnd.linkLost,
        (r) async {
          r.link.set(SessionState.disconnected, error: 'Could not reconnect');
        },
      ),
      (
        'ignitionOff',
        TripEnd.ignitionOff,
        (r) async {
          r.link.set(SessionState.ignitionOff);
          await r.tick(600);
        },
      ),
      (
        'otherVehicle',
        TripEnd.otherVehicle,
        (r) async {
          r.recorder.follow(const OwnerVehicle('passat', 'Passat'));
        },
      ),
      (
        'heldTooLong',
        TripEnd.heldTooLong,
        (r) async {
          r.recorder.follow(const OwnerPending('golf'));
          await r.tick(600);
        },
      ),
      (
        'storageFull',
        TripEnd.storageFull,
        (r) async {
          r.sink.failNext = const TripWriteFailure(outOfSpace: true);
          r.link.publish('010D', 36);
          await r.tick();
        },
      ),
      (
        'writeFailed',
        TripEnd.writeFailed,
        (r) async {
          r.sink.failNext = const TripWriteFailure(outOfSpace: false);
          r.link.publish('010D', 36);
          await r.tick();
        },
      ),
      ('releaseVehicle', null, (r) => r.recorder.releaseVehicle('golf')),
      ('shutdown', null, (r) => r.recorder.shutdown()),
    ];

    for (final (name, end, act) in paths) {
      test('★ $name', () async {
        // Pro, so only the freeCap path meets the free plan's 2:00.
        final r = _Rig(isPro: name != 'freeCap');
        addTearDown(r.dispose);
        final id = await record(r);
        await drive(r, const Duration(seconds: 3));
        expect(r.link.recordingCalls, [true], reason: 'recording allowed');
        expect(r.dashboard.recordingPids, TripPlan.channels);
        expect(r.background.running, isTrue, reason: 'the service is up');

        await act(r);
        await RecorderRig.settle();

        final at = r.store.firstAsked;
        expect(at, isNotNull, reason: 'the store was asked');
        expect(at!.lastSetRecording, isFalse, reason: 'setRecording(false)');
        expect(at.recordingPids, isEmpty, reason: 'recordingPids {}');
        expect(at.stopRecording, 1, reason: 'the service stopped');
        expect(r.recorder.view.phase, RecorderPhase.idle);
        expect(r.link.recordingCalls.last, isFalse);
        if (end == null) {
          expect(r.store.discarded, [id]);
          expect(r.recorder.view.result, isNull);
        } else {
          expect(r.store.rows[id]!.endReason, end);
          expect(r.recorder.view.result!.end, end);
        }
      });
    }
  });

  test('★ nothing is written until the car is settled', () async {
    // §9.6 "prompt on mismatch before recording". Every falling edge makes
    // the owner Pending until the next VIN verdict, and the session polls
    // as soon as a rung reconnects — so without the identity hold, samples
    // from a car that may not be the Golf land in the Golf's trip.
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    final id = await record(rig);
    String file() => rig.store.sinks[id]!.content;
    await drive(rig, const Duration(seconds: 5));
    expect(rowsIn(file()).last.t, 5000);

    // The link drops; LiveSession hears the edge and the garage forgets
    // which car this is.
    rig.link.set(
      SessionState.lost,
      reconnecting: true,
      error: 'Connection lost',
    );
    rig.recorder.follow(const OwnerPending('golf'));
    expect(rig.recorder.view.hold, TripHold.link);
    await rig.tick(3);
    // A rung reconnects and the VIN is being read. Samples arrive.
    rig.link.set(SessionState.connected);
    await drive(rig, const Duration(seconds: 5));
    expect(
      rowsIn(file()).where((r) => r.t > 5000),
      isEmpty,
      reason: 'nothing while the car is unsettled',
    );
    expect(rig.recorder.view.hold, TripHold.identity);
    expect(rig.recorder.view.phase, RecorderPhase.recording);

    // The verdict: it is the Golf. The same trip continues.
    rig.recorder.follow(RecorderRig.golf);
    expect(rig.recorder.view.hold, isNull);
    await drive(rig, const Duration(seconds: 5));
    final after = rowsIn(file()).where((r) => r.t > 5000).toList();
    expect(after.first.t, 13500, reason: 'from the verdict on');
    expect(after.last.t, 18000);
    expect(rig.store.starts, 1);

    // Another drop, and this time the answer is the Passat. The trip ends
    // where the Golf's samples end, filed under the Golf.
    rig.link.set(
      SessionState.lost,
      reconnecting: true,
      error: 'Connection lost',
    );
    rig.recorder.follow(const OwnerPending('golf'));
    rig.link.set(SessionState.connected);
    await drive(rig, const Duration(seconds: 2));
    rig.recorder.follow(const OwnerVehicle('passat', 'Passat'));
    await RecorderRig.settle();
    await drive(rig, const Duration(seconds: 3));

    expect(rig.recorder.view.phase, RecorderPhase.idle);
    final result = rig.recorder.view.result!;
    expect(result.end, TripEnd.otherVehicle);
    expect(result.vehicleId, 'golf');
    expect(result.nickname, 'Golf', reason: '"saved under Golf"');
    final saved = rig.store.rows[id]!;
    expect(saved.vehicleId, 'golf', reason: 'never re-filed');
    expect(saved.endReason, TripEnd.otherVehicle);
    expect(saved.recordedMs, 18000);
    expect(rowsIn(file()).last.t, 18000, reason: 'no row after the verdict');
    expect(rig.store.rows, hasLength(1));
  });

  test('★ a rung does not end the trip; the give-up does, at the last '
      'sample', () async {
    // §9.2. A failed rung reports `disconnected` with the ladder still
    // running: ending there splits one drive at every tunnel. And the trip
    // was last heard at its last sample — stamped at the give-up, a trip
    // lost for 90 s of ladder would claim 90 s it never recorded.
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    final id = await record(rig);
    final startedAt = rig.store.rows[id]!.startedAt;
    await drive(rig, const Duration(seconds: 30));
    rig.clock.advance(const Duration(milliseconds: 300));
    rig.link.set(
      SessionState.lost,
      reconnecting: true,
      error: 'Connection lost',
    );
    expect(rig.recorder.view.hold, TripHold.link);
    await rig.tick(4);
    rig.link.set(
      SessionState.connecting,
      reconnecting: true,
      error: 'Connection lost',
    );
    await rig.tick(2);
    rig.link.set(
      SessionState.disconnected,
      reconnecting: true,
      error: 'Connection lost',
    );
    await RecorderRig.settle();
    expect(rig.recorder.view.phase, RecorderPhase.recording);
    expect(rig.recorder.view.hold, TripHold.link);
    await rig.tick(20);
    expect(rig.recorder.view.phase, RecorderPhase.recording);

    // The ladder gives up: heard with reconnecting already false.
    rig.link.set(SessionState.disconnected, error: 'Could not reconnect');
    await RecorderRig.settle();
    final saved = rig.store.rows[id]!;
    expect(saved.endReason, TripEnd.linkLost);
    expect(saved.interrupted, isTrue);
    expect(saved.recordedMs, 30000);
    expect(
      saved.endedAt,
      startedAt.add(const Duration(seconds: 30)),
      reason: 'the last sample, not the give-up 26 s later',
    );
    expect(rig.recorder.view.result!.end, TripEnd.linkLost);
    expect(rig.recorder.view.result!.savedUpTo, saved.endedAt);

    // A Disconnect the user taps has no error: a clean stop.
    final user = RecorderRig();
    addTearDown(user.dispose);
    final u = await record(user);
    await drive(user, const Duration(seconds: 10));
    user.link.set(SessionState.disconnected);
    await RecorderRig.settle();
    expect(user.store.rows[u]!.endReason, TripEnd.disconnected);
    expect(user.store.rows[u]!.interrupted, isFalse);
    expect(user.store.rows[u]!.recordedMs, 10000);
  });

  test('★ a hold ends at 10 minutes, not before', () async {
    // TripPlan.maxHold. Without it a recording left on in a parked car
    // keeps the ladder and the service going all night; with every key-off
    // ending the trip, a fuel stop splits one drive in two.
    final rig = RecorderRig(isPro: true); // the free 2:00 would come first
    addTearDown(rig.dispose);
    final id = await record(rig);
    await drive(rig, const Duration(seconds: 20));
    rig.clock.advance(const Duration(milliseconds: 200));
    rig.link.set(SessionState.ignitionOff);
    await rig.tick(599);
    expect(rig.recorder.view.phase, RecorderPhase.recording, reason: '9:59');
    expect(rig.recorder.view.hold, TripHold.ignitionOff);

    rig.link.set(SessionState.connected);
    expect(rig.recorder.view.hold, isNull);
    await drive(rig, const Duration(seconds: 10));
    expect(rig.store.starts, 1, reason: 'the same trip');
    final lastRow = rowsIn(rig.store.sinks[id]!.content).last.t;
    expect(lastRow, 629200);

    rig.clock.advance(const Duration(milliseconds: 300));
    rig.link.set(SessionState.ignitionOff);
    await rig.tick(599);
    expect(rig.recorder.view.phase, RecorderPhase.recording);
    await rig.tick();
    expect(rig.recorder.view.phase, RecorderPhase.idle, reason: '10:00');
    final saved = rig.store.rows[id]!;
    expect(saved.endReason, TripEnd.ignitionOff);
    expect(saved.interrupted, isFalse);
    expect(saved.recordedMs, lastRow, reason: 'at the last row');
    // 19.5 s and 9.5 s at 36 km/h: the ten minutes parked are not a drive.
    expect(saved.distanceKm, closeTo(0.29, 1e-9));
    expect(rig.link.recordingCalls.last, isFalse);
  });

  test('storage full mid-trip ends it as storageFull, figures kept', () async {
    // §9.7 "storage full". The sink has rolled back to its last whole line;
    // what the file holds is saved with its figures.
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    final id = await record(rig);
    await drive(rig, const Duration(seconds: 30));
    rig.sink.failNext = const TripWriteFailure(outOfSpace: true);
    await drive(rig, const Duration(seconds: 1));
    await RecorderRig.settle();

    expect(rig.recorder.view.phase, RecorderPhase.idle);
    final saved = rig.store.rows[id]!;
    expect(saved.endReason, TripEnd.storageFull);
    expect(saved.interrupted, isTrue);
    expect(rowsIn(rig.sink.content).last.t, 30000, reason: 'what landed');
    // 29.5 s at 36 km/h and 3.6 L/h, from the rows on disk.
    expect(saved.distanceKm, closeTo(0.295, 1e-9));
    expect(saved.fuelUsedL, closeTo(0.0295, 1e-9));
    expect(saved.maxSpeedKph, 36);
    final result = rig.recorder.view.result!;
    expect(result.kind, TripResultKind.saved);
    expect(result.end, TripEnd.storageFull);
    expect(result.distanceKm, saved.distanceKm);
    expect(result.fuelUsedL, saved.fuelUsedL);
    expect(result.savedUpTo, saved.endedAt);
    expect(rig.link.recordingCalls.last, isFalse);
  });

  test('a save that fails leaves the trip for the launch pass: '
      'summaryPending', () async {
    // The database is full too. The row stays open, and the file says how
    // the trip ended, so the next launch pass closes it truthfully.
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    final id = await record(rig);
    await drive(rig, const Duration(seconds: 10));
    rig.store.failFinish = SqliteException(
      extendedResultCode: 13,
      message: 'database or disk is full',
    );
    await rig.recorder.stop();

    final result = rig.recorder.view.result!;
    expect(result.kind, TripResultKind.summaryPending);
    expect(result.end, TripEnd.stopped);
    expect(result.vehicleId, 'golf');
    expect(rig.store.rows[id]!.endedAt, isNull, reason: 'left open');
    final file = rig.store.summaryOf(id, now: rig.clock.nowUtc());
    expect(file.end, TripEnd.stopped, reason: '#end is on disk');
    expect(file.endT, 10000);
    expect(rig.recorder.view.phase, RecorderPhase.idle);
    expect(rig.link.recordingCalls.last, isFalse);
  });

  test('a start before the launch pass is done is refused and makes no '
      'row', () async {
    // The pass closes what the last run left open. A Record before it
    // would open a second trip, and the pass would then close the new one
    // as killed.
    final launch = Completer<void>();
    final rig = RecorderRig(launch: launch.future);
    addTearDown(rig.dispose);
    expect(rig.recorder.refusal, RecordRefusal.notLaunched);
    await rig.recorder.start();
    await RecorderRig.settle();
    expect(rig.store.starts, 0);
    expect(rig.store.rows, isEmpty);
    expect(rig.recorder.view.phase, RecorderPhase.idle);
    expect(rig.link.recordingCalls, isEmpty);

    launch.complete();
    await rig.recorder.launched;
    expect(rig.recorder.refusal, isNull);
    await rig.recorder.start();
    expect(rig.store.rows, hasLength(1));
  });

  test('a start the disk refuses says so: startFailed(outOfSpace)', () async {
    final rig = RecorderRig(platform: android);
    addTearDown(rig.dispose);
    rig.store.failStart = const FileSystemException(
      'Cannot write the trip header',
      'trips/0123456789abcdef0123456789abcdef.csv',
      OSError('No space left on device', 28),
    );
    await rig.recorder.start();
    var result = rig.recorder.view.result!;
    expect(result.kind, TripResultKind.startFailed);
    expect(result.outOfSpace, isTrue);
    expect(result.vehicleId, 'golf');
    expect(rig.recorder.lastEvent!.kind, TripEventKind.startFailed);
    expect(rig.recorder.view.phase, RecorderPhase.idle);
    expect(rig.store.rows, isEmpty);
    expect(rig.link.recordingCalls, isEmpty, reason: 'nothing asked');
    expect(rig.dashboard.recordingPids, isEmpty);
    expect(rig.background.calls, isNot(contains('startRecording')));

    // Anything else is not called a full disk.
    rig.store.failStart = const FileSystemException(
      'Cannot create the trip file',
      'trips/0123456789abcdef0123456789abcdef.csv',
      OSError('Permission denied', 13),
    );
    await rig.recorder.start();
    result = rig.recorder.view.result!;
    expect(result.kind, TripResultKind.startFailed);
    expect(result.outOfSpace, isFalse);
  });

  test('detach writes nothing and leaves the row open', () async {
    // The engine is going away. The next launch pass closes the trip from
    // its file (§9.2); a write now could only race it.
    final rig = RecorderRig(platform: android);
    addTearDown(rig.dispose);
    final id = await record(rig);
    await drive(rig, const Duration(seconds: 3));
    rig.link.publish('010D', 40); // buffered, not yet written
    final sink = rig.store.sinks[id]!;
    final content = sink.content;
    final ops = [...sink.log];

    rig.recorder.detach();
    rig.link.publish('010D', 41);
    rig.link.set(SessionState.disconnected);
    rig.recorder.follow(const OwnerVehicle('passat', 'Passat'));
    rig.recorder.isPro = true;
    await RecorderRig.settle();

    expect(sink.content, content);
    expect(sink.log, ops, reason: 'no append, no sync, no close');
    expect(sink.closed, isFalse);
    expect(rig.store.finishes, 0);
    expect(rig.store.discarded, isEmpty);
    expect(rig.store.rows[id]!.endedAt, isNull, reason: 'left open');
    expect(
      rig.background.calls.last,
      'stopRecording',
      reason: 'the service does not outlive the engine',
    );
  });

  group('a notify after detach throws nothing', () {
    // LiveSession.dispose detaches the recorder and disposes it at once.
    // Whatever it was awaiting still comes back afterwards, and a notifier
    // touched after dispose throws.
    test('the launch pass, the link, the garage and the plan', () async {
      final launch = Completer<void>();
      final r = RecorderRig(launch: launch.future);
      var heard = 0;
      r.recorder
        ..addListener(() => heard++)
        ..detach()
        ..dispose();
      r.link.set(SessionState.disconnected);
      r.link.set(SessionState.connected);
      r.link.publish('010D', 40);
      launch.complete();
      await RecorderRig.settle();
      expect(heard, 0);
      r.dashboard.dispose();
      r.link.dispose();
    });

    test('a trip being saved', () async {
      final store = _Store()..hold = Completer<void>();
      final r = _Rig(store: store, isPro: true);
      final id = await record(r);
      await drive(r, const Duration(seconds: 3));
      final stopping = r.recorder.stop();
      await RecorderRig.settle();
      expect(store.firstAsked, isNotNull, reason: 'inside the save');
      r.recorder
        ..detach()
        ..dispose();
      store.hold!.complete();
      await expectLater(stopping, completes);
      expect(store.rows[id]!.endReason, TripEnd.stopped);
      r.dashboard.dispose();
      r.link.dispose();
    });

    test('a start waiting on the Android service', () async {
      final service = _Service()..hold = Completer<void>();
      final r = _Rig(background: service);
      final starting = r.recorder.start();
      await RecorderRig.settle();
      expect(service.calls, contains('startRecording'), reason: 'waiting');
      final ops = [...r.sink.log];
      r.recorder
        ..detach()
        ..dispose();
      service.hold!.complete();
      await expectLater(starting, completes);
      await RecorderRig.settle();
      expect(r.sink.log, ops, reason: 'nothing written after detach');
      r.dashboard.dispose();
      r.link.dispose();
    });
  });
}

/// Taps Record and waits for the trip to open; returns its id.
Future<String> record(RecorderRig rig) async {
  await rig.recorder.start();
  await RecorderRig.settle();
  expect(rig.recorder.view.phase, RecorderPhase.recording);
  return rig.store.rows.keys.last;
}

/// A 2 Hz poll loop: every 500 ms both clocks move and Speed and Fuel rate
/// are published; every second the recorder ticks, after that instant's
/// samples — as its 1 s timer would.
Future<void> drive(
  RecorderRig rig,
  Duration d, {
  double kph = 36,
  double lph = 3.6,
}) async {
  for (var i = 1; i <= d.inMilliseconds ~/ 500; i++) {
    rig.clock.advance(const Duration(milliseconds: 500));
    rig.link
      ..publish('010D', kph)
      ..publish('015E', lph);
    if (i.isEven) rig.recorder.debugTick();
    await RecorderRig.settle();
  }
}

/// The data rows of a trip file: what it says was recorded. The header and
/// the `#` anchors are not rows.
List<({int t, String pid, String value})> rowsIn(String content) => [
  for (final line in content.split('\n').skip(2))
    if (line.isNotEmpty && !line.startsWith('#'))
      switch (line.split(',')) {
        [final t, final pid, final value] => (
          t: int.parse(t),
          pid: pid,
          value: value,
        ),
        _ => throw FormatException('not a row', line),
      },
];

/// What had been stopped when the store was first asked to save or drop
/// the trip.
typedef _Stopped = ({
  bool? lastSetRecording,
  Set<String> recordingPids,
  int stopRecording,
});

/// [FakeTripStore] that notes what had stopped when it was first asked to
/// save or drop a trip, and can hold a save open.
class _Store extends FakeTripStore {
  _Stopped Function()? look;
  _Stopped? firstAsked;
  Completer<void>? hold;

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) async {
    firstAsked ??= look?.call();
    final h = hold;
    if (h != null) await h.future;
    return super.finish(trip, end, now: now);
  }

  @override
  Future<void> discard(OpenTrip trip) {
    firstAsked ??= look?.call();
    return super.discard(trip);
  }
}

/// [FakeBackgroundService] whose service start can be held open.
class _Service extends FakeBackgroundService {
  Completer<void>? hold;

  @override
  Future<bool> startRecording() async {
    final started = super.startRecording();
    final h = hold;
    if (h != null) await h.future;
    return started;
  }
}

/// A [RecorderRig] on Android whose store and service a test hands in.
/// The shared rig builds its own, and support.dart is shared.
class _Rig implements RecorderRig {
  _Rig({_Store? store, FakeBackgroundService? background, bool isPro = false})
    : link = FakeTripLink(),
      clock = ManualTripClock(),
      store = store ?? _Store(),
      background = background ?? FakeBackgroundService() {
    dashboard = DashboardLayoutController(publish: published.add);
    recorder = TripRecorder(
      link: link,
      store: this.store,
      dashboard: dashboard,
      background: this.background,
      platform: const FakePlatform(isAndroid: true),
      clock: clock,
      tickEvery: null,
    )..isPro = isPro;
    recorder.follow(RecorderRig.golf);
    this.store.look = () => (
      lastSetRecording: link.recordingCalls.lastOrNull,
      recordingPids: {...dashboard.recordingPids},
      stopRecording: this.background.calls
          .where((c) => c == 'stopRecording')
          .length,
    );
  }

  @override
  final FakeTripLink link;
  @override
  final ManualTripClock clock;
  @override
  final _Store store;
  @override
  final FakeBackgroundService background;
  @override
  final List<Set<String>> published = [];
  @override
  late final DashboardLayoutController dashboard;
  @override
  late final TripRecorder recorder;

  @override
  Future<void> tick([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      clock.advance(const Duration(seconds: 1));
      recorder.debugTick();
      await RecorderRig.settle();
    }
  }

  @override
  MemoryTripSink get sink => store.sinks.values.single;

  @override
  void dispose() {
    recorder.dispose();
    dashboard.dispose();
    link.dispose();
  }
}
