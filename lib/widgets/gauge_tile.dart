import 'package:flutter/widgets.dart';

import '../models/enums.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'blueprint.dart';
import 'gauge_treatments.dart';

/// The signature component: a blueprint tile carrying one PID.
///
/// Four states. `live` is full opacity; `stale` fades to 42% and shows its age;
/// `unavailable` shows `—`; `unsupported` says so in words and hatches out the
/// range bar. A stale number is never displayed as if it were live.
///
/// Five treatments, selected by [type], all sharing this one component and one
/// set of props. Whichever is chosen, the numeral is printed in figures — a
/// dial is a second reading of the same value, never the only one.
class GaugeTile extends StatelessWidget {
  const GaugeTile({
    super.key,
    required this.reading,
    this.onTap,
    this.editing = false,
    this.now,
    this.type = TileType.figure,
    this.selected = false,
  });

  final GaugeReading reading;
  final VoidCallback? onTap;
  final bool editing;

  /// Which of the five treatments to draw. Set per tile, per vehicle.
  final TileType type;

  /// Marks the tile the theme picker is currently targeting.
  final bool selected;

  /// The clock the decay is resolved against. Injected so tests and the
  /// scenario fixtures can pin it; defaults to the wall clock.
  final DateTime? now;

  DateTime get _now => now ?? DateTime.now();

  /// Resolved from [reading]'s own age, not taken on trust from a fixture.
  TileState get _state => reading.stateAt(_now);

  String? get _note => reading.ageNoteAt(_now);

  Color get _valueColor => switch (_state) {
    TileState.stale || TileState.unavailable => T.neutral700,
    _ => switch (reading.tone) {
      Tone.caution => T.cautionText,
      Tone.fault => T.fault,
      Tone.pass => T.passText,
      Tone.ink => T.text,
    },
  };

  Color get _noteColor => switch (reading.tone) {
    Tone.caution => T.cautionText,
    Tone.fault => T.fault,
    _ => T.neutral700,
  };

  Color get _borderColor => selected
      ? T.accent700
      : switch (reading.tone) {
          Tone.caution => T.cautionBorder,
          Tone.fault => T.fault,
          _ => T.divider,
        };

  /// The tone drives the sweep; the track stays neutral and the needle stays
  /// ink. A stale tile sweeps neutral too — a dimmed amber arc would still
  /// read as a live warning.
  GaugePalette get _palette => GaugePalette(
    sweep: switch (_state) {
      TileState.stale || TileState.unavailable => T.neutral500,
      _ => switch (reading.tone) {
        Tone.caution => T.cautionBorder,
        Tone.fault => T.fault,
        Tone.pass => T.pass,
        Tone.ink => T.accent,
      },
    },
    track: T.neutral300,
  );

  /// 42% once stale. The staleness decay and the one-shot fault pulse are the
  /// only motion in the app that the user did not trigger.
  double get _opacity => switch (_state) {
    TileState.stale || TileState.unavailable => 0.42,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final unsupported = _state == TileState.unsupported;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      container: true,
      button: onTap != null,
      // Everything colour and opacity convey is spoken here in words — a
      // VoiceOver user must not be the only one who can't tell live from stale.
      label: reading.semanticLabelAt(_now),
      excludeSemantics: true,
      child: _PressScale(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: Duration(milliseconds: reduceMotion ? 0 : 400),
          curve: Curves.easeOut,
          child: Blueprint(
            height: type.tileHeight,
            borderColor: _borderColor,
            child: ClipRect(
              child: Padding(
                // 12px 13px 0 — the range bar bleeds to the tile edges below.
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
                child: unsupported ? _unsupported() : _live(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _live() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _header(),
      if (type.numeralInsideGraphic)
        // Dial and arc centre the numeral inside their own graphic.
        Expanded(child: _graphicWithNumeral())
      else ...[
        const Spacer(),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _numeral()),
        _flatGraphic(),
      ],
    ],
  );

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          reading.label.toUpperCase(),
          style: Type.pidLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // Edit mode puts a drag handle and a remove control in this corner, so
      // the note stands down rather than colliding with them. The tone still
      // reads from the border and the numeral.
      if (_note != null && !editing)
        Text(
          _note!.toUpperCase(),
          style: Type.gaugeNote(_noteColor),
          textAlign: TextAlign.right,
        ),
    ],
  );

  /// The numeral, laid out on a baseline with its unit beside it. Used by the
  /// three flat treatments.
  Widget _numeral() => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Flexible(
        child: Text(
          reading.valueTextAt(_now),
          style: Type.gaugeNumeral(_valueColor),
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
      ),
      const SizedBox(width: 5),
      Text(reading.unit, style: _unitStyle),
    ],
  );

