import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart' show DistanceUnit;
import '../dashboard/layout_controller.dart';
import 'trip_format.dart';
import 'trip_recorder.dart';
import 'trip_strip_content.dart';

/// SPEC §7.3 "recording past 2 min" — opened only by a tap on the line
/// that says the recording stopped there, never by the stop itself.
Future<void> showRecordingDoor(
  BuildContext context, {
  required VoidCallback onUpgrade,
}) => showAdaptiveAlert(
  context,
  title: '2-minute recordings on the free plan',
  message: 'Longer recordings are part of Pro. This trip is saved.',
  actions: [
    AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
    AdaptiveAlertAction(
      label: 'See Pro',
      isDefault: true,
      onPressed: onUpgrade,
    ),
  ],
);

/// SPEC §5.3 "trip strip" — the Dashboard's trip meter and its Record.
///
/// Sits in the slot §B.29 kept between the header and the grid. It never
/// raises a modal (the driver may be moving), never blinks, and says what
/// it cannot do as a statement, not a dimmed button (§B.26). Everything it
/// says comes from [stripContentFor]; the meter changes once a second, the
/// grid below never rebuilds for it.
class TripStrip extends StatefulWidget {
  const TripStrip({
    super.key,
    required this.recorder,
    required this.layouts,
    required this.distance,
    required this.electric,
    this.onUpgrade,
    this.onAddVehicle,
  });

  final TripRecorder recorder;

  /// For edit mode: the strip stays there only while a trip is open.
  final DashboardLayoutController layouts;
  final DistanceUnit distance;

  /// §9.4 — asked when drawn, as the grid's doors ask it.
  final bool Function() electric;
  final VoidCallback? onUpgrade;
  final VoidCallback? onAddVehicle;

  @override
  State<TripStrip> createState() => _TripStripState();
}

class _TripStripState extends State<TripStrip> {
  late int _heard = widget.recorder.eventSerial;

  @override
  void initState() {
    super.initState();
    widget.recorder.addListener(_onEvent);
  }

  @override
  void didUpdateWidget(TripStrip old) {
    super.didUpdateWidget(old);
    if (old.recorder != widget.recorder) {
      old.recorder.removeListener(_onEvent);
      widget.recorder.addListener(_onEvent);
      _heard = widget.recorder.eventSerial;
    }
  }

  @override
  void dispose() {
    widget.recorder.removeListener(_onEvent);
    super.dispose();
  }

  /// Each event is said once, politely — never per tick or per sample, and
  /// never as a live region.
  void _onEvent() {
    final r = widget.recorder;
    if (r.eventSerial == _heard) return;
    _heard = r.eventSerial;
    final e = r.lastEvent;
    if (e == null || !mounted) return;
    final said = announcementFor(
      e,
      _format(context),
      freePlan: r.reading.value?.capMs != null,
    );
    if (said != null) AdaptiveAnnounce.polite(context, said);
  }

  TripFormat _format(BuildContext context) => TripFormat(
    widget.distance,
    numberLocale: Intl.canonicalizedLocale(
      View.of(context).platformDispatcher.locale.toString(),
    ),
    use24h: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  void _act(StripActionKind kind) {
    final r = widget.recorder;
    switch (kind) {
      case StripActionKind.record:
        unawaited(r.start());
      case StripActionKind.stop:
        unawaited(AdaptiveHaptics.select());
        unawaited(r.stop());
      case StripActionKind.resume:
        unawaited(r.resume());
      case StripActionKind.notNow:
        r.declineOffer();
      case StripActionKind.addVehicle:
        widget.onAddVehicle?.call();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.recorder, widget.layouts]),
    builder: (context, _) => ValueListenableBuilder<TripReading?>(
      valueListenable: widget.recorder.reading,
      builder: (context, reading, _) {
        final content = stripContentFor(
          widget.recorder.view,
          reading,
          editing: widget.layouts.editing,
          electric: widget.electric(),
          canUpgrade: widget.onUpgrade != null,
          canAddVehicle: widget.onAddVehicle != null,
          fmt: _format(context),
        );
        if (content == null) return const SizedBox.shrink();
        return _StripBody(
          content: content,
          onAction: _act,
          onDoor: content.capDoor
              ? () => showRecordingDoor(context, onUpgrade: widget.onUpgrade!)
              : null,
        );
      },
    ),
  );
}

class _StripBody extends StatelessWidget {
  const _StripBody({
    required this.content,
    required this.onAction,
    required this.onDoor,
  });

  final StripContent content;
  final void Function(StripActionKind) onAction;
  final VoidCallback? onDoor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = content;
    final tone = switch (c.tone) {
      Tell.blue => t.tellBlue,
      Tell.amber => t.tellAmber,
      Tell.red => t.tellRed,
      Tell.green => t.tellGreen,
      Tell.none => t.inkSecondary,
    };
    final wordColor = switch (c.ink) {
      StripInk.primary => t.inkPrimary,
      StripInk.secondary => t.inkSecondary,
      StripInk.tone => tone,
    };
    final head = Wrap(
      spacing: Space.x8,
      runSpacing: Space.x4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (c.glyph != null) Icon(c.glyph, size: 16, color: tone),
        Text(
          c.word,
          style: TorqueType.label.copyWith(
            color: wordColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (c.timer != null)
          Text(
            c.timer!,
            style: TorqueType.label.copyWith(
              color: t.inkPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
    final lines = [
      for (final l in c.lines)
        Padding(
          padding: const EdgeInsets.only(top: Space.x4),
          child: Opacity(
            opacity: l.dimmed ? t.dimmedOpacity : 1,
            child: Text(
              l.text,
              style: TorqueType.meta.copyWith(color: t.inkSecondary),
            ),
          ),
        ),
    ];

    // One node for the status. When the word is the §7.3 door, the word
    // is its own button and the status node keeps the rest.
    final Widget status;
    if (onDoor != null) {
      status = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: c.word,
            onTapHint: 'about the free plan',
            onTap: onDoor,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDoor,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Targets.min),
                  child: Row(
                    children: [
                      Expanded(child: head),
                      Icon(Icons.chevron_right, color: t.inkTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (lines.isNotEmpty)
            Semantics(
              container: true,
              label: [for (final l in c.lines) l.text].join(' '),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines,
                ),
              ),
            ),
        ],
      );
    } else {
      status = Semantics(
        container: true,
        label: c.spoken,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [head, ...lines],
          ),
        ),
      );
    }

    final actions = c.actions.isEmpty
        ? null
        : Wrap(
            spacing: Space.x4,
            children: [
              for (final a in c.actions)
                GhostButton(
                  key: ValueKey(a.kind),
                  label: a.label,
                  icon: a.icon,
                  semanticLabel: a.semanticLabel,
                  onPressed: () => onAction(a.kind),
                ),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x8,
          Space.x4,
          Space.x8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.min),
          child: LayoutBuilder(
            builder: (context, box) {
              // AC-16: at large text, or on a narrow phone, the status and
              // its buttons stack instead of squeezing each other.
              final stacked =
                  c.stacked ||
                  box.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              if (actions == null) return status;
              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    status,
                    const SizedBox(height: Space.x4),
                    actions,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: Space.x12),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
