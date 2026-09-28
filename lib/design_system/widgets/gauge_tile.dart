import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../../domain/pid_sample.dart';
import '../spacing.dart';
import '../surfaces.dart';
import '../tokens.dart';
import '../typography.dart';
import 'range_bar.dart';

/// The five things a tile can be. Never render stale as live (hard rule 4).
enum GaugeState { live, stale, unavailable, unsupported, outOfRange }

enum GaugeVariant { numeric, arc, sparkline, bar }

/// SPEC B.5 — `GaugeTile`.
///
/// ```
/// RepaintBoundary
///   RaisedSurface
///     const chrome: header (label + state word), excluded from semantics
///     ListenableBuilder(sample + state)  ← the readout: numeral, unit,
///                                          marker, the variant graphic,
///                                          and the tile's ONE Semantics node
/// ```
///
/// The numeral is swapped, never animated. Staleness is a state, derived
/// from the shared [clock] and never stored: past 2× the expected interval
/// the *readout* fades to the tokens' dimmed opacity over 400 ms and its
/// colours drop to ink; the header word ("3 s ago", with a clock glyph)
/// stays at full strength, because the word that explains the dimming
/// must be the most legible thing on the tile. Past 5 s it shows `—` and
/// "No data" at full opacity — absence, not staleness.
///
/// One `Semantics` node per tile, carrying label, value, unit, range
/// position and freshness; `liveRegion` only when a threshold is crossed,
/// never per sample.
class GaugeTile extends StatefulWidget {
  const GaugeTile({
    super.key,
    required this.spec,
    required this.sample,
    required this.clock,
    this.expectedInterval,
    this.variant = GaugeVariant.numeric,
    this.history,
    this.onTap,
    this.onLongPress,
    this.onTapHint,
    this.onLongPressHint,
    this.semanticsSuffix,
    this.semanticsActions,
    this.primary = false,
  });

  final GaugeSpec spec;
  final ValueListenable<PidSample?> sample;

  /// Drives decay without a new sample. **Required**: a tile with no clock
  /// would hold its last value at full strength forever once samples stop —
  /// exactly the hard-rule-4 failure. Share one [DashboardClock] across the
  /// dashboard and tick it from a periodic timer independent of the command
  /// loop (a hung link must not also stop the clock).
  final ValueListenable<DateTime> clock;

  /// How long this reading waits between answers, as the session is asking
  /// for it right now (`ObdSession.cadence`). Stale is past twice this: a
  /// reading asked every second on a slow adapter is not stale at 400 ms.
  /// Null, or a null value, falls back to [GaugeSpec.expectedInterval].
  final ValueListenable<Duration?>? expectedInterval;
  final GaugeVariant variant;

  /// Recent values for the sparkline variant, oldest first.
  final ValueListenable<List<double>>? history;
  final VoidCallback? onTap;

  /// SPEC §5.3 "Long-press → edit". On the tile's one Semantics node, as
  /// its long-press action.
  final VoidCallback? onLongPress;

  /// What a tap or a long-press does, for TalkBack's "double-tap to …".
  final String? onTapHint;
  final String? onLongPressHint;

  /// Appended to the tile's spoken label: "Gauge 3 of 6".
  final String? semanticsSuffix;

  /// Screen-reader actions — move, change, remove — on the same one node,
  /// so a tile stays one stop (B.8).
  final Map<CustomSemanticsAction, VoidCallback>? semanticsActions;

  /// The hero tile uses the XL readout.
  final bool primary;

  static const staleAfterFactor = 2;
  static const unavailableAfter = Duration(seconds: 5);

  /// Default stale opacity; the high-contrast tokens raise it.
  static const dimmedOpacity = 0.4;

  /// [expectedInterval] is the session's word on how often it asks for
  /// this reading, and wins over the spec's whenever there is one.
  static GaugeState stateFor(
    GaugeSpec spec,
    PidSample? sample,
    DateTime now, {
    Duration? expectedInterval,
  }) {
    if (!spec.supported) return GaugeState.unsupported;
    final s = sample;
    if (s == null || s.value == null) return GaugeState.unavailable;
    final age = now.difference(s.at);
    if (age > unavailableAfter) return GaugeState.unavailable;
    final expected = expectedInterval ?? spec.expectedInterval;
    if (age > expected * staleAfterFactor) return GaugeState.stale;
    if (!spec.inRange(s.value!)) return GaugeState.outOfRange;
    return GaugeState.live;
  }

