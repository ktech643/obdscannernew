import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/data/trips/trip_sink.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_store.dart';
import 'package:torque_obd2/session/obd_session.dart' show SessionState;
import 'package:torque_obd2/transport/obd_transport.dart' show TransportKind;

import 'support.dart';

const _ios = FakePlatform(isAndroid: false);
const _android = FakePlatform(isAndroid: true);

/// A recorder and what drives it: [RecorderRig]'s own, or one built over a
/// store the test chooses — the same store after a "kill", or a gated one.
class _Car {
  _Car._(this.recorder, this.link, this.clock, this.background, this.layouts);

  factory _Car.of(RecorderRig rig) =>
      _Car._(rig.recorder, rig.link, rig.clock, rig.background, rig.dashboard);

  /// Built as [RecorderRig] builds its recorder — no timer, [clock] by
  /// hand — but over [store], and following nobody until the test says.
  factory _Car.over(
    TripStore store, {
    PlatformInfo platform = _ios,
    bool isPro = false,
    ManualTripClock? clock,
  }) {
    final link = FakeTripLink();
    final c = clock ?? ManualTripClock();
    final background = FakeBackgroundService();
    final layouts = DashboardLayoutController(publish: (_) {});
    final recorder = TripRecorder(
      link: link,
      store: store,
      dashboard: layouts,
      background: background,
      platform: platform,
      clock: c,
      tickEvery: null,
    )..isPro = isPro;
    addTearDown(() {
      recorder.dispose();
      layouts.dispose();
      link.dispose();
    });
    return _Car._(recorder, link, c, background, layouts);
  }

  final TripRecorder recorder;
  final FakeTripLink link;
  final ManualTripClock clock;
  final FakeBackgroundService background;
  final DashboardLayoutController layouts;

  TripView get view => recorder.view;

  /// One second of driving as a 2 Hz poll loop publishes it — Speed every
  /// 500 ms, Fuel rate once a second — and then the 1 s tick.
  Future<void> second({double? kph = 36, double lph = 3.6}) async {
    clock.advance(const Duration(milliseconds: 500));
    link.publish('010D', kph);
    clock.advance(const Duration(milliseconds: 500));
    link.publish('010D', kph);
    link.publish('015E', lph);
    recorder.debugTick();
    await RecorderRig.settle();
  }

  Future<void> seconds(int n, {double? kph = 36}) async {
    for (var i = 0; i < n; i++) {
      await second(kph: kph);
    }
  }
}

/// The app opened again after [rig]'s recorder died: a new process — a new
/// link, a Stopwatch back at zero — over the same trips, [gap] after [from].
_Car _relaunch(
  RecorderRig rig, {
  required DateTime from,
  required Duration gap,
  bool isPro = false,
}) => _Car.over(
  rig.store,
  isPro: isPro,
  clock: ManualTripClock(start: from.add(gap)),
);

/// The file of the trip being recorded, among the ones [store] holds.
MemoryTripSink _openSink(FakeTripStore store) =>
    store.sinks[store.rows.values.singleWhere((r) => r.endedAt == null).id]!;

/// Every data row's t, in file order.
List<int> _rowTimes(String csv) => [
  for (final l in csv.split('\n'))
    if (l.isNotEmpty && !l.startsWith('#') && l != TripCsv.columns)
      int.parse(l.split(',').first),
];

/// The store, with a start that waits at [gate]: the row and the file are
/// still being made while the user does something else.
class _GatedStore extends FakeTripStore {
  final gate = Completer<void>();

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async {
    await gate.future;
    return super.start(vehicleId: vehicleId, startedAt: startedAt);
  }
}

/// A sink that keeps no bytes, only what each append carried: half an
/// hour at 30 samples a second costs the test nothing to hold.
class _TallySink implements TripSink {
  int _bytes = 0;
  int appends = 0;
  int rows = 0;

  /// Data rows in the last append; '#' lines are not rows.
  int lastRows = 0;
  int maxBytes = 0;

  @override
  int get committed => _bytes;

