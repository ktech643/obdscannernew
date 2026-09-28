import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:torque_obd2/core/platform/platform_info.dart';
import 'package:torque_obd2/data/db/app_database.dart';
import 'package:torque_obd2/data/ids.dart';
import 'package:torque_obd2/data/trips/trip_csv.dart';
import 'package:torque_obd2/data/trips/trip_sink.dart';
import 'package:torque_obd2/domain/pid_sample.dart';
import 'package:torque_obd2/features/dashboard/layout_controller.dart';
import 'package:torque_obd2/features/trips/trip_clock.dart';
import 'package:torque_obd2/features/trips/trip_link.dart';
import 'package:torque_obd2/features/trips/trip_plan.dart';
import 'package:torque_obd2/features/trips/trip_recorder.dart';
import 'package:torque_obd2/features/trips/trip_store.dart';
import 'package:torque_obd2/platform/background_service.dart';
import 'package:torque_obd2/platform/battery_optimizer.dart';
import 'package:torque_obd2/session/obd_session.dart' show SessionState;
import 'package:torque_obd2/transport/obd_transport.dart' show TransportKind;

/// Fakes for the trip recorder: every one keeps its state in memory and
/// every future it returns is made in the caller's zone, so the recorder
/// runs deterministically in a plain `test()` and under `testWidgets`'
/// fake clock alike. Nothing here touches a file.

/// Time moves only when a test says so.
class ManualTripClock implements TripClock {
  ManualTripClock({DateTime? start})
    : utc = start ?? DateTime.utc(2026, 9, 28, 12);

  int ms = 0;
  DateTime utc;

  /// Both clocks move together — as they do, unless [stepWall] says the
  /// wall clock jumped.
  void advance(Duration d) {
    ms += d.inMilliseconds;
    utc = utc.add(d);
  }

  /// A manual clock change or DST: only the wall moves.
  void stepWall(Duration d) => utc = utc.add(d);

  @override
  int elapsedMs() => ms;

  @override
  DateTime nowUtc() => utc;
}

/// A link a test can put in any state the session has.
class FakeTripLink extends ChangeNotifier implements TripLink {
  FakeTripLink({
    this.state = SessionState.connected,
    Set<String>? supported,
    this.transportKind = TransportKind.ble,
  }) : supportedPids = supported ?? {'010C', '010D', '0105', '015E'};

  @override
  SessionState state;

  @override
  bool reconnecting = false;

  @override
  String? lastError;

  @override
  Set<String> supportedPids;

  @override
  TransportKind? transportKind;

  @override
  final PidBus bus = PidBus();

  /// Every setRecording call, in order.
  final recordingCalls = <bool>[];

  @override
  void setRecording(bool value) => recordingCalls.add(value);

  /// Changes the link and notifies once, as the session does.
  void set(SessionState s, {bool reconnecting = false, String? error}) {
    state = s;
    this.reconnecting = reconnecting;
    lastError = error;
    notifyListeners();
  }

  void publish(String pid, double? value) => bus.publish(
    PidSample(pid: pid, value: value, at: DateTime.utc(2026, 9, 28)),
  );
}

/// A sink in memory. [failNext] makes the next append throw, the way the
/// real sink does once it has rolled back to its last whole line.
class MemoryTripSink implements TripSink {
  MemoryTripSink([String initial = '']) : _content = initial;

  String _content;
  bool closed = false;
  TripWriteFailure? failNext;

  /// 'append', 'sync' and 'close', in order.
  final log = <String>[];

  String get content => _content;

  @override
  int get committed => _content.length;

  @override
  Future<void> append(String ascii) async {
    log.add('append');
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    _content += ascii;
  }

  @override
  Future<void> sync() async => log.add('sync');

  @override
  Future<void> close() async {
    log.add('close');
    closed = true;
  }

  /// A relaunch: what is past the last whole line is gone.
  void truncateTo(int length) => _content = _content.substring(0, length);
}

/// The store, in memory: rows and their files' contents, summarised with
/// the real reader — so the figures a test sees saved are the ones the
/// file can prove, exactly as with [DbTripStore].
class FakeTripStore implements TripStore {
  final rows = <String, TripSessionRow>{};
  final sinks = <String, MemoryTripSink>{};
  final discarded = <String>[];
  int starts = 0;
  int finishes = 0;
  int retentions = 0;

  /// Thrown by the next start.
  Object? failStart;

  /// Thrown by the next finish.
  Object? failFinish;

  TripFileSummary summaryOf(String id, {required DateTime now}) =>
      TripCsv.summarize(
        sinks[id]!.content,
        startedAtMs: rows[id]!.startedAt.millisecondsSinceEpoch,
        nowMs: now.millisecondsSinceEpoch,
      );

  @override
  Future<OpenTrip> start({
    required String vehicleId,
    required DateTime startedAt,
  }) async {
    starts++;
    final f = failStart;
    if (f != null) {
      failStart = null;
      throw f;
    }
    // As DbTripStore: one open trip at a time, and a row left open by a
    // failed save is closed from its file before the next one starts.
    for (final open in [
      for (final r in rows.values)
        if (r.endedAt == null) r.id,
    ]) {
      closeAsKilled(open, now: startedAt);
    }
    final id = newId();
    rows[id] = TripSessionRow(
      id: id,
      vehicleId: vehicleId,
      startedAt: startedAt,
      lastOpenedAt: startedAt,
      sampleCount: 0,
      samplesFilePath: 'trips/$id.csv',
      fileBytes: TripCsv.header.length,
      interrupted: false,
    );
    final sink = sinks[id] = MemoryTripSink(TripCsv.header);
    return OpenTrip(
      id: id,
      vehicleId: vehicleId,
      startedAt: startedAt,
      sink: sink,
    );
  }

