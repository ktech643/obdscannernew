import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../surfaces.dart';
import '../tokens.dart';
import 'range_bar.dart';

/// SPEC B.6 — Loading: skeletons that match the final geometry, so nothing
/// jumps when the data lands. A slow pulse; static under reduced motion.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Radii.chip,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfacePanel,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gauge-tile-shaped skeleton: the same surface, padding, minimum height
/// and row heights as a numeric `GaugeTile`, so the grid does not move when
/// the first sample lands. Tested against the live tile's height.
class GaugeTileSkeleton extends StatelessWidget {
  const GaugeTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: Targets.min * 2),
    child: const RaisedSurface(
      padding: EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // gaugeLabel: 12 × 1.17
          Skeleton(width: 72, height: 14),
          SizedBox(height: Space.x8),
          // readoutLg: 40 × 1.0
          Skeleton(width: 96, height: 40),
          SizedBox(height: Space.x8),
          // The RangeBar box with its 4px track.
          SizedBox(
            height: RangeBar.height,
            child: Center(
              child: Skeleton(height: RangeBar.trackHeight, radius: 0),
            ),
          ),
        ],
      ),
    ),
  );
}
