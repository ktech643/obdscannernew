import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:flutter/foundation.dart';

import '../../core/platform/platform_info.dart';
import '../../data/db/app_database.dart' show TripSessionRow;
import '../../data/db/tables.dart' show TripEnd;
import '../../data/trips/trip_csv.dart';
import '../../data/trips/trip_sink.dart';
import '../../data/trips/trip_stats.dart';
import '../../design_system/design_system.dart' show AdaptiveHaptics;
import '../../domain/pid_sample.dart';
import '../../platform/background_service.dart';
import '../../session/obd_session.dart' show SessionState;
import '../../transport/obd_transport.dart' show TransportKind;
import '../dashboard/layout_controller.dart';
import 'trip_clock.dart';
import 'trip_link.dart';
import 'trip_plan.dart';
import 'trip_store.dart';

enum RecorderPhase { idle, starting, recording, ending }

/// Why a recording is waiting rather than writing. Every kind shares the
/// one [TripPlan.maxHold] limit.
enum TripHold { link, ignitionOff, identity, background }

/// Something true about this phone or link that changes what a recording
/// can do, said before and during it.
enum TripCaveat { wifiInBackground, notificationsOff, serviceRefused }

/// Why Record is not offered. The strip says the reason as a statement;
/// there is never a dimmed button (§B.26).
enum RecordRefusal {
  notLaunched,
  latched,
  busy,
  loading,
  demo,
  noVehicle,
  checkingIdentity,
  notLive,
}

/// Whose trip a recording would be — pushed by `LiveSession` from the
/// garage, the identity verdict and Demo Mode.
sealed class TripOwner {
  const TripOwner();
}

class OwnerLoading extends TripOwner {
  const OwnerLoading();
}

class OwnerNone extends TripOwner {
  const OwnerNone();
}

class OwnerDemo extends TripOwner {
  const OwnerDemo();
}

/// A primary exists, but the car on the wire has not been judged against
/// it yet — the VIN is being read, or a §9.6 question is open.
class OwnerPending extends TripOwner {
  const OwnerPending(this.vehicleId);
  final String vehicleId;

  @override
  bool operator ==(Object other) =>
      other is OwnerPending && other.vehicleId == vehicleId;

  @override
  int get hashCode => vehicleId.hashCode;
}

class OwnerVehicle extends TripOwner {
  const OwnerVehicle(this.vehicleId, this.nickname);
  final String vehicleId;
  final String nickname;

  @override
  bool operator ==(Object other) =>
      other is OwnerVehicle &&
      other.vehicleId == vehicleId &&
      other.nickname == nickname;

  @override
  int get hashCode => Object.hash(vehicleId, nickname);
}

/// The live meter, once a second.
@immutable
class TripReading {
  const TripReading({
    required this.elapsedMs,
    required this.capMs,
    required this.distanceKm,
    required this.avgSpeedKph,
    required this.fuelUsedL,
    required this.speedReported,
  });

  final int elapsedMs;

  /// The free plan's limit while it applies to this trip; null on Pro.
  final int? capMs;
  final double? distanceKm;
  final double? avgSpeedKph;
  final double? fuelUsedL;
  final bool speedReported;

  @override
  bool operator ==(Object other) =>
      other is TripReading &&
      other.elapsedMs == elapsedMs &&
      other.capMs == capMs &&
      other.distanceKm == distanceKm &&
      other.avgSpeedKph == avgSpeedKph &&
      other.fuelUsedL == fuelUsedL &&
      other.speedReported == speedReported;

  @override
  int get hashCode => Object.hash(
    elapsedMs,
    capMs,
    distanceKm,
    avgSpeedKph,
    fuelUsedL,
    speedReported,
  );
}

enum TripResultKind {
  saved,
  startFailed,
  resumeFailed,

  /// The offered trip was no longer there to resume.
  resumeGone,

  /// Stopped before a single reading: nothing kept, no trip saved — as the
  /// launch pass does with an empty file.
  nothingRecorded,
  summaryPending,
}

/// How the last recording went, kept until the next one.
@immutable
class TripResult {
  const TripResult({
    required this.kind,
    required this.vehicleId,
    this.end,
    this.nickname,
    this.savedUpTo,
    this.recordedMs,
    this.distanceKm,
    this.avgSpeedKph,
    this.fuelUsedL,
    this.outOfSpace = false,
  });

  final TripResultKind kind;

  /// The car the trip belongs to.
  final String vehicleId;
  final TripEnd? end;

  /// The trip's car, for "saved under …" when another car answered.
  final String? nickname;

  /// The last moment on disk, for a trip that stopped early.
  final DateTime? savedUpTo;
  final int? recordedMs;
  final double? distanceKm;
  final double? avgSpeedKph;
  final double? fuelUsedL;
  final bool outOfSpace;
}

