import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../protocol/pid_registry.dart';
import '../../session/gauge_catalog.dart';
import 'dashboard_header.dart';
import 'dashboard_layout.dart';
import 'layout_controller.dart';

/// What the readings list can say about the car: what it reports, if known.
class ReadingSupport {
  const ReadingSupport(this.pids, {required this.connected});

  /// Empty when nothing is known yet.
  final Set<String> pids;

  /// True when [pids] came from this connection, not a cache.
  final bool connected;

  bool get known => pids.isNotEmpty;
  bool reports(String pid) => !known || pids.contains(pid);
}

/// The readings that can go on this layout: gaugeable, reported by the car
/// when that is known, never one already stored (held ones included).
List<String> candidateReadings(
  List<LayoutTile> stored,
  ReadingSupport support,
) {
  final taken = {for (final t in stored) t.pid};
  return [
    for (final p in GaugeCatalog.pickerOrder)
      if (!taken.contains(p) && support.reports(p)) p,
  ];
}

/// Tap a tile in edit mode: its style, its place, its reading, or remove it.
Future<void> showTileSheet(
  BuildContext context, {
  required DashboardLayoutController layouts,
  required String pid,
  required ReadingSupport support,
}) => showAdaptiveSheet<void>(
  context,
  builder: (_) => _TileSheet(
    layouts: layouts,
    pid: pid,
    support: support,
    ref: layouts.ref,
  ),
);

/// The Add tile: the readings list alone.
Future<void> showAddReading(
  BuildContext context, {
  required DashboardLayoutController layouts,
  required ReadingSupport support,
  required void Function(String pid) onPicked,
}) => showAdaptiveSheet<void>(
  context,
  builder: (_) => _ReadingPicker(
    layouts: layouts,
    support: support,
    ref: layouts.ref,
    onPicked: onPicked,
  ),
);

/// Closes itself — its own route, never the one above it (a paywall) —
/// when edit mode ends or its layout is not the one shown any more.
mixin _SelfClosing<T extends StatefulWidget> on State<T> {
  DashboardLayoutController get controller;
  LayoutRef get ref;
  bool _closing = false;

  void _watch() {
    if (_closing || !mounted) return;
    if (!controller.editing || controller.ref != ref) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    } else {
      setState(() {});
    }
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }
}

class _TileSheet extends StatefulWidget {
  const _TileSheet({
    required this.layouts,
    required this.pid,
    required this.support,
    required this.ref,
  });
  final DashboardLayoutController layouts;
  final String pid;
  final ReadingSupport support;
  final LayoutRef ref;

  @override
  State<_TileSheet> createState() => _TileSheetState();
}

class _TileSheetState extends State<_TileSheet> with _SelfClosing {
  @override
  DashboardLayoutController get controller => widget.layouts;
  @override
  LayoutRef get ref => widget.ref;

  /// The tile this sheet is about. A new reading closes the sheet.
  String get _pid => widget.pid;

  @override
  void initState() {
    super.initState();
    controller.addListener(_watch);
  }

  @override
  void dispose() {
    controller.removeListener(_watch);
    super.dispose();
  }