  /// The header's age: "3 s ago". A tile can be stale well inside its first
  /// second — twice a 135 ms cycle — and "0 s ago" beside a dimmed reading
  /// read as a contradiction, so under a second it says so.
  static String ageNote(Duration age) =>
      age < const Duration(seconds: 1) ? '<1 s ago' : '${age.inSeconds} s ago';

  /// The same age, in words for a screen reader.
  static String ageSpoken(Duration age) {
    if (age < const Duration(seconds: 1)) return 'less than a second ago';
    final s = age.inSeconds;
    return s == 1 ? '1 second ago' : '$s seconds ago';
  }

  @override
  State<GaugeTile> createState() => _GaugeTileState();
}

class _GaugeTileState extends State<GaugeTile> {
  final _state = ValueNotifier<GaugeState>(GaugeState.unavailable);
  final _position = ValueNotifier<double?>(null);

  /// Set when the state crosses into or out of a fault, consumed by the next
  /// readout build so the announcement happens exactly once.
  bool _announce = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    widget.sample.addListener(_recompute);
    widget.clock.addListener(_recompute);
    widget.expectedInterval?.addListener(_recompute);
    _recompute();
    // A tile built already at Caution has crossed nothing: it is the same
    // reading on a new tile (edit mode, a reorder), not a new fault, and a
    // live region here re-announced every Caution tile each time.
    _announce = false;
  }

  @override
  void didUpdateWidget(GaugeTile old) {
    super.didUpdateWidget(old);
    if (old.sample != widget.sample) {
      old.sample.removeListener(_recompute);
      widget.sample.addListener(_recompute);
    }
    if (old.clock != widget.clock) {
      old.clock.removeListener(_recompute);
      widget.clock.addListener(_recompute);
    }
    if (old.expectedInterval != widget.expectedInterval) {
      old.expectedInterval?.removeListener(_recompute);
      widget.expectedInterval?.addListener(_recompute);
    }
    if (old.spec != widget.spec ||
        old.sample != widget.sample ||
        old.expectedInterval != widget.expectedInterval) {
      _recompute();
    }
  }

  @override
  void dispose() {
    widget.sample.removeListener(_recompute);
    widget.clock.removeListener(_recompute);
    widget.expectedInterval?.removeListener(_recompute);
    _state.dispose();
    _position.dispose();
    super.dispose();
  }

  void _recompute() {
    final s = widget.sample.value;
    final next = GaugeTile.stateFor(
      widget.spec,
      s,
      widget.clock.value,
      expectedInterval: widget.expectedInterval?.value,
    );
    final prev = _state.value;
    if (next != prev) {
      final wasFault = prev == GaugeState.outOfRange;
      final isFault = next == GaugeState.outOfRange;
      if (wasFault != isFault) _announce = true;
      _state.value = next;
    }
    final v = s?.value;
    _position.value =
        v == null ||
            next == GaugeState.unavailable ||
            next == GaugeState.unsupported
        ? null
        : widget.spec.position(v);
  }

  bool _takeAnnounce() {
    final a = _announce;
    _announce = false;
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget tile = RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: _Chrome(
        spec: widget.spec,
        variant: widget.variant,
        primary: widget.primary,
        sample: widget.sample,
        state: _state,
        position: _position,
        history: widget.history,
        announce: _takeAnnounce,
        clock: widget.clock,
        semantics: _TileSemantics(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapHint: widget.onTapHint,
          onLongPressHint: widget.onLongPressHint,
          suffix: widget.semanticsSuffix,
          actions: widget.semanticsActions,
        ),
      ),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      // Touch goes through the detector; the accessibility actions live on
      // the readout's Semantics node, so the detector adds no node of its own.
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        // Long-press callbacks only with a long-press: any one of them makes
        // a recogniser that, after half a second, wins the arena and does
        // nothing — a held tile in edit mode could then not be swiped,
        // tapped or scrolled.
        onLongPress: widget.onLongPress,
        onLongPressEnd: widget.onLongPress == null
            ? null
            : (_) => setState(() => _pressed = false),
        onLongPressCancel: widget.onLongPress == null
            ? null
            : () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: Motion.of(context, Motion.tilePress),
          child: tile,
        ),
      );
    }

    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Targets.min * 2),
        child: DefaultTextStyle(
          style: TorqueType.body.copyWith(color: t.inkPrimary),
          child: tile,
        ),
      ),
    );
  }
}

