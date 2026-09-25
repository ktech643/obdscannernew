import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';

/// The screen-reader actions a tile carries in edit mode — constants, so
/// their ids hold while the readout rebuilds at 10 Hz.
abstract final class TileActions {
  static const editDashboard = CustomSemanticsAction(label: 'Edit dashboard');
  static const moveEarlier = CustomSemanticsAction(label: 'Move earlier');
  static const moveLater = CustomSemanticsAction(label: 'Move later');
  static const moveFirst = CustomSemanticsAction(label: 'Move to first');
  static const moveLast = CustomSemanticsAction(label: 'Move to last');
  static const changeReading = CustomSemanticsAction(label: 'Change reading');
  static const remove = CustomSemanticsAction(label: 'Remove');
}

/// One slot of the grid.
class GridSlot {
  const GridSlot({
    required this.pid,
    required this.tile,
    required this.feedback,
  });
  final String pid;

  /// The tile as it stands in the grid.
  final Widget tile;

  /// The same tile, on the same notifiers, lifted under the finger.
  final Widget Function() feedback;
}

/// SPEC §5.3's grid, and B.8's reflow: two up, one up when the text is too
/// large for two — measured on the grid's own width, never the screen's.
///
/// Each slot carries a key of its own, so a moved tile keeps its element
/// and its semantics node — in whichever row it lands — and VoiceOver's
/// focus goes with it.
class DashboardGrid extends StatefulWidget {
  const DashboardGrid({
    super.key,
    required this.slots,
    this.editing = false,
    this.canRemove = true,
    this.onMove,
    this.onRemove,
    this.onResist,
    this.trailing,
    this.footer,
    this.controller,
  });

  final List<GridSlot> slots;
  final bool editing;

  /// False on the last tile: the swipe resists and the × is gone.
  final bool canRemove;
  final void Function(String pid, int toIndex)? onMove;
  final void Function(String pid)? onRemove;

  /// A swipe on the one tile that cannot go.
  final VoidCallback? onResist;

  /// After the last slot: the Add tile in edit mode.
  final Widget? trailing;

  /// Below the grid: the saved-but-held line.
  final Widget? footer;
  final ScrollController? controller;

  /// Two columns while a 16-pt line still gets 100 pt of tile width.
  static int columnsFor(double width, TextScaler scaler) {
    final tile = (width - 2 * Space.gutter - Space.x12) / 2;
    return tile / (scaler.scale(16) / 16) >= 100 ? 2 : 1;
  }

  @override
  State<DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<DashboardGrid> {
  // A slot keeps its element — and its semantics node, so VoiceOver's focus
  // goes with a moved tile — even when a move takes it into another row.
  final _keys = <String, GlobalKey>{};

  GlobalKey _keyFor(String pid) => _keys.putIfAbsent(pid, GlobalKey.new);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = DashboardGrid.columnsFor(
        box.maxWidth,
        MediaQuery.textScalerOf(context),
      );
      final slotWidth =
          (box.maxWidth - 2 * Space.gutter - (columns - 1) * Space.x12) /
          columns;
      final pids = {for (final s in widget.slots) s.pid};
      _keys.removeWhere((pid, _) => !pids.contains(pid));
      final cells = <Widget>[
        for (var i = 0; i < widget.slots.length; i++)
          KeyedSubtree(
            key: _keyFor(widget.slots[i].pid),
            child: widget.editing
                ? _EditableSlot(
                    slot: widget.slots[i],
                    index: i,
                    width: slotWidth,
                    words: columns == 1,
                    canRemove: widget.canRemove,
                    onDrop: (pid) => widget.onMove?.call(pid, i),
                    onRemove: () => widget.onRemove?.call(widget.slots[i].pid),
                    onResist: widget.onResist,
                  )
                : widget.slots[i].tile,
          ),
        if (widget.trailing != null) widget.trailing!,
      ];
      // Rows as tall as their tallest tile: an Arc beside a Number no
      // longer leaves the pair — and their grips — at different heights.
      final rows = <Widget>[
        for (var r = 0; r < cells.length; r += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: Space.x12),
                  SizedBox(
                    width: slotWidth,
                    child: r + c < cells.length ? cells[r + c] : null,
                  ),
                ],
              ],
            ),
          ),
      ];
      return SingleChildScrollView(
        controller: widget.controller,
        physics: adaptiveScrollPhysics(context),
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: Space.x12),
              rows[i],
            ],
            if (widget.footer != null) ...[
              const SizedBox(height: Space.x16),
              widget.footer!,
            ],
          ],
        ),
      );
    },
  );
}

