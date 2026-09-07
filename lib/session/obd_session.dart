import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db/app_database.dart';
import '../data/repositories/dtc_repository.dart';
import '../domain/pid_sample.dart';
import '../protocol/dtc_decoder.dart';
import '../protocol/elm_session.dart';
import '../protocol/pid_registry.dart';
import '../protocol/pid_scheduler.dart';
import '../protocol/protocol_negotiator.dart';
import '../protocol/readiness_decoder.dart';
import '../protocol/response_parser.dart';
import '../protocol/vin_reader.dart';
import '../transport/obd_transport.dart';
import 'gauge_catalog.dart';

/// What the connection is doing, in the vocabulary SPEC §2.1 uses for the
/// global banner.
enum SessionState {
  disconnected,

  /// Opening the transport.
  connecting,

  /// The 7-step handshake is running; [ObdSession.progressStep] says where.
  handshaking,

  /// Polling normally.
  connected,

  /// Polling, but the adapter forced the rate down or dropped PIDs.
  degraded,

  /// The adapter answers but the ECU does not — key out, or engine off on a
  /// car that sleeps its bus.
  ignitionOff,

  /// The link dropped; the reconnect ladder is running.
  lost,

  /// Handshake finished but nothing spoke OBD-II.
  unsupported,
}

/// A snapshot of one diagnostic read.
class DtcReadResult {
  const DtcReadResult({
    required this.stored,
    required this.pending,
    required this.permanent,
    this.readiness,
    this.milOn,
    this.reportedCount,
  });

  final List<RawDtc> stored;
  final List<RawDtc> pending;
  final List<RawDtc> permanent;
  final ReadinessReport? readiness;
  final bool? milOn;

  /// What Mode 01 PID 01 claimed, which can disagree with what Mode 03
  /// actually returned. Both are shown; neither is invented.
  final int? reportedCount;

  List<RawDtc> get all => [...stored, ...pending, ...permanent];
  bool get isEmpty => all.isEmpty;
}

/// How a clear attempt ended, in terms the UI can explain.
enum ClearResult {
  /// Mode 04 accepted and the re-read came back empty.
  cleared,

  /// Mode 04 accepted but codes are still there — a live fault.
  codesReturned,

  /// The ECU refused. Almost always: engine running.
  refused,

  /// The link went away mid-clear. The snapshot is on disk, pending.
  interrupted,
}

/// The live connection: transport, then `ElmSession`, then the handshake,
/// then the poll loop feeding [bus].
///
/// This is the only place that owns the running conversation with the car.
/// It is a [ChangeNotifier] for *connection* state — which changes rarely —
/// while live PID values go through [bus], one `ValueNotifier` per PID, so
/// no widget rebuilds at 10 Hz (hard rule 3).
///
/// Hard rule 2 is enforced one layer down: `ElmSession` keeps exactly one
/// command outstanding, so this class can await freely without ever
/// pipelining.
class ObdSession extends ChangeNotifier {
  ObdSession({
    PidBus? bus,
    DashboardClock? clock,
    PidScheduler? scheduler,
    this.dtcs,
    this.timeScale = 1.0,
  }) : bus = bus ?? PidBus(),
       clock = clock ?? DashboardClock(),
       _scheduler = scheduler ?? PidScheduler();

  /// One notifier per PID; the dashboard's tiles listen here, not to this
  /// object.
  final PidBus bus;

  /// Ticked once per poll cycle so tiles can decay without a new sample.
  final DashboardClock clock;

  /// Where the §9.5 before/after-clear snapshots go. Null in tests that
  /// don't exercise clearing.
  final DtcRepository? dtcs;

  /// Compresses every internal delay, so a test can replay a whole session
  /// in milliseconds. 1.0 in the app.
  final double timeScale;

  final PidScheduler _scheduler;
  PidScheduler get scheduler => _scheduler;

  ObdTransport? _transport;
  ElmSession? _elm;
  StreamSubscription<TransportState>? _transportSub;

  /// Bumped by every connect and disconnect. Every async step checks it, so
  /// a loop belonging to a previous connection stops the moment it resumes.
  int _generation = 0;

  SessionState _state = SessionState.disconnected;
  SessionState get state => _state;

  int _progressStep = 0;
  String _progressLabel = '';

