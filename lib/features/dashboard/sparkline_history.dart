import 'package:flutter/foundation.dart';

import '../../domain/pid_sample.dart';

/// The last minute of one reading, for a tile drawn as a trace.
///
/// Kept only for tiles shown that way — one listener on that PID's own
/// notifier, no extra round trip. A new list per accepted sample, because
/// the painter compares lists by value and one mutated in place would
/// never repaint.
class SparklineHistory extends ValueNotifier<List<double>> {
  SparklineHistory(this._source) : super(const []) {
    _source.addListener(_onSample);
  }

  static const window = Duration(seconds: 60);
  static const minSpacing = Duration(milliseconds: 250);
  static const maxPoints = 240;

  final ValueListenable<PidSample?> _source;
  final _points = <(DateTime, double)>[];

  void _onSample() {
    final s = _source.value;
    final v = s?.value;
    if (s == null || v == null) return;
    if (_points.isNotEmpty) {
      final last = _points.last.$1;
      if (!s.at.isAfter(last) || s.at.difference(last) < minSpacing) return;
    }
    _points.add((s.at, v));
    final cutoff = s.at.subtract(window);
    _points.removeWhere((p) => p.$1.isBefore(cutoff));
    while (_points.length > maxPoints) {
      _points.removeAt(0);
    }
    value = List.unmodifiable([for (final p in _points) p.$2]);
  }

  /// A new connection: the old trace is not this drive's.
  void reset() {
    _points.clear();
    value = const [];
  }

  @override
  void dispose() {
    _source.removeListener(_onSample);
    super.dispose();
  }
}
