import 'dart:async';

import 'obd_trace.dart';
import 'obd_transport.dart';

/// Replays a recorded `.obdtrace` as if it were a live adapter.
///
/// The same code path a real transport uses — bytes arrive on [inbound],
/// framed exactly as the adapter emitted them, with the adapter's real latency
/// (divided by [speed] for CI). Nothing above this layer can tell the
/// difference, which is the point: the engine tested here is the engine that
/// ships.
class MockTransport implements ObdTransport {
  MockTransport(
    this.trace, {
    this.speed = 1.0,
    this.unknownCommandReply = 'NO DATA\r\r>',
    this.chunkSize = 20,
  }) : _replies = trace.repliesByCommand,
       _latencies = trace.latenciesByCommand,
       _unanswered = trace.unansweredCommands;

  final ObdTrace trace;

  /// Replay speed. 1.0 reproduces recorded timing; CI runs at 50–100×.
  final double speed;

  /// What the mock says to a command the trace never saw. `NO DATA` is the
  /// honest default: a trace that lacks a PID is a car that didn't answer it.
  final String unknownCommandReply;

  /// Emulates a BLE MTU. Responses arrive in chunks this size, so the session
  /// is exercised against fragmentation just as it will be on a real link.
  final int chunkSize;

  final Map<String, List<String>> _replies;
  final Map<String, List<Duration>> _latencies;
  final Set<String> _unanswered;

  /// How many times each command has been sent, to pick the Nth reply.
  final Map<String, int> _sendCount = {};

  final _inbound = StreamController<List<int>>.broadcast();
  final _state = StreamController<TransportState>.broadcast();
  TransportState _current = TransportState.disconnected;

  /// Every command written, for tests to assert the handshake sequence.
  final List<String> written = [];

  /// Set to make the next N commands go unanswered — simulates an adapter
  /// that has died mid-session without a disconnect callback, which is what
  /// the session's watchdog exists to catch.
  int dropNext = 0;

  Timer? _pending;

  @override
  TransportKind get kind => TransportKind.mock;

  @override
  String get id => 'mock:${trace.adapter ?? 'trace'}';

  @override
  String get displayName => trace.adapter ?? 'Recorded session';

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  Stream<List<int>> get inbound => _inbound.stream;

  @override
  int get maxWriteLength => chunkSize;

  @override
  TransportCapabilities get capabilities => TransportCapabilities.mock;

  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    _set(TransportState.connecting);
    _set(TransportState.connected);
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_current != TransportState.connected) return;

    final command = String.fromCharCodes(bytes).trim();
    written.add(command);

    if (dropNext > 0) {
      dropNext--;
      return;
    }

    final key = ObdTrace.normalise(command);
    final n = _sendCount[key] ?? 0;
    _sendCount[key] = n + 1;

    // A command the recording shows going unanswered stays unanswered — that
    // is the recording of a dead adapter, and the session's timeout is what
    // is under test.
    if (_unanswered.contains(key) && !_replies.containsKey(key)) return;

    final replies = _replies[key];
    final reply = replies == null
        ? unknownCommandReply
        : replies[n < replies.length ? n : replies.length - 1];
    final latencies = _latencies[key];
    final latency = latencies == null
        ? const Duration(milliseconds: 40)
        : latencies[n < latencies.length ? n : latencies.length - 1];

    _pending?.cancel();
    _pending = Timer(_scaled(latency), () => _emit(reply.codeUnits));
  }

  /// Delivers a response in MTU-sized chunks, each on its own microtask, so
  /// the session's reassembly is genuinely exercised.
  void _emit(List<int> bytes) {
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = i + chunkSize < bytes.length ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);
      scheduleMicrotask(() {
        if (!_inbound.isClosed) _inbound.add(chunk);
      });
    }
  }

  Duration _scaled(Duration d) => Duration(
    microseconds: (d.inMicroseconds / speed).round().clamp(1, 1 << 40),
  );

  @override
  Future<void> disconnect() async {
    _pending?.cancel();
    _set(TransportState.disconnected);
  }

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> dispose() async {
    _pending?.cancel();
    await _inbound.close();
    await _state.close();
  }
}
