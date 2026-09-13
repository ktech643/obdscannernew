import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db/app_database.dart';
import '../data/repositories/dtc_repository.dart';
import '../domain/pid_sample.dart';
import '../protocol/dtc_decoder.dart';
import '../protocol/elm_session.dart';
import '../protocol/isotp_reassembler.dart';
import '../protocol/pid_registry.dart';
import '../protocol/pid_scheduler.dart';
import '../protocol/protocol_log.dart';
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
  /// car that sleeps its bus. A slow probe keeps running so the session
  /// comes back on its own when the key is turned.
  ignitionOff,

  /// The link dropped; the reconnect ladder is running.
  lost,

  /// Handshake finished but nothing spoke OBD-II.
  unsupported,
}

/// One diagnostic read.
///
/// [failedModes] is the difference between "the car has no pending codes"
/// and "we could not ask" — without it an empty list means both, and a
/// clear that could not be verified would be reported as a success.
class DtcReadResult {
  const DtcReadResult({
    required this.stored,
    required this.pending,
    required this.permanent,
    this.readiness,
    this.milOn,
    this.reportedCount,
    this.failedModes = const {},
  });

  final List<RawDtc> stored;
  final List<RawDtc> pending;
  final List<RawDtc> permanent;
  final ReadinessReport? readiness;
  final bool? milOn;

  /// What Mode 01 PID 01 claimed, which can disagree with what Mode 03
  /// actually returned. Both are shown; neither is invented.
  final int? reportedCount;

  /// Modes that did not answer at all: `'0101'`, `'03'`, `'07'`, `'0A'`.
  final Set<String> failedModes;

  List<RawDtc> get all => [...stored, ...pending, ...permanent];

  /// Empty *and* trustworthy. An unanswered mode makes this false even
  /// when no codes were parsed.
  bool get isEmpty => all.isEmpty && failedModes.isEmpty;

  /// Whether every mode answered.
  bool get complete => failedModes.isEmpty;
}

/// How a clear attempt ended, in terms the UI can explain.
enum ClearResult {
  /// Mode 04 accepted and the re-read came back verifiably empty.
  cleared,

  /// Mode 04 accepted but codes are still there — a live fault.
  codesReturned,

  /// The ECU refused. Almost always: engine running.
  refused,

