import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/repositories/vehicle_repository.dart';
import 'package:torque_obd2/features/live_tabs.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/models/enums.dart';
import 'package:torque_obd2/platform/screen_wake.dart';
import 'package:torque_obd2/session/obd_session.dart';
import 'package:torque_obd2/transport/mock_transport.dart';
import 'package:torque_obd2/transport/obd_trace.dart';

import '../data/support.dart' show memoryDb;
import 'trips/support.dart';

/// Hard rule 9, AC-11, §9.7 and §5.3's "keep awake while foreground", in
/// the running app: `LiveSession` owns the app-lifecycle listener, because
/// the screens that once did may not be built. Before slice 17 nothing
/// called `setBackgrounded` at all, so a phone in a pocket polled the car at
/// 10 Hz until the battery or iOS gave out.
///
/// The lifecycle arrives the way the engine sends it — 'flutter/lifecycle'
/// platform messages — so the framework synthesises the states in between
/// (resumed → inactive → hidden → paused) exactly as it does on a phone.
/// Each test starts from 'resumed', and the tearDown puts it back: the
/// binding's lifecycle state outlives a test.
void main() {
  const civicVin = '1HGBH41JXMN109186';
  const wakeChannel = MethodChannel('ktc.torque/screen');

  late final Map<String, ObdTrace> traces;
  setUpAll(() {
    traces = {
      for (final name in const ['clean_can', 'trip_drive_can'])
        name: ObdTrace.parse(
          File('assets/traces/$name.obdtrace').readAsStringSync(),
        ),
    };
  });

  Future<void> lifecycle(AppLifecycleState state) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/lifecycle',
            const StringCodec().encodeMessage(state.toString()),
            (_) {},
          );

  tearDown(() => lifecycle(AppLifecycleState.resumed));

  /// A PID asked of the car, as opposed to an AT command or a VIN read.
  bool isPoll(String command) =>
      command.length == 4 && command.startsWith('01');

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

  /// Nothing may outlive the body: the poll loop, the clock's ticker and
  /// the replayed car's reply timer all run on the fake clock.
  Future<void> quiesce(WidgetTester tester, LiveSession live) async {
    unawaited(live.session.disconnect());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Every `setKeepAwake` argument the platform would have received.
  List<Object?> wakeHeard(WidgetTester tester) {
    final calls = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(wakeChannel, (call) async {
      // Heard inside a pump, where `expect` may not run: anything but the
      // one method goes into the list by name, and fails the comparison.
      calls.add(call.method == 'setKeepAwake' ? call.arguments : call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(wakeChannel, null));
    return calls;
  }

  /// A LiveSession polling [car], with no garage and so no recorder.
  Future<LiveSession> liveOn(
    WidgetTester tester,
    _TimedCar car, {
    ScreenWake? wake,
  }) async {
    await lifecycle(AppLifecycleState.resumed);
    final live = LiveSession(
      session: ObdSession(timeScale: 0.05),
      screenWake: wake,
    );
    addTearDown(live.dispose);
    unawaited(live.session.connect(car));
    await pumpUntil(
      tester,
      () => car.written.where(isPoll).length > 20,
      reason: 'the gauges being asked',
    );
    return live;
  }

  /// A LiveSession on an iPhone, recording the Civic over [car]: the garage
  /// read, the VIN judged to be the primary's, Record tapped. The store and
  /// the service are fakes, so nothing touches a file under the fake clock.
  /// The caller disposes it.
  Future<LiveSession> recordingOn(
    WidgetTester tester,
    _TimedCar car, {
    required FakeTripStore store,
    ScreenWake? wake,
  }) async {
    await lifecycle(AppLifecycleState.resumed);
    final db = memoryDb();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    final vehicles = VehicleRepository(db);
    await vehicles.create(
      nickname: 'The Civic',
      fuel: VehicleFuel.petrol,
      vin: civicVin,
    );
    final live = LiveSession(
      session: ObdSession(timeScale: 0.05),
      vehicles: vehicles,
      screenWake: wake,
      platform: const FakePlatform(isAndroid: false),
      background: FakeBackgroundService(),
      tripStore: store,
      tripClock: ManualTripClock(),
    );
    final recorder = live.recorder!;
    await pumpUntil(tester, () => live.garage!.loaded, reason: 'the garage');
    unawaited(live.session.connect(car));
    // Nothing is recorded until the car on the wire is judged (§9.6).
    await pumpUntil(
      tester,
      () => recorder.refusal == null,
      reason: 'the Civic, live and settled',
    );
    unawaited(recorder.start());
    await pumpUntil(
      tester,
      () => recorder.view.phase == RecorderPhase.recording,
      reason: 'Record',
    );
    return live;
  }

  testWidgets('★ AC-11: backgrounded with nothing recording, the car is not '
      'asked', (tester) async {
    // Nothing called setBackgrounded before LiveSession listened: the loop
    // ran on in the pocket.
    final car = _TimedCar(traces['clean_can']!, tester.binding.clock.now);
    final live = await liveOn(tester, car);

    await lifecycle(AppLifecycleState.paused);
    // The command in flight was written before the message arrived; its
    // reply lands and the loop stops there.
    final inFlight = car.written.length;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      car.written.skip(inFlight),
      isEmpty,
      reason: 'five fake seconds in the background, nothing recording',
    );
    expect(live.session.backgrounded, isTrue);
    expect(
      live.session.state,
      SessionState.connected,
      reason: 'the link is kept, only not asked',
    );

    await lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      car.written.skip(inFlight).where(isPoll),
      isNotEmpty,
      reason: 'back in front, the gauges are asked again',
    );
    await quiesce(tester, live);
  });

  testWidgets('★ §9.7: hidden is the background; inactive is still on '
      'screen', (tester) async {
    final car = _TimedCar(traces['clean_can']!, tester.binding.clock.now);
    final live = await liveOn(tester, car);

    // Control Center, a phone call, the permission sheet, split screen: the
    // gauges are still in view and must stay live.
    await lifecycle(AppLifecycleState.inactive);
    final atInactive = car.written.length;
    await tester.pump(const Duration(seconds: 1));
    expect(
      car.written.skip(atInactive).where(isPoll).length,
      greaterThan(20),
      reason: 'inactive keeps polling',
    );
    expect(live.session.backgrounded, isFalse);

    // Hidden, and no further: a minimised desktop window stops here, and on
    // a phone it comes before paused. §9.7: hidden is treated as paused.
    await lifecycle(AppLifecycleState.hidden);
    final atHidden = car.written.length;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      car.written.skip(atHidden),
      isEmpty,
      reason: 'hidden, nothing recording: not one command',
    );

    await lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(car.written.skip(atHidden).where(isPoll), isNotEmpty);
    await quiesce(tester, live);
  });

  testWidgets('★ §5.3: the screen is held awake only while Torque is in '
      'front', (tester) async {
    // "Keep awake while foreground and connected". Without the foreground
    // term a phone put in a pocket mid-drive kept its screen lit.
    final heard = wakeHeard(tester);
    final car = _TimedCar(traces['clean_can']!, tester.binding.clock.now);
    final live = await liveOn(
      tester,
      car,
      wake: ScreenWake(channel: wakeChannel),
    );
    await tester.pump();
    expect(heard, [true], reason: 'live, in front');

    // resumed → inactive → hidden → paused: four states, one change.
    await lifecycle(AppLifecycleState.paused);
    await tester.pump();
    expect(live.session.isLive, isTrue, reason: 'still connected');
    expect(heard, [true, false], reason: 'let go once, in the background');

    await lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(heard, [true, false, true], reason: 'held again, once, in front');
    await quiesce(tester, live);
  });

  testWidgets('★ a background recording polls only its PIDs at one cycle '
      'per 2 s', (tester) async {
    // §5.3 "iOS bluetooth-central at 0.5 Hz for active recordings only";
    // §9.3 "10 Hz in background gets the app killed"; §4.5 restated: in
    // the background only what the recording needs. The foreground's
    // tiles at the foreground's rate is the bug this guards.
    final car = _TimedCar(traces['trip_drive_can']!, tester.binding.clock.now);
    final store = FakeTripStore();
    final live = await recordingOn(tester, car, store: store);
    addTearDown(live.dispose);
    final window =
        PlatformInfo.iosBackgroundPollInterval * live.session.timeScale;

    await lifecycle(AppLifecycleState.paused);
    expect(live.session.backgrounded, isTrue);
    // The cycle in flight finishes as it began, at the foreground's rate;
    // from the next one on, the background rules.
    await tester.pump(window * 2.5);
    final from = car.written.length;
    const span = Duration(seconds: 4);
    await tester.pump(span);

    final asked = [
      for (var i = from; i < car.written.length; i++)
        if (isPoll(car.written[i])) (pid: car.written[i], at: car.at[i]),
    ];
    // Speed is the one critical PID left, and criticals go first: every
    // cycle starts with it.
    final starts = [
      for (final a in asked)
        if (a.pid == '010D') a.at,
    ];
    final windows = span.inMilliseconds ~/ window.inMilliseconds;
    // Hard rule 9 cuts both ways: with a trip recording, the car is still
    // asked — a stopped loop would pass every check below.
    expect(
      starts.length,
      greaterThanOrEqualTo(windows - 8),
      reason: 'a recording is still asked in the background',
    );
    expect(
      {for (final a in asked) a.pid},
      {'010D', '015E'},
      reason: 'Speed and Fuel rate, and no tile',
    );
    final gaps = [
      for (var i = 1; i < starts.length; i++)
        starts[i].difference(starts[i - 1]).inMilliseconds,
    ];
    // The loop times its budget on the wall clock while this test runs on
    // a fake one: a tenth of the window is allowed for that, and nothing
    // near the foreground's 5 ms.
    expect(
      gaps.where((ms) => ms < window.inMilliseconds * 0.9),
      isEmpty,
      reason: 'at most one cycle per ${window.inMilliseconds} ms window',
    );
    expect(starts.length, lessThanOrEqualTo(windows + 1));
    expect(live.session.recording, isTrue);
    expect(live.session.state, SessionState.connected, reason: 'no Weak link');
    expect(live.recorder!.view.hold, isNull, reason: 'recording, not paused');

    await lifecycle(AppLifecycleState.resumed);
    final back = car.written.length;
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      car.written.skip(back).where(isPoll),
      contains('010C'),
      reason: 'back in front, the tiles are asked again',
    );

    unawaited(live.recorder!.stop());
    await quiesce(tester, live);
  });

  testWidgets('★ the listener is disposed first', (tester) async {
    // A lifecycle message after the owner is gone must reach nothing. The
    // session guards its own setBackgrounded after dispose, and that is
    // tested in obd_session_test; this is the listener, which also reaches
    // the recorder — detached, but still holding its trip's file — and the
    // screen-wake channel, neither of which has a disposed guard of its own.
    // Kept apart from the session's guard: with the two in one test, either
    // fix alone would hide the other's absence. Dispose is synchronous, so
    // first or last cannot be told apart from here; that it is disposed at
    // all is what this sees.
    final heard = wakeHeard(tester);
    final car = _TimedCar(traces['trip_drive_can']!, tester.binding.clock.now);
    final store = FakeTripStore();
    final live = await recordingOn(
      tester,
      car,
      store: store,
      wake: ScreenWake(channel: wakeChannel),
    );
    var disposed = false;
    addTearDown(() {
      if (!disposed) live.dispose();
    });
    await tester.pump();
    expect(heard, [true]);
    final file = store.sinks.values.single;

    live.dispose();
    disposed = true;
    expect(heard, [true, false], reason: 'dispose lets the screen go');
    final writes = car.written.length;
    final fileOps = file.log.length;

    // To the background and back, after the owner is gone.
    await lifecycle(AppLifecycleState.paused);
    await lifecycle(AppLifecycleState.resumed);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    expect(
      file.log.skip(fileOps),
      isEmpty,
      reason: 'a detached recorder writes nothing to its file',
    );
    expect(car.written.skip(writes), isEmpty, reason: 'nothing is polled');
    expect(heard, [
      true,
      false,
    ], reason: 'the screen is never held again for a session that is gone');
  });
}

/// A replayed car that notes when each command reached it, on the test's
/// fake clock: the rate a backgrounded recording is asked at is the point.
class _TimedCar extends MockTransport {
  _TimedCar(super.trace, this._now) : super(speed: 100);

  final DateTime Function() _now;

  /// When each of [written] arrived, index for index.
  final at = <DateTime>[];

  @override
  Future<void> write(List<int> bytes) {
    final before = written.length;
    final done = super.write(bytes);
    if (written.length > before) at.add(_now());
    return done;
  }
}