/// A tile in edit mode: a drop target; a body that swipes sideways to
/// remove; under it a grip to drag it by and a ×. The grip and the × are
/// hidden from screen readers — their functions are the tile's own
/// actions, so each tile stays one stop.
class _EditableSlot extends StatefulWidget {
  const _EditableSlot({
    required this.slot,
    required this.index,
    required this.width,
    required this.words,
    required this.canRemove,
    required this.onDrop,
    required this.onRemove,
    this.onResist,
  });

  final GridSlot slot;
  final int index;
  final double width;

  /// At one column the grip and the × say what they do.
  final bool words;
  final bool canRemove;
  final void Function(String pid) onDrop;
  final VoidCallback onRemove;
  final VoidCallback? onResist;

  @override
  State<_EditableSlot> createState() => _EditableSlotState();
}

class _EditableSlotState extends State<_EditableSlot>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _armed = false;
  bool _dragging = false;
  bool _resisted = false;
  EdgeDraggingAutoScroller? _scroller;
  late final _back = AnimationController(vsync: this);
  double _backFrom = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() {
      setState(
        () => _dx = _backFrom * (1 - Motion.easeOut.transform(_back.value)),
      );
    });
  }

  @override
  void dispose() {
    _back.dispose();
    _scroller?.stopAutoScroll();
    super.dispose();
  }

  double get _threshold => widget.width / 3;

  void _swipeUpdate(DragUpdateDetails d) {
    _back.stop();
    final resistance = widget.canRemove ? 1.0 : 0.3;
    setState(() => _dx += d.delta.dx * resistance);
    final armed = widget.canRemove && _dx.abs() >= _threshold;
    if (armed != _armed) {
      setState(() => _armed = armed);
      if (armed) AdaptiveHaptics.select();
    }
    if (!widget.canRemove && !_resisted && _dx.abs() > 24) {
      _resisted = true;
      widget.onResist?.call();
    }
  }

  /// Distance, never velocity: a fast short flick removes nothing — a
  /// stray thumb never deletes a tile.
  void _swipeEnd(DragEndDetails _) {
    _resisted = false;
    if (_armed) {
      setState(() {
        _armed = false;
        _dx = 0;
      });
      AdaptiveHaptics.light();
      widget.onRemove();
      return;
    }
    final d = Motion.of(context, Motion.springBack);
    if (d == Duration.zero || _dx == 0) {
      setState(() => _dx = 0);
      return;
    }
    _backFrom = _dx;
    _back
      ..duration = d
      ..forward(from: 0);
  }

  Offset _anchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final box = this.context.findRenderObject() as RenderBox?;
    return box == null ? Offset.zero : box.globalToLocal(position);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != widget.slot.pid,
      onAcceptWithDetails: (d) => widget.onDrop(d.data),
      builder: (context, candidates, _) {
        final hover = candidates.isNotEmpty;
        final body = _dragging
            ? Stack(
                children: [
                  Opacity(opacity: 0, child: widget.slot.tile),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: t.hairline),
                        borderRadius: BorderRadius.circular(Radii.tile),
                      ),
                      child: Center(
                        child: Text(
                          'Moving',
                          style: TorqueType.label.copyWith(
                            color: t.inkSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : widget.slot.tile;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: hover
                ? Border.all(color: t.inkPrimary, width: 2)
                : Border.all(color: const Color(0x00000000), width: 2),
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Stack(
            children: [
              if (_dx != 0)
                Positioned.fill(
                  child: _RemoveHint(armed: _armed, left: _dx < 0),
                ),
              Transform.translate(
                offset: Offset(_dx, 0),
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        excludeFromSemantics: true,
                        onHorizontalDragUpdate: _swipeUpdate,
                        onHorizontalDragEnd: _swipeEnd,
                        onHorizontalDragCancel: () =>
                            _swipeEnd(DragEndDetails()),
                        child: body,
                      ),
                    ),
                    ExcludeSemantics(child: _controls(t)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controls(TorqueTokens t) {
    final ink = TorqueType.label.copyWith(color: t.inkSecondary);
    return SizedBox(
      height: Targets.min,
      child: Row(
        children: [
          Draggable<String>(
            data: widget.slot.pid,
            dragAnchorStrategy: _anchor,
            feedback: IgnorePointer(
              child: SizedBox(
                width: widget.width,
                child: widget.slot.feedback(),
              ),
            ),
            onDragStarted: () {
              setState(() => _dragging = true);
              AdaptiveHaptics.select();
              final scrollable = Scrollable.maybeOf(context);
              if (scrollable != null) {
                _scroller = EdgeDraggingAutoScroller(
                  scrollable,
                  velocityScalar: 20,
                );
              }
            },
            onDragUpdate: (d) => _scroller?.startAutoScrollIfNecessary(
              Rect.fromCenter(center: d.globalPosition, width: 1, height: 1),
            ),
            onDragEnd: (_) => _stopDrag(),
            onDraggableCanceled: (_, _) => _stopDrag(),
            onDragCompleted: () {
              _stopDrag();
              AdaptiveHaptics.select();
            },
            child: SizedBox(
              height: Targets.min,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: Targets.min,
                    height: Targets.min,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: t.inkSecondary,
                    ),
                  ),
                  if (widget.words) Text('Move', style: ink),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (widget.canRemove)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onRemove,
              child: SizedBox(
                height: Targets.min,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.words) Text('Remove', style: ink),
                    SizedBox(
                      width: Targets.min,
                      height: Targets.min,
                      child: Icon(Icons.close, size: 20, color: t.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _stopDrag() {
    _scroller?.stopAutoScroll();
    _scroller = null;
    if (mounted) setState(() => _dragging = false);
  }
}

/// Behind a tile being swiped: what letting go will do. Red, and the words
/// change, only once it will — never colour alone.
class _RemoveHint extends StatelessWidget {
  const _RemoveHint({required this.armed, required this.left});
  final bool armed;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = armed ? t.tellRed : t.inkSecondary;
    return Align(
      alignment: left ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: color),
            const SizedBox(height: Space.x4),
            Text(
              armed ? 'Release to remove' : 'Remove',
              textAlign: TextAlign.center,
              style: TorqueType.meta.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the Add slot is.
enum AddGaugeForm {
  /// Every reading the car reports is already on the layout: a statement.
  nothingLeft,

  /// The free plan's six: a door, with the lock and the word.
  locked,

  /// The free plan's six on an electric car (§9.4): a statement, no door.
  freeLimit,
  open,
}

/// The last slot in edit mode.
class AddGaugeTile extends StatelessWidget {
  const AddGaugeTile({super.key, required this.form, this.onTap});
  final AddGaugeForm form;
  final VoidCallback? onTap;

  String? get _statement => switch (form) {
    AddGaugeForm.nothingLeft =>
      'Every reading this car reports is on the dashboard',
    AddGaugeForm.freeLimit =>
      'The free plan shows 6 gauges. Tap one to show something else.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Widget content = switch (form) {
      AddGaugeForm.nothingLeft || AddGaugeForm.freeLimit => Text(
        _statement!,
        textAlign: TextAlign.center,
        style: TorqueType.meta.copyWith(color: t.inkSecondary),
      ),
      AddGaugeForm.locked || AddGaugeForm.open => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.x8,
        children: [
          Icon(
            form == AddGaugeForm.locked ? Icons.lock_outline : Icons.add,
            size: 20,
            color: t.inkPrimary,
          ),
          Text(
            'Add gauge',
            style: TorqueType.label.copyWith(color: t.inkPrimary),
          ),
          if (form == AddGaugeForm.locked)
            const TelltaleChip(tone: Tell.none, label: 'Pro'),
        ],
      ),
    };
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Targets.min * 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: t.hairline),
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.x16),
          child: Center(child: content),
        ),
      ),
    );
    if (_statement case final words?) {
      return Semantics(
        container: true,
        label: words,
        child: ExcludeSemantics(child: box),
      );
    }
    return Semantics(
      button: true,
      label: form == AddGaugeForm.locked ? 'Add gauge, Pro' : 'Add gauge',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: box,
        ),
      ),
    );
  }
}
