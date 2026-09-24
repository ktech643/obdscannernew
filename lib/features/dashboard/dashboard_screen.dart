import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart' show DistanceUnit, TemperatureUnit;
import '../../session/gauge_catalog.dart';
import '../../session/obd_session.dart';
import '../session_banner.dart';

/// SPEC §5.3 — the Dashboard.
///
/// A 2-up grid of gauge tiles fed by [ObdSession.bus], one `ValueNotifier`
/// per PID, with a single shared clock. Nothing here rebuilds at 10 Hz: this
/// widget listens to the *session*, which changes state rarely, while each
/// tile listens to its own notifier and repaints alone (hard rule 3).
///
/// The grid also decides what gets asked for at all. Only the PIDs with a
/// tile on screen are handed to [ObdSession.setVisible]; a tile the user
/// removed stops costing a round trip immediately.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    this.layout,
    this.onConnect,
    this.adapterName,
    this.distance = DistanceUnit.km,
    this.temperature = TemperatureUnit.celsius,
  });

  final ObdSession session;

  /// SPEC §5.6 — the user's units. Applied to each tile's spec, never to
  /// the samples on the bus.
  final DistanceUnit distance;
  final TemperatureUnit temperature;

  /// The PIDs to show, in order. Defaults to [GaugeCatalog.defaultLayout];
  /// Phase 6's later slices persist this per vehicle.
  final List<String>? layout;

  /// Opens the Connect screen from the banner.
  final VoidCallback? onConnect;
  final String? adapterName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> get _layout => widget.layout ?? GaugeCatalog.defaultLayout;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _publishVisible();
  }

  @override
  void didUpdateWidget(DashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      old.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
    }
    if (old.layout != widget.layout) _publishVisible();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  /// Hard rule: a tile that is not on screen must not consume round trips.
  void _publishVisible() => widget.session.setVisible(_layout.toSet());

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return BannerHost(
      banner: bannerFor(
        session,
        onConnect: widget.onConnect,
        adapterName: widget.adapterName,
      ),
      child: _body(context, session),
    );
  }

  Widget _body(BuildContext context, ObdSession session) {
    // B.6 Loading — skeletons matching the final geometry, so nothing jumps
    // when the first sample lands.
    if (session.state == SessionState.connecting ||
        session.state == SessionState.handshaking) {
      return _Grid(
        children: [
          for (var i = 0; i < _layout.length; i++) const GaugeTileSkeleton(),
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

    // B.6 Empty — the car answered, but nothing in the layout exists on it.
    final tiles = _layout
        .map(
          (pid) => GaugeCatalog.specFor(
            pid,
            supported:
                session.supportedPids.isEmpty ||
                session.supportedPids.contains(pid),
            distance: widget.distance,
            temperature: widget.temperature,
          ),
        )
        .whereType<GaugeSpec>()
        .toList();

    if (tiles.every((t) => !t.supported)) {
      return const EmptyStateView(
        title: 'This car reports no live data',
        why:
            'It answered, but none of the standard sensors are available. '
            'Fault codes and readiness still work.',
        tone: Tell.amber,
      );
    }

    // B.6 Partial — the normal state in OBD2. Unsupported tiles stay in the
    // grid and say why, rather than vanishing and leaving a hole.
    return _Grid(
      children: [
        for (final spec in tiles)
          GaugeTile(
            key: ValueKey(spec.pid),
            spec: spec,
            sample: session.bus.of(spec.pid),
            clock: session.clock,
          ),
      ],
    );
  }
}

/// Two up, gutter outside, 12 between. Sized by the tallest tile in a row
/// so mixed variants stay aligned.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: adaptiveScrollPhysics(context),
    padding: const EdgeInsets.all(Space.gutter),
    child: Wrap(
      spacing: Space.x12,
      runSpacing: Space.x12,
      children: [
        for (final child in children)
          LayoutBuilder(
            builder: (context, _) {
              final width = MediaQuery.sizeOf(context).width;
              final tile = (width - Space.gutter * 2 - Space.x12) / 2;
              return SizedBox(width: tile, child: child);
            },
          ),
      ],
    ),
  );
}
