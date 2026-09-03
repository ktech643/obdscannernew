import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The five gauge treatments.
///
/// Each takes the same props the tile already has — a position along the
/// band, the band boundaries, and a tone — so switching treatment never
/// changes what the tile knows, only how it draws.
///
/// Two rules hold across all of them:
/// * **The tone drives the sweep colour.** A caution reading sweeps amber, a
///   fault sweeps red. Nothing else in the graphic takes the semantic colour.
/// * **The needle stays ink.** It marks position, which is not a judgement;
///   colouring it too would double-encode the same fact and lose the contrast
///   that makes an amber sweep read as amber.

/// Where the tone colour is applied, and where ink is held.
class GaugePalette {
  const GaugePalette({required this.sweep, required this.track});

  /// Takes the telltale tone.
  final Color sweep;

  /// The unfilled remainder. Always neutral — an empty track carries no
  /// meaning of its own.
  final Color track;

  static const _needle = T.text;

  /// The needle is ink at every tone.
  Color get needle => _needle;
}

/// A ~270° speedo with tick marks and a needle. The most decorative of the
/// five, and the one that most needs its numeral: a needle at arm's length is
/// a rough reading, so the figure below it is the real one.
class DialPainter extends CustomPainter {
  DialPainter({
    required this.position,
    required this.palette,
    this.showNeedle = true,
  });

  /// 0–100 along the sweep.
  final double position;
  final GaugePalette palette;
  final bool showNeedle;

  /// Opening at the bottom: starts lower-left, sweeps clockwise through the
  /// top to lower-right.
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = side / 2 - 8;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final fraction = (position / 100).clamp(0.0, 1.0);

    final track = Paint()
      ..color = palette.track
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, _start, _sweep, false, track);

    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _start,
        _sweep * fraction,
        false,
        Paint()
          ..color = palette.sweep
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Tick dots just outside the sweep — the instrument-cluster convention,
    // and a coarse scale for reading the needle against.
    final tick = Paint()..color = T.neutral400;
    const ticks = 21;
    for (var i = 0; i < ticks; i++) {
      final a = _start + _sweep * (i / (ticks - 1));
      final p = centre + Offset(math.cos(a), math.sin(a)) * (radius + 6);
      canvas.drawCircle(p, i % 5 == 0 ? 1.4 : 0.9, tick);
    }

    if (!showNeedle) return;
    final angle = _start + _sweep * fraction;
    final tip =
        centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 9);
    final tail = centre - Offset(math.cos(angle), math.sin(angle)) * 7;
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = palette.needle
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // Hub: a ring, not a disc, so it reads as drawn rather than filled.
    canvas.drawCircle(
      centre,
      3.5,
      Paint()
        ..color = palette.needle
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant DialPainter old) =>
      old.position != position ||
      old.palette.sweep != palette.sweep ||
      old.showNeedle != showNeedle;
}

/// A 180° sweep, no needle. Reads faster than the dial at a glance because
/// there is only one thing moving.
class ArcPainter extends CustomPainter {
  ArcPainter({required this.position, required this.palette});

  final double position;
  final GaugePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2, size.height) - 5;
    // Centre on the baseline so the semicircle sits above it.
    final centre = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final fraction = (position / 100).clamp(0.0, 1.0);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = palette.track
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt,
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * fraction,
        false,
        Paint()
          ..color = palette.sweep
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArcPainter old) =>
      old.position != position || old.palette.sweep != palette.sweep;
}

/// Seven segments filled to the current position. Quantised on purpose — it
/// reads as a coarse level, which is honest for a value the adapter is only
/// sampling a few times a second.
class SegmentBarPainter extends CustomPainter {
  SegmentBarPainter({
    required this.position,
    required this.palette,
    this.segments = 7,
  });

  final double position;
  final GaugePalette palette;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final w = (size.width - gap * (segments - 1)) / segments;
    final filled = (position / 100 * segments).ceil().clamp(0, segments);
    for (var i = 0; i < segments; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * (w + gap), 0, w, size.height),
        Paint()..color = i < filled ? palette.sweep : palette.track,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentBarPainter old) =>
      old.position != position || old.palette.sweep != palette.sweep;
}

/// A sparkline over the recent sample window — the only treatment that shows
/// where the value has been rather than only where it is.
class SparklinePainter extends CustomPainter {
  SparklinePainter({required this.samples, required this.palette});

  final List<double> samples;
  final GaugePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) {
      // One sample is not a trend. Draw the baseline rather than a line
      // implying history we don't have.
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = palette.track
          ..strokeWidth = 1,
      );
      return;
    }
    final min = samples.reduce(math.min);
    final max = samples.reduce(math.max);
    final span = (max - min).abs() < 0.0001 ? 1.0 : max - min;

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (samples.length - 1);
      final y = size.height * (1 - (samples[i] - min) / span);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.sweep
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) =>
      old.samples != samples || old.palette.sweep != palette.sweep;
}