/// Everything that does not change at 10 Hz. Built once; excluded from
/// semantics because the readout node already says all of it in words.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.spec,
    required this.variant,
    required this.primary,
    required this.sample,
    required this.state,
    required this.position,
    required this.history,
    required this.announce,
    required this.clock,
    required this.semantics,
  });

  final GaugeSpec spec;
  final GaugeVariant variant;
  final bool primary;
  final ValueListenable<PidSample?> sample;
  final ValueListenable<GaugeState> state;
  final ValueListenable<double?> position;
  final ValueListenable<List<double>>? history;
  final bool Function() announce;
  final ValueListenable<DateTime> clock;
  final _TileSemantics semantics;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  spec.label.toUpperCase(),
                  style: TorqueType.gaugeLabel.copyWith(color: t.inkSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.x8),
              _StateNote(state: state, sample: sample, clock: clock),
            ],
          ),
        ),
        const SizedBox(height: Space.x8),
        _Readout(
          spec: spec,
          variant: variant,
          primary: primary,
          sample: sample,
          state: state,
          position: position,
          history: history,
          announce: announce,
          clock: clock,
          semantics: semantics,
        ),
      ],
    );
  }
}

/// What the tile's one Semantics node offers besides its label.
@immutable
class _TileSemantics {
  const _TileSemantics({
    this.onTap,
    this.onLongPress,
    this.onTapHint,
    this.onLongPressHint,
    this.suffix,
    this.actions,
  });
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? onTapHint;
  final String? onLongPressHint;
  final String? suffix;
  final Map<CustomSemanticsAction, VoidCallback>? actions;
}

/// The top-right word: "Caution", "4 s ago", "<1 s ago", "No data",
/// "Not supported".
/// Rebuilds on state change, and on the clock while stale (for the age).
/// Always at full strength — it is the word that explains the readout.
class _StateNote extends StatelessWidget {
  const _StateNote({
    required this.state,
    required this.sample,
    required this.clock,
  });
  final ValueListenable<GaugeState> state;
  final ValueListenable<PidSample?> sample;
  final ValueListenable<DateTime> clock;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TorqueType.meta.copyWith(color: t.inkSecondary);
    return ValueListenableBuilder<GaugeState>(
      valueListenable: state,
      builder: (context, s, _) => switch (s) {
        GaugeState.live => const SizedBox.shrink(),
        GaugeState.unsupported => Text('Not supported', style: style),
        GaugeState.unavailable => Text('No data', style: style),
        GaugeState.outOfRange => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Tell.amber.glyph, size: 12, color: t.tellAmber),
            const SizedBox(width: Space.x4),
            Text(
              Tell.amber.word,
              style: TorqueType.meta.copyWith(color: t.tellAmber),
            ),
          ],
        ),
        GaugeState.stale => ValueListenableBuilder<DateTime>(
          valueListenable: clock,
          builder: (context, now, _) {
            final at = sample.value?.at;
            final age = at == null ? Duration.zero : now.difference(at);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 12, color: t.inkSecondary),
                const SizedBox(width: Space.x4),
                Text(GaugeTile.ageNote(age), style: style),
              ],
            );
          },
        ),
      },
    );
  }
}

