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

  /// Whether the rate has recovered as far as it currently *can* — the
  /// literal 10 Hz when Auto, or the user's chosen ceiling otherwise.
  ///
  /// A caller latched into its own backoff (the session's BUFFER FULL
  /// handling) has to clear that backoff against this, not against a
  /// hardcoded 10: with a ceiling below 10 the rate can never reach
  /// literal 10 again, and a check against that literal would leave the
  /// backoff latched for the rest of the connection.
  bool get hasRecovered => _targetHz >= (_maxHz ?? 10);

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

  /// The cycle each non-critical PID was last asked in. When the budget
  /// is short, the one that has waited longest goes next.
  final Map<String, int> _lastServed = {};

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
    if (due.length <= limit) {
      for (final pid in due) {
        _lastServed[pid] = _cycle;
      }
      return due;
    }

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
    // The rest always get one turn, even when the criticals alone fill
    // the budget: RPM and Speed on a 45 ms adapter are a budget of two, and
    // every other tile read "No data" for good — found by recording a trip,
    // which asks for Speed beside RPM. The cycle runs one command long
    // instead: slower, and every tile still live.
    final slots = limit > criticals.length ? limit - criticals.length : 1;
    if (rest.isEmpty) return criticals;
    // Longest-waiting first. A counter rotating over the due list landed
    // on the same offset whenever the list's length divided the turns
    // between two due cycles: a low tile, due every 20th cycle, was never
    // asked at all.
    rest.sort((a, b) {
      final wait = (_lastServed[a] ?? -1).compareTo(_lastServed[b] ?? -1);
      if (wait != 0) return wait;
      final pa = PidRegistry.lookup(a)!.priority.index;
      final pb = PidRegistry.lookup(b)!.priority.index;
      return pa != pb ? pa.compareTo(pb) : a.compareTo(b);
    });
    final picked = rest.take(slots).toList();
    for (final pid in picked) {
      _lastServed[pid] = _cycle;
    }
    return [...criticals, ...picked];
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
    _lastServed.clear();
    _noDataStreak.clear();
    _dropped.clear();
    _targetHz = _capped(10); // the ceiling is the user's, and survives
    _maxPidsPerCycle = 6;
  }
}