/// §9.2 "Resume trip?" — this car's newest trip, cut short by the app
/// closing or the link going.
@immutable
class ResumeOffer {
  const ResumeOffer({
    required this.tripId,
    required this.vehicleId,
    required this.end,
    required this.endedAt,
    this.recordedMs,
    this.distanceKm,
  });

  factory ResumeOffer.of(TripSessionRow r) => ResumeOffer(
    tripId: r.id,
    vehicleId: r.vehicleId,
    end: r.endReason ?? TripEnd.appKilled,
    endedAt: r.endedAt ?? r.startedAt,
    recordedMs: r.recordedMs,
    distanceKm: r.distanceKm,
  );

  final String tripId;
  final String vehicleId;
  final TripEnd end;
  final DateTime endedAt;
  final int? recordedMs;
  final double? distanceKm;
}

enum TripEventKind {
  started,
  resumed,
  paused,
  continued,
  ended,
  startFailed,
  resumeFailed,
}

/// One thing to say once, never per sample or per tick.
@immutable
class TripEvent {
  const TripEvent(this.kind, {this.hold, this.result});
  final TripEventKind kind;
  final TripHold? hold;
  final TripResult? result;
}

/// Everything the strip draws, except the meter — which changes once a
/// second and goes out on [TripRecorder.reading] instead.
@immutable
class TripView {
  const TripView({
    required this.launched,
    required this.latched,
    required this.phase,
    required this.hold,
    required this.owner,
    required this.live,
    required this.caveat,
    required this.result,
    required this.offer,
    required this.isPro,
    required this.speedMissing,
    required this.tripVehicleId,
  });

  final bool launched;
  final bool latched;
  final RecorderPhase phase;
  final TripHold? hold;
  final TripOwner owner;

  /// Connected or degraded.
  final bool live;
  final TripCaveat? caveat;
  final TripResult? result;

  /// Only when it can be taken now: the right car, live, on a plan that
  /// has time left for it.
  final ResumeOffer? offer;
  final bool isPro;

  /// The recording's car reports no Speed, so there is no distance.
  final bool speedMissing;

  /// The car of the trip being recorded.
  final String? tripVehicleId;

  bool get open =>
      phase == RecorderPhase.recording || phase == RecorderPhase.ending;

  @override
  bool operator ==(Object other) =>
      other is TripView &&
      other.launched == launched &&
      other.latched == latched &&
      other.phase == phase &&
      other.hold == hold &&
      other.owner == owner &&
      other.live == live &&
      other.caveat == caveat &&
      identical(other.result, result) &&
      identical(other.offer, offer) &&
      other.isPro == isPro &&
      other.speedMissing == speedMissing &&
      other.tripVehicleId == tripVehicleId;

  @override
  int get hashCode => Object.hash(
    launched,
    latched,
    phase,
    hold,
    owner,
    live,
    caveat,
    result,
    offer,
    isPro,
    speedMissing,
    tripVehicleId,
  );
}