  @override
  Future<void> append(String ascii) async {
    appends++;
    _bytes += ascii.length;
    if (ascii.length > maxBytes) maxBytes = ascii.length;
    lastRows = 0;
    for (var i = 0; i < ascii.length; i = ascii.indexOf('\n', i) + 1) {
      if (ascii.codeUnitAt(i) != 0x23) lastRows++;
    }
    rows += lastRows;
  }

  @override
  Future<void> sync() async {}

  @override
  Future<void> close() async {}
}

class _TallyStore implements TripStore {
  _TallyStore(this.sink);
  final _TallySink sink;

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async => OpenTrip(
    id: 'a' * 32,
    vehicleId: vehicleId,
    startedAt: startedAt,
    sink: sink,
  );

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) async => null;

  @override
  Future<void> discard(OpenTrip trip) async {}

  @override
  Future<TripSessionRow?> resumable(
    String vehicleId, {
    required DateTime now,
  }) async => null;

  @override
  Future<OpenTrip?> resume(String tripId, {required DateTime now}) async =>
      null;

  @override
  Future<void> retention() async {}
}

/// SPEC §9.2 "Resume trip?", the Android service and the background, and
/// what a recording holds in memory — the recorder over the fakes in
/// support.dart, deterministically, in plain tests.
void main() {
  group('★ Resume trip? — §9.2', () {
    test("★ Resume continues the same row from the file's last row", () async {
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      final car = _Car.of(rig);
      await rig.recorder.start();
      final id = rig.store.rows.keys.single;
      final startedAt = rig.store.rows[id]!.startedAt;
      final sink = rig.sink;
      await car.seconds(90); // 1:30 at 36 km/h, the last row at t = 90000
      // Heard after the last tick: in the buffer, not the file, when the
      // process dies (AC-09's second).
      rig.clock.advance(const Duration(milliseconds: 500));
      rig.link.publish('010D', 36);
      rig.recorder.detach();
      final killedAt = rig.clock.nowUtc();

      // The launch pass, five minutes later.
      final closed = rig.store.closeAsKilled(
        id,
        now: killedAt.add(const Duration(minutes: 5)),
      );
      expect(closed.recordedMs, 90000, reason: 'the last row on disk');
      expect(closed.endReason, TripEnd.appKilled);
      expect(closed.distanceKm, closeTo(0.895, 1e-9));

      final again = _relaunch(
        rig,
        from: killedAt,
        gap: const Duration(minutes: 5),
      );
      again.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      final offer = again.view.offer;
      expect(offer, isNotNull, reason: 'the same car, live, within 30 min');
      expect(offer!.tripId, id);
      expect(offer.end, TripEnd.appKilled);
      expect(offer.recordedMs, 90000);

      final resumedAt = again.clock.nowUtc();
      await again.recorder.resume();
      expect(again.view.phase, RecorderPhase.recording);
      expect(again.recorder.lastEvent?.kind, TripEventKind.resumed);
      expect(rig.store.rows.keys, [id], reason: 'the same row, not a new one');
      // A new process's Stopwatch reads 0; recorded time does not.
      expect(
        again.recorder.reading.value?.elapsedMs,
        90000,
        reason: 'the meter reads 1:30 of 2:00, not 0:00',
      );

      await again.seconds(10);
      // The figures carry on from the file: 0.895 km before the kill, plus
      // 9.5 s at 36 km/h since — the kill's gap is neither timed nor
      // integrated.
      final meter = again.recorder.reading.value!;
      expect(meter.elapsedMs, 100000);
      expect(meter.distanceKm, closeTo(0.895 + 0.095, 1e-9));
      expect(meter.fuelUsedL, closeTo(0.089 + 0.009, 1e-9));

      // Free: 2:00 counts the whole trip, so 30 s more is all it gets.
      var resumedFor = 10;
      while (again.view.phase == RecorderPhase.recording && resumedFor < 60) {
        await again.second();
        resumedFor++;
      }
      expect(resumedFor, 30, reason: 'resumed at 1:30, stopped at 2:00');
      expect(again.view.result?.end, TripEnd.freeCap);

      final row = rig.store.rows.values.single;
      expect(row.id, id);
      expect(row.startedAt, startedAt, reason: 'one trip in the list');
      expect(row.endReason, TripEnd.freeCap);
      expect(row.interrupted, isFalse);
      expect(row.recordedMs, 120000);
      expect(row.distanceKm, closeTo(0.895 + 0.29, 1e-9));
      expect(row.endedAt, resumedAt.add(const Duration(seconds: 30)));

      // The file: one '#segment' at the resume point, t never going back,
      // nothing at or past 2:00 — and the one row at 90500 is the resumed
      // segment's first, not the sample the kill lost at the same t.
      final csv = sink.content;
      expect(
        csv,
        contains(
          '\n${TripCsv.segment(90000, resumedAt)}'
          '90500,010D,36.0\n',
        ),
      );
      final times = _rowTimes(csv);
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThanOrEqualTo(times[i - 1]), reason: 'row $i');
      }
      expect(times.last, 119500);
      expect(times.where((t) => t == 90500), hasLength(1));
      final summary = TripCsv.summarize(
        csv,
        startedAtMs: startedAt.millisecondsSinceEpoch,
        nowMs: again.clock.nowUtc().millisecondsSinceEpoch,
      );
      expect(summary.malformed, 0);
      expect(summary.rows, row.sampleCount);
    });

    test('★ Resume is offered only for the same settled car', () async {
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      await rig.recorder.start();
      final id = rig.store.rows.keys.single;
      await _Car.of(rig).seconds(40);
      rig.recorder.detach();
      final endedAt = rig.store
          .closeAsKilled(id, now: rig.clock.nowUtc())
          .endedAt!;

      final again = _relaunch(
        rig,
        from: endedAt,
        gap: const Duration(minutes: 5),
      );
      // The VIN is being read: nothing is offered for a car not yet known.
      again.recorder.follow(const OwnerPending('golf'));
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'checking which car');
      again.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(again.view.offer?.tripId, id);

      // The owner changes under an offer already fetched.
      again.recorder.follow(const OwnerPending('golf'));
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'pending again');
      again.recorder.follow(const OwnerVehicle('polo', 'Polo'));
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'another car');
      again.recorder.follow(const OwnerDemo());
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'Demo Mode');
      again.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(again.view.offer?.tripId, id, reason: 'the Golf again');

      // "Not now" holds for this run, even when a new live edge asks the
      // store again and gets the same trip back.
      again.recorder.declineOffer();
      expect(again.view.offer, isNull);
      again.link.set(SessionState.lost, reconnecting: true);
      again.link.set(SessionState.connected);
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'declined this session');

      // A later run asks again — until 30 minutes after its last sample.
      final at30 = _relaunch(
        rig,
        from: endedAt,
        gap: const Duration(minutes: 30),
      );
      at30.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(at30.view.offer?.tripId, id, reason: 'at 30:00');
      final past30 = _relaunch(
        rig,
        from: endedAt,
        gap: const Duration(minutes: 30, seconds: 1),
      );
      past30.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(past30.view.offer, isNull, reason: 'at 30:01');
    });

    test('★ on Free, a trip already at 2:00 has nothing to resume', () async {
      // Recorded on Pro, killed at 2:30; the plan lapsed before the relaunch.
      final rig = RecorderRig(isPro: true);
      addTearDown(rig.dispose);
      await rig.recorder.start();
      final id = rig.store.rows.keys.single;
      await _Car.of(rig).seconds(150);
      rig.recorder.detach();
      final closed = rig.store.closeAsKilled(id, now: rig.clock.nowUtc());
      expect(closed.recordedMs, 150000);

      final again = _relaunch(
        rig,
        from: closed.endedAt!,
        gap: const Duration(minutes: 2),
      );
      again.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(again.view.offer, isNull, reason: 'Free: recordedMs ≥ 120000');
      again.recorder.isPro = true;
      expect(again.view.offer?.tripId, id, reason: 'Pro: no limit');
    });
  });

  group('★ the Android service — §9.3', () {
    test(
      "★ the notification's Stop ends the trip within one 5 s tick",
      () async {
        final rig = RecorderRig(platform: _android);
        addTearDown(rig.dispose);
        final car = _Car.of(rig);
        await rig.recorder.start();
        expect(rig.background.calls, contains('startRecording'));
        expect(rig.link.recordingCalls, [true]);
        await car.seconds(5); // the first check sees it running
        expect(
          rig.background.calls.where((c) => c == 'isRunning'),
          hasLength(1),
        );

        // Stop on the notification: the service stops itself (stopSelf), and
        // nothing tells Dart.
        rig.background.running = false;
        var ticks = 0;
        while (rig.recorder.view.phase == RecorderPhase.recording &&
            ticks < 10) {
          await car.second();
          ticks++;
        }
        expect(ticks, lessThanOrEqualTo(5), reason: 'heard at the next check');
        final row = rig.store.rows.values.single;
        expect(row.endReason, TripEnd.notification);
        expect(row.interrupted, isFalse, reason: 'the user stopped it');
        expect(rig.recorder.view.result?.end, TripEnd.notification);
        expect(rig.link.recordingCalls.last, isFalse);

        // A service that never ran was refused, not stopped: the trip goes on
        // in the foreground and pauses in the background.
        final refused = RecorderRig(platform: _android);
        addTearDown(refused.dispose);
        final other = _Car.of(refused);
        await refused.recorder.start();
        // startForegroundService returned; the service could not go to the
        // foreground and stopped itself.
        refused.background.running = false;
        await other.seconds(5);
        expect(refused.recorder.view.phase, RecorderPhase.recording);
        expect(refused.recorder.view.caveat, TripCaveat.serviceRefused);
        expect(refused.link.recordingCalls, [true, false]);
        final before = _rowTimes(refused.sink.content).length;
        await other.seconds(10);
        expect(_rowTimes(refused.sink.content).length, before + 30);
        expect(
          refused.background.calls.where((c) => c == 'isRunning'),
          hasLength(1),
          reason: 'nothing left to check',
        );
        refused.recorder.setForeground(false);
        expect(refused.recorder.view.hold, TripHold.background);
      },
    );

    test(
      '★ notifications off: no service, one request, paused in the background',
      () async {
        final rig = RecorderRig(platform: _android);
        addTearDown(rig.dispose);
        final car = _Car.of(rig);
        int rows() => _rowTimes(_openSink(rig.store).content).length;
        int count(String call) =>
            rig.background.calls.where((c) => c == call).length;

        rig.background.notifications = false;
        await rig.recorder.start();
        expect(count('requestNotificationPermission'), 1);
        expect(count('startRecording'), 0, reason: 'no notification');
        expect(rig.link.recordingCalls, [false]);
        expect(rig.recorder.view.caveat, TripCaveat.notificationsOff);

        await car.seconds(2);
        expect(rows(), 6, reason: 'recording in the foreground');
        rig.recorder.setForeground(false);
        expect(rig.recorder.view.hold, TripHold.background);
        await car.seconds(3);
        expect(rows(), 6, reason: 'nothing written in the background');
        rig.recorder.setForeground(true);
        expect(rig.recorder.view.hold, isNull);
        await car.seconds(1);
        expect(rows(), 9);

        // The next trip asks nothing: the answer is read on the next resume.
        await rig.recorder.stop();
        await rig.recorder.start();
        expect(count('requestNotificationPermission'), 1);
        expect(rig.link.recordingCalls.last, isFalse);

        // Granted from Settings while Torque is in the background: the
        // service still starts only once Torque is in front again.
        rig.recorder.setForeground(false);
        rig.background.notifications = true;
        await car.seconds(5);
        expect(count('startRecording'), 0, reason: 'never from the background');
        rig.recorder.setForeground(true);
        await rig.recorder.onResumed();
        expect(count('startRecording'), 1);
        expect(rig.link.recordingCalls.last, isTrue);
        expect(rig.recorder.view.caveat, isNull);

        final sink = _openSink(rig.store);
        final now = sink.content.length;
        rig.recorder.setForeground(false);
        expect(rig.recorder.view.hold, isNull);
        await car.seconds(2);
        expect(
          _rowTimes(sink.content.substring(now)),
          hasLength(6),
          reason: 'the service holds it now',
        );
      },
    );
  });

  test(
    '★ iOS Wi-Fi pauses in the background; iOS BLE keeps recording',
    () async {
      final wifi = RecorderRig(transport: TransportKind.wifi);
      addTearDown(wifi.dispose);
      final w = _Car.of(wifi);
      int rows(RecorderRig r) => _rowTimes(r.sink.content).length;
      expect(
        wifi.recorder.view.caveat,
        TripCaveat.wifiInBackground,
        reason: 'said before Record',
      );
      await wifi.recorder.start();
      expect(wifi.link.recordingCalls, [
        false,
      ], reason: 'no dead socket polled');
      expect(wifi.recorder.view.caveat, TripCaveat.wifiInBackground);
      await w.seconds(2);
      wifi.recorder.setForeground(false);
      expect(wifi.recorder.view.hold, TripHold.background);
      await w.seconds(3);
      expect(rows(wifi), 6);
      wifi.recorder.setForeground(true);
      await w.seconds(1);
      expect(rows(wifi), 9, reason: 'continues on return');
      expect(wifi.background.calls, isEmpty, reason: 'iOS has no service');

      for (final kind in [TransportKind.ble, TransportKind.mock]) {
        final rig = RecorderRig(transport: kind);
        addTearDown(rig.dispose);
        final car = _Car.of(rig);
        expect(rig.recorder.view.caveat, isNull, reason: '$kind');
        await rig.recorder.start();
        expect(rig.link.recordingCalls, [true], reason: '$kind');
        expect(rig.recorder.view.caveat, isNull, reason: '$kind');
        rig.recorder.setForeground(false);
        expect(rig.recorder.view.hold, isNull, reason: '$kind');
        await car.seconds(3);
        expect(rows(rig), 9, reason: '$kind: bluetooth-central holds it');
        expect(rig.background.calls, isEmpty, reason: '$kind');
      }
    },
  );

  test('★ iOS Wi-Fi: away more than 10 minutes, the trip has ended at its '
      'last row', () async {
    // Nothing keeps Torque awake in the background over Wi-Fi, so iOS
    // suspends it and no tick runs there. The first thing the recorder hears
    // on return is the foreground itself — and one 10-minute limit holds for
    // every kind of pause (§9.2; the USER DECISIONS default).
    // Pro, so the free plan's 2:00 cannot end either trip first.
    final back = RecorderRig(transport: TransportKind.wifi, isPro: true);
    addTearDown(back.dispose);
    await back.recorder.start();
    await _Car.of(back).seconds(30);
    back.recorder.setForeground(false);
    back.clock.advance(const Duration(minutes: 9, seconds: 59));
    back.recorder.setForeground(true);
    await RecorderRig.settle();
    expect(back.recorder.view.phase, RecorderPhase.recording, reason: '9:59');
    expect(back.recorder.view.hold, isNull);

    final away = RecorderRig(transport: TransportKind.wifi, isPro: true);
    addTearDown(away.dispose);
    await away.recorder.start();
    await _Car.of(away).seconds(30);
    final lastRowAt = away.clock.nowUtc();
    away.recorder.setForeground(false);
    expect(away.recorder.view.hold, TripHold.background);
    away.clock.advance(const Duration(minutes: 11)); // suspended: no tick
    away.recorder.setForeground(true);
    await RecorderRig.settle();
    expect(away.recorder.view.phase, RecorderPhase.idle, reason: '11 min');
    final row = away.store.rows.values.single;
    expect(row.endReason, TripEnd.heldTooLong);
    expect(row.recordedMs, 30000, reason: 'at its last row');
    expect(row.endedAt, lastRowAt);
  });

  test('★ the background edge flushes', () async {
    // BLE on iOS may record in the background, so going there is no hold —
    // and a hold's own flush cannot stand in for the edge's.
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    await rig.recorder.start();
    await _Car.of(rig).seconds(2);
    final sink = rig.sink..log.clear();
    final before = sink.content.length;
    rig.clock.advance(const Duration(milliseconds: 300));
    rig.link.publish('010D', 40);
    rig.link.publish('015E', 3.1);

    rig.recorder.setForeground(false);
    await RecorderRig.settle(); // no tick
    expect(rig.recorder.view.hold, isNull);
    expect(sink.log, ['append', 'sync'], reason: 'iOS may suspend us next');
    expect(sink.content.substring(before), '2300,010D,40.0\n2300,015E,3.1\n');
  });

  test(
    '★ hard rule 3: a sample never notifies; the meter moves once a tick',
    () async {
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      await rig.recorder.start();
      var notified = 0;
      var readings = 0;
      rig.recorder.addListener(() => notified++);
      rig.recorder.reading.addListener(() => readings++);

      // 100 samples: ten a second, Speed climbing and Fuel rate moving.
      for (var s = 0; s < 10; s++) {
        for (var i = 0; i < 10; i++) {
          rig.clock.advance(const Duration(milliseconds: 100));
          final n = s * 10 + i;
          if (n.isEven) {
            rig.link.publish('010D', 30.0 + n);
          } else {
            rig.link.publish('015E', 2.5 + n / 100);
          }
        }
        await RecorderRig.settle();
        expect(readings, s, reason: 'no meter change from a sample');
        rig.recorder.debugTick();
        await RecorderRig.settle();
        expect(readings, s + 1, reason: 'one per tick');
      }
      expect(notified, 0);
      expect(_rowTimes(rig.sink.content), hasLength(100));
    },
  );

  test(
    '★ AC-15 shape: 30 minutes at 30 samples a second keeps nothing per sample',
    () async {
      // What a unit test can show: each tick hands the sink exactly that
      // second's rows, so the buffer is empty after every tick and nothing
      // is held back for later. It cannot see the heap: that TripStats keeps
      // running sums and never a series is by construction (trip_stats.dart),
      // and how much memory the app uses needs Instruments.
      final sink = _TallySink();
      final car = _Car.over(_TallyStore(sink), isPro: true);
      car.recorder.follow(RecorderRig.golf);
      await car.recorder.start();
      const minutes = 30;
      for (var s = 1; s <= minutes * 60; s++) {
        // 10 poll cycles of three PIDs.
        for (var c = 0; c < 10; c++) {
          car.clock.advance(const Duration(milliseconds: 100));
          car.link.publish('010C', 2000.0 + c * 10);
          car.link.publish('010D', 50.0 + c);
          car.link.publish('015E', 4.2);
        }
        car.recorder.debugTick();
        await Future<void>.delayed(Duration.zero);
        if (sink.lastRows != 30) {
          expect(sink.lastRows, 30, reason: 'tick $s handed over its second');
        }
      }
      expect(sink.rows, minutes * 60 * 30);
      expect(sink.appends, minutes * 60);
      // A second's rows at t = 1 800 000 are a little longer than at t = 1000.
      expect(sink.maxBytes, lessThan(1000));
      await car.recorder.stop();
      expect(sink.lastRows, 0, reason: 'the end found nothing left behind');
    },
  );

  test('★ Demo never records', () async {
    final rig = RecorderRig(platform: _android);
    addTearDown(rig.dispose);
    rig.recorder.follow(const OwnerDemo());
    expect(rig.recorder.refusal, RecordRefusal.demo);
    await rig.recorder.start();
    await RecorderRig.settle();
    expect(rig.store.starts, 0, reason: 'nothing filed under the Golf');
    expect(rig.store.rows, isEmpty);
    expect(rig.background.calls, isEmpty, reason: 'no service for a demo');
    expect(rig.link.recordingCalls, isEmpty);
    expect(rig.dashboard.recordingPids, isEmpty);
    expect(rig.link.bus.tap, isNull);
    expect(rig.recorder.view.phase, RecorderPhase.idle);
  });

  test("★ the saved figures are the strip's figures", () async {
    final rig = RecorderRig();
    addTearDown(rig.dispose);
    final car = _Car.of(rig);
    await rig.recorder.start();
    // Pulling away, 22 → 60 km/h, with one NO DATA for Speed on the way…
    for (var s = 1; s <= 20; s++) {
      rig.clock.advance(const Duration(milliseconds: 500));
      rig.link.publish('010D', s == 10 ? null : 20.0 + s * 2);
      rig.clock.advance(const Duration(milliseconds: 500));
      rig.link.publish('010D', 20.0 + s * 2);
      rig.link.publish('015E', 2 + s / 10);
      rig.recorder.debugTick();
      await RecorderRig.settle();
    }
    // …the link lost for 20 s, so the meter's average is over what it
    // heard, not over the clock…
    rig.link.set(SessionState.lost, reconnecting: true);
    await rig.tick(20);
    rig.link.set(SessionState.connected);
    // …then 72 km/h.
    await car.seconds(20, kph: 72);
    final meter = rig.recorder.reading.value!;

    await rig.recorder.stop();
    final row = rig.store.rows.values.single;
    final result = rig.recorder.view.result!;
    expect(row.endReason, TripEnd.stopped);
    expect(row.recordedMs, meter.elapsedMs);
    expect(result.recordedMs, meter.elapsedMs);
    expect(row.distanceKm, isNotNull);
    expect(row.distanceKm, meter.distanceKm);
    expect(result.distanceKm, meter.distanceKm);
    expect(row.avgSpeedKph, isNotNull);
    expect(row.avgSpeedKph, meter.avgSpeedKph);
    expect(result.avgSpeedKph, meter.avgSpeedKph);
    expect(row.fuelUsedL, isNotNull);
    expect(row.fuelUsedL, meter.fuelUsedL);
    expect(result.fuelUsedL, meter.fuelUsedL);
    // The strip shows no top speed; the row's is the file's.
    expect(row.maxSpeedKph, 72);
  });

  group('★ releaseVehicle — deleting a car', () {
    test('★ its trip is discarded, polling and the service stop, and '
        'nothing is said', () async {
      final rig = RecorderRig(platform: _android);
      addTearDown(rig.dispose);
      final car = _Car.of(rig);
      await rig.recorder.start();
      final id = rig.store.rows.keys.single;
      final sink = rig.sink;
      await car.seconds(3);
      final serial = rig.recorder.eventSerial;

      await rig.recorder.releaseVehicle('golf');
      expect(rig.store.discarded, [id]);
      expect(rig.store.rows, isEmpty);
      expect(rig.store.finishes, 0, reason: 'never finished into a row');
      expect(rig.recorder.view.phase, RecorderPhase.idle);
      expect(rig.link.recordingCalls.last, isFalse);
      expect(rig.dashboard.recordingPids, isEmpty);
      expect(rig.background.calls, contains('stopRecording'));
      expect(rig.recorder.view.result, isNull);
      expect(
        rig.recorder.eventSerial,
        serial,
        reason: 'the delete alert already said its trips go',
      );

      // Nothing more reaches the file the delete is about to remove.
      sink.log.clear();
      await car.seconds(5);
      expect(sink.log, isEmpty);
    });

    test("★ another car's delete leaves the trip recording", () async {
      final rig = RecorderRig(platform: _android);
      addTearDown(rig.dispose);
      final car = _Car.of(rig);
      await rig.recorder.start();
      await car.seconds(2);

      await rig.recorder.releaseVehicle('polo');
      expect(rig.store.discarded, isEmpty);
      expect(rig.recorder.view.phase, RecorderPhase.recording);
      expect(rig.link.recordingCalls.last, isTrue);
      expect(rig.dashboard.recordingPids, {'010D', '015E'});
      expect(rig.background.calls, isNot(contains('stopRecording')));
      await car.seconds(1);
      expect(_rowTimes(rig.sink.content), hasLength(9));
    });

    test("★ that car's offer and result go; another car's are kept", () async {
      // A result: the Golf's trip, stopped.
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      await rig.recorder.start();
      await _Car.of(rig).seconds(3);
      await rig.recorder.stop();
      expect(rig.recorder.view.result?.vehicleId, 'golf');
      await rig.recorder.releaseVehicle('polo');
      expect(rig.recorder.view.result, isNotNull);
      await rig.recorder.releaseVehicle('golf');
      expect(rig.recorder.view.result, isNull);

      // An offer: a Golf trip the app was killed during.
      final killed = RecorderRig();
      addTearDown(killed.dispose);
      await killed.recorder.start();
      final id = killed.store.rows.keys.single;
      await _Car.of(killed).seconds(3);
      killed.recorder.detach();
      final closed = killed.store.closeAsKilled(id, now: killed.clock.nowUtc());
      final again = _relaunch(
        killed,
        from: closed.endedAt!,
        gap: const Duration(minutes: 1),
      );
      again.recorder.follow(RecorderRig.golf);
      await RecorderRig.settle();
      expect(again.view.offer?.tripId, id);
      await again.recorder.releaseVehicle('polo');
      expect(again.view.offer?.tripId, id);
      await again.recorder.releaseVehicle('golf');
      expect(again.view.offer, isNull);
    });

    test('★ a delete waits for a start or an end in flight', () async {
      // The start: its row and file are still being made when the delete
      // comes; it is let finish, then discarded.
      final store = _GatedStore();
      final car = _Car.over(store, platform: _android);
      car.recorder.follow(RecorderRig.golf);
      final starting = car.recorder.start();
      await RecorderRig.settle();
      expect(car.view.phase, RecorderPhase.starting);
      final release = car.recorder.releaseVehicle('golf');
      await RecorderRig.settle();
      store.gate.complete();
      await starting;
      await release;
      expect(store.rows, isEmpty);
      expect(store.discarded, hasLength(1));
      expect(car.view.phase, RecorderPhase.idle);
      expect(car.link.recordingCalls.last, isFalse);
      expect(car.layouts.recordingPids, isEmpty);
      expect(car.background.calls.last, 'stopRecording');

      // The end: its result lands after the delete began, and is dropped.
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      await rig.recorder.start();
      await _Car.of(rig).seconds(3);
      final stopping = rig.recorder.stop();
      await rig.recorder.releaseVehicle('golf');
      await stopping;
      expect(
        rig.recorder.view.result,
        isNull,
        reason: 'no line for a car gone',
      );
    });
  });

  group('★ shutdown — Delete all data', () {
    test('★ it latches until unlatched', () async {
      final rig = RecorderRig();
      addTearDown(rig.dispose);
      final done = rig.recorder.shutdown();
      expect(rig.recorder.view.latched, isTrue);
      expect(rig.recorder.refusal, RecordRefusal.latched);
      await done;
      await rig.recorder.start();
      expect(rig.store.starts, 0, reason: 'no Record during an erase');

      // The erase failed: Record works again.
      rig.recorder.unlatch();
      expect(rig.recorder.view.latched, isFalse);
      expect(rig.recorder.refusal, isNull);
      await rig.recorder.start();
      expect(rig.recorder.view.phase, RecorderPhase.recording);
    });

    test('★ it discards the open trip; polling and the service stop', () async {
      final rig = RecorderRig(platform: _android);
      addTearDown(rig.dispose);
      final car = _Car.of(rig);
      await rig.recorder.start();
      final id = rig.store.rows.keys.single;
      final sink = rig.sink;
      await car.seconds(3);
      final serial = rig.recorder.eventSerial;

      await rig.recorder.shutdown();
      expect(rig.store.discarded, [id]);
      expect(rig.store.rows, isEmpty);
      expect(rig.store.finishes, 0);
      expect(rig.recorder.view.phase, RecorderPhase.idle);
      expect(rig.recorder.view.result, isNull);
      expect(rig.recorder.eventSerial, serial);
      expect(rig.link.recordingCalls.last, isFalse);
      expect(rig.dashboard.recordingPids, isEmpty);
      expect(rig.background.calls, contains('stopRecording'));
      sink.log.clear();
      await car.seconds(5);
      expect(sink.log, isEmpty, reason: 'no write after the wipe');
    });

    test('★ it waits for a start in flight, which never begins', () async {
      final store = _GatedStore();
      final car = _Car.over(store, platform: _android);
      car.recorder.follow(RecorderRig.golf);
      unawaited(car.recorder.start());
      await RecorderRig.settle();
      expect(car.view.phase, RecorderPhase.starting);

      var done = false;
      final shutdown = car.recorder.shutdown().then((_) => done = true);
      await RecorderRig.settle();
      expect(done, isFalse, reason: 'the row and file are still being made');
      store.gate.complete();
      await shutdown;
      expect(store.starts, 1);
      expect(store.rows, isEmpty, reason: 'discarded before the wipe runs');
      expect(store.discarded, hasLength(1));
      expect(car.view.phase, RecorderPhase.idle);
      expect(car.recorder.eventSerial, 0, reason: 'it never started');
      expect(car.link.recordingCalls, isEmpty);
      expect(car.layouts.recordingPids, isEmpty);
      expect(car.background.calls, isNot(contains('startRecording')));
    });
  });
}
