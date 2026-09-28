import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart' show DistanceUnit, TemperatureUnit;
import '../../session/gauge_catalog.dart';
import '../../session/obd_session.dart';
import '../session_banner.dart';
import 'dashboard_grid.dart';
import 'dashboard_header.dart';
import 'dashboard_layout.dart';
import 'layout_controller.dart';
import 'layouts_sheet.dart';
import 'sparkline_history.dart';
import 'tile_sheet.dart';

/// SPEC §5.3 — the Dashboard.
///
/// A grid of gauge tiles fed by [ObdSession.bus], one `ValueNotifier` per
/// PID, with a single shared clock. Nothing here rebuilds at 10 Hz: this
/// widget listens to the session and to the [layouts] controller, which
/// change rarely, while each tile listens to its own notifier and repaints
/// alone (hard rule 3).
///
/// What is on the grid, and so what the car is asked for, is [layouts]'s:
/// the controller is the one caller of `setVisible`, and this screen never
/// is. Edit mode — long-press a tile, the header's Edit, or the tile's
/// "Edit dashboard" action — moves, changes, restyles and removes tiles,
/// each saved as it is made.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.layouts,
    this.onConnect,
    this.adapterName,
    this.distance = DistanceUnit.km,
    this.temperature = TemperatureUnit.celsius,
    this.onUpgrade,
    this.onAddVehicle,
    this.tripStrip,
  });

  final ObdSession session;
  final DashboardLayoutController layouts;

  /// SPEC §5.6 — the user's units. Applied to each tile's spec, never to
  /// the samples on the bus.
  final DistanceUnit distance;
  final TemperatureUnit temperature;

  /// Opens the Connect screen from the banner.
  final VoidCallback? onConnect;
  final String? adapterName;

  /// The paywall, from the 7th-tile and 2nd-layout doors.
  final VoidCallback? onUpgrade;

  /// Layouts are saved per car: with none in the garage, edit mode offers
  /// to add one.
  final VoidCallback? onAddVehicle;

  /// Reserved between the header and the grid for the trip strip.
  final Widget? tripStrip;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scroll = ScrollController();
  final _histories = <String, SparklineHistory>{};

  // One element per tile across normal and edit mode: rebuilt, a tile lost
  // its semantics node (VoiceOver's focus jumped) and re-announced any
  // Caution it was already at.
  final _tileKeys = <String, GlobalKey>{};
  GlobalKey _tileKey(String pid) => _tileKeys.putIfAbsent(pid, GlobalKey.new);
  late int _heard = widget.layouts.eventSerial;
  late String _owner = widget.layouts.target.key;
  SessionState? _state;

  /// A line the screen says itself, until the next event.
  String? _status;

  DashboardLayoutController get _c => widget.layouts;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _c.addListener(_onLayouts);
    _state = widget.session.state;
  }

  @override
  void didUpdateWidget(DashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      old.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
      _resetHistories();
    }
    if (old.layouts != widget.layouts) {
      old.layouts.removeListener(_onLayouts);
      widget.layouts.addListener(_onLayouts);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Another tab in front: edit mode ends, and Speed stops being asked for
    // on the tabs that do not need it. The sheets that hear it rebuild after
    // the frame: they are not below this screen.
    if (!Visibility.of(context) && _c.editing) {
      _c.endEditing(EndReason.hidden);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _c.removeListener(_onLayouts);
    for (final h in _histories.values) {
      h.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _onSession() {
    final s = widget.session.state;
    if (s == SessionState.connecting && _state != SessionState.connecting) {
      _resetHistories();
    }
    _state = s;
    if (mounted) setState(() {});
  }

  void _onLayouts() {
    if (!mounted) return;
    if (_c.target.key != _owner) {
      _owner = _c.target.key;
      _resetHistories();
    }
    if (_c.eventSerial != _heard) {
      _heard = _c.eventSerial;
      _status = null;
      final e = _c.lastEvent;
      if (e != null) {
        AdaptiveAnnounce.polite(
          context,
          eventText(e, owner: ownerOf(_c.target), a11y: true),
        );
      }
    }
    setState(() {});
  }

  void _resetHistories() {
    for (final h in _histories.values) {
      h.reset();
    }
  }

  /// What the car reports: this connection's answer, else what it said
  /// last time, else nothing known.
  ReadingSupport get _support {
    final live = widget.session.supportedPids;
    if (live.isNotEmpty) return ReadingSupport(live, connected: true);
    final t = _c.target;
    if (t is VehicleTarget && t.cachedSupport.isNotEmpty) {
      return ReadingSupport(t.cachedSupport, connected: false);
    }
    return const ReadingSupport({}, connected: false);
  }

  /// SPEC §9.4 — never sell more gauges to a car that has none to give.
  bool get _electric => looksElectric(_c.target, widget.session.supportedPids);

  void _enterEdit() {
    switch (_c.beginEditing()) {
      case EditOutcome.done:
        AdaptiveHaptics.select();
      case EditOutcome.noVehicle:
        showAdaptiveAlert(
          context,
          title: 'Gauges are saved for each car',
          message:
              'Add your car to the Garage and this dashboard is kept for it. '
              'No VIN is needed.',
          actions: [
            AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
            if (widget.onAddVehicle != null)
              AdaptiveAlertAction(
                label: 'Add your car',
                isDefault: true,
                onPressed: widget.onAddVehicle!,
              ),
          ],
        );
      default:
        break;
    }
  }

  Future<void> _done() async {
    if (_c.saveError) {
      await _c.settle();
    } else {
      _c.endEditing();
    }
  }

  void _openLayouts() => showLayoutsSheet(
    context,
    layouts: _c,
    onUpgrade: widget.onUpgrade,
    electric: _electric,
  );

  AddGaugeForm get _addForm {
    final support = _support;
    if (support.known && candidateReadings(_c.tiles, support).isEmpty) {
      return AddGaugeForm.nothingLeft;
    }
    if (LayoutPlan.canAddTile(_c.tiles.length, isPro: _c.isPro)) {
      return AddGaugeForm.open;
    }
    // §9.4: an electric car is never sold more gauges — not even a lock.
    return _electric ? AddGaugeForm.freeLimit : AddGaugeForm.locked;
  }

  void _add() {
    final support = _support;
    if (_addForm == AddGaugeForm.locked) {
      showSeventhTileDoor(
        context,
        onUpgrade: widget.onUpgrade,
        electric: _electric,
        unreported: support.known
            ? _c.shown.where((t) => !support.reports(t.pid)).length
            : 0,
      );
      return;
    }
    showAddReading(
      context,
      layouts: _c,
      support: support,
      onPicked: (pid) {
        if (_c.add(_c.ref, pid) != EditOutcome.done) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final end = _scroll.position.maxScrollExtent;
          final d = Motion.of(context, Motion.layout);
          if (d == Duration.zero) {
            _scroll.jumpTo(end);
          } else {
            _scroll.animateTo(end, duration: d, curve: Motion.easeOut);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return PopScope(
      canPop: !_c.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _c.endEditing(EndReason.back);
      },
      child: BannerHost(
        banner: bannerFor(
          session,
          onConnect: widget.onConnect,
          adapterName: widget.adapterName,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_c.loaded)
              _c.editing
                  ? EditBar(
                      layouts: _c,
                      onDone: _done,
                      onLayouts: _openLayouts,
                      onRetry: _c.settle,
                      status: _status,
                    )
                  : DashboardHeader(
                      layouts: _c,
                      onEdit: _enterEdit,
                      onLayouts: _openLayouts,
                      onRetry: _c.settle,
                    ),
            // Shown in edit mode too: the strip hides itself there unless a
            // trip is being recorded, which keeps its status and its Stop.
            if (widget.tripStrip != null) widget.tripStrip!,
            Expanded(child: _body(context, session)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ObdSession session) {
    // Until the car's layout is read there is nothing honest to draw.
    if (!_c.loaded) return const SizedBox.shrink();
    if (_c.editing) return _grid(editing: true);

    // B.6 Loading — skeletons matching the final geometry, so nothing jumps
    // when the first sample lands.
    if (session.state == SessionState.connecting ||
        session.state == SessionState.handshaking) {
      return DashboardGrid(
        slots: [
          for (var i = 0; i < _c.shown.length; i++)
            GridSlot(
              pid: 'skeleton-$i',
              tile: const GaugeTileSkeleton(),
              feedback: () => const GaugeTileSkeleton(),
            ),
        ],
      );
    }

    // B.6 Error — name what happened and what to do. Never a network error:
    // the app is fully functional offline (B.6 Offline).
    if (session.state == SessionState.disconnected ||
        session.state == SessionState.unsupported) {
      return EmptyStateView(
        title: session.lastError == null
            ? 'Not connected'
            : 'Could not connect',
        why:
            session.lastError ??
            'Plug an adapter into the port under the dash, then connect.',
        tone: session.lastError == null ? Tell.none : Tell.red,
        actionLabel: widget.onConnect == null ? null : 'Choose an adapter',
        onAction: widget.onConnect,
      );
    }

    // B.6 Empty — only when the car answered and reports no gauge at all.
    // A layout whose own tiles are all unsupported, on a car that reports
    // others, is Partial: the tiles say so, and Edit is right there.
    final reported = session.supportedPids;
    final gauges = GaugeCatalog.gaugeable.toSet();
    if (reported.isNotEmpty && !reported.any(gauges.contains)) {
      return const EmptyStateView(
        title: 'This car reports no live data',
        why:
            'It answered, but none of the standard sensors are available. '
            'Fault codes and readiness still work.',
        tone: Tell.amber,
      );
    }
    return _grid(editing: false);
  }

  Widget _grid({required bool editing}) {
    final shown = _c.shown;
    _keepHistories(shown);
    final held = _c.held;
    return DashboardGrid(
      controller: _scroll,
      editing: editing,
      canRemove: _c.tiles.length > 1,
      onMove: (pid, to) => _c.move(_c.ref, pid, to),
      onRemove: (pid) => _c.remove(_c.ref, pid),
      onResist: () => setState(
        () => _status = 'Keep at least one gauge — change this one instead.',
      ),
      slots: [
        for (var i = 0; i < shown.length; i++)
          GridSlot(
            pid: shown[i].pid,
            tile: _tile(shown[i], i, shown.length, editing: editing),
            feedback: () =>
                _tile(shown[i], i, shown.length, editing: false, lifted: true),
          ),
      ],
      trailing: editing ? AddGaugeTile(form: _addForm, onTap: _add) : null,
      footer: held.isEmpty ? null : _HeldLine(held: held),
    );
  }

  Widget _tile(
    LayoutTile tile,
    int i,
    int n, {
    required bool editing,
    bool lifted = false,
  }) {
    final spec = GaugeCatalog.specFor(
      tile.pid,
      supported: _support.reports(tile.pid),
      distance: widget.distance,
      temperature: widget.temperature,
    )!;
    final history = tile.variant == GaugeVariant.sparkline
        ? _histories[tile.pid]
        : null;
    // Stale against how often the session really asks for this reading,
    // not against the tier's 10 Hz pace (SPEC §5.3).
    final expected = widget.session.cadence.of(tile.pid);
    if (lifted) {
      return GaugeTile(
        spec: spec,
        sample: widget.session.bus.of(tile.pid),
        clock: widget.session.clock,
        expectedInterval: expected,
        variant: tile.variant,
        history: history,
      );
    }
    if (!editing) {
      final canEdit = !_c.gated;
      return GaugeTile(
        key: _tileKey(tile.pid),
        spec: spec,
        sample: widget.session.bus.of(tile.pid),
        clock: widget.session.clock,
        expectedInterval: expected,
        variant: tile.variant,
        history: history,
        onLongPress: canEdit ? _enterEdit : null,
        onLongPressHint: canEdit ? 'edit the dashboard' : null,
        semanticsActions: canEdit
            ? {TileActions.editDashboard: _enterEdit}
            : null,
      );
    }
    final pid = tile.pid;
    final ref = _c.ref;
    return GaugeTile(
      key: _tileKey(pid),
      spec: spec,
      sample: widget.session.bus.of(pid),
      clock: widget.session.clock,
      expectedInterval: expected,
      variant: tile.variant,
      history: history,
      onTap: () =>
          showTileSheet(context, layouts: _c, pid: pid, support: _support),
      onTapHint: 'change the reading',
      semanticsSuffix: 'Gauge ${i + 1} of $n',
      semanticsActions: {
        if (i > 0) TileActions.moveEarlier: () => _c.moveBy(ref, pid, -1),
        if (i < n - 1) TileActions.moveLater: () => _c.moveBy(ref, pid, 1),
        if (i > 0)
          TileActions.moveFirst: () => _c.moveToEdge(ref, pid, first: true),
        if (i < n - 1)
          TileActions.moveLast: () => _c.moveToEdge(ref, pid, first: false),
        TileActions.changeReading: () =>
            showTileSheet(context, layouts: _c, pid: pid, support: _support),
        if (_c.tiles.length > 1) TileActions.remove: () => _c.remove(ref, pid),
      },
    );
  }

  /// A trace for each tile drawn as one, and only those; the rest are let
  /// go after the frame, once no tile listens to them.
  void _keepHistories(List<LayoutTile> shown) {
    final wanted = {
      for (final t in shown)
        if (t.variant == GaugeVariant.sparkline) t.pid,
    };
    for (final p in wanted) {
      _histories.putIfAbsent(
        p,
        () => SparklineHistory(widget.session.bus.of(p)),
      );
    }
    final kept = {for (final t in _c.tiles) t.pid};
    _tileKeys.removeWhere((p, _) => !kept.contains(p));
    final gone = _histories.keys.where((p) => !wanted.contains(p)).toList();
    if (gone.isEmpty) return;
    final dropped = [for (final p in gone) _histories.remove(p)!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final h in dropped) {
        h.dispose();
      }
    });
  }
}

/// After a lapse: the gauges kept on the layout that the free plan does not
/// show. A statement — no "See Pro" (§7.3: never unasked).
class _HeldLine extends StatelessWidget {
  const _HeldLine({required this.held});
  final List<LayoutTile> held;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final names = [for (final h in held) GaugeCatalog.labelFor(h.pid)];
    final n = names.length;
    return Text(
      '$n more gauge${n == 1 ? ' is' : 's are'} saved on this layout: '
      '${names.join(', ')}. The free plan shows ${LayoutPlan.freeTiles}.',
      style: TorqueType.meta.copyWith(color: t.inkSecondary),
    );
  }
}