/// The numeral, the unit, the marker — and for the graphic variants, the
/// graphic. The only subtree that rebuilds per sample (and on the rare
/// state change). Carries the tile's single Semantics node.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.spec,
    required this.variant,
    required this.primary,
    required this.sample,
    required this.state,
    required this.position,
    required this.history,
    required this.announce,
    required this.clock,
    required this.semantics,
  });

  final GaugeSpec spec;
  final GaugeVariant variant;
  final bool primary;
  final ValueListenable<PidSample?> sample;
  final ValueListenable<GaugeState> state;
  final ValueListenable<double?> position;
  final ValueListenable<List<double>>? history;
  final bool Function() announce;
  final ValueListenable<DateTime> clock;
  final _TileSemantics semantics;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Listens to the sample *and* the state: the clock can move a tile from
    // stale to unavailable with no new sample, and the numeral must become
    // a dash the moment it does.
    return ListenableBuilder(
      listenable: Listenable.merge([sample, state]),
      builder: (context, _) {
        final s = sample.value;
        final st = state.value;
        final showValue =
            st != GaugeState.unavailable && st != GaugeState.unsupported;
        final dimmed = st == GaugeState.stale;
        final text = showValue ? spec.format(s?.value) : '—';
        // Desaturation is a colour choice, not a filter: amber drops to ink
        // while stale. No ColorFilter layer, nothing re-inflated.
        final tone = st == GaugeState.outOfRange ? Tell.amber : Tell.none;
        final numeralColor = switch (st) {
          GaugeState.outOfRange => t.tellAmber,
          GaugeState.stale => t.inkSecondary,
          _ => t.inkPrimary,
        };
        final numeralStyle =
            (primary ? TorqueType.readoutXl : TorqueType.readoutLg).copyWith(
              color: numeralColor,
            );

        // Scales down rather than overflows: a six-digit PID at text scale
        // 2.0 in a 2-up tile is still one whole numeral.
        final numeral = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, style: numeralStyle, maxLines: 1),
              ),
            ),
            if (spec.unit.isNotEmpty) ...[
              const SizedBox(width: Space.x4),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.x4),
                  child: Text(
                    spec.unit,
                    style: TorqueType.unit.copyWith(color: t.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        );

        final bar = RangeBar(
          position: position,
          bandLow: spec.bandLow,
          bandHigh: spec.bandHigh,
          tone: tone,
          dimmed: dimmed,
        );

        final Widget body = switch (variant) {
          GaugeVariant.numeric => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              numeral,
              const SizedBox(height: Space.x8),
              bar,
            ],
          ),
          GaugeVariant.bar => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              numeral,
              const SizedBox(height: Space.x8),
              _SegmentBar(
                position: position.value,
                color: numeralColor,
                dim: !showValue,
              ),
            ],
          ),
          // The arc sits above the numeral, never around it: a 4-digit RPM
          // at text scale 2.0 has nowhere to fit inside a 2-up arc.
          GaugeVariant.arc => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ArcPainter(
                    position: position.value,
                    bandLow: spec.bandLow,
                    bandHigh: spec.bandHigh,
                    track: t.surfacePanel,
                    band: t.inkPrimary.withValues(alpha: t.bandAlpha),
                    fill: numeralColor,
                  ),
                ),
              ),
              const SizedBox(height: Space.x4),
              Center(child: numeral),
            ],
          ),
          GaugeVariant.sparkline => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              numeral,
              const SizedBox(height: Space.x8),
              SizedBox(
                height: 28,
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: history ?? const _Empty(),
                  builder: (context, points, _) => CustomPaint(
                    painter: _SparkPainter(
                      points: points,
                      spec: spec,
                      color: numeralColor,
                      band: t.inkPrimary.withValues(alpha: t.bandAlpha),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: Space.x4),
              bar,
            ],
          ),
        };

        final base = _semanticLabel(s, st);
        return Semantics(
          container: true,
          button: semantics.onTap != null,
          onTap: semantics.onTap,
          onLongPress: semantics.onLongPress,
          onTapHint: semantics.onTapHint,
          onLongPressHint: semantics.onLongPressHint,
          customSemanticsActions: semantics.actions,
          liveRegion: announce(),
          label: semantics.suffix == null ? base : '$base. ${semantics.suffix}',
          child: ExcludeSemantics(
            child: AnimatedOpacity(
              opacity: dimmed ? t.dimmedOpacity : 1,
              duration: Motion.of(context, Motion.stalenessDecay),
              child: body,
            ),
          ),
        );
      },
    );
  }

  /// Everything the sighted user gets from colour and opacity, in words.
  String _semanticLabel(PidSample? s, GaugeState st) {
    final unit = spec.unit.isEmpty ? '' : ' ${spec.unit}';
    final v = spec.format(s?.value);
    switch (st) {
      case GaugeState.unsupported:
        return '${spec.label}, not available on this vehicle';
      case GaugeState.unavailable:
        return '${spec.label}, no data';
      case GaugeState.stale:
        final age = s == null ? Duration.zero : clock.value.difference(s.at);
        return '${spec.label}, $v$unit, ${GaugeTile.ageSpoken(age)}. '
            'This reading is not live';
      case GaugeState.outOfRange:
        return '${spec.label}, $v$unit, caution, outside its normal range';
      case GaugeState.live:
        final p = s?.value == null ? null : spec.position(s!.value!);
        final where = p == null
            ? ''
            : p < 0.33
            ? ', low in range'
            : p > 0.67
            ? ', high in range'
            : ', mid-range';
        return '${spec.label}, $v$unit$where';
    }
  }
}

