import 'pid_registry.dart';

/// Decides which PIDs to ask for on each cycle, and how fast to ask.
///
/// Kept free of timers so the whole policy is unit-testable: the owner drives
/// [nextCycle] on a real clock, and tests drive it directly.
class PidScheduler {
  PidScheduler({this._targetHz = 10});

  /// 10 Hz on CAN with a good adapter. Reduced automatically as the measured
  /// round trip degrades — a slow adapter cannot be made fast by asking more
  /// often, only by asking for less.
  int _targetHz;
  int get targetHz => _targetHz;

  int? _maxHz;

  /// SPEC §5.6 "Polling rate" — a ceiling the user chose, or null for
  /// Auto. The adaptive rate never rises above it and never needs to be
  /// asked to fall below it; the adaptation still runs underneath, so a
  /// slow adapter on a 4 Hz ceiling still drops to 2 Hz and says so.
  int? get maxHz => _maxHz;
  set maxHz(int? hz) {
    _maxHz = hz?.clamp(1, 10);
    _targetHz = _capped(_targetHz);
  }

  int _capped(int hz) => _maxHz == null ? hz : hz.clamp(1, _maxHz!);

  Duration get cycleBudget =>
      Duration(milliseconds: (1000 / _targetHz).round());

  /// **Only PIDs whose tile is on screen.** This is the difference between a
  /// responsive dashboard and a slideshow: a tile scrolled out of view or an
  /// app in the background must not consume round trips.
  Set<String> _visible = {};

  /// PIDs the vehicle declared via the support bitmasks. Nothing outside this
  /// is ever polled.
  Set<String> _supported = {};

  /// Dropped after three consecutive `NO DATA`. The tile becomes
  /// "Not available", which is visually distinct from a live zero.
  final Map<String, int> _noDataStreak = {};
  final Set<String> _dropped = {};

  int _cycle = 0;

  /// Where the round-robin over non-critical PIDs has got to.
  int _rotation = 0;

  Set<String> get droppedPids => Set.unmodifiable(_dropped);

  void setSupported(Set<String> pids) {
    _supported = pids;
    _dropped.removeWhere((p) => !pids.contains(p));
  }

  void setVisible(Set<String> pids) => _visible = pids;

  /// The PIDs to request this cycle, ordered so criticals go first if the
  /// budget runs out mid-cycle.
  List<String> nextCycle({int? maxPids}) {
    final candidates = _visible
        .where((p) => _supported.isEmpty || _supported.contains(p))
        .where((p) => !_dropped.contains(p))
        .toList();

    final due = <String>[];
    for (final pid in candidates) {
      final def = PidRegistry.lookup(pid);
      if (def == null) continue;
      if (_cycle % _interval(def.priority) == 0) due.add(pid);
    }

    due.sort((a, b) {
      final pa = PidRegistry.lookup(a)!.priority.index;
      final pb = PidRegistry.lookup(b)!.priority.index;
      return pa.compareTo(pb);
    });

    _cycle++;
    final limit = maxPids ?? _maxPidsPerCycle;
    if (due.length <= limit) return due;

    // Truncating a stably-sorted list starves its tail: the same lowest
    // priority PIDs fall off every single cycle and are never asked for at
    // all, so their tiles read "No data" on a car that answers them
    // perfectly well. Criticals are never dropped; everything else takes
    // turns, which delays a PID instead of losing it.
    final criticals = <String>[];
    final rest = <String>[];
    for (final pid in due) {
      if (PidRegistry.lookup(pid)!.priority == PidPriority.critical) {
        criticals.add(pid);
      } else {
        rest.add(pid);
      }
    }
    if (criticals.length >= limit) return criticals;

    // The rotation advances once per *truncated* cycle, not per cycle: a
    // high-priority PID is only due every other cycle, so a counter keyed
    // on the cycle number lands on the same offset every time and rotates
    // nothing.
    final slots = limit - criticals.length;
    final start = rest.isEmpty ? 0 : _rotation % rest.length;
    _rotation += slots;
    return [
      ...criticals,
      for (var i = 0; i < slots && i < rest.length; i++)
        rest[(start + i) % rest.length],
    ];
  }

  static int _interval(PidPriority p) => switch (p) {
    PidPriority.critical => 1,
    PidPriority.high => 2,
    PidPriority.medium => 5,
    PidPriority.low => 20,
    // Never scheduled — read once at handshake.
    PidPriority.once => 1 << 30,
  };

  int _maxPidsPerCycle = 6;
  int get maxPidsPerCycle => _maxPidsPerCycle;

  /// Feeds measured latency back into the rate.
  ///
  /// Thresholds from SPEC §4.5: past 250 ms drop to 5 Hz and say so; past
  /// 600 ms drop to 2 Hz and show the degraded banner. The user is told the
  /// adapter is slow rather than left to wonder why the numbers crawl.
  void recordP95Rtt(int? p95Ms) {
    if (p95Ms == null || p95Ms <= 0) return;
    if (p95Ms > 600) {
      _targetHz = _capped(2);
    } else if (p95Ms > 250) {
      _targetHz = _capped(5);
    } else {
      _targetHz = _capped(10);
    }
    _maxPidsPerCycle = (cycleBudget.inMilliseconds / p95Ms).floor().clamp(
      1,
      12,
    );
  }

  /// The adapter's own buffer overflowed. Halve the rate immediately — this
  /// is not negotiable, the adapter is already dropping data.
  void onBufferFull() {
    _targetHz = _capped((_targetHz / 2).ceil().clamp(1, 10));
    _maxPidsPerCycle = (_maxPidsPerCycle / 2).ceil().clamp(1, 12);
  }

  /// Ramp back gently once the adapter recovers.
  void relax() {
    if (_targetHz < 10) {
      _targetHz = _capped((_targetHz * 1.1).ceil().clamp(1, 10));
    }
  }

  void recordNoData(String pid) {
    final streak = (_noDataStreak[pid] ?? 0) + 1;
    _noDataStreak[pid] = streak;
    if (streak >= 3) _dropped.add(pid);
  }

  void recordSuccess(String pid) {
    _noDataStreak.remove(pid);
    _dropped.remove(pid);
  }

  /// True when the link should be considered degraded: the banner appears and
  /// the dashboard explains why rather than silently slowing down.
  bool get isDegraded => _targetHz <= 2;

  void reset() {
    _cycle = 0;
    _rotation = 0;
    _noDataStreak.clear();
    _dropped.clear();
    _targetHz = _capped(10); // the ceiling is the user's, and survives
    _maxPidsPerCycle = 6;
  }
}