  /// The link went away, or the verifying re-read could not be trusted.
  /// The snapshot stays `pending` on disk and the next launch reconciles.
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
    this.log,
    this.timeScale = 1.0,
  }) : bus = bus ?? PidBus(),
       clock = clock ?? DashboardClock(),
       _scheduler = scheduler ?? PidScheduler();

  /// One notifier per PID; the dashboard's tiles listen here, not to this
  /// object.
  final PidBus bus;

  /// Ticked by a timer of its own, never by the poll loop: a hung link must
  /// not also stop the clock, or every tile freezes at its last value and
  /// stale renders as live (hard rule 4).
  final DashboardClock clock;

  /// Where the §9.5 before/after-clear snapshots go. Null in tests that
  /// don't exercise clearing.
  final DtcRepository? dtcs;

  /// SPEC §10.4 — the diagnostics log, fed by every `ElmSession` this
  /// object opens. Null when nobody is keeping one.
  final ProtocolLog? log;

  /// Compresses every internal delay, so a test can replay a whole session
  /// in milliseconds. 1.0 in the app.
  final double timeScale;

  final PidScheduler _scheduler;
  PidScheduler get scheduler => _scheduler;

  ObdTransport? _transport;
  ElmSession? _elm;
  StreamSubscription<TransportState>? _transportSub;
  Timer? _ticker;

  /// Bumped by every connect and disconnect. Every async step checks it, so
  /// a loop belonging to a previous connection stops the moment it resumes.
  int _generation = 0;

  /// Owns the reconnect ladder. Separate from [_generation] because the
  /// ladder calls `connect`, which bumps the generation itself — checking
  /// the generation after an attempt would abort the ladder every time,
  /// collapsing 0.5/1/2/4/8 s into a single try.
  int _reconnectToken = 0;
  bool _reconnecting = false;

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

  /// How many hex characters of header each reply carries, measured rather
  /// than assumed — see [_calibrateHeader].
  int _headerChars = 0;
  int get headerChars => _headerChars;

  /// What the last failure was, for the banner. Null when nothing is wrong.
  String? _lastError;
  String? get lastError => _lastError;

  int _reconnectAttempt = 0;
  int get reconnectAttempt => _reconnectAttempt;

  bool _backgrounded = false;
  bool _recording = false;

  int _bufferOverflows = 0;

  /// How many times the adapter's own buffer overflowed this session. A
  /// clone that does this repeatedly is the thing to name in the
  /// diagnostics log (§10.4) — the car is fine, the adapter is not.
  int get bufferOverflows => _bufferOverflows;

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
      await _teardown();
      return false;
    }
    // Superseded while the transport was opening: close what this call
    // opened and leave the winner's fields alone.
    if (gen != _generation) {
      await _closeQuietly(transport, null);
      return false;
    }

    // The transport can drop at any moment from here on.
    final sub = _transportSub = transport.state.listen((s) {
      if (gen != _generation) return;
      if (s == TransportState.disconnected || s == TransportState.failed) {
        _onLinkLost();
      }
    });

    final elm = _elm = ElmSession(
      transport,
      timeScale: timeScale,
      log: log,
      describe: _describeReply,
    );
    _set(SessionState.handshaking);
    _startTicker();

    final result = await ProtocolNegotiator(elm).handshake(
      onProgress: (step, label) {
        if (gen != _generation) return;
        _progressStep = step;
        _progressLabel = label;
        notifyListeners();
      },
    );
    if (gen != _generation) {
      await sub.cancel();
      await _closeQuietly(transport, elm);
      return false;
    }

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
      await _teardown();
      return false;
    }

    _protocol = result.protocol;
    _calibrateHeader(result.supportFrames, result.headersUnavailable);
    await _discoverSupported(gen, result.supportFrames);
    if (gen != _generation) return false;

    _set(SessionState.connected, error: null);
    _reconnectAttempt = 0;
    unawaited(_pollLoop(gen));
    return true;
  }

  /// Stops polling and closes the transport. Safe to call at any point.
  Future<void> disconnect() async {
    _generation++;
    _reconnectToken++;
    _reconnecting = false;
    await _teardown();
    _protocol = null;
    _adapterIdentity = null;
    _batteryVolts = null;
    _supported = {};
    _headerChars = 0;
    _progressStep = 0;
    _progressLabel = '';
    _reconnectAttempt = 0;
    _bufferOverflows = 0;
    _backedOff = false;
    bus.clear();
    _set(SessionState.disconnected, error: null);
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _transportSub?.cancel();
    _transportSub = null;
    final elm = _elm;
    _elm = null;
    final t = _transport;
    _transport = null;
    await _closeQuietly(t, elm);
  }

  Future<void> _closeQuietly(ObdTransport? t, ElmSession? elm) async {
    await elm?.dispose();
    if (t == null) return;
    try {
      await t.disconnect();
    } catch (_) {
      // Already gone; the outcome is the same.
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _reconnectToken++;
    unawaited(_teardown());
    bus.dispose();
    clock.dispose();
    super.dispose();
  }

  /// The clock runs for as long as a transport is attached, at a cadence
  /// independent of the command loop. Tiles decay on their own even when
  /// the link has hung, the app is backgrounded, or the ladder is running.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      _scaled(const Duration(milliseconds: 200)),
      (_) => clock.tick(),
    );
  }

  // -------------------------------------------------------------- discovery

  /// Works out how wide this adapter's headers are by measuring, not by
  /// trusting `ATH1`.
  ///
  /// The handshake's `0100` probe is the one reply whose shape is known in
  /// advance: it must decode to a payload beginning `41 00`. Trying each
  /// plausible header width against it settles the question once, for every
  /// decode that follows.
  ///
  /// Assuming zero — which is what this class did first — leaves an 11-bit
  /// CAN header prefixing three hex characters to every frame. Three is
  /// odd, so byte-pairing shifts by a nibble and *every* decode comes back
  /// empty: no supported PIDs, a blank dashboard, no codes on a car with a
  /// lit lamp. Guessing from the protocol number instead would break on the
  /// clones that quietly ignore `ATH1`.
  void _calibrateHeader(List<String> frames, bool headersUnavailable) {
    if (frames.isEmpty) {
      _headerChars = 0;
      return;
    }
    // 3: 11-bit CAN. 8: 29-bit CAN. 6: three-byte legacy (J1850, ISO
    // 9141-2, KWP). 0: headers off, or an adapter that ignored ATH1.
    const candidates = [0, 3, 8, 6];
    for (final width in headersUnavailable ? const [0] : candidates) {
      final bytes = IsoTpReassembler.reassemble(frames, headerChars: width);
      if (bytes.length >= 2 && bytes[0] == 0x41 && bytes[1] == 0x00) {
        _headerChars = width;
        return;
      }
    }
    _headerChars = 0;
  }

  /// The log's parsed column: a PID reply as the value it decodes to, a
  /// Mode 09 reply as the VIN, any failure as its status word. Never a
  /// guess — a reply this cannot decode gets no description at all.
  String? _describeReply(ElmResponse r) {
    if (!r.isOk) return r.status.name;
    final cmd = r.command.toUpperCase();
    if (cmd == '0902') {
      return VinReader.parse(r.frames, headerChars: _headerChars)?.vin;
    }
    if (cmd.length == 4 && cmd.startsWith('01')) {
      final def = PidRegistry.lookup(cmd);
      final v = def == null
          ? null
          : PidRegistry.decodeResponse(cmd, _payload(r));
      if (def == null || v == null) return null;
      final text = v == v.roundToDouble()
          ? v.round().toString()
          : v.toStringAsFixed(1);
      return '${def.name} $text ${def.unit}'.trimRight();
    }
    return null;
  }

  List<int> _payload(ElmResponse r) =>
      IsoTpReassembler.reassemble(r.frames, headerChars: _headerChars);

  /// Asks the remaining support bitmasks and tells the scheduler what
  /// exists. Nothing outside the result is ever polled — clones answer
  /// unpredictably to unsupported PIDs and it wrecks throughput.
  Future<void> _discoverSupported(int gen, List<String> handshakeFrames) async {
    final found = <String>{};
    // The handshake's own `0100` probe already carried the first bitmask.
    // Re-asking would cost a round trip on every connect and tell us
    // nothing new.
    var queries = PidRegistry.supportQueries;
    if (handshakeFrames.isNotEmpty) {
      found.addAll(
        PidRegistry.decodeSupportMask(
          '0100',
          IsoTpReassembler.reassemble(
            handshakeFrames,
            headerChars: _headerChars,
          ),
        ),
      );
      queries = queries.skip(1).toList();
    }

    for (final query in queries) {
      if (gen != _generation) return;
      var r = await _elm!.send(query);
      if (gen != _generation) return;
      // A transient BUS BUSY or BUFFER FULL is not "unsupported": retry
      // once before writing off every PID above this block for the whole
      // session.
      if (!r.isOk && r.status != ElmStatus.noData) {
        r = await _elm!.send(query);
        if (gen != _generation) return;
      }
      if (!r.isOk) break; // the chain ends where the car stops answering
      found.addAll(PidRegistry.decodeSupportMask(query, _payload(r)));
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
    if (!_backgrounded && _canPoll) unawaited(_pollLoop(_generation));
  }

  void setRecording(bool value) {
    if (_recording == value) return;
    _recording = value;
    if (_canPoll) unawaited(_pollLoop(_generation));
  }

  /// `ignitionOff` keeps polling — slowly — because that is the only way
  /// the session notices the key coming back. Stopping there would wedge
  /// it: nothing else restarts the loop.
  bool get _canPoll =>
      (isLive || _state == SessionState.ignitionOff) &&
      (!_backgrounded || _recording);

  // -------------------------------------------------------------- poll loop

  /// Set by a BUFFER FULL and cleared only once the rate has climbed all
  /// the way back. §4.4 wants +10% every 30 s, not every cycle.
  bool _backedOff = false;
  DateTime? _lastRelax;

  /// One cycle at a time, never overlapping: each await is a full round
  /// trip and `ElmSession` allows only one outstanding command anyway.
  bool _looping = false;

  Future<void> _pollLoop(int gen) async {
    if (_looping || gen != _generation) return;
    _looping = true;
    try {
      var consecutiveTimeouts = 0;
      var consecutiveNoEcu = 0;
      var busBusyRetries = 0;

      while (gen == _generation && _canPoll) {
        final started = DateTime.now();
        // While the ECU is asleep, probe one PID slowly rather than
        // hammering a bus that is not listening.
        final probing = _state == SessionState.ignitionOff;
        final cycle = probing
            ? _scheduler.nextCycle(maxPids: 1)
            : _scheduler.nextCycle();
        var overflowed = false;

        if (cycle.isEmpty) {
          // Nothing visible: idle politely rather than spinning.
          await Future<void>.delayed(
            _scaled(const Duration(milliseconds: 200)),
          );
          continue;
        }

        for (final pid in cycle) {
          if (gen != _generation || !_canPoll) return;
          final r = await _elm!.send(pid);
          if (gen != _generation) return;

          // Only silence counts towards the watchdog. Every other status is
          // the adapter answering, which means the link is alive.
          if (r.status == ElmStatus.timeout) {
            consecutiveTimeouts++;
          } else {
            consecutiveTimeouts = 0;
          }
          if (r.status != ElmStatus.noEcu) consecutiveNoEcu = 0;
          if (r.status != ElmStatus.busBusy) busBusyRetries = 0;

          switch (r.status) {
            case ElmStatus.ok:
              _scheduler.recordSuccess(pid);
              _publish(pid, r);
              if (_state == SessionState.ignitionOff) {
                _set(SessionState.connected, error: null); // the bus woke up
              }
            case ElmStatus.noData:
              _scheduler.recordNoData(pid);
            case ElmStatus.bufferFull:
              // The adapter's own buffer overflowed: halve the rate now.
              overflowed = true;
              _bufferOverflows++;
              _scheduler.onBufferFull();
            case ElmStatus.badCommand:
              // The adapter does not know this PID, and a second ask cannot
              // change that. Drop it now rather than after three strikes.
              _scheduler
                ..recordNoData(pid)
                ..recordNoData(pid)
                ..recordNoData(pid);
            case ElmStatus.busBusy:
              // §4.4: back off and retry, but do not spin on a busy bus.
              if (busBusyRetries < 2) {
                busBusyRetries++;
                await Future<void>.delayed(
                  _scaled(const Duration(milliseconds: 500)),
                );
              }
            case ElmStatus.noEcu:
              consecutiveNoEcu++;
            case ElmStatus.busInitError:
            case ElmStatus.lowVoltage:
            case ElmStatus.canError:
            case ElmStatus.internalError:
              // §4.4: these need the whole conversation restarted. Continue
              // the *same* loop afterwards — starting a new one here would
              // be a no-op, because this one still holds `_looping`.
              if (!await _rehandshake(gen, r.status)) return;
              consecutiveTimeouts = 0;
              consecutiveNoEcu = 0;
            case ElmStatus.searching:
            case ElmStatus.stopped:
            case ElmStatus.malformed:
            case ElmStatus.timeout:
              // Counted above. SEARCHING resolves itself; STOPPED, a
              // garbled frame and a lone timeout are retried by the next
              // cycle rather than by a tight retry here.
              break;
          }

          // §9.2: three consecutive timeouts is the watchdog for an adapter
          // yanked from the port whose disconnect callback never fires.
          if (consecutiveTimeouts >= 3) {
            _onLinkLost();
            return;
          }
          if (consecutiveNoEcu >= 3 && _state != SessionState.ignitionOff) {
            // The adapter is answering; the car is not.
            _set(SessionState.ignitionOff, error: 'The car is not answering');
          }
        }

        // Latency feedback must never undo a buffer-full backoff: the
        // adapter has already told us it is dropping data, and
        // recordP95Rtt would put the rate straight back to 10 Hz on the
        // next fast cycle.
        final now = DateTime.now();
        if (overflowed) {
          _backedOff = true;
          _lastRelax = now;
        } else if (_backedOff) {
          if (now.difference(_lastRelax ?? now) >=
              _scaled(const Duration(seconds: 30))) {
            _scheduler.relax();
            _lastRelax = now;
            if (_scheduler.targetHz >= 10) _backedOff = false;
          }
        } else {
          _scheduler.recordP95Rtt(_elm!.p95Rtt);
        }
        _refreshDegraded();

        final budget = probing
            ? _scaled(const Duration(seconds: 2))
            : _scaled(_scheduler.cycleBudget);
        final remaining = budget - DateTime.now().difference(started);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
    } finally {
      _looping = false;
    }
  }

  void _publish(String pid, ElmResponse r) {
    final value = PidRegistry.decodeResponse(pid, _payload(r));
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

  /// LV RESET, CAN ERROR, a failed bus init or an internal fault: reset the
  /// adapter and renegotiate rather than carrying on against a confused
  /// ELM. Returns true when the caller's loop may continue.
  Future<bool> _rehandshake(int gen, ElmStatus cause) async {
    if (gen != _generation) return false;
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
    if (gen != _generation) return false;
    if (!result.ok) {
      _onLinkLost();
      return false;
    }
    _protocol = result.protocol ?? _protocol;
    _batteryVolts = result.batteryVolts ?? _batteryVolts;
    // ATWS may have changed what the adapter reports; re-measure rather
    // than carry a stale width into every later decode.
    _calibrateHeader(result.supportFrames, result.headersUnavailable);
    _scheduler.reset();
    _backedOff = false;
    _set(SessionState.connected, error: null);
    return true;
  }

  // ------------------------------------------------------------- reconnect

  /// SPEC §5.6 "Auto-reconnect". Off means a dropped link is reported and
  /// left dropped: the state goes to `disconnected` with the reason and
  /// the §9.2 ladder does not run — the user asked to decide for
  /// themselves. On, which is the default, the ladder runs as §9.2 says.
  bool autoReconnect = true;

  void _onLinkLost() {
    if (_state == SessionState.disconnected || _reconnecting) return;
    if (!autoReconnect) {
      unawaited(_dropLink());
      return;
    }
    _reconnecting = true;
    _set(SessionState.lost, error: 'Connection lost');
    unawaited(_reconnect(++_reconnectToken));
  }

  /// A drop with auto-reconnect off: tear down like a deliberate
  /// disconnect — the tiles decay, the loop stops — but keep the reason,
  /// so the banner says "lost", not "not connected".
  Future<void> _dropLink() async {
    await disconnect();
    _set(SessionState.disconnected, error: 'Connection lost');
  }

  /// SPEC §9.2 — 0.5 / 1 / 2 / 4 / 8 s, then stop and let the user decide.
  static const reconnectDelays = <Duration>[
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  Future<void> _reconnect(int token) async {
    final transport = _transport;
    if (transport == null) {
      _reconnecting = false;
      return;
    }

    try {
      for (var i = 0; i < reconnectDelays.length; i++) {
        if (token != _reconnectToken) return;
        _reconnectAttempt = i + 1;
        notifyListeners();
        await Future<void>.delayed(_scaled(reconnectDelays[i]));
        if (token != _reconnectToken) return;

        // connect() bumps the generation itself, so the ladder cannot use
        // it to tell "my own attempt" from "someone else took over" — that
        // is what the token is for.
        final ok = await connect(transport);
        if (token != _reconnectToken) return;
        if (ok) return;
      }
      _set(SessionState.disconnected, error: 'Could not reconnect');
    } finally {
      if (token == _reconnectToken) _reconnecting = false;
    }
  }

  // ------------------------------------------------------------ diagnostics

  /// Modes 03, 07 and 0A plus the Mode 01 PID 01 summary.
  ///
  /// Pro gates permanent codes (§7.2) — the caller decides whether to ask;
  /// this returns everything the car gave, and records which modes did not
  /// answer at all.
  Future<DtcReadResult> readDtcs({
    bool includePermanent = true,
    void Function(String mode)? onStep,
  }) async {
    final elm = _elm;
    if (elm == null) {
      return const DtcReadResult(
        stored: [],
        pending: [],
        permanent: [],
        failedModes: {'0101', '03', '07', '0A'},
      );
    }

    final failed = <String>{};
    // A scan is five round trips long; a link can drop and a reconnect can
    // land inside one. Every step is pinned to the connection it started
    // on, so a reply from a *different* session is never folded into this
    // result — the modes are reported as unanswered instead, which is what
    // they are.
    final gen = _generation;

    Future<List<RawDtc>> read(String mode, DtcMode kind) async {
      if (gen != _generation) {
        failed.add(mode);
        return const [];
      }
      onStep?.call(mode);
      final r = await elm.send(mode, timeout: ElmSession.slowTimeout);
      if (gen != _generation) {
        failed.add(mode);
        return const [];
      }
      if (r.isOk) {
        return DtcDecoder.decode(r.frames, kind, headerChars: _headerChars);
      }
      // NO DATA is an honest "nothing here" on a lot of hardware,
      // especially for modes 07 and 0A. Anything else means we could not
      // ask, which is not the same as "no codes".
      if (r.status != ElmStatus.noData) failed.add(mode);
      return const [];
    }

    // §5.4 fixes the order — 03, 07, 0A, then the Mode 01 summary — so the
    // per-step label the user reads matches what is actually on the wire.
    final stored = await read('03', DtcMode.stored);
    final pending = await read('07', DtcMode.pending);
    final permanent = includePermanent
        ? await read('0A', DtcMode.permanent)
        : const <RawDtc>[];

    ReadinessReport? readiness;
    if (gen != _generation) {
      failed.add('0101');
    } else {
      onStep?.call('0101');
      final summary = await elm.send('0101', timeout: ElmSession.slowTimeout);
      readiness = gen != _generation || !summary.isOk
          ? null
          : ReadinessDecoder.decode(_payload(summary));
      if (readiness == null) failed.add('0101');
    }

    return DtcReadResult(
      stored: stored,
      pending: pending,
      permanent: permanent,
      readiness: readiness,
      milOn: readiness?.milOn,
      reportedCount: readiness?.dtcCount,
      failedModes: failed,
    );
  }

  /// SPEC §9.5 — the snapshot is written **before** Mode 04 goes out, and
  /// the codes are always re-read afterwards. If the app dies in between,
  /// or the link drops, or the re-read cannot be trusted, the snapshot
  /// stays `pending` on disk and the next launch reconciles it.
  ///
  /// [vehicleId] is required for the snapshot; without a repository this
  /// still clears, it just keeps no history.
  Future<ClearResult> clearDtcs({
    String? vehicleId,
    void Function(DtcReadResult)? onReread,
  }) async {
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

    // A refusal is a negative response — `7F 04 22` when the engine is
    // running — which is well-formed hex and therefore parses as `ok`.
    // Reading only the status would report a refusal as "the code came
    // straight back", which is a different problem with a different fix.
    final payload = _payload(cleared);
    final negative = _hasPair(payload, 0x7F, 0x04);
    final accepted = cleared.isOk && !negative && payload.contains(0x44);

    if (!accepted) {
      if (negative || cleared.status == ElmStatus.noData) {
        // The ECU answered, and said no.
        if (snapshot != null) {
          await dtcs!.failClear(snapshot.id, ClearOutcome.refused);
        }
        return ClearResult.refused;
      }
      // Timeout, LV RESET, bus error: the clear may well have executed and
      // only the reply was lost. Leave the snapshot pending so relaunch
      // reconciles it — this ambiguity is exactly why §9.5 writes it first.
      return ClearResult.interrupted;
    }

    // Always re-read: "cleared" that didn't clear is the single most
    // damaging thing this app could claim.
    final after = await readDtcs();
    // Handed to the caller so the screen shows the reading the verdict was
    // decided on. A second re-read of its own would cost four more round
    // trips and could disagree with the verdict it sits next to.
    onReread?.call(after);
    if (!after.complete) {
      // The re-read could not be trusted, so neither can "cleared". The
      // snapshot stays pending rather than being stamped with a result
      // nobody verified.
      return ClearResult.interrupted;
    }
    if (snapshot != null) {
      await dtcs!.completeClear(
        beforeSnapshotId: snapshot.id,
        afterCodes: after.all,
        milOn: after.milOn,
        dtcCount: after.reportedCount,
        protocol: _protocol?.number,
      );
    }
    // A permanent code is *expected* to survive Mode 04 — only the ECU
    // releases those, and the sheet says so before the button is
    // reachable. Counting one as "the code came straight back" would
    // report a clean clear as a live fault.
    final returned = after.stored.isNotEmpty || after.pending.isNotEmpty;
    return returned ? ClearResult.codesReturned : ClearResult.cleared;
  }

  static bool _hasPair(List<int> bytes, int a, int b) {
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == a && bytes[i + 1] == b) return true;
    }
    return false;
  }

  /// One read of [pid], outside the poll rotation.
  ///
  /// The diagnostics scan needs values the Dashboard may not be showing —
  /// coolant, fuel trims — and a hard gate needs a *fresh* speed, not
  /// whatever the rotation last left on the bus (hard rule 4). Safe to
  /// call while polling: `ElmSession` keeps exactly one command
  /// outstanding (hard rule 2), so this queues rather than pipelines.
  ///
  /// Null means the ECU did not answer. A successful read of a PID the car
  /// has no data for publishes null too, which is an absence, not a zero.
  Future<double?> readPidOnce(String pid) async {
    final elm = _elm;
    if (elm == null) return null;
    final gen = _generation;
    final r = await elm.send(pid);
    // A reply that arrived after the link was replaced belongs to the old
    // connection. Publishing it would put another car's number on a tile.
    if (gen != _generation || !r.isOk) return null;
    final value = PidRegistry.decodeResponse(pid, _payload(r));
    bus.publish(PidSample(pid: pid, value: value, at: DateTime.now()));
    return value;
  }

  /// Mode 09 PID 02. Null when the car doesn't answer — common pre-2008,
  /// and never a reason to block anything (§9.6).
  Future<VinResult?> readVin() async {
    final elm = _elm;
    if (elm == null) return null;
    final r = await elm.send('0902', timeout: ElmSession.slowTimeout);
    if (!r.isOk) return null;
    return VinReader.parse(r.frames, headerChars: _headerChars);
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
    if (_disposed) return;
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
