import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';

/// SPEC B.5 — the thin bar under every numeral that answers "is this
/// number normal?". 4px track, the normal band drawn at 22% ink, a 2×10
/// marker. Only the marker moves, and it takes 120 ms easeOut; the track
/// and bands are painted once and never repaint.
class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.position,
    this.bandLow,
    this.bandHigh,
    this.tone = Tell.none,
    this.dimmed = false,
  });

  /// 0…1 along the track. Null hides the marker (no reading).
  final ValueListenable<double?> position;

  /// 0…1 band edges. Both null: no band drawn.
  final double? bandLow;
  final double? bandHigh;

  /// Marker colour. Amber when the value is outside the band.
  final Tell tone;
  final bool dimmed;

  static const height = 10.0;
  static const trackHeight = 4.0;
  static const markerWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Static: track + band. A RepaintBoundary so marker motion never
          // repaints it.
          RepaintBoundary(
            child: CustomPaint(
              painter: _TrackPainter(
                track: t.surfacePanel,
                band: t.inkPrimary.withValues(alpha: t.bandAlpha),
                bandLow: bandLow,
                bandHigh: bandHigh,
              ),
            ),
          ),
          ValueListenableBuilder<double?>(
            valueListenable: position,
            builder: (context, p, _) {
              if (p == null) return const SizedBox.shrink();
              return TweenAnimationBuilder<double>(
                tween: Tween(end: p),
                duration: Motion.of(context, Motion.rangeBar),
                curve: Motion.easeOut,
                builder: (context, v, _) => Align(
                  alignment: Alignment(v * 2 - 1, 0),
                  child: SizedBox(
                    width: markerWidth,
                    height: height,
                    child: ColoredBox(
                      color: (tone == Tell.none ? t.inkPrimary : t.tell(tone))
                          .withValues(alpha: dimmed ? 0.4 : 1),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({
    required this.track,
    required this.band,
    this.bandLow,
    this.bandHigh,
  });

  final Color track;
  final Color band;
  final double? bandLow;
  final double? bandHigh;

  @override
  void paint(Canvas canvas, Size size) {
    final y = (size.height - RangeBar.trackHeight) / 2;
    final r = Rect.fromLTWH(0, y, size.width, RangeBar.trackHeight);
    canvas.drawRect(r, Paint()..color = track);
    if (bandLow != null || bandHigh != null) {
      final lo = (bandLow ?? 0).clamp(0.0, 1.0) * size.width;
      final hi = (bandHigh ?? 1).clamp(0.0, 1.0) * size.width;
      if (hi > lo) {
        canvas.drawRect(
          Rect.fromLTWH(lo, y, hi - lo, RangeBar.trackHeight),
          Paint()..color = band,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.track != track ||
      old.band != band ||
      old.bandLow != bandLow ||
      old.bandHigh != bandHigh;
}