/// SPEC §5.3 "Record" — one trip at a time, written to its CSV as it
/// happens.
///
/// Owned by `LiveSession`, next to the layout controller. It hears every
/// sample the session publishes through one synchronous `PidBus.tap`, and
/// writes nothing from inside it: rows go to a buffer that a 1 s tick
/// appends and every fifth tick fsyncs (AC-09: a kill loses about a
/// second). It notifies only when [view] changes — never per sample — and
/// the meter goes out once a second on [reading] (hard rule 3).
///
/// Every way a trip ends goes through [_end], which stops background
/// polling and the Android service before any summary work, so no path can
/// leave the car being polled with the app in the background (hard rule 9).
class TripRecorder extends ChangeNotifier {
  TripRecorder({
    required this._link,
    required this._store,
    required this._dashboard,
    required this._background,
    required this._platform,
    Future<void>? launch,
    TripClock? clock,
    this._tickEvery = const Duration(seconds: 1),
  }) : _clock = clock ?? SystemTripClock() {
    _wasLive = _isLive;
    _link.addListener(_onLink);
    if (launch == null) {
      _launched = true;
    } else {
      _launching = launch
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() {
            if (_detached) return;
            _launched = true;
            _launching = null;
            unawaited(_readNotifications());
            _recompute();
          });
    }
    _view = _viewNow();
  }

  final TripLink _link;
  final TripStore _store;
  final DashboardLayoutController _dashboard;
  final BackgroundService _background;
  final PlatformInfo _platform;
  final TripClock _clock;
  final Duration? _tickEvery;

  // ------------------------------------------------------------- the view

  late TripView _view;
  TripView get view => _view;

  final reading = ValueNotifier<TripReading?>(null);

  int _eventSerial = 0;
  TripEvent? _lastEvent;
  int get eventSerial => _eventSerial;
  TripEvent? get lastEvent => _lastEvent;

  bool _launched = false;
  Future<void>? _launching;

  /// Completes once the launch pass has closed what a previous run left
  /// open. With nothing to wait for, a future of the caller's own zone.
  Future<void> get launched => _launching ?? Future.value();

  bool _latched = false;
  bool _detached = false;
  RecorderPhase _phase = RecorderPhase.idle;
  TripOwner _owner = const OwnerLoading();
  bool _isPro = false;
  bool _foreground = true;
  TripHold? _hold;
  int _holdSinceMs = 0;
  TripCaveat? _caveat;
  TripResult? _result;
  ResumeOffer? _offer;
  final _declined = <String>{};

  bool get _isLive =>
      _link.state == SessionState.connected ||
      _link.state == SessionState.degraded;

  RecordRefusal? get refusal {
    if (!_launched) return RecordRefusal.notLaunched;
    if (_latched) return RecordRefusal.latched;
    if (_phase != RecorderPhase.idle) return RecordRefusal.busy;
    switch (_owner) {
      case OwnerLoading():
        return RecordRefusal.loading;
      case OwnerDemo():
        return RecordRefusal.demo;
      case OwnerNone():
        return RecordRefusal.noVehicle;
      case OwnerPending():
        return RecordRefusal.checkingIdentity;
      case OwnerVehicle():
        break;
    }
    if (!_isLive) return RecordRefusal.notLive;
    return null;
  }

  TripView _viewNow() {
    final offer = _offer;
    final o = _owner;
    final showOffer =
        offer != null &&
        _phase == RecorderPhase.idle &&
        !_latched &&
        _isLive &&
        o is OwnerVehicle &&
        o.vehicleId == offer.vehicleId &&
        !_declined.contains(offer.tripId) &&
        _fresh(offer) &&
        TripPlan.canResume(offer.recordedMs, isPro: _isPro);
    return TripView(
      launched: _launched,
      latched: _latched,
      phase: _phase,
      hold: _hold,
      owner: _owner,
      live: _isLive,
      caveat: _phase == RecorderPhase.idle ? _idleCaveat() : _caveat,
      result: _result,
      offer: showOffer ? offer : null,
      isPro: _isPro,
      speedMissing: _trip != null ? _speedMissing : _reportsNoSpeed(),
      tripVehicleId: _trip?.vehicleId,
    );
  }

  /// The car on the wire has said what it reports, and Speed is not in it.
  bool _reportsNoSpeed() {
    final supported = _link.supportedPids;
    return _isLive && supported.isNotEmpty && !supported.contains('010D');
  }

  /// The trip being recorded, for the Garage list: an open row that is not
  /// this one is a trip whose save is waiting for the next launch.
  String? get recordingTripId => _trip?.id;

  /// Within §9.2's window now — not only when it was first offered: left on
  /// the strip, an offer taken hours later joined two drives in one trip.
  bool _fresh(ResumeOffer offer) {
    final age = _clock.nowUtc().difference(offer.endedAt);
    return !age.isNegative && age <= TripPlan.resumeWithin;
  }

  /// Said before a recording starts, so no one learns it from a trip that
  /// paused in their pocket.
  TripCaveat? _idleCaveat() {
    if (_platform.backgroundNeedsService) {
      return _notifOk == false ? TripCaveat.notificationsOff : null;
    }
    return _link.transportKind == TransportKind.wifi &&
            !_platform.holdsWifiInBackground
        ? TripCaveat.wifiInBackground
        : null;
  }

  void _publishView() {
    if (_detached) return;
    final next = _viewNow();
    if (next == _view) return;
    _view = next;
    notifyListeners();
  }

  void _event(TripEvent e) {
    _lastEvent = e;
    _eventSerial++;
  }

  // ------------------------------------------------------------ the inputs

  /// Whose trip a recording would be. Called on every garage change, and
  /// when Demo Mode starts or stops.
  void follow(TripOwner owner) {
    if (owner == _owner) return;
    _owner = owner;
    // A demo is not the user's car: nothing about their trips shows there.
    if (owner is OwnerDemo) _result = null;
    _recompute();
  }

  set isPro(bool value) {
    if (value == _isPro) return;
    _isPro = value;
    if (value && _trip != null) _proSeen = true;
    _publishView();
  }

  bool get isPro => _isPro;

  /// The app went to the background or came back (§9.7: hidden counts as
  /// paused). Going, what is buffered is written and synced at once — iOS
  /// may suspend the app before the next tick.
  void setForeground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    if (!value && _phase == RecorderPhase.recording) _flush(sync: true);
    _recompute();
  }

  /// Back in front: notification permission may have been granted in the
  /// meantime, and the Android service may have been stopped from its
  /// notification.
  Future<void> onResumed() async {
    if (_detached || !_platform.backgroundNeedsService) return;
    final ok = await _readNotifications();
    if (_detached) return;
    final trip = _trip;
    if (trip != null && _phase == RecorderPhase.recording) {
      if (ok && !_fgsRequested) {
        final started = await _background.startRecording();
        if (!_stillRecording(trip)) {
          // Ended while the service came up: the end funnel has run, and a
          // background flag or a service set now would outlive the trip
          // (hard rule 9).
          if (started) unawaited(_background.stopRecording());
        } else if (started) {
          _fgsRequested = true;
          _fgsSeen = false;
          _fgsChecked = false;
          _backgroundAllowed = true;
          _caveat = null;
          _link.setRecording(true);
        }
      } else if (_fgsRequested) {
        await _checkService();
      }
    }
    _recompute();
  }

  bool? _notifOk;
  bool _askedNotifications = false;

  Future<bool> _readNotifications() async {
    if (!_platform.backgroundNeedsService) return true;
    final ok = await _background.hasNotificationPermission();
    _notifOk = ok;
    _publishView();
    return ok;
  }

  // ------------------------------------------------------- the open trip

  OpenTrip? _trip;
  String? _tripNickname;
  int _baseT = 0;
  int _segStartMs = 0;
  int _anchorT = 0;
  DateTime _anchorUtc = DateTime.utc(1970);
  int _lastRowT = 0;
  int _ticks = 0;
  bool _capReached = false;

  /// Pro when the trip began or at any moment since: bought mid-trip, the
  /// cap lifts for good — a lapse or refund later never cuts it.
  bool _proSeen = false;
  bool _speedMissing = false;
  bool _backgroundAllowed = true;
  bool _fgsRequested = false;
  bool _fgsSeen = false;
  bool _fgsChecked = false;
  TripStats _stats = TripStats();
  final _buffer = StringBuffer();
  Timer? _timer;

  /// Guards the awaits of a start or resume against a shutdown or detach.
  int _gen = 0;
  Future<void>? _inflight;
  Future<void>? _ending;

  /// Recorded time: monotonic, continuing from the file across a resume.
  int get _t => _baseT + _clock.elapsedMs() - _segStartMs;

  bool get _capOn => !_proSeen && !_isPro;

  // -------------------------------------------------------------- actions

  Future<void> start() {
    if (refusal != null) return Future.value();
    final owner = _owner as OwnerVehicle;
    return _inflight = _start(owner);
  }

  Future<void> _start(OwnerVehicle owner) async {
    final gen = _gen;
    _phase = RecorderPhase.starting;
    _offer = null;
    _result = null;
    _publishView();
    final notifOk = await _askNotifications();
    if (gen != _gen) return _abandon(null);
    final OpenTrip trip;
    try {
      trip = await _store.start(
        vehicleId: owner.vehicleId,
        startedAt: _clock.nowUtc(),
      );
    } catch (e) {
      if (gen != _gen) return;
      _phase = RecorderPhase.idle;
      _result = TripResult(
        kind: TripResultKind.startFailed,
        vehicleId: owner.vehicleId,
        outOfSpace: _outOfSpace(e),
      );
      _event(TripEvent(TripEventKind.startFailed, result: _result));
      _publishView();
      return;
    }
    // Erased, detached, another car, or the link went while the row and
    // file were being made: nothing of it is kept.
    final o = _owner;
    if (gen != _gen ||
        o is! OwnerVehicle ||
        o.vehicleId != owner.vehicleId ||
        !_isLive) {
      return _abandon(trip, discard: !_detached);
    }
    _tripNickname = owner.nickname;
    await _begin(trip, notifOk: notifOk, resumed: false);
  }

  Future<void> resume() {
    final offer = _view.offer;
    if (offer == null || refusal != null) return Future.value();
    return _inflight = _resume(offer);
  }

  Future<void> _resume(ResumeOffer offer) async {
    final gen = _gen;
    final o = _owner as OwnerVehicle;
    _phase = RecorderPhase.starting;
    _offer = null;
    _result = null;
    _publishView();
    final notifOk = await _askNotifications();
    if (gen != _gen) return _abandon(null);
    // Still the trip to resume? Deleted from the Garage, overtaken by a
    // newer trip, or past the window since it was offered, it is not — and
    // "It stays saved as it was" would not be true of a deleted one.
    TripSessionRow? still;
    try {
      still = await _store.resumable(offer.vehicleId, now: _clock.nowUtc());
    } catch (_) {
      still = null;
    }
    if (gen != _gen) return _abandon(null);
    if (still?.id != offer.tripId) {
      _phase = RecorderPhase.idle;
      _result = TripResult(
        kind: TripResultKind.resumeGone,
        vehicleId: offer.vehicleId,
      );
      _event(TripEvent(TripEventKind.resumeFailed, result: _result));
      _publishView();
      return;
    }
    OpenTrip? trip;
    try {
      trip = await _store.resume(offer.tripId, now: _clock.nowUtc());
    } catch (_) {
      trip = null;
    }
    if (gen != _gen) return _abandon(trip, discard: !_detached);
    if (trip == null) {
      _phase = RecorderPhase.idle;
      _result = TripResult(
        kind: TripResultKind.resumeFailed,
        vehicleId: offer.vehicleId,
      );
      _event(TripEvent(TripEventKind.resumeFailed, result: _result));
      _publishView();
      return;
    }
    _tripNickname = o.nickname;
    await _begin(trip, notifOk: notifOk, resumed: true);
  }

  /// A start or resume overtaken by a shutdown or a detach. After a
  /// shutdown the trip is discarded here — the shutdown is waiting for this
  /// future and will find nothing open.
  Future<void> _abandon(OpenTrip? trip, {bool discard = true}) async {
    if (trip != null && discard) await _store.discard(trip);
    if (_detached) return;
    _phase = RecorderPhase.idle;
    _publishView();
  }

  /// Android asks once per session, at the first Record; the answer comes
  /// back after the dialog, so it is read again on the next resume.
  Future<bool> _askNotifications() async {
    if (!_platform.backgroundNeedsService) return true;
    final ok = await _background.hasNotificationPermission();
    _notifOk = ok;
    if (!ok && !_askedNotifications) {
      _askedNotifications = true;
      unawaited(_background.requestNotificationPermission());
    }
    return ok;
  }

  Future<void> _begin(
    OpenTrip trip, {
    required bool notifOk,
    required bool resumed,
  }) async {
    _trip = trip;
    _baseT = trip.baseT;
    _segStartMs = _clock.elapsedMs();
    final utc = _clock.nowUtc();
    _anchorT = trip.baseT;
    _anchorUtc = utc;
    _lastRowT = trip.baseT;
    _ticks = 0;
    _capReached = false;
    _hold = null;
    _stats = TripStats(trip.seed);
    _buffer
      ..clear()
      ..write(TripCsv.segment(trip.baseT, utc));
    _proSeen = _isPro;

    final supported = _link.supportedPids;
    final channels = supported.isEmpty
        ? TripPlan.channels
        : TripPlan.channels.intersection(supported);
    _speedMissing = supported.isNotEmpty && !supported.contains('010D');
    _dashboard.recordingPids = channels;
    _link.bus.tap = _onSample;

    if (_platform.backgroundNeedsService) {
      _backgroundAllowed = notifOk;
      _caveat = notifOk ? null : TripCaveat.notificationsOff;
    } else {
      final wifi =
          _link.transportKind == TransportKind.wifi &&
          !_platform.holdsWifiInBackground;
      _backgroundAllowed = !wifi;
      _caveat = wifi ? TripCaveat.wifiInBackground : null;
    }
    _link.setRecording(_backgroundAllowed);
    _fgsRequested = false;
    _fgsSeen = false;
    _fgsChecked = false;
    _phase = RecorderPhase.recording;
    if (_platform.backgroundNeedsService && notifOk) {
      _fgsRequested = true;
      // Started here, from a tap in the foreground: API 31+ refuses a
      // foreground service started from the background.
      final started = await _background.startRecording();
      // Ended, discarded or torn down while the service came up: the end
      // funnel has run, so no timer, no event and no service may follow.
      // Torn down, the row stays open for the next launch pass.
      if (!_stillRecording(trip)) {
        if (started) unawaited(_background.stopRecording());
        return;
      }
      if (!started) {
        _fgsRequested = false;
        _caveat = TripCaveat.serviceRefused;
        _backgroundAllowed = false;
        _link.setRecording(false);
      }
    }
    if (_tickEvery case final every?) {
      _timer = Timer.periodic(every, (_) => debugTick());
    }
    _event(TripEvent(resumed ? TripEventKind.resumed : TripEventKind.started));
    unawaited(AdaptiveHaptics.select());
    _updateReading();
    _recompute();
  }

  /// [trip] is still the one being recorded — not ending, not replaced,
  /// and the recorder not torn down.
  bool _stillRecording(OpenTrip trip) =>
      _phase == RecorderPhase.recording && identical(trip, _trip) && !_detached;

  Future<void> stop() {
    if (_phase != RecorderPhase.recording) return Future.value();
    return _end(TripEnd.stopped);
  }

  void declineOffer() {
    final offer = _view.offer;
    if (offer == null) return;
    _declined.add(offer.tripId);
    _offer = null;
    _publishView();
  }

  // --------------------------------------------------------- the samples

  void _onSample(PidSample s) {
    if (_phase != RecorderPhase.recording || _hold != null || _capReached) {
      return;
    }
    if (!TripCsv.isPid(s.pid)) return;
    final t = _t;
    if (TripPlan.capped(t, proAtStart: _proSeen, proNow: _isPro)) {
      // Nothing past 2:00 is written, and the end never runs inside the
      // poll loop's call.
      _capReached = true;
      scheduleMicrotask(() => _end(TripEnd.freeCap, endT: TripPlan.freeMs));
      return;
    }
    _buffer.write(TripCsv.row(t, s.pid, s.value));
    _stats.add(t, s.pid, s.value);
    _lastRowT = t;
  }

  /// The 1 s tick. Public for tests, which drive time by hand.
  @visibleForTesting
  void debugTick() {
    if (_phase != RecorderPhase.recording) return;
    final t = _t;
    if (!_capReached &&
        TripPlan.capped(t, proAtStart: _proSeen, proNow: _isPro)) {
      _capReached = true;
      unawaited(_end(TripEnd.freeCap, endT: TripPlan.freeMs));
      return;
    }
    final hold = _hold;
    if (hold != null && _heldTooLong()) {
      unawaited(_end(_endForHold(hold)));
      return;
    }
    _ticks++;
    final fifth = _ticks % 5 == 0;
    if (fifth) {
      final utc = _clock.nowUtc();
      _buffer.write(TripCsv.sync(t, utc));
      _anchorT = t;
      _anchorUtc = utc;
    }
    _flush(sync: fifth);
    _updateReading();
    if (fifth && _fgsRequested) unawaited(_checkService());
  }

  void _updateReading() {
    final totals = _stats.totals;
    final cap = _capOn ? TripPlan.freeMs : null;
    final t = _t;
    reading.value = TripReading(
      elapsedMs: cap == null || t < cap ? t : cap,
      capMs: cap,
      distanceKm: totals.distanceKm,
      avgSpeedKph: totals.avgSpeedKph,
      fuelUsedL: totals.fuelUsedL,
      speedReported: !_speedMissing,
    );
  }

  /// Hands the buffer to the sink, which keeps one operation in flight at
  /// a time. A write the disk refuses ends the trip where the file stops.
  void _flush({bool sync = false}) {
    final trip = _trip;
    if (trip == null) return;
    final text = _buffer.toString();
    _buffer.clear();
    if (text.isEmpty && !sync) return;
    Future<void> write() async {
      if (text.isNotEmpty) await trip.sink.append(text);
      if (sync) await trip.sink.sync();
    }

    write().catchError((Object e) {
      if (e is TripWriteFailure &&
          identical(trip, _trip) &&
          _phase == RecorderPhase.recording) {
        unawaited(
          _end(e.outOfSpace ? TripEnd.storageFull : TripEnd.writeFailed),
        );
      }
    });
  }

  // --------------------------------------------------- holds and the ends

  bool _wasLive = false;
  int _liveEdges = 0;

  void _onLink() {
    final live = _isLive;
    if (live && !_wasLive) _liveEdges++;
    _wasLive = live;
    _recompute();
  }

  /// Runs on every link change, owner change, foreground change and tick:
  /// first whether the trip must end, then whether it must wait.
  void _recompute() {
    if (_detached) return;
    if (_phase == RecorderPhase.recording && _trip != null) {
      final end = _endFor();
      if (end != null) {
        unawaited(_end(end));
        return;
      }
      final hold = _holdFor();
      // The limit is checked on the tick, and a suspended app has none: back
      // from twenty minutes away, the hold must not simply lift.
      if (_hold != null && _heldTooLong()) {
        unawaited(_end(_endForHold(_hold!)));
        return;
      }
      if (hold != _hold) {
        if (_hold == null) {
          _holdSinceMs = _clock.elapsedMs();
          _flush(sync: true);
          if (hold != TripHold.background) {
            _event(TripEvent(TripEventKind.paused, hold: hold));
          }
        } else if (hold == null) {
          if (_hold != TripHold.background) {
            _event(const TripEvent(TripEventKind.continued));
          }
        }
        // A pause that changes kind keeps its start: one limit for all —
        // and is then ended as a pause, not as its last kind.
        if (_hold != null && hold != null) _holdMixed = true;
        if (_hold == null) _holdMixed = false;
        _hold = hold;
      }
    }
    _queryOffer();
    _publishView();
  }

  /// The current pause began as another kind.
  bool _holdMixed = false;

  bool _heldTooLong() =>
      _clock.elapsedMs() - _holdSinceMs >= TripPlan.maxHold.inMilliseconds;

  /// Eight minutes waiting for the link and two with the ignition off is
  /// ten minutes paused, not "the ignition was off for 10 minutes".
  TripEnd _endForHold(TripHold hold) => _holdMixed
      ? TripEnd.heldTooLong
      : switch (hold) {
          TripHold.link => TripEnd.linkLost,
          TripHold.ignitionOff => TripEnd.ignitionOff,
          TripHold.identity || TripHold.background => TripEnd.heldTooLong,
        };

  TripEnd? _endFor() {
    final s = _link.state;
    if ((s == SessionState.disconnected || s == SessionState.unsupported) &&
        !_link.reconnecting) {
      return _link.lastError == null ? TripEnd.disconnected : TripEnd.linkLost;
    }
    final o = _owner;
    final owner = switch (o) {
      OwnerPending(:final vehicleId) => vehicleId,
      OwnerVehicle(:final vehicleId) => vehicleId,
      _ => null,
    };
    // A trip is never re-filed under another car.
    if (owner != _trip!.vehicleId) return TripEnd.otherVehicle;
    return null;
  }

  TripHold? _holdFor() {
    final s = _link.state;
    if (s == SessionState.lost ||
        s == SessionState.connecting ||
        s == SessionState.handshaking ||
        ((s == SessionState.disconnected || s == SessionState.unsupported) &&
            _link.reconnecting)) {
      return TripHold.link;
    }
    if (s == SessionState.ignitionOff) return TripHold.ignitionOff;
    if (_owner is OwnerPending) return TripHold.identity;
    if (!_foreground && !_backgroundAllowed) return TripHold.background;
    return null;
  }

  /// The one way a trip ends. A second call gets the first one's future.
  Future<void> _end(TripEnd reason, {int? endT}) =>
      _ending ??= _doEnd(reason, endT);

  Future<void> _doEnd(TripEnd reason, int? endAt) async {
    final trip = _trip!;
    _phase = RecorderPhase.ending;
    _publishView();
    // Polling and the service stop before any summary work: the summary
    // runs in an isolate and can take a moment, and hard rule 9 does not
    // wait for it.
    _stopWriting();
    final t = _t;
    final endT =
        endAt ??
        switch (reason) {
          TripEnd.stopped ||
          TripEnd.notification ||
          TripEnd.disconnected => _hold == null ? t : _lastRowT,
          _ => _lastRowT,
        };
    var why = reason;
    _buffer.write(
      TripCsv.end(
        endT,
        _anchorUtc.add(Duration(milliseconds: endT - _anchorT)),
        reason,
      ),
    );
    final text = _buffer.toString();
    _buffer.clear();
    try {
      await trip.sink.append(text);
      await trip.sink.sync();
    } on TripWriteFailure catch (e) {
      if (why != TripEnd.storageFull && why != TripEnd.writeFailed) {
        why = e.outOfSpace ? TripEnd.storageFull : TripEnd.writeFailed;
      }
    }
    try {
      await trip.sink.close();
    } catch (_) {}

    TripSessionRow? row;
    var pending = false;
    // Record then Stop with not one reading: kept, it would take one of the
    // free plan's last three for a 0 s trip, where the launch pass deletes
    // the same empty file. A resumed trip always has its first segment.
    final empty = _stats.totals.rows == 0;
    if (empty) {
      try {
        await _store.discard(trip);
      } catch (_) {
        // Left for the launch pass, which deletes an empty trip.
      }
    } else {
      try {
        row = await _store.finish(trip, why, now: _clock.nowUtc());
      } catch (_) {
        // The row stays open; the next Record or launch closes it from the
        // file.
        pending = true;
      }
    }
    final last = reading.value;
    _trip = null;
    _ending = null;
    _hold = null;
    _capReached = false;
    _phase = RecorderPhase.idle;
    // Torn down while saving: the notifiers are gone, and nothing is said.
    if (_detached) return;
    reading.value = null;
    _result = empty
        ? TripResult(
            kind: TripResultKind.nothingRecorded,
            vehicleId: trip.vehicleId,
            end: why,
          )
        : pending
        ? TripResult(
            kind: TripResultKind.summaryPending,
            vehicleId: trip.vehicleId,
            end: why,
          )
        : TripResult(
            kind: TripResultKind.saved,
            vehicleId: trip.vehicleId,
            end: why,
            nickname: _tripNickname,
            savedUpTo: row?.endedAt,
            recordedMs: row?.recordedMs ?? last?.elapsedMs,
            distanceKm: row == null ? last?.distanceKm : row.distanceKm,
            avgSpeedKph: row == null ? last?.avgSpeedKph : row.avgSpeedKph,
            fuelUsedL: row == null ? last?.fuelUsedL : row.fuelUsedL,
          );
    if (reason == TripEnd.freeCap) unawaited(AdaptiveHaptics.light());
    _event(TripEvent(TripEventKind.ended, result: _result));
    _publishView();
    unawaited(_store.retention().catchError((Object _) {}));
  }

  /// Stops everything that keeps the car polled or the service up.
  void _stopWriting() {
    _timer?.cancel();
    _timer = null;
    if (identical(_link.bus.tap, _onSample)) _link.bus.tap = null;
    _link.setRecording(false);
    _dashboard.recordingPids = const {};
    if (_fgsRequested) unawaited(_background.stopRecording());
    _fgsRequested = false;
  }

  /// Android: the service's own notification has a Stop. Dart hears it
  /// here, within one five-second tick. A service never seen running at
  /// the first check was refused, not stopped.
  Future<void> _checkService() async {
    final trip = _trip;
    final up = await _background.isRunning();
    if (!identical(trip, _trip) || _phase != RecorderPhase.recording) return;
    if (up) {
      _fgsSeen = true;
    } else if (_fgsSeen) {
      unawaited(_end(TripEnd.notification));
    } else if (!_fgsChecked) {
      _fgsRequested = false;
      _caveat = TripCaveat.serviceRefused;
      _backgroundAllowed = false;
      _link.setRecording(false);
      _recompute();
    }
    _fgsChecked = true;
  }

  // ---------------------------------------------------------- the offer

  String? _offerKey;

  /// Asked once per car per live edge — never on every notify.
  void _queryOffer() {
    if (!_launched || _latched || _phase != RecorderPhase.idle) return;
    final o = _owner;
    if (o is! OwnerVehicle || !_isLive) return;
    final key = '${o.vehicleId}#$_liveEdges';
    if (key == _offerKey) return;
    _offerKey = key;
    final gen = _gen;
    _store
        .resumable(o.vehicleId, now: _clock.nowUtc())
        .then((row) {
          if (gen != _gen || _detached) return;
          // Nothing to offer now means the last offer is stale too.
          _offer = row == null
              ? (_offer?.vehicleId == o.vehicleId ? null : _offer)
              : ResumeOffer.of(row);
          _publishView();
        })
        .catchError((Object _) {});
  }

  // --------------------------------------------------- teardown and data

  /// A vehicle is being deleted. Its open trip is discarded — the delete
  /// alert already said its trips go with it — and nothing about it stays.
  Future<void> releaseVehicle(String vehicleId) async {
    await _settled();
    final trip = _trip;
    if (trip != null && trip.vehicleId == vehicleId) await _discardOpen();
    if (_offer?.vehicleId == vehicleId) _offer = null;
    if (_result?.vehicleId == vehicleId) _result = null;
    _publishView();
  }

  /// Delete all data: no start may begin, anything in flight finishes,
  /// and the open trip is discarded before the wipe.
  Future<void> shutdown() {
    _latched = true;
    _gen++;
    if (_inflight == null && _ending == null && _trip == null) {
      _publishView();
      return Future.value();
    }
    return () async {
      await _settled();
      if (_trip != null) await _discardOpen();
      _publishView();
    }();
  }

  /// A failed erase lets the recorder be used again.
  void unlatch() {
    _latched = false;
    _publishView();
  }

  Future<void> _settled() async {
    final inflight = _inflight;
    if (inflight != null) await inflight;
    _inflight = null;
    final ending = _ending;
    if (ending != null) await ending;
  }

  Future<void> _discardOpen() async {
    final trip = _trip!;
    _stopWriting();
    _trip = null;
    _hold = null;
    _capReached = false;
    _buffer.clear();
    reading.value = null;
    _phase = RecorderPhase.idle;
    await _store.discard(trip);
  }

  /// The app is going away with the engine: nothing is written, the row
  /// stays open, and the next launch pass closes it from the file.
  void detach() {
    _detached = true;
    _gen++;
    _timer?.cancel();
    _timer = null;
    if (identical(_link.bus.tap, _onSample)) _link.bus.tap = null;
    _link.removeListener(_onLink);
    if (_fgsRequested) unawaited(_background.stopRecording());
  }

  /// ENOSPC is 28 on Darwin and on Linux/Android alike.
  static bool _outOfSpace(Object e) =>
      (e is TripWriteFailure && e.outOfSpace) ||
      (e is FileSystemException && e.osError?.errorCode == 28);

  @override
  void dispose() {
    if (!_detached) detach();
    reading.dispose();
    super.dispose();
  }
}
