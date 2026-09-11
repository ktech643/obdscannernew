import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/platform_info.dart';
import '../data/repositories/dtc_repository.dart';
import '../data/repositories/vehicle_repository.dart';
import '../design_system/design_system.dart';
import '../session/adapter_discovery.dart';
import '../session/obd_session.dart';
import 'connect/connect_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'demo/demo_mode.dart';
import 'diagnostics/diagnostics_controller.dart';
import 'diagnostics/diagnostics_screen.dart';

/// Holds the one live [ObdSession] and the discovery feeding it, so the
/// Connect and Dashboard tabs are looking at the same connection.
///
/// This is a `ChangeNotifier` only for *which* discovery is in use —
/// swapping to the recorded one when Demo Mode starts. The session's own
/// state changes are broadcast by the session itself.
class LiveSession extends ChangeNotifier {
  LiveSession({
    ObdSession? session,
    AdapterDiscovery? discovery,
    DtcRepository? dtcs,
    VehicleRepository? vehicles,
  }) : session = session ?? ObdSession(dtcs: dtcs),
       _discovery = discovery ?? RealAdapterDiscovery() {
    _vehicles = vehicles;
    diagnostics = DiagnosticsController(session: this.session, dtcs: dtcs);
    _resolveVehicle();
  }

  final ObdSession session;

  /// One controller for the whole app, so a scan survives switching tabs
  /// and the §9.5 pending-clear check runs once rather than per rebuild.
  late final DiagnosticsController diagnostics;

  VehicleRepository? _vehicles;

  /// The snapshots a scan writes belong to a car. Until the Garage names
  /// one there is no id, and the clear sheet says the history is not being
  /// kept rather than silently keeping none.
  Future<void> _resolveVehicle() async {
    final primary = await _vehicles?.primary();
    diagnostics.vehicleId = primary?.id;
  }

  AdapterDiscovery _discovery;
  AdapterDiscovery get discovery => _discovery;

  bool _demo = false;

  /// True while the recorded session is standing in for a car.
  bool get isDemo => _demo;

  /// SPEC §11.1. Replaces discovery with the recording and connects to it,
  /// so the whole flow — scan, pick, handshake, live gauges — runs exactly
  /// as it does with hardware.
  Future<void> startDemo() async {
    await session.disconnect();
    _discovery = await DemoMode.discovery();
    _demo = true;
    notifyListeners();
    await session.connect(_discovery.transportFor(DemoMode.adapter));
  }

  Future<void> stopDemo() async {
    if (!_demo) return;
    await session.disconnect();
    _discovery = RealAdapterDiscovery();
    _demo = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _discovery.dispose();
    diagnostics.dispose();
    session.dispose();
    super.dispose();
  }
}

/// Wraps a Part B screen in its own theme.
///
/// The remaining tabs are still the older Industry design, which is built
/// against a light theme, so the new theme is applied here rather than at
/// the app root. It comes out at the root once every screen has moved.
class _Backlit extends StatelessWidget {
  const _Backlit({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: torqueTheme(),
    child: AdaptiveScope(
      platform: PlatformInfo.current,
      child: ColoredBox(
        color: TorqueTokens.dark.surfaceDeep,
        child: SafeArea(bottom: false, child: child),
      ),
    ),
  );
}

/// The Connect tab, on the live session.
class LiveConnectTab extends StatelessWidget {
  const LiveConnectTab({super.key, this.onConnected});
  final VoidCallback? onConnected;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    return _Backlit(
      child: ConnectScreen(
        // A new discovery means a new scan, so the screen is rebuilt rather
        // than handed a different object mid-flight.
        key: ValueKey(live.discovery),
        session: live.session,
        discovery: live.discovery,
        onConnected: onConnected,
        onDemoMode: live.isDemo ? null : live.startDemo,
      ),
    );
  }
}

/// The Dashboard tab, on the live session.
class LiveDashboardTab extends StatelessWidget {
  const LiveDashboardTab({super.key, this.onConnect});
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    return _Backlit(
      child: DashboardScreen(
        session: live.session,
        onConnect: onConnect,
        adapterName: live.isDemo ? DemoMode.adapter.name : null,
      ),
    );
  }
}

/// The Diagnostics tab, on the live session.
class LiveDiagnosticsTab extends StatelessWidget {
  const LiveDiagnosticsTab({super.key, this.onConnect});
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    return _Backlit(
      child: DiagnosticsScreen(
        controller: live.diagnostics,
        onConnect: onConnect,
        adapterName: live.isDemo ? DemoMode.adapter.name : null,
      ),
    );
  }
}
