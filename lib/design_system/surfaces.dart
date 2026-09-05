import 'package:flutter/widgets.dart';

import 'spacing.dart';
import 'tokens.dart';

/// A raised surface: `surfaceRaised`, a radius, and the 1px top-edge white
/// highlight at 6% that stands in for elevation. Never a shadow.
class RaisedSurface extends StatelessWidget {
  const RaisedSurface({
    super.key,
    required this.child,
    this.radius = Radii.tile,
    this.padding = EdgeInsets.zero,
    this.color,
    this.topOnly = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Defaults to `surfaceRaised`; pass `surfacePanel` for inputs/headers.
  final Color? color;

  /// Sheets round the top corners only.
  final bool topOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = Radius.circular(radius);
    return ClipRRect(
      borderRadius: topOnly
          ? BorderRadius.vertical(top: r)
          : BorderRadius.all(r),
      child: TopEdge(
        child: DecoratedBox(
          decoration: BoxDecoration(color: color ?? t.surfaceRaised),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The 1px top edge, painted above the surface so the highlight sits on
/// the glass rather than under it.
class TopEdge extends StatelessWidget {
  const TopEdge({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _TopEdgePainter(context.tokens.edgeHighlight),
    child: child,
  );
}

class _TopEdgePainter extends CustomPainter {
  const _TopEdgePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TopEdgePainter old) => old.color != color;
}

/// A 1px rule in `hairline`.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.vertical = false});
  final bool vertical;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: vertical ? 1 : null,
    height: vertical ? null : 1,
    child: ColoredBox(color: context.tokens.hairline),
  );
}
