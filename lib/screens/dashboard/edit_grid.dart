import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/gauge_tile.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// The edit-mode grid: drag to reorder, swipe to remove, tap to retarget.
///
/// The caption on the edit screen promises all three, so all three are real
/// gestures here rather than buttons standing in for them. The × remains as
/// well — a swipe is not discoverable, and this screen may be used with
/// gloves on.
class EditGrid extends StatefulWidget {
  const EditGrid({super.key, required this.onPickPid});

  /// Opens the PID picker for a tile that is being retargeted.
  final void Function(GaugeReading tile) onPickPid;

  @override
  State<EditGrid> createState() => _EditGridState();
}

class _EditGridState extends State<EditGrid> {
  /// The tile currently under the finger, by PID.
  String? _dragging;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final tiles = d.tiles;

    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - T.gridGutter) / 2;
        return Wrap(
          spacing: T.gridGutter,
          runSpacing: T.gridGutter,
          children: [
            for (var i = 0; i < tiles.length; i++)
              SizedBox(
                width: w,
                child: _EditableTile(
                  tile: tiles[i],
                  index: i,
                  width: w,
                  dragging: _dragging == tiles[i].pid,
                  onDragStart: () => setState(() => _dragging = tiles[i].pid),
                  onDragEnd: () => setState(() => _dragging = null),
                  onPickPid: widget.onPickPid,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EditableTile extends StatelessWidget {
  const _EditableTile({
    required this.tile,
    required this.index,
    required this.width,
    required this.dragging,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onPickPid,
  });

  final GaugeReading tile;
  final int index;
  final double width;
  final bool dragging;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(GaugeReading) onPickPid;

  @override
  Widget build(BuildContext context) {
    final d = context.read<DashboardProvider>();
    final type = context.select<DashboardProvider, dynamic>(
      (p) => p.typeFor(tile.pid),
    );
    final selected = context.select<DashboardProvider, bool>(
      (p) => p.selectedPid == tile.pid,
    );

    final body = _Dismissible(
      onDismissed: () => d.removeTile(tile.pid),
      child: Stack(
        children: [
          GaugeTile(
            reading: tile,
            editing: true,
            type: type,
            selected: selected,
            onTap: () =>
                d.selectTile(d.selectedPid == tile.pid ? null : tile.pid),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                // The drag handle is the drag target, not the whole tile —
                // tapping a tile aims the theme picker, and one gesture must
                // not shadow the other.
                _DragHandle(
                  index: index,
                  tile: tile,
                  width: width,
                  onDragStart: onDragStart,
                  onDragEnd: onDragEnd,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => d.removeTile(tile.pid),
                  child: Semantics(
                    button: true,
                    label: 'Remove ${tile.label}',
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(child: Icn(Lu.x, size: 15, color: T.fault)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tapping the body below the controls retargets what the tile reads.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 34,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPickPid(tile),
              child: Semantics(
                button: true,
                label: 'Change what ${tile.label} reads',
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => d.reorder(details.data, index),
      builder: (context, candidate, _) => Opacity(
        opacity: dragging ? 0.3 : 1,
        child: Container(
          decoration: candidate.isNotEmpty
              // The drop target is marked with the accent, the system's only
              // "this is where it lands" signal.
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: T.accent700, width: 3),
                  ),
                )
              : null,
          child: body,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.index,
    required this.tile,
    required this.width,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final int index;
  final GaugeReading tile;
  final double width;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final d = context.read<DashboardProvider>();
    return Draggable<int>(
      data: index,
      onDragStarted: onDragStart,
      onDraggableCanceled: (_, _) => onDragEnd(),
      onDragCompleted: onDragEnd,
      feedback: Opacity(
        opacity: 0.9,
        child: SizedBox(
          width: width,
          child: GaugeTile(
            reading: tile,
            editing: true,
            type: d.typeFor(tile.pid),
          ),
        ),
      ),
      childWhenDragging: const SizedBox(width: 36, height: 36),
      child: Semantics(
        label: 'Reorder ${tile.label}',
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Icn(Lu.grip, size: 16, color: T.neutral600)),
        ),
      ),
    );
  }
}

/// Swipe-away-to-remove. Written rather than using the framework's Dismissible
/// so the tile keeps its blueprint geometry — Dismissible needs a keyed list
/// item, and this grid is a Wrap.
class _Dismissible extends StatefulWidget {
  const _Dismissible({required this.child, required this.onDismissed});

  final Widget child;
  final VoidCallback onDismissed;

  @override
  State<_Dismissible> createState() => _DismissibleState();
}

class _DismissibleState extends State<_Dismissible> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
      onHorizontalDragEnd: (_) {
        // Past a third of the tile's width the gesture counts; anything less
        // springs back, so a stray thumb never deletes a tile.
        if (_dx.abs() > context.size!.width / 3) {
          widget.onDismissed();
        }
        setState(() => _dx = 0);
      },
      child: AnimatedSlide(
        offset: Offset(_dx / 200, 0),
        duration: Duration(milliseconds: _dx == 0 && !reduceMotion ? 160 : 0),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The PID picker — the catalogue behind "Add tile" and "change what it
/// reads". Opens as a sheet so the grid stays visible behind it.
Future<void> showPidPicker(
  BuildContext context, {
  GaugeReading? replacing,
}) => showAppSheet<void>(context, (sheetContext) {
  final d = context.read<DashboardProvider>();
  final available = d.availablePids();
  return SheetBody(
    eyebrow: replacing == null ? 'Add tile' : 'Change what it reads',
    title: replacing == null ? 'Pick a reading' : replacing.label,
    children: [
      if (available.isEmpty)
        const EmptyState(
          headline: 'Every reading is already on the dashboard',
          why: 'Remove a tile first, or swap what an existing one reads.',
        )
      else
        SizedBox(
          height: 320,
          child: ListView(
            children: [
              for (final pid in available)
                AppListRow(
                  title: pid.label,
                  subtitle: '${pid.pid} · ${pid.unit}',
                  onTap: () {
                    replacing == null
                        ? d.addTile(pid)
                        : d.replaceTile(replacing.pid, pid);
                    Navigator.of(sheetContext).pop();
                  },
                  chevron: true,
                ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text(
        'Only PIDs this vehicle answered are listed. A reading the car does '
        "not report can't be added — we would have nothing to put in it.",
        style: Type.footnote,
      ),
    ],
  );
});
