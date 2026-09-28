/// A trip's figures so far: what the strip shows while recording and what
/// the row keeps once it ends. Pure values, so an isolate can hand them back.
///
/// Every figure is null until the car has said something about it — a car
/// that never answers fuel rate has no fuel figure, never "0.0 L" (hard
/// rule 5). Distances are km, speeds km/h, fuel litres: the registry's own
/// metric units, whatever the user shows.
class TripTotals {
  const TripTotals({
    this.rows = 0,
    this.distanceKm,
    this.speedCoveredMs = 0,
    this.maxSpeedKph,
    this.fuelUsedL,
  });

  /// Data rows, null-valued ones included: every answer the car gave.
  final int rows;

  /// ∫ speed dt. Null until the first speed value.
  final double? distanceKm;

  /// The time the distance integral actually covers: the sum of the gaps
  /// it bridged. Silence longer than [TripStats.maxBridgeMs] is not in it.
  final int speedCoveredMs;
  final double? maxSpeedKph;

  /// ∫ fuel rate dt — an estimate, always shown as one. Null until the
  /// first fuel-rate value.
  final double? fuelUsedL;

  /// Distance over the time it covers — not over the trip's length, which
  /// would count a stop at the lights with the adapter silent as 0 km/h.
  /// Null under 10 s of coverage, where one sample would be "the average".
  double? get avgSpeedKph {
    final d = distanceKm;
    if (d == null || speedCoveredMs < TripStats.minAverageMs) return null;
    return d / (speedCoveredMs / Duration.millisecondsPerHour);
  }

  @override
  bool operator ==(Object other) =>
      other is TripTotals &&
      other.rows == rows &&
      other.distanceKm == distanceKm &&
      other.speedCoveredMs == speedCoveredMs &&
      other.maxSpeedKph == maxSpeedKph &&
      other.fuelUsedL == fuelUsedL;

  @override
  int get hashCode =>
      Object.hash(rows, distanceKm, speedCoveredMs, maxSpeedKph, fuelUsedL);

  @override
  String toString() =>
      'TripTotals(rows: $rows, km: $distanceKm, covered: $speedCoveredMs ms, '
      'max: $maxSpeedKph, fuel: $fuelUsedL)';
}

/// The one integrator. The recorder feeds it live, sample by sample, and
/// the file summary feeds it row by row from the CSV, so the strip's
/// figures and the saved row cannot disagree (§4.3).
///
/// O(1) in time and memory per sample: it keeps the running sums and the
/// last point of each chain, never a series (AC-15).
///
/// Both integrals are trapezoids between consecutive values `0 < dt ≤`
/// [maxBridgeMs] apart. Anything else breaks the chain rather than being
/// filled in:
///  - a null value — the ECU answered with no data, which is absence, not
///    zero (hard rule 5);
///  - a gap longer than 15 s — Doze, a stall, a hold (§9.3: timestamp every
///    sample, never assume an interval). 15 s still bridges the 2 s
///    background cycle and the 10 s fuel-rate cadence inside it;
///  - [newSegment] — a Resume. The kill that preceded it is not a drive.
class TripStats {
  TripStats([TripTotals? seed])
    : _rows = seed?.rows ?? 0,
      _distanceKm = seed?.distanceKm,
      _coveredMs = seed?.speedCoveredMs ?? 0,
      _maxKph = seed?.maxSpeedKph,
      _fuelL = seed?.fuelUsedL;

  static const speedPid = '010D';
  static const fuelRatePid = '015E';
  static const maxBridgeMs = 15000;
  static const minAverageMs = 10000;

  int _rows;
  double? _distanceKm;
  int _coveredMs;
  double? _maxKph;
  double? _fuelL;

  int? _speedT;
  double? _speed;
  int? _fuelT;
  double? _fuel;

  /// One sample at [t] ms of recorded time, in the registry's unit. A
  /// value that is null or not finite is the same absence the file writes
  /// as an empty field.
  void add(int t, String pid, double? v) {
    _rows++;
    final x = v != null && v.isFinite ? v : null;
    if (pid == speedPid) {
      if (x == null) {
        _speedT = _speed = null;
        return;
      }
      _distanceKm ??= 0;
      if (_maxKph == null || x > _maxKph!) _maxKph = x;
      final dt = _bridge(_speedT, t);
      if (dt != null) {
        _distanceKm = _distanceKm! + (_speed! + x) / 2 * dt / _msPerHour;
        _coveredMs += dt;
      }
      _speedT = t;
      _speed = x;
    } else if (pid == fuelRatePid) {
      if (x == null) {
        _fuelT = _fuel = null;
        return;
      }
      _fuelL ??= 0;
      final dt = _bridge(_fuelT, t);
      if (dt != null) _fuelL = _fuelL! + (_fuel! + x) / 2 * dt / _msPerHour;
      _fuelT = t;
      _fuel = x;
    }
  }

  /// A new segment starts: nothing before it bridges to anything after.
  void newSegment() {
    _speedT = _speed = null;
    _fuelT = _fuel = null;
  }

  TripTotals get totals => TripTotals(
    rows: _rows,
    distanceKm: _distanceKm,
    speedCoveredMs: _coveredMs,
    maxSpeedKph: _maxKph,
    fuelUsedL: _fuelL,
  );

  static const _msPerHour = 3600000.0;

  static int? _bridge(int? from, int t) {
    if (from == null) return null;
    final dt = t - from;
    return dt > 0 && dt <= maxBridgeMs ? dt : null;
  }
}
