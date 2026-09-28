import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/repositories/trip_repository.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/data/trips/trip_sink.dart';
import 'package:torque_obd2/features/dashboard/dashboard_layout.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/features/trips/trip_clock.dart';
import 'package:torque_obd2/features/trips/trip_launch.dart';
import 'package:torque_obd2/features/trips/trip_link.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_store.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

import '../../data/support.dart';
import 'support.dart';

/// The recorder over the real disk: [DbTripStore], [FileTripSink], drift
/// and `Isolate.run`, in plain `test()` on the real clock. What the fakes
/// cannot show is shown here — what is on disk at the moment of a kill,
/// what the next launch makes of it, and a real session's samples arriving
/// in the file in the order the car sent them.
void main() {
  late AppDatabase db;
  late Directory dir;
  late TripRepository repo;
  late VehicleRow car;
  late ObdTrace driveTrace;

  setUpAll(() {
    // The Civic pulling away, cruising near 60 km/h, braking to a stop.
    driveTrace = ObdTrace.parse(
      File('assets/traces/trip_drive_can.obdtrace').readAsStringSync(),
    );
  });

  setUp(() async {
    db = memoryDb();
    dir = await scratchDir();
    repo = TripRepository(db, TripFiles(dir));
    car = await golf(db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  /// A link that is live on the Golf, disposed after the recorder that
  /// listens to it.
  FakeTripLink liveLink() {
    final link = FakeTripLink();
    addTearDown(link.dispose);
    return link;
  }

  /// A recorder on the settled Golf, iOS, free plan, ticked by hand.
  TripRecorder recorderOver(
    TripStore store,
    TripLink link,
    TripClock clock, {
    Future<void>? launch,
  }) {
    final dashboard = DashboardLayoutController(publish: (_) {});
    final r = TripRecorder(
      link: link,
      store: store,
      dashboard: dashboard,
      background: FakeBackgroundService(),
      platform: const FakePlatform(isAndroid: false),
      launch: launch,
      clock: clock,
      tickEvery: null,
    )..follow(OwnerVehicle(car.id, car.nickname));
    addTearDown(() {
      r.dispose();
      dashboard.dispose();
    });
    return r;
  }

  /// Waits on the real clock for what real I/O will do.
  Future<void> until(bool Function() done, {required String reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $reason');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('★ a trip whose save failed does not block the next Record', () async {
    // The summary could not be read (the database full, the isolate
    // failing), so the row was left open for the launch pass — and one open
    // trip at a time made every Record fail with "Try again" until the app
    // was relaunched. The next start closes it from its file.
    var failOnce = true;
    Future<TripFileSummary> flaky(
      String path, {
      required int startedAtMs,
      required int nowMs,
    }) {
      if (failOnce) {
        failOnce = false;
        throw const FileSystemException('Input/output error');
      }
      return summarizeTripFile(path, startedAtMs: startedAtMs, nowMs: nowMs);
    }

    final clock = ManualTripClock(start: DateTime.utc(2026, 9, 28, 12));
    final link = liveLink();
    final r = recorderOver(DbTripStore(repo, summarize: flaky), link, clock);
    await r.start();
    for (var i = 0; i < 3; i++) {
      link.publish('010D', 36);
      clock.advance(const Duration(seconds: 1));
      r.debugTick();
    }
    await r.stop();
    expect(r.view.result?.kind, TripResultKind.summaryPending);
    final first = (await repo.openTrip())!.id;

    await r.start();
    await until(
      () => r.view.phase == RecorderPhase.recording,
      reason: 'Record',
    );
    final closed = (await repo.byId(first))!;
    expect(closed.endedAt, isNotNull, reason: 'closed from its file');
    expect(closed.sampleCount, 3);
    expect((await repo.openTrip())!.id, isNot(first));
  });

  test('★ Resume never writes onto a torn line, even one the launch pass '
      'could not cut', () async {
    // The launch pass cuts a killed trip's torn tail, and Resume opens the
    // file cut to its last whole line too: the pass's cut is best effort,
    // and a segment appended to half a row reads as garbage. One rule in
    // two places, each for its own failure — so each is proven alone.
    final started = DateTime.utc(2026, 9, 28, 12);
    final row = await repo.start(vehicleId: car.id, now: started);
    final file = repo.fileOf(row);
    final drive = driveCsv(started, toMs: 20000);
    await file.writeAsString(
      '${drive.substring(TripCsv.header.length)}20400,010D,4',
      mode: FileMode.append,
    );
    // Closed as killed, but the tail left in place.
    await repo.finish(
      row.id,
      end: TripEnd.appKilled,
      summary: TripCsv.summarizeFileSync(
        file.path,
        startedAtMs: started.millisecondsSinceEpoch,
        nowMs: started.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      ),
    );

    final now = started.add(const Duration(minutes: 5));
    final trip = await DbTripStore(repo).resume(row.id, now: now);
    expect(trip, isNotNull);
    await trip!.sink.append(TripCsv.segment(trip.baseT, now));
    await trip.sink.append(TripCsv.row(trip.baseT + 500, '010D', 30));
    await trip.sink.close();

    final content = await file.readAsString();
    expect(content, isNot(contains('20400,010D,4')));
    final summary = TripCsv.summarize(
      content,
      startedAtMs: started.millisecondsSinceEpoch,
      nowMs: now.millisecondsSinceEpoch,
    );
    expect(summary.malformed, 0);
  });

  test('★ AC-09 a kill loses at most the last second', () async {
    // Rows go from the buffer to the file every 1 s tick; every fifth also
    // fsyncs. Killed at 14.9 s — no stop, no close — the file must hold
    // every row to 14.0 s: the second still in the buffer is all a kill
    // may take. Written every 5 s, the file would stop at 10.0 s and the
    // kill would take 4.9 s; written only at stop, all of it.
    final store = _Watched(DbTripStore(repo));
    final link = liveLink();
    final clock = ManualTripClock();
    final rec = recorderOver(store, link, clock);
    await rec.start();
    expect(rec.view.phase, RecorderPhase.recording);
    final trip = (await repo.openTrip())!;

    // Speed ten times a second, and the tick each second. Before the
    // next tick, the write it issued lands, as it has a second to.
    for (var i = 1; i <= 149; i++) {
      clock.advance(const Duration(milliseconds: 100));
      link.publish('010D', 48.0 + i % 5);
      if (i % 10 == 0) {
        rec.debugTick();
        await store.drained;
      }
    }

    // t = 14.9 s: the process dies here. The file as it is now is all the
    // next launch will have.
    final content = await repo.fileOf(trip).readAsString();
    rec.detach();
    await store.closeAll();

    final onDisk = [for (final r in _dataRows(content)) int.parse(r[0])];
    expect(
      onDisk.isEmpty ? null : onDisk.last,
      14000,
      reason: 'at 14.9 s the rows to the last tick are on disk: 900 ms lost',
    );
    expect(onDisk, [for (var t = 100; t <= 14000; t += 100) t]);
    // And that is what the next launch will close the trip at.
    final s = TripCsv.summarize(
      content,
      startedAtMs: trip.startedAt.millisecondsSinceEpoch,
      nowMs: clock.nowUtc().millisecondsSinceEpoch,
    );
    expect(s.malformed, 0);
    expect(s.rows, 140);
    expect(s.endT, 14000);
  });

  test('★ §9.2 relaunch end to end: closed at the last durable row, then '
      'resumed into the same row', () async {
    final started = DateTime.utc(2026, 9, 28, 17, 30);

    // ---- The first run: 32 s at 36 km/h, 3.6 L/h.
    final store1 = _Watched(DbTripStore(TripRepository(db, TripFiles(dir))));
    final link1 = liveLink();
    final clock1 = ManualTripClock(start: started);
    final rec1 = recorderOver(store1, link1, clock1);
    await rec1.start();
    final open = (await repo.openTrip())!;
    expect(open.startedAt, started);

    // Speed every 500 ms, Fuel rate every second, the tick each second.
    // At 10 s the phone sets its clock from the network, a minute ahead:
    // only the anchors written after that know it.
    for (var i = 1; i <= 64; i++) {
      clock1.advance(const Duration(milliseconds: 500));
      if (i.isEven) link1.publish('015E', 3.6);
      link1.publish('010D', 36.0);
      if (i.isEven) {
        rec1.debugTick();
        await store1.drained;
      }
      if (i == 20) clock1.stepWall(const Duration(minutes: 1));
    }
    final killedAt = clock1.nowUtc();
    expect(killedAt, started.add(const Duration(minutes: 1, seconds: 32)));

    // iOS ends the app while the 32 s tick's write is landing: the last
    // line got only its first bytes. The recorder writes nothing more,
    // and the OS closes its file.
    rec1.detach();
    await store1.closeAll();
    final file = repo.fileOf(open);
    final written = await file.readAsString();
    const lastLine = '32000,010D,36.0\n';
    expect(written, endsWith('32000,015E,3.6\n$lastLine'));
    final durable = written.substring(0, written.length - lastLine.length);
    await file.writeAsString(written.substring(0, written.length - 4));
    expect(await file.readAsString(), endsWith('\n32000,010D,3'));

    // ---- The relaunch, 5 minutes on: a new process, a new repository
    // over the same database and directory, the pass started from main()
    // and the recorder waiting for it.
    final relaunchAt = killedAt.add(const Duration(minutes: 5));
    final repo2 = TripRepository(db, TripFiles(dir));
    final pass = runTripLaunchPass(
      repo2,
      background: FakeBackgroundService(),
      now: relaunchAt,
    );
    final store2 = _Watched(DbTripStore(repo2));
    final link2 = liveLink();
    final clock2 = ManualTripClock(start: relaunchAt);
    final rec2 = recorderOver(store2, link2, clock2, launch: pass);
    expect(rec2.refusal, RecordRefusal.notLaunched);

    final report = await pass;
    final closed = report.closed.single;
    expect(closed.id, open.id);
    expect(closed.endReason, TripEnd.appKilled);
    expect(closed.interrupted, isTrue);
    expect(
      closed.endedAt,
      killedAt,
      reason:
          'the last durable row, by the anchor before it — not the '
          'relaunch 5 min on, and not startedAt + 32 s on a clock that moved',
    );
    expect(closed.recordedMs, 32000);
    expect(closed.sampleCount, 95, reason: '63 speeds and 32 fuel rates');
    expect(closed.distanceKm, closeTo(0.31, 1e-9));
    // The torn line is cut off, so whatever follows starts a whole line.
    expect(
      closed.fileBytes,
      durable.length,
      reason: "'32000,010D,3' is 12 bytes of a row that never landed",
    );
    expect(await file.readAsString(), durable);

    // The same car, live and settled, within 30 minutes: offered.
    await until(() => rec2.view.offer != null, reason: 'the Resume offer');
    final offer = rec2.view.offer!;
    expect(offer.tripId, open.id);
    expect(offer.end, TripEnd.appKilled);
    expect(offer.endedAt, killedAt);

    // ---- Resume, then 10 s at 72 km/h, 7.2 L/h.
    await rec2.resume();
    expect(rec2.view.phase, RecorderPhase.recording);
    expect(
      (await repo2.openTrip())?.id,
      open.id,
      reason: 'the same row records again',
    );
    for (var i = 1; i <= 20; i++) {
      clock2.advance(const Duration(milliseconds: 500));
      if (i.isEven) link2.publish('015E', 7.2);
      link2.publish('010D', 72.0);
      if (i.isEven) {
        rec2.debugTick();
        await store2.drained;
      }
    }
    final meter = rec2.reading.value!;
    await rec2.stop();
    await store2.drained;

    final trips = await repo2.recent(car.id);
    expect(trips.map((r) => r.id), [open.id], reason: 'one trip, not two');
    final done = trips.single;
    expect(done.startedAt, started);
    expect(done.endReason, TripEnd.stopped);
    expect(done.interrupted, isFalse);
    // Recorded time runs on from the file's last row: 32 s, then 10 s.
    // The 5 minutes Torque was gone are not recorded time...
    expect(done.recordedMs, 42000);
    // ...though the wall clock saw them.
    expect(done.endedAt, relaunchAt.add(const Duration(seconds: 10)));
    expect(done.sampleCount, 95 + 30);
    // Both segments, and nothing across the kill: 31 s at 36 km/h plus
    // 9.5 s at 72 km/h. A bridge from 31.5 s to 32.5 s would add 0.015 km,
    // and 0.0015 L to the fuel.
    expect(done.distanceKm, closeTo(0.31 + 0.19, 1e-9));
    expect(done.fuelUsedL, closeTo(0.031 + 0.018, 1e-9));
    expect(done.maxSpeedKph, 72);
    // What the strip showed at the end is what was saved: the live
    // figures carried the first segment on.
    expect(meter.elapsedMs, 42000);
    expect(meter.distanceKm, closeTo(done.distanceKm!, 1e-9));
    expect(meter.fuelUsedL, closeTo(done.fuelUsedL!, 1e-9));

    // The file reads whole: two segments, nothing malformed, no torn row.
    final content = await file.readAsString();
    final summary = TripCsv.summarize(
      content,
      startedAtMs: started.millisecondsSinceEpoch,
      nowMs: clock2.nowUtc().millisecondsSinceEpoch,
    );
    expect(summary.version, TripCsv.version);
    expect(summary.malformed, 0);
    expect(summary.rows, done.sampleCount);
    expect(summary.end, TripEnd.stopped);
    expect(
      content.split('\n').where((l) => l.startsWith('${TripCsv.segmentTag},')),
      [
        TripCsv.segment(0, started).trim(),
        TripCsv.segment(32000, relaunchAt).trim(),
      ],
    );
    expect(await file.length(), done.fileBytes);
  });

  test(
    'smoke: a real session, through SessionTripLink, into a real file',
    () async {
      final session = ObdSession(timeScale: 0.05);
      addTearDown(() async {
        await session.disconnect();
        session.dispose();
      });
      // RPM is the one tile on screen. Speed and Fuel rate reach the car
      // only because the recording asks the layout controller for them.
      final dashboard = DashboardLayoutController(
        publish: session.setVisible,
        publishQuiet: session.setQuiet,
        defaults: const [LayoutTile('010C')],
      );
      addTearDown(dashboard.dispose);
      dashboard.setTarget(VehicleTarget(car));
      expect(dashboard.loaded, isTrue);

      final transport = MockTransport(driveTrace, speed: 100);
      expect(await session.connect(transport), isTrue);
      final store = _Watched(DbTripStore(repo));
      // The real clocks and the real 1 s tick.
      final rec = TripRecorder(
        link: SessionTripLink(session),
        store: store,
        dashboard: dashboard,
        background: FakeBackgroundService(),
        platform: const FakePlatform(isAndroid: false),
      )..follow(OwnerVehicle(car.id, car.nickname));
      addTearDown(rec.dispose);
      await until(
        () => session.bus.of('010C').value != null,
        reason: 'the RPM tile polled',
      );
      expect(
        transport.written,
        isNot(contains('010D')),
        reason: 'nothing asks for Speed before the recording',
      );

      await rec.start();
      expect(rec.view.phase, RecorderPhase.recording);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await rec.stop();
      await store.drained;

      final row = (await repo.recent(car.id)).single;
      expect(row.endReason, TripEnd.stopped);
      final content = await repo.fileOf(row).readAsString();
      final summary = TripCsv.summarize(
        content,
        startedAtMs: row.startedAt.millisecondsSinceEpoch,
        nowMs: DateTime.timestamp().millisecondsSinceEpoch,
      );
      expect(summary.version, TripCsv.version);
      expect(summary.malformed, 0);
      expect(summary.end, TripEnd.stopped);
      final rows = _dataRows(content);
      expect(row.sampleCount, rows.length);

      // Speed, exactly as the car answered it and in that order — the
      // mock repeats its last answer once the recording runs out of them.
      final answers = [
        for (final reply in driveTrace.repliesByCommand['010D']!)
          _kph.firstMatch(reply)!.group(1)!,
      ].map((hex) => int.parse(hex, radix: 16).toDouble()).toList();
      final speeds = [
        for (final r in rows)
          if (r[1] == '010D') double.parse(r[2]),
      ];
      expect(speeds, isNotEmpty);
      expect(speeds, [
        for (var i = 0; i < speeds.length; i++)
          answers[math.min(i, answers.length - 1)],
      ]);
      expect(row.distanceKm, greaterThan(0));
      expect(rows.map((r) => r[1]).toSet(), containsAll(['010C', '010D']));
    },
  );
}

final _kph = RegExp(r'41 ?0D ?([0-9A-F]{2})');

/// Every data row among [content]'s whole lines, split into its fields.
List<List<String>> _dataRows(String content) {
  final whole = content.substring(0, content.lastIndexOf('\n') + 1);
  return [
    for (final line in whole.split('\n').skip(2))
      if (line.isNotEmpty && !line.startsWith('#')) line.split(','),
  ];
}

/// [DbTripStore] with every sink it opens watched, so a test can wait for
/// the writes the recorder has already issued to land — as they would in
/// the second of real time a tick leaves them — without stopping or
/// closing anything. Everything is delegated to the real store and sink.
class _Watched implements TripStore {
  _Watched(this._inner);
  final DbTripStore _inner;
  final _sinks = <_WatchedSink>[];
  Future<void> _retention = Future.value();

  /// Every write issued so far has landed, and retention has run.
  Future<void> get drained async {
    for (final s in [..._sinks]) {
      await s.drained;
    }
    await _retention;
  }

  /// What the OS does to a killed process's files.
  Future<void> closeAll() async {
    for (final s in _sinks) {
      await s.inner.close();
    }
  }

  OpenTrip _watch(OpenTrip t) {
    final sink = _WatchedSink(t.sink);
    _sinks.add(sink);
    return OpenTrip(
      id: t.id,
      vehicleId: t.vehicleId,
      startedAt: t.startedAt,
      sink: sink,
      baseT: t.baseT,
      seed: t.seed,
    );
  }

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async =>
      _watch(await _inner.start(vehicleId: vehicleId, startedAt: startedAt));

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) => _inner.finish(trip, end, now: now);

  @override
  Future<void> discard(OpenTrip trip) => _inner.discard(trip);

  @override
  Future<TripSessionRow?> resumable(
    String vehicleId, {
    required DateTime now,
  }) => _inner.resumable(vehicleId, now: now);

  @override
  Future<OpenTrip?> resume(String tripId, {required DateTime now}) async {
    final t = await _inner.resume(tripId, now: now);
    return t == null ? null : _watch(t);
  }

  @override
  Future<void> retention() => _retention = _inner.retention();
}

class _WatchedSink implements TripSink {
  _WatchedSink(this.inner);
  final TripSink inner;
  Future<void> _last = Future.value();

  Future<void> _track(Future<void> op) {
    _last = op.then((_) {}, onError: (Object _) {});
    return op;
  }

  /// The last operation issued has finished — and so has every one
  /// before it, since the real sink runs them in order. A sync the
  /// recorder issues once its append lands is waited for too.
  Future<void> get drained async {
    while (true) {
      final last = _last;
      await last;
      await Future<void>.delayed(Duration.zero);
      if (identical(last, _last)) return;
    }
  }

  @override
  int get committed => inner.committed;

  @override
  Future<void> append(String ascii) => _track(inner.append(ascii));

  @override
  Future<void> sync() => _track(inner.sync());

  @override
  Future<void> close() => _track(inner.close());
}
