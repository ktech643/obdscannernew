import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import 'dashboard_layout.dart';
import 'layout_controller.dart';

/// Whose Dashboard this is, in words.
String ownerOf(LayoutTarget t) => switch (t) {
  VehicleTarget(:final nickname) => nickname,
  DemoTarget() => 'Demo car',
  NoVehicleTarget() || LoadingTarget() => 'No car in the garage',
};

/// The style's name as the user sees it. "Trace" is the design board's
/// word; "sparkline" is jargon.
String variantName(GaugeVariant v) => switch (v) {
  GaugeVariant.numeric => 'Number',
  GaugeVariant.arc => 'Arc',
  GaugeVariant.sparkline => 'Trace',
  GaugeVariant.bar => 'Bar',
};

/// Every word the Dashboard says about an edit — for the status line and,
/// with [a11y], for the screen reader. One place, in English.
String eventText(
  LayoutEvent? e, {
  required String owner,
  bool a11y = false,
  bool describeActions = false,
}) {
  if (e == null) return '';
  return switch (e.kind) {
    LayoutEventKind.entered =>
      a11y || describeActions
          ? 'Editing gauges. Each gauge has actions to move it, change it or '
                'remove it.'
          // Words, not the grip's glyph: Barlow has no braille cell, and
          // the golden showed an empty box where it stood.
          : 'Tap a gauge to change it. Drag it by its grip to move it. Swipe '
                'it sideways to remove it.',
    LayoutEventKind.moved =>
      '${e.label} moved to gauge ${e.position} of ${e.count}',
    LayoutEventKind.removed =>
      '${e.label} removed. Undo is at the top.'
          '${e.revealed == null ? '' : ' ${e.revealed} is now shown.'}',
    LayoutEventKind.added =>
      '${e.label} added, gauge ${e.position} of ${e.count}',
    LayoutEventKind.replaced => '${e.label} changed to ${e.other}',
    LayoutEventKind.restyled =>
      '${e.label} shown as ${variantName(GaugeVariant.values.byName(e.other!))}',
    LayoutEventKind.undone => 'Undone: ${e.other} ${e.label}',
    LayoutEventKind.switched => 'Showing ${e.label}',
    LayoutEventKind.saveFailed =>
      "Couldn't save the last change. Tap Done to try again.",
    LayoutEventKind.ended => switch (e.reason) {
      EndReason.moving =>
        'Editing stopped while moving. Your changes are saved.',
      EndReason.targetChanged => "Now showing $owner's gauges",
      _ => 'Done editing',
    },
  };
}

/// Above the grid, outside edit mode: whose gauges these are, the layout,
/// and the way into edit mode. Moving (§8.4), the way in is a statement —
/// "Edit when parked" — not a dimmed button.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.layouts,
    required this.onEdit,
    required this.onLayouts,
  });

  final DashboardLayoutController layouts;
  final VoidCallback onEdit;
  final VoidCallback onLayouts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = layouts.active;
    final showLayout =
        active != null &&
        (layouts.isPro || layouts.layouts.length > 1) &&
        !layouts.gated;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter - Space.x16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Targets.min),
        child: Row(
          children: [
            const SizedBox(width: Space.x16),
            // The name's side takes every spare point, so Edit sits at the
            // edge: a Flexible name beside a Spacer split the room in two,
            // and a short name left Edit mid-row.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ownerOf(layouts.target),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TorqueType.label.copyWith(color: t.inkSecondary),
                    ),
                  ),
                  if (showLayout)
                    Flexible(
                      child: GhostButton(
                        label: active.name,
                        icon: Icons.view_module_outlined,
                        semanticLabel: '${active.name}, change layout',
                        onPressed: onLayouts,
                      ),
                    ),
                ],
              ),
            ),
            if (layouts.gated)
              Semantics(
                container: true,
                label:
                    'Editing is off while the car is moving. Edit when '
                    'parked.',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.x16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 18,
                          color: t.inkSecondary,
                        ),
                        const SizedBox(width: Space.x4),
                        Text(
                          'Edit when parked',
                          style: TorqueType.label.copyWith(
                            color: t.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              GhostButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                semanticLabel: 'Edit gauges',
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

/// The header in edit mode. The word "Editing" states the mode — never
/// colour alone — and Done sits where Edit was, so the thumb finds the way
/// out where it came in.
class EditBar extends StatelessWidget {
  const EditBar({
    super.key,
    required this.layouts,
    required this.onDone,
    required this.onLayouts,
    this.status,
  });

  final DashboardLayoutController layouts;
  final VoidCallback onDone;
  final VoidCallback onLayouts;

  /// A line the screen sets itself ("Keep at least one gauge…"); else the
  /// last event's words.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final owner = ownerOf(layouts.target);
    final line =
        status ??
        eventText(
          layouts.lastEvent,
          owner: owner,
          describeActions: MediaQuery.accessibleNavigationOf(context),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x8,
        Space.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Editing · $owner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                ),
              ),
              const SizedBox(width: Space.x12),
              PrimaryButton(label: 'Done', expand: false, onPressed: onDone),
            ],
          ),
          const SizedBox(height: Space.x8),
          if (line.isNotEmpty)
            Text(line, style: TorqueType.meta.copyWith(color: t.inkSecondary)),
          if (layouts.target is DemoTarget) ...[
            const SizedBox(height: Space.x4),
            Text(
              'Demo Mode — changes last until you leave the demo.',
              style: TorqueType.meta.copyWith(color: t.inkSecondary),
            ),
          ],
          if (layouts.saveError) ...[
            const SizedBox(height: Space.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Tell.red.glyph, size: 14, color: t.tellRed),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Text(
                    "Couldn't save the last change. Tap Done to try again.",
                    style: TorqueType.meta.copyWith(color: t.tellRed),
                  ),
                ),
              ],
            ),
          ],
          Wrap(
            spacing: Space.x8,
            children: [
              if (layouts.canUndo)
                GhostButton(
                  label: layouts.undoLabel!,
                  icon: Icons.undo,
                  onPressed: layouts.undo,
                ),
              GhostButton(
                label: 'Layouts',
                icon: Icons.view_module_outlined,
                onPressed: onLayouts,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