  @override
  Future<TripSessionRow?> finish(
    OpenTrip trip,
    TripEnd end, {
    required DateTime now,
  }) async {
    finishes++;
    final f = failFinish;
    if (f != null) {
      failFinish = null;
      throw f;
    }
    final row = rows[trip.id];
    if (row == null) return null;
    final s = summaryOf(trip.id, now: now);
    return rows[trip.id] = row.copyWith(
      endedAt: Value(s.endedAtUtc),
      distanceKm: Value(s.totals.distanceKm),
      avgSpeedKph: Value(s.totals.avgSpeedKph),
      maxSpeedKph: Value(s.totals.maxSpeedKph),
      fuelUsedL: Value(s.totals.fuelUsedL),
      recordedMs: Value(s.endT),
      sampleCount: s.rows,
      fileBytes: sinks[trip.id]!.content.length,
      interrupted: end.interrupted,
      endReason: Value(end),
    );
  }

  @override
  Future<void> discard(OpenTrip trip) async {
    discarded.add(trip.id);
    rows.remove(trip.id);
    sinks.remove(trip.id);
  }

  /// Closes an open row from its file, as the launch pass does after a
  /// kill: at its last durable sample, appKilled.
  TripSessionRow closeAsKilled(String id, {required DateTime now}) {
    final s = summaryOf(id, now: now);
    sinks[id]!.truncateTo(s.committedBytes);
    return rows[id] = rows[id]!.copyWith(
      endedAt: Value(s.endedAtUtc),
      distanceKm: Value(s.totals.distanceKm),
      recordedMs: Value(s.endT),
      sampleCount: s.rows,
      interrupted: true,
      endReason: Value(s.end ?? TripEnd.appKilled),
    );
  }

  @override
  Future<TripSessionRow?> resumable(
    String vehicleId, {
    required DateTime now,
  }) async {
    final mine = [
      for (final r in rows.values)
        if (r.vehicleId == vehicleId) r,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (mine.isEmpty) return null;
    final r = mine.first;
    final end = r.endedAt;
    if (end == null || !(r.endReason?.resumable ?? false)) return null;
    final age = now.difference(end);
    if (age.isNegative || age > TripPlan.resumeWithin) return null;
    return sinks.containsKey(r.id) ? r : null;
  }

  @override
  Future<OpenTrip?> resume(String tripId, {required DateTime now}) async {
    final row = rows[tripId];
    if (row == null) return null;
    final s = summaryOf(tripId, now: now);
    rows[tripId] = row.copyWith(
      endedAt: const Value(null),
      interrupted: false,
      endReason: const Value(null),
      lastOpenedAt: now,
    );
    final sink = sinks[tripId]!..truncateTo(s.committedBytes);
    return OpenTrip(
      id: tripId,
      vehicleId: row.vehicleId,
      startedAt: row.startedAt,
      sink: sink,
      baseT: s.endT,
      seed: s.totals,
    );
  }

  @override
  Future<void> retention() async => retentions++;
}

/// The Android service, answered from fields. `calls` records every
/// method in order.
class FakeBackgroundService implements BackgroundService {
  bool running = false;
  bool notifications = true;
  bool startOk = true;
  final calls = <String>[];

  /// Holds startRecording until completed — the platform round trip in
  /// which a trip can end.
  Completer<void>? startGate;

  @override
  Future<bool> startRecording() async {
    calls.add('startRecording');
    final gate = startGate;
    if (gate != null) await gate.future;
    if (startOk) running = true;
    return startOk;
  }

  @override
  Future<void> stopRecording() async {
    calls.add('stopRecording');
    running = false;
  }

  @override
  Future<bool> isRunning() async {
    calls.add('isRunning');
    return running;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    calls.add('hasNotificationPermission');
    return notifications;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('requestNotificationPermission');
    return notifications;
  }

  @override
  Future<BatteryOptimization?> batteryOptimization() async => null;

  @override
  Future<bool> openBatterySettings() async => false;
}

/// A recorder over fakes, ready to record the Golf: live, settled, free
/// plan, no timer (tests tick by hand), on [platform] (iOS by default).
class RecorderRig {
  RecorderRig({
    PlatformInfo platform = const FakePlatform(isAndroid: false),
    Set<String>? supported,
    TransportKind transport = TransportKind.ble,
    bool isPro = false,
    Future<void>? launch,
  }) : link = FakeTripLink(supported: supported, transportKind: transport),
       clock = ManualTripClock(),
       store = FakeTripStore(),
       background = FakeBackgroundService(),
       published = [] {
    dashboard = DashboardLayoutController(publish: published.add);
    recorder = TripRecorder(
      link: link,
      store: store,
      dashboard: dashboard,
      background: background,
      platform: platform,
      launch: launch,
      clock: clock,
      tickEvery: null,
    )..isPro = isPro;
    recorder.follow(golf);
  }

  static const golf = OwnerVehicle('golf', 'Golf');

  final FakeTripLink link;
  final ManualTripClock clock;
  final FakeTripStore store;
  final FakeBackgroundService background;
  final List<Set<String>> published;
  late final DashboardLayoutController dashboard;
  late final TripRecorder recorder;

  /// Lets every queued microtask and zero-delay future run.
  static Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// [n] ticks, each after a second of both clocks.
  Future<void> tick([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      clock.advance(const Duration(seconds: 1));
      recorder.debugTick();
      await settle();
    }
  }

  /// The one open trip's file, or the only one there is.
  MemoryTripSink get sink => store.sinks.values.single;

  void dispose() {
    recorder.dispose();
    dashboard.dispose();
    link.dispose();
  }
}
