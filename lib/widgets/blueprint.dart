import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// A framed object in the Industry system: 1px hairline, zero radius, no fill,
/// and `+` registration marks at all four corners.
///
/// The marks are drawn *outside* the box, so the widget reserves 6px of
/// overflow room on every side. Do not drop them — every framed element in the
/// system carries all four.
class Blueprint extends StatelessWidget {
  const Blueprint({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = EdgeInsets.zero,
    this.corners = true,
    this.fill,
    this.width,
    this.height,
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsets padding;
  final bool corners;

  /// Cards and figures are transparent line drawings. A fill here is the
  /// exception, not the rule.
  final Color? fill;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: borderColor ?? T.divider, width: 1),
      ),
      child: child,
    );
    if (!corners) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        const Positioned(top: -6, left: -6, child: _Corner()),
        const Positioned(top: -6, right: -6, child: _Corner()),
        const Positioned(bottom: -6, left: -6, child: _Corner()),
        const Positioned(bottom: -6, right: -6, child: _Corner()),
      ],
    );
  }
}

/// One 11×11 registration mark — a `+` with its strokes at the 5px offset,
/// matching `.blueprint > .corner` in the token sheet.
class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 11,
    height: 11,
    child: CustomPaint(painter: _CornerPainter()),
  );
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = T.text.withValues(alpha: 0.55);
    canvas.drawRect(const Rect.fromLTWH(5, 0, 1, 11), p);
    canvas.drawRect(const Rect.fromLTWH(0, 5, 11, 1), p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}

/// Convenience wrapper for the common case: a blueprint card with the standard
/// internal padding, laid out in a column.
class BlueprintCard extends StatelessWidget {
  const BlueprintCard({
    super.key,
    required this.children,
    this.borderColor,
    this.fill,
    this.padding = const EdgeInsets.fromLTRB(14, 13, 14, 14),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final Color? borderColor;
  final Color? fill;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Blueprint(
    borderColor: borderColor,
    fill: fill,
    padding: padding,
    child: Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}

/// A placeholder plate — ad slots, vehicle photos and preview boxes. Hairline
/// framed, filled with `--color-neutral-200`, never a shimmer.
class Plate extends StatelessWidget {
  const Plate({
    super.key,
    this.height,
    this.width,
    this.child,
    this.corners = false,
    this.hatched = false,
  });

  final double? height;
  final double? width;
  final Widget? child;
  final bool corners;
  final bool hatched;

  @override
  Widget build(BuildContext context) => Blueprint(
    corners: corners,
    width: width,
    height: height,
    fill: hatched ? null : T.neutral200,
    child: hatched
        ? CustomPaint(
            painter: HatchPainter(),
            child: Center(child: child),
          )
        : Center(child: child),
  );
}

/// 135° repeating hatch — the "not available" treatment. Matches the
/// `repeating-linear-gradient(135deg, neutral-300 0 3px, transparent 3px 6px)`
/// used on unsupported gauge tiles.
class HatchPainter extends CustomPainter {
  HatchPainter({this.color = T.neutral300});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // 135° stripes: draw along the anti-diagonal at a 6px period.
    for (double x = -size.height; x < size.width + size.height; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HatchPainter oldDelegate) =>
      oldDelegate.color != color;
}
