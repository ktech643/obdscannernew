/// The recorder's two clocks (§9.7 "DST/clock change: monotonic
/// `Stopwatch`, store UTC").
///
/// Recorded time — every row's t, the free plan's 2:00, how long a pause
/// has lasted — comes from [elapsedMs], which a clock change cannot move.
/// Instants that are stored — when a trip started, the anchors that map t
/// to the wall — come from [nowUtc].
abstract interface class TripClock {
  int elapsedMs();
  DateTime nowUtc();
}

class SystemTripClock implements TripClock {
  SystemTripClock() : _watch = Stopwatch()..start();

  final Stopwatch _watch;

  @override
  int elapsedMs() => _watch.elapsedMilliseconds;

  @override
  DateTime nowUtc() => DateTime.timestamp();
}
