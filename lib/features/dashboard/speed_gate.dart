import 'package:flutter/foundation.dart';

import '../../domain/pid_sample.dart';

/// SPEC §8.4 — "Tile editing disabled above 5 km/h; display stays live."
///
/// Moving is a Speed (010D) sample no older than the tile's own "No data"
/// threshold and above the limit. A car without Speed, or with no fresh
/// sample, is not known to be moving, and editing is allowed — as the
/// earlier dashboard's gate allowed it. Samples stay metric, so the mph
/// setting changes nothing here. [moving] notifies only when the answer
/// flips: nothing downstream rebuilds per sample (hard rule 3).
class SpeedGate {
  SpeedGate({
    required this.speed,
    required this.clock,
    this.link,
    this.isLive,
  }) {
    speed.addListener(_check);
    clock.addListener(_check);
    link?.addListener(_check);
    _check();
  }

  static const pid = '010D';
  static const limitKph = 5.0;
  static const freshFor = Duration(seconds: 5);

  /// The Speed notifier on the bus, and the Dashboard's shared clock.
  final ValueListenable<PidSample?> speed;
  final ValueListenable<DateTime> clock;

  /// The session, and whether it has a live link. The clock stops with the
  /// link: after a reconnect that gave up, the last Speed reading — 68 km/h
  /// — stayed "fresh" against a clock that no longer moved, and edit mode
  /// stayed locked in a parked car. No link, not known to be moving.
  final Listenable? link;
  final bool Function()? isLive;
  final _moving = ValueNotifier<bool>(false);

  ValueListenable<bool> get moving => _moving;

  /// Exactly [limitKph] is parked enough.
  static bool isMoving(PidSample? s, DateTime now) {
    final v = s?.value;
    if (s == null || v == null) return false;
    return now.difference(s.at) <= freshFor && v > limitKph;
  }

  void _check() => _moving.value =
      (isLive?.call() ?? true) && isMoving(speed.value, clock.value);

  void dispose() {
    speed.removeListener(_check);
    clock.removeListener(_check);
    link?.removeListener(_check);
    _moving.dispose();
  }
}