class _Empty extends ValueListenable<List<double>> {
  const _Empty();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  List<double> get value => const [];
}

/// Seven segments filled to the current position.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.position,
    required this.color,
    required this.dim,
  });
  final double? position;
  final Color color;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = position == null ? 0 : (position! * 7).ceil().clamp(0, 7);
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: SizedBox(
              height: 6,
              child: ColoredBox(
                color: !dim && i < filled ? color : t.surfacePanel,
              ),
            ),
          ),
          if (i < 6) const SizedBox(width: Space.x4),
        ],
      ],
    );
  }
}

/// A 180° sweep, no needle: track, band, then fill to the position.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.position,
    required this.bandLow,
    required this.bandHigh,
    required this.track,
    required this.band,
    required this.fill,
  });

  final double? position;
  final double? bandLow;
  final double? bandHigh;
  final Color track;
  final Color band;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final r = math.min(size.width / 2, size.height) - stroke;
    if (r <= 0) return;
    final c = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    void arc(double from, double to, Color color) {
      if (to <= from) return;
      canvas.drawArc(
        rect,
        math.pi + from * math.pi,
        (to - from) * math.pi,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(0, 1, track);
    if (bandLow != null || bandHigh != null) {
      arc(bandLow ?? 0, bandHigh ?? 1, band);
    }
    if (position != null) {
      arc(0, position!, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.position != position ||
      old.fill != fill ||
      old.bandLow != bandLow ||
      old.bandHigh != bandHigh;
}

/// A polyline over the recent window, the normal band behind it.
///
/// Scaled to the normal band widened by half its width on each side (or
/// the physical range when there is no band): coolant wandering 84–91 °C
/// on a 0–150 axis is a flat line and says nothing; on a 60–120 axis it
/// shows the warm-up and the thermostat cycling.
class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.points,
    required this.spec,
    required this.color,
    required this.band,
  });

  final List<double> points;
  final GaugeSpec spec;
  final Color color;
  final Color band;

  ({double low, double high}) get _axis {
    final nl = spec.normalLow ?? spec.min;
    final nh = spec.normalHigh ?? spec.max;
    if (!spec.hasBand || nh <= nl) return (low: spec.min, high: spec.max);
    final half = (nh - nl) / 2;
    return (
      low: math.max(spec.min, nl - half),
      high: math.min(spec.max, nh + half),
    );
  }

  double _y(double value, Size size) {
    final a = _axis;
    final span = a.high - a.low;
    final p = span <= 0 ? 0.5 : ((value - a.low) / span).clamp(0.0, 1.0);
    return size.height * (1 - p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (spec.hasBand) {
      final top = _y(spec.normalHigh ?? _axis.high, size);
      final bottom = _y(spec.normalLow ?? _axis.low, size);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = band,
      );
    }
    if (points.length < 2) return;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      // History holds raw samples; the axis is in the displayed unit.
      final y = _y(spec.display.apply(points[i]), size);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      !listEquals(old.points, points) || old.color != color;
}
