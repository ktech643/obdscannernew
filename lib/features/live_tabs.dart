import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/platform_info.dart';
import '../data/db/app_database.dart' show VehicleRow;
import '../data/repositories/dtc_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/vehicle_repository.dart';
import '../design_system/design_system.dart';
import '../providers/app_providers.dart';
import '../session/adapter_discovery.dart';
import '../session/obd_session.dart';
import 'connect/connect_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'demo/demo_mode.dart';
import 'diagnostics/diagnostics_controller.dart';
import 'diagnostics/diagnostics_screen.dart';
import 'garage/garage_controller.dart';
import 'garage/garage_screen.dart';
import 'garage/identity_prompt.dart';

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
    ServiceRepository? services,
    TripRepository? trips,
  }) : session = session ?? ObdSession(dtcs: dtcs),
       _discovery = discovery ?? RealAdapterDiscovery() {
    garage = vehicles == null
        ? null
        : GarageController(
            vehicles: vehicles,
            services: services,
            trips: trips,
            dtcs: dtcs,
          );
    diagnostics = DiagnosticsController(
      session: this.session,
      dtcs: dtcs,
      countOverdue: garage == null ? null : _countOverdue,
    );
    garage?.addListener(_syncVehicle);
    _wasLive = this.session.isLive;
    this.session.addListener(_onSession);
  }

  final ObdSession session;

  /// One controller for the whole app, so a scan survives switching tabs
  /// and the §9.5 pending-clear check runs once rather than per rebuild.
  late final DiagnosticsController diagnostics;

  /// Null only in tests that give no repositories.
  late final GarageController? garage;

  bool _wasLive = false;

  /// The vehicle a scan is recorded under is the garage's primary — and
  /// *nothing* while a §9.6 identity question is open, because until it is
  /// answered the app does not know which car it is talking to.
  void _syncVehicle() {
    final g = garage!;
    diagnostics.vehicleId = g.pendingIdentity == null ? g.primary?.id : null;
  }

  Future<int> _countOverdue(String vehicleId) {
    final g = garage!;
    VehicleRow? row;
    for (final v in g.all) {
      if (v.id == vehicleId) row = v;
    }
    return g.overdueCount(vehicleId, odometerKm: row?.odometerKm);
  }

  /// The edge into a live link, and only the edge: the session notifies
  /// for changes inside a link too — degraded and back, a fresh voltage —
  /// and reading the VIN on each of those would cost a round trip a
  /// second and put the identity question up again every time.
  void _onSession() {
    final live = session.isLive;
    if (live && !_wasLive) unawaited(garage?.onConnected(session));
    _wasLive = live;
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
    session.removeListener(_onSession);
    garage?.removeListener(_syncVehicle);
    _discovery.dispose();
    diagnostics.dispose();
    garage?.dispose();
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
  Widget build(BuildContext context) => Backlit(
    platform: PlatformInfo.current,
    child: SafeArea(bottom: false, child: child),
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

/// The Garage tab, on the live session.
///
/// Units and the Pro flag still come from the older providers: Settings
/// has not moved yet and they are the truth until it does.
class LiveGarageTab extends StatelessWidget {
  const LiveGarageTab({super.key, this.onConnect});
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    final garage = live.garage;
    if (garage == null) return const SizedBox.shrink();
    return _Backlit(
      child: GarageScreen(
        controller: garage,
        session: live.session,
        unit: context.watch<SettingsProvider>().distance,
        isPro: context.watch<EntitlementProvider>().isPro,
        onConnect: onConnect,
        adapterName: live.isDemo ? DemoMode.adapter.name : null,
      ),
    );
  }
}

/// Puts the §9.6 identity question above the whole tab stack, so it is
/// asked wherever the user happens to be when the car answers.
class LiveIdentityPrompt extends StatelessWidget {
  const LiveIdentityPrompt({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    final garage = live.garage;
    if (garage == null) return child;
    return Backlit(
      platform: PlatformInfo.current,
      child: IdentityPromptHost(
        garage: garage,
        session: live.session,
        unit: context.watch<SettingsProvider>().distance,
        isPro: context.watch<EntitlementProvider>().isPro,
        child: child,
      ),
    );
  }
}