  /// 0-based index into `ProtocolNegotiator.steps`.
  int get progressStep => _progressStep;
  String get progressLabel => _progressLabel;
  int get totalSteps => ProtocolNegotiator.steps.length;

  ObdProtocol? _protocol;
  ObdProtocol? get protocol => _protocol;

  String? _adapterIdentity;
  String? get adapterIdentity => _adapterIdentity;

  double? _batteryVolts;
  double? get batteryVolts => _batteryVolts;

  Set<String> _supported = {};
  Set<String> get supportedPids => Set.unmodifiable(_supported);

  Set<String> _visible = {};

  /// What the last failure was, for the banner. Null when nothing is wrong.
  String? _lastError;
  String? get lastError => _lastError;

  int _reconnectAttempt = 0;
  int get reconnectAttempt => _reconnectAttempt;

  int _bufferOverflows = 0;

  /// How many times the adapter's own buffer overflowed this session. A
  /// clone that does this repeatedly is the thing to name in the
  /// diagnostics log (§10.4) — the car is fine, the adapter is not.
  int get bufferOverflows => _bufferOverflows;

  bool _backgrounded = false;
  bool _recording = false;

  /// Round-trip p95 over the recent window, for the diagnostics screen.
  int? get p95Rtt => _elm?.p95Rtt;

  bool get isLive =>
      _state == SessionState.connected || _state == SessionState.degraded;

  Duration _scaled(Duration d) =>
      Duration(microseconds: (d.inMicroseconds * timeScale).round());

  // ------------------------------------------------------------- lifecycle

  /// Opens [transport], handshakes, discovers supported PIDs, and starts
  /// polling. Returns true once polling has started.
  Future<bool> connect(ObdTransport transport) async {
    await _teardown();
    final gen = ++_generation;

    _transport = transport;
    _set(SessionState.connecting, error: null);

    try {
      await transport.connect();
    } catch (e) {
      if (gen != _generation) return false;
      _set(SessionState.disconnected, error: _describe(e));
      return false;
    }
    if (gen != _generation) return false;

    // The transport can drop at any moment from here on.
    _transportSub = transport.state.listen((s) {
      if (gen != _generation) return;
      if (s == TransportState.disconnected || s == TransportState.failed) {
        _onLinkLost();
      }
    });

    final elm = _elm = ElmSession(transport, timeScale: timeScale);
    _set(SessionState.handshaking);

    final result = await ProtocolNegotiator(elm).handshake(
      onProgress: (step, label) {
        if (gen != _generation) return;
        _progressStep = step;
        _progressLabel = label;
        notifyListeners();
      },
    );
    if (gen != _generation) return false;

    _adapterIdentity = result.adapterIdentity;
    _batteryVolts = result.batteryVolts;

    if (!result.ok) {
      // A handshake that reached the last step and still got nothing means
      // the adapter is fine and the car is not answering.
      _set(
        result.status == ElmStatus.noEcu || result.failedAtStep == totalSteps
            ? SessionState.unsupported
            : SessionState.disconnected,
        error: _handshakeError(result),
      );
      return false;
    }

    _protocol = result.protocol;
    await _discoverSupported(gen, result.supportBytes);
    if (gen != _generation) return false;

    _set(SessionState.connected, error: null);
    _reconnectAttempt = 0;
    unawaited(_pollLoop(gen));
    return true;
  }

  /// Stops polling and closes the transport. Safe to call at any point.
  Future<void> disconnect() async {
    _generation++;
    await _teardown();
    _protocol = null;
    _adapterIdentity = null;
    _batteryVolts = null;
    _supported = {};
    _progressStep = 0;
    _progressLabel = '';
    _reconnectAttempt = 0;
    _bufferOverflows = 0;
    _backedOff = false;
    bus.clear();
    _set(SessionState.disconnected, error: null);
  }