  static final _unitStyle = Type.gaugeNote(T.neutral700)
      .copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.66);

  /// Bar, trace and figure keep the numeral above and the graphic below.
  Widget _flatGraphic() => switch (type) {
    TileType.bar => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 12,
        child: CustomPaint(
          painter: SegmentBarPainter(
            position: reading.position,
            palette: _palette,
          ),
          size: Size.infinite,
        ),
      ),
    ),
    TileType.trace => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 26,
        child: CustomPaint(
          painter: SparklinePainter(
            samples: reading.samples,
            palette: _palette,
          ),
          size: Size.infinite,
        ),
      ),
    ),
    // The figure treatment keeps the system's range bar, which bleeds to the
    // tile edges — hence the negative margin against the tile's own padding.
    _ => RangeBar(
      position: reading.position,
      cautionAt: reading.cautionAt,
      criticalAt: reading.criticalAt,
    ),
  };

  /// Dial and arc: the graphic carries the numeral, and the numeral is still
  /// the reading — the sweep is a second view of the same number.
  Widget _graphicWithNumeral() {
    final dial = type == TileType.dial;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // The painter is the sizing widget and the numeral is its child, so the
      // graphic always gets the tile's real box. A Positioned.fill inside a
      // loose Stack collapses it to the numeral's size instead.
      child: SizedBox.expand(
        child: CustomPaint(
          painter: dial
              ? DialPainter(position: reading.position, palette: _palette)
              : ArcPainter(position: reading.position, palette: _palette),
          child: Align(
            // Low in the dial's face; inside the arc's opening.
            alignment: dial
                ? const Alignment(0, 0.52)
                : const Alignment(0, 0.95),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reading.valueTextAt(_now),
                  style: Type.gaugeNumeral(_valueColor)
                      .copyWith(fontSize: dial ? 25 : 30),
                  maxLines: 1,
                ),
                Text(reading.unit.toUpperCase(), style: _unitStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unsupported() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(reading.label.toUpperCase(), style: Type.pidLabel),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Not available on\nthis vehicle',
          style: Type.rowPrimary.copyWith(height: 1.3, color: T.neutral700),
        ),
      ),
      // The bar is hatched rather than absent — the tile keeps its
      // geometry so the grid never reflows when support is discovered.
      SizedBox(
        height: 5,
        child: CustomPaint(
          painter: HatchPainter(),
          size: const Size.fromHeight(5),
        ),
      ),
    ],
  );
}

/// The 5px band strip at the foot of a tile: normal / caution / critical, with
/// a 2px ink marker at the current value.
class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.position,
    this.cautionAt,
    this.criticalAt,
    this.height = 5,
  });

  /// 0–100 along the bar.
  final double position;
  final double? cautionAt;
  final double? criticalAt;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c1 = cautionAt ?? 100;
    final c2 = criticalAt ?? 100;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: w * c1 / 100,
                    child: const ColoredBox(
                      color: T.bandNormal,
                      child: SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    width: w * (c2 - c1) / 100,
                    child: const ColoredBox(
                      color: T.bandCaution,
                      child: SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    width: w * (100 - c2) / 100,
                    child: const ColoredBox(
                      color: T.bandCritical,
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
              // 120 ms ease-out. The marker is the only thing on a tile that
              // animates — the numeral itself swaps directly.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                left: (w * position / 100 - 1).clamp(0, w - 2),
                top: 0,
                bottom: 0,
                child: const ColoredBox(
                  color: T.text,
                  child: SizedBox(width: 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 80 ms scale-to-0.98 press feedback. Honours Reduce Motion.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: Duration(milliseconds: reduceMotion ? 0 : 80),
        child: widget.child,
      ),
    );
  }
}
