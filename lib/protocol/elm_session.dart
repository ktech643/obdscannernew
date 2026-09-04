import 'dart:async';
import 'dart:collection';

import '../transport/obd_transport.dart';
import 'response_parser.dart';

/// The serial command queue.
///
/// **There is no pipelining in ELM327.** Exactly one command may be outstanding
/// at any moment, and the next may not be written until the prompt byte `>`
/// (0x3E) has been seen or the deadline has passed. Every clone-adapter
/// disaster in this category traces back to violating that, so the invariant is
/// enforced here and asserted in tests rather than left to callers.
class ElmSession {
  ElmSession(this._transport) {
    _sub = _transport.inbound.listen(_onBytes);
  }

  final ObdTransport _transport;
  late final StreamSubscription<List<int>> _sub;

  final Queue<_PendingCommand> _queue = Queue();
  _PendingCommand? _active;
  final StringBuffer _rx = StringBuffer();
  Timer? _timeout;

  /// ASCII '>'. The only reliable frame terminator — a response may contain
  /// any number of carriage returns, so splitting on `\r` loses frames.
  static const int promptByte = 0x3E;

  static const defaultTimeout = Duration(milliseconds: 1200);

  /// `ATZ` and `0100` genuinely take seconds on older vehicles.
  static const slowTimeout = Duration(seconds: 5);

  /// K-line protocols in the negotiation ladder.
  static const verySlowTimeout = Duration(seconds: 15);

  /// True while a command is in flight. Tests assert this never overlaps.
  bool get isBusy => _active != null;

  int get queueDepth => _queue.length;

  /// Set when the adapter kept echoing after `ATE0`. The parser strips it, but
  /// callers may want to know they're on a limited adapter.
  bool echoActive = false;

  /// Set when `ATH1` was rejected. Multi-ECU disambiguation is impossible, so
  /// only the first well-formed frame per request may be trusted.
  bool headersUnavailable = false;

  /// Round-trip times, newest last, capped. Feeds the scheduler's budget.
  final List<int> _rtt = [];
  List<int> get rttSamples => List.unmodifiable(_rtt);

  /// p95 round-trip over the recent window. Returns null before any sample.
  int? get p95Rtt {
    if (_rtt.isEmpty) return null;
    final sorted = [..._rtt]..sort();
    return sorted[((sorted.length - 1) * 0.95).floor()];
  }

  Future<ElmResponse> send(String command, {Duration? timeout}) {
    final pending = _PendingCommand(command, timeout ?? defaultTimeout);
    _queue.add(pending);
    _pump();
    return pending.completer.future;
  }

  void _pump() {
    // ★ The invariant. Nothing else in this class may write to the transport.
    if (_active != null || _queue.isEmpty) return;

    final next = _queue.removeFirst();
    _active = next;
    _rx.clear();
    next.startedAt = DateTime.now();
    _timeout = Timer(next.timeout, _onTimeout);
    _transport.write('${next.cmd}\r'.codeUnits);
  }

  void _onBytes(List<int> chunk) {
    if (_active == null) return; // unsolicited data between commands

    // Filter to the characters an ELM327 can legitimately emit. A clone that
    // sprays binary must not corrupt the buffer.
    for (final b in chunk) {
      if (_isAcceptable(b)) _rx.writeCharCode(b);
    }

    // Cap the buffer. A clone stuck emitting garbage would otherwise grow it
    // without limit while the timeout runs.
    if (_rx.length > maxResponseChars) {
      _finish(ElmStatus.malformed);
      return;
    }

    if (chunk.contains(promptByte)) _finish(null);
  }

  static const maxResponseChars = 4096;

  static bool _isAcceptable(int b) =>
      (b >= 0x30 && b <= 0x39) || // 0-9
      (b >= 0x41 && b <= 0x5A) || // A-Z
      (b >= 0x61 && b <= 0x7A) || // a-z
      b == 0x20 || // space
      b == 0x0D || // CR
      b == 0x0A || // LF
      b == 0x3E || // >
      b == 0x3F || // ?
      b == 0x2E || // .
      b == 0x3A || // :
      b == 0x2D; // -

  void _onTimeout() => _finish(ElmStatus.timeout);

  void _finish(ElmStatus? forced) {
    final active = _active;
    if (active == null) return;

    _timeout?.cancel();
    _timeout = null;
    _active = null;

    final raw = _rx.toString();
    final response = forced != null
        ? ElmResponse(command: active.cmd, raw: raw, status: forced)
        : ResponseParser.parse(active.cmd, raw);

    if (forced == null && active.startedAt != null) {
      final ms = DateTime.now().difference(active.startedAt!).inMilliseconds;
      _rtt.add(ms);
      if (_rtt.length > 20) _rtt.removeAt(0);
    }

    if (!active.completer.isCompleted) active.completer.complete(response);
    _pump();
  }

  /// Drops every queued command without completing them as errors — used when
  /// the link is torn down and the answers can no longer arrive.
  void flush() {
    _timeout?.cancel();
    _timeout = null;
    final dropped = [?_active, ..._queue];
    _active = null;
    _queue.clear();
    for (final p in dropped) {
      if (!p.completer.isCompleted) {
        p.completer.complete(
          ElmResponse(command: p.cmd, raw: '', status: ElmStatus.timeout),
        );
      }
    }
  }

  Future<void> dispose() async {
    flush();
    await _sub.cancel();
  }
}

class _PendingCommand {
  _PendingCommand(this.cmd, this.timeout);

  final String cmd;
  final Duration timeout;
  final Completer<ElmResponse> completer = Completer();
  DateTime? startedAt;
}