  Future<void> _teardown() async {
    await _transportSub?.cancel();
    _transportSub = null;
    await _elm?.dispose();
    _elm = null;
    final t = _transport;
    _transport = null;
    if (t != null) {
      try {
        await t.disconnect();
      } catch (_) {
        // Already gone; the outcome is the same.
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_teardown());
    bus.dispose();
    clock.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- discovery

  /// Asks the four support bitmasks and tells the scheduler what exists.
  /// Nothing outside the result is ever polled — clones answer unpredictably
  /// to unsupported PIDs and it wrecks throughput.
  Future<void> _discoverSupported(int gen, List<int> handshakeMask) async {
    final found = <String>{};
    // The handshake's own `0100` probe already carried the first bitmask.
    // Re-asking would cost a round trip on every connect and tell us
    // nothing new.
    var queries = PidRegistry.supportQueries;
    if (handshakeMask.isNotEmpty) {
      found.addAll(PidRegistry.decodeSupportMask('0100', handshakeMask));
      queries = queries.skip(1).toList();
    }
    for (final query in queries) {
      if (gen != _generation) return;
      final r = await _elm!.send(query);
      if (gen != _generation) return;
      if (!r.isOk) break; // the chain ends where the car stops answering
      found.addAll(PidRegistry.decodeSupportMask(query, r.bytes));
    }
    _supported = found;
    _scheduler.setSupported(found);
    if (_visible.isEmpty) {
      setVisible(GaugeCatalog.defaultLayout.where(found.contains).toSet());
    } else {
      _scheduler.setVisible(_visible.intersection(found));
    }
    notifyListeners();
  }

  /// Only tiles on screen are polled. A tile scrolled out of view or an app
  /// in the background must not consume round trips.
  void setVisible(Set<String> pids) {
    _visible = pids;
    _scheduler.setVisible(
      _supported.isEmpty ? pids : pids.intersection(_supported),
    );
  }

  /// Hard rule 9: no polling while backgrounded unless a trip is recording.
  void setBackgrounded(bool value) {
    if (_backgrounded == value) return;
    _backgrounded = value;
    if (!_backgrounded && isLive) unawaited(_pollLoop(_generation));
  }

  void setRecording(bool value) {
    if (_recording == value) return;
    _recording = value;
    if (isLive) unawaited(_pollLoop(_generation));
  }

  bool get _shouldPoll => isLive && (!_backgrounded || _recording);

  // -------------------------------------------------------------- poll loop

  /// Set by a BUFFER FULL and cleared only once the rate has climbed
  /// all the way back, so recovery is gradual rather than instant.
  bool _backedOff = false;

  /// One cycle at a time, never overlapping: each await is a full round
  /// trip and `ElmSession` allows only one outstanding command anyway.
  bool _looping = false;

  Future<void> _pollLoop(int gen) async {
    if (_looping || gen != _generation) return;
    _looping = true;
    try {
      var consecutiveTimeouts = 0;
      var consecutiveNoEcu = 0;

      while (gen == _generation && _shouldPoll) {
        final started = DateTime.now();
        final cycle = _scheduler.nextCycle();
        var overflowed = false;

        if (cycle.isEmpty) {
          // Nothing visible: idle politely rather than spinning.
          await Future<void>.delayed(
            _scaled(const Duration(milliseconds: 200)),
          );
          continue;
        }

        for (final pid in cycle) {
          if (gen != _generation || !_shouldPoll) return;
          final r = await _elm!.send(pid);
          if (gen != _generation) return;

          switch (r.status) {
            case ElmStatus.ok:
              consecutiveTimeouts = 0;
              consecutiveNoEcu = 0;
              _scheduler.recordSuccess(pid);
              _publish(pid, r);
            case ElmStatus.noData:
              _scheduler.recordNoData(pid);
            case ElmStatus.bufferFull:
              // The adapter's own buffer overflowed: halve the rate now.
              overflowed = true;
              _bufferOverflows++;
              _scheduler.onBufferFull();
            case ElmStatus.noEcu:
              consecutiveNoEcu++;
            case ElmStatus.timeout:
              consecutiveTimeouts++;
            case ElmStatus.lowVoltage:
            case ElmStatus.canError:
            case ElmStatus.internalError:
              // §4.4: these need the whole conversation restarted.
              await _rehandshake(gen, r.status);
              return;
            default:
              break;
          }

          if (consecutiveTimeouts >= 5) {
            _onLinkLost();
            return;
          }
          if (consecutiveNoEcu >= 3) {
            // The adapter is answering; the car is not.
            _set(SessionState.ignitionOff, error: 'The car is not answering');
            consecutiveNoEcu = 0;
          } else if (_state == SessionState.ignitionOff && r.isOk) {
            _set(SessionState.connected, error: null);
          }
        }

        // Latency feedback must never undo a buffer-full backoff: the
        // adapter has already told us it is dropping data, and
        // recordP95Rtt would put the rate straight back to 10 Hz on the
        // next fast cycle. After an overflow the only way up is relax(),
        // which ramps over several cycles.
        if (overflowed) {
          _backedOff = true;
        } else if (_backedOff) {
          _scheduler.relax();
          if (_scheduler.targetHz >= 10) _backedOff = false;
        } else {
          _scheduler.recordP95Rtt(_elm!.p95Rtt);
        }
        _refreshDegraded();
        clock.tick();

        final remaining =
            _scaled(_scheduler.cycleBudget) -
            DateTime.now().difference(started);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
    } finally {
      _looping = false;
    }
  }

  void _publish(String pid, ElmResponse r) {
    final value = PidRegistry.decodeResponse(pid, r.bytes);
    // A null here is a real absence — a short frame, the wrong PID, or a
    // value outside physical bounds. Publishing it keeps the tile honest
    // rather than leaving the last good value on screen forever.
    bus.publish(PidSample(pid: pid, value: value, at: DateTime.now()));
  }

  void _refreshDegraded() {
    final degraded = _scheduler.isDegraded || _scheduler.droppedPids.isNotEmpty;
    final next = degraded ? SessionState.degraded : SessionState.connected;
    if (_state == SessionState.connected || _state == SessionState.degraded) {
      if (_state != next) _set(next);
    }
  }

  /// LV RESET, CAN ERROR or an internal fault: reset the adapter and
  /// renegotiate rather than carrying on against a confused ELM.
  Future<void> _rehandshake(int gen, ElmStatus cause) async {
    if (gen != _generation) return;
    _set(SessionState.handshaking, error: _statusMessage(cause));
    final result = await ProtocolNegotiator(_elm!).handshake(
      cachedProtocol: _protocol?.number,
      onProgress: (step, label) {
        if (gen != _generation) return;
        _progressStep = step;
        _progressLabel = label;
        notifyListeners();
      },
    );
    if (gen != _generation) return;
    if (!result.ok) {
      _onLinkLost();
      return;
    }
    _protocol = result.protocol ?? _protocol;
    _batteryVolts = result.batteryVolts ?? _batteryVolts;
    _scheduler.reset();
    _set(SessionState.connected, error: null);
    unawaited(_pollLoop(gen));
  }

  // ------------------------------------------------------------- reconnect

  void _onLinkLost() {
    if (_state == SessionState.disconnected) return;
    _set(SessionState.lost, error: 'Connection lost');
    unawaited(_reconnect(_generation));
  }

  /// SPEC §9.2 — 0.5 / 1 / 2 / 4 / 8 s, then stop and let the user decide.
  static const reconnectDelays = <Duration>[
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  Future<void> _reconnect(int gen) async {
    final transport = _transport;
    if (transport == null) return;

    for (var i = 0; i < reconnectDelays.length; i++) {
      if (gen != _generation) return;
      _reconnectAttempt = i + 1;
      notifyListeners();
      await Future<void>.delayed(_scaled(reconnectDelays[i]));
      if (gen != _generation) return;

      // connect() bumps the generation itself, so this attempt owns the
      // session from here.
      final ok = await connect(transport);
      if (ok) return;
      if (gen != _generation) return; // someone else took over
    }
    _set(SessionState.disconnected, error: 'Could not reconnect');
  }

  // ------------------------------------------------------------ diagnostics

  /// Modes 03, 07 and 0A plus the Mode 01 PID 01 summary.
  ///
  /// Pro gates permanent codes (§7.2) — the caller decides whether to ask;
  /// this returns everything the car gave.
  Future<DtcReadResult> readDtcs({bool includePermanent = true}) async {
    final elm = _elm;
    if (elm == null) {
      return const DtcReadResult(stored: [], pending: [], permanent: []);
    }

    final summary = await elm.send('0101', timeout: ElmSession.slowTimeout);
    final readiness = summary.isOk
        ? ReadinessDecoder.decode(summary.bytes)
        : null;

    Future<List<RawDtc>> read(String mode, DtcMode kind) async {
      final r = await elm.send(mode, timeout: ElmSession.slowTimeout);
      if (!r.isOk) return const [];
      return DtcDecoder.decode(r.frames, kind);
    }

    return DtcReadResult(
      stored: await read('03', DtcMode.stored),
      pending: await read('07', DtcMode.pending),
      permanent: includePermanent
          ? await read('0A', DtcMode.permanent)
          : const [],
      readiness: readiness,
      milOn: readiness?.milOn,
      reportedCount: readiness?.dtcCount,
    );
  }

  /// SPEC §9.5 — the snapshot is written **before** Mode 04 goes out, and
  /// the codes are always re-read afterwards. If the app dies in between,
  /// the snapshot is on disk marked pending and the next launch reconciles.
  ///
  /// [vehicleId] is required for the snapshot; without a repository this
  /// still clears, it just keeps no history.
  Future<ClearResult> clearDtcs({String? vehicleId}) async {
    final elm = _elm;
    if (elm == null) return ClearResult.interrupted;

    final before = await readDtcs();
    DtcSnapshotRow? snapshot;
    if (dtcs != null && vehicleId != null) {
      snapshot = await dtcs!.beginClear(
        vehicleId: vehicleId,
        codes: before.all,
        milOn: before.milOn,
        dtcCount: before.reportedCount,
        protocol: _protocol?.number,
      );
    }

    final cleared = await elm.send('04', timeout: ElmSession.slowTimeout);
    if (!cleared.isOk) {
      if (snapshot != null) {
        await dtcs!.failClear(snapshot.id, ClearOutcome.refused);
      }
      return ClearResult.refused;
    }

    // Always re-read: "cleared" that didn't clear is the single most
    // damaging thing this app could claim.
    final after = await readDtcs();
    if (snapshot != null) {
      await dtcs!.completeClear(
        beforeSnapshotId: snapshot.id,
        afterCodes: after.all,
        milOn: after.milOn,
        dtcCount: after.reportedCount,
        protocol: _protocol?.number,
      );
    }
    return after.isEmpty ? ClearResult.cleared : ClearResult.codesReturned;
  }

  /// Mode 09 PID 02. Null when the car doesn't answer — common pre-2008,
  /// and never a reason to block anything (§9.6).
  Future<VinResult?> readVin() async {
    final elm = _elm;
    if (elm == null) return null;
    final r = await elm.send('0902', timeout: ElmSession.slowTimeout);
    if (!r.isOk) return null;
    return VinReader.parse(r.frames);
  }

  /// The adapter's own voltage reading, which works even with the key out.
  Future<double?> readBatteryVolts() async {
    final elm = _elm;
    if (elm == null) return null;
    final r = await elm.send('ATRV');
    if (!r.isOk) return null;
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(r.raw);
    final v = match == null ? null : double.tryParse(match.group(1)!);
    if (v != null) {
      _batteryVolts = v;
      notifyListeners();
    }
    return v;
  }

  // ----------------------------------------------------------------- state

  void _set(SessionState next, {String? error = _keep}) {
    final changed = _state != next || (error != _keep && error != _lastError);
    _state = next;
    if (error != _keep) _lastError = error;
    if (changed) notifyListeners();
  }

  /// Sentinel so [_set] can tell "leave the error alone" from "clear it".
  static const _keep = ' keep';

  static String _describe(Object e) =>
      e.toString().replaceFirst(RegExp(r'^\w+Exception:?\s*'), '');

  static String _handshakeError(HandshakeResult r) {
    if (r.status != null) return _statusMessage(r.status!);
    final step = r.failedAtStep;
    if (step == null) return 'The adapter did not respond';
    return 'The adapter stopped responding at step $step';
  }

  static String _statusMessage(ElmStatus s) => switch (s) {
    ElmStatus.noEcu => 'No response from the car',
    ElmStatus.lowVoltage => 'The adapter lost power',
    ElmStatus.canError => 'Bus error — retrying',
    ElmStatus.busInitError => 'The car did not start a session',
    ElmStatus.internalError => 'The adapter reported an internal error',
    ElmStatus.timeout => 'The adapter stopped responding',
    _ => 'Connection problem',
  };
}