  void _outcome(EditOutcome o) {
    if (o == EditOutcome.stale) _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = controller;
    final shown = c.shown;
    final i = shown.indexWhere((x) => x.pid == _pid);
    if (i < 0) return const SizedBox.shrink();
    final tile = shown[i];
    final label = GaugeCatalog.labelFor(_pid);
    final candidates = candidateReadings(c.tiles, widget.support);
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        physics: adaptiveScrollPhysics(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x24,
              Space.gutter,
              Space.x8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                ),
                const SizedBox(height: Space.x4),
                Text(
                  [
                    'Gauge ${i + 1} of ${shown.length}',
                    if (widget.support.known && !widget.support.reports(_pid))
                      'Not reported by this car',
                  ].join(' · '),
                  style: TorqueType.meta.copyWith(color: t.inkSecondary),
                ),
                const SizedBox(height: Space.x16),
                ChoiceChips<GaugeVariant>(
                  label: 'Show as',
                  values: GaugeVariant.values,
                  value: tile.variant,
                  labelOf: variantName,
                  onChanged: (v) => _outcome(c.setVariant(ref, _pid, v)),
                ),
                Wrap(
                  spacing: Space.x8,
                  children: [
                    if (i > 0)
                      GhostButton(
                        label: 'Move earlier',
                        icon: Icons.arrow_back,
                        onPressed: () => _outcome(c.moveBy(ref, _pid, -1)),
                      ),
                    if (i < shown.length - 1)
                      GhostButton(
                        label: 'Move later',
                        icon: Icons.arrow_forward,
                        onPressed: () => _outcome(c.moveBy(ref, _pid, 1)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const ListSection(title: 'Reading'),
          ListRow(title: label, value: 'Showing', subtitle: _describe(_pid)),
          for (final p in candidates)
            ListRow(
              title: GaugeCatalog.labelFor(p),
              subtitle: _describe(p),
              onTap: () {
                final o = c.replace(ref, _pid, p);
                if (o == EditOutcome.done) _close();
                _outcome(o);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              _footnote(c.tiles, widget.support),
              style: TorqueType.meta.copyWith(color: t.inkSecondary),
            ),
          ),
          if (c.tiles.length > 1)
            ListRow(
              title: 'Remove from dashboard',
              destructive: true,
              onTap: () {
                final o = c.remove(ref, _pid);
                if (o == EditOutcome.done) _close();
                _outcome(o);
              },
            ),
          const SizedBox(height: Space.x16),
        ],
      ),
    );
  }
}

class _ReadingPicker extends StatefulWidget {
  const _ReadingPicker({
    required this.layouts,
    required this.support,
    required this.ref,
    required this.onPicked,
  });
  final DashboardLayoutController layouts;
  final ReadingSupport support;
  final LayoutRef ref;
  final void Function(String pid) onPicked;

  @override
  State<_ReadingPicker> createState() => _ReadingPickerState();
}

class _ReadingPickerState extends State<_ReadingPicker> with _SelfClosing {
  @override
  DashboardLayoutController get controller => widget.layouts;
  @override
  LayoutRef get ref => widget.ref;

  @override
  void initState() {
    super.initState();
    controller.addListener(_watch);
  }

  @override
  void dispose() {
    controller.removeListener(_watch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final candidates = candidateReadings(controller.tiles, widget.support);
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        physics: adaptiveScrollPhysics(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x24,
              Space.gutter,
              Space.x8,
            ),
            child: Text(
              'Add a gauge',
              style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
            ),
          ),
          for (final p in candidates)
            ListRow(
              title: GaugeCatalog.labelFor(p),
              subtitle: _describe(p),
              onTap: () {
                _close();
                widget.onPicked(p);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              _footnote(controller.tiles, widget.support),
              style: TorqueType.meta.copyWith(color: t.inkSecondary),
            ),
          ),
          const SizedBox(height: Space.x16),
        ],
      ),
    );
  }
}

/// "Engine oil temperature · °C".
String _describe(String pid) {
  final d = PidRegistry.lookup(pid);
  if (d == null) return pid;
  return d.unit.isEmpty ? d.name : '${d.name} · ${d.unit}';
}

String _footnote(List<LayoutTile> stored, ReadingSupport support) {
  if (!support.known) {
    return 'Not connected yet — some of these may not be on your car. '
        'Readings already on the dashboard aren\'t listed.';
  }
  final taken = {for (final t in stored) t.pid};
  final missing = GaugeCatalog.gaugeable
      .where((p) => !taken.contains(p) && !support.pids.contains(p))
      .length;
  return missing == 0
      ? 'Readings already on the dashboard aren\'t listed.'
      : 'Readings already on the dashboard, and the $missing this car '
            'doesn\'t report, aren\'t listed.';
}
