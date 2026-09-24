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
import '../platform/screen_wake.dart';
import '../protocol/protocol_log.dart';
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
import 'settings/settings_screen.dart';

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
    ScreenWake? screenWake,
  }) : log = ProtocolLog(),
       screenWake = screenWake ?? ScreenWake(),
       _discovery = discovery ?? RealAdapterDiscovery() {
    // Built in the body, not the initializer list, so it can pass this
    // session's own `log` — a field can't see a sibling field yet while
    // the initializer list is still running.
    this.session = session ?? ObdSession(dtcs: dtcs, log: log);
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

  late final ObdSession session;

  /// SPEC §10.4 — every command and reply this session's `ObdSession` has
  /// sent over the wire. Fed automatically; nothing here is generated.
  /// Shown by Settings › Diagnostics log.
  final ProtocolLog log;

  /// One controller for the whole app, so a scan survives switching tabs
  /// and the §9.5 pending-clear check runs once rather than per rebuild.
  late final DiagnosticsController diagnostics;

  /// Null only in tests that give no repositories.
  late final GarageController? garage;

  /// SPEC §5.6 "Keep screen on". Told the answer whenever the link or the
  /// setting changes; it forwards only a change.
  final ScreenWake screenWake;

  bool _keepScreenOn = true;

  /// The setting as last applied. The screen is held awake only while this
  /// is on *and* the link is live.
  bool get keepScreenOn => _keepScreenOn;

  void _syncWake() =>
      unawaited(screenWake.set(_keepScreenOn && session.isLive));

  bool _wasLive = false;

  /// The vehicle a scan is recorded under is the garage's primary — and
  /// *nothing* while a §9.6 identity question is open, because until it is
  /// answered the app does not know which car it is talking to.
  ///
  /// And nothing in Demo Mode: the recording is not the user's car, and a
  /// demo scan or clear filed under their vehicle would sit in its history
  /// as if it had happened to it.
  void _syncVehicle() {
    final g = garage;
    if (g == null) return;
    diagnostics.vehicleId = _demo || g.pendingIdentity != null
        ? null
        : g.primary?.id;
    diagnostics.notRecording = _demo
        ? NotRecording.demo
        : g.pendingIdentity != null
        ? NotRecording.identityUnsettled
        : NotRecording.noVehicle;
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
  ///
  /// Demo Mode never asks: the recording's VIN is the ISO 3779 worked
  /// example, and judging it against the real garage attached that VIN to
  /// the user's own VIN-less car, cached the recording's protocol on it,
  /// and left their real car a stranger on its next connect.
  void _onSession() {
    final live = session.isLive;
    if (live && !_wasLive && !_demo) unawaited(garage?.onConnected(session));
    if (!live && _wasLive) garage?.onDisconnected();
    _wasLive = live;
    _syncWake();
  }

  /// SPEC §5.6 — the settings that mean something to a live link.
  /// Idempotent: [LiveSettingsSync] calls this every rebuild, so an
  /// unchanged value is just a few field writes, not a resubscribe, a
  /// reconnect or a platform call.
  void applySettings({
    required bool autoReconnect,
    required bool haptics,
    int? maxPollingHz,
    bool keepScreenOn = true,
  }) {
    session.autoReconnect = autoReconnect;
    session.scheduler.maxHz = maxPollingHz;
    AdaptiveHaptics.enabled = haptics;
    _keepScreenOn = keepScreenOn;
    _syncWake();
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
    _syncVehicle();
    notifyListeners();
    await session.connect(_discovery.transportFor(DemoMode.adapter));
  }

  Future<void> stopDemo() async {
    if (!_demo) return;
    await session.disconnect();
    _discovery = RealAdapterDiscovery();
    _demo = false;
    _syncVehicle();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(screenWake.set(false));
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

/// The Settings tab, on the live session.
class LiveSettingsTab extends StatelessWidget {
  const LiveSettingsTab({super.key});

  @override
  Widget build(BuildContext context) => const _Backlit(child: SettingsScreen());
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

/// Keeps the live link's behaviour in step with SPEC §5.6 Settings —
/// auto-reconnect, the polling-rate ceiling, haptics and keep-screen-on.
/// Wraps the whole tab stack next to [LiveIdentityPrompt], so a change
/// reaches the session on the next frame no matter which tab is open,
/// without the session needing to know `SettingsProvider` exists.
class LiveSettingsSync extends StatelessWidget {
  const LiveSettingsSync({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    final settings = context.watch<SettingsProvider>();
    live.applySettings(
      autoReconnect: settings.autoReconnect,
      haptics: settings.haptics,
      maxPollingHz: _hzFor(settings.pollingRate),
      keepScreenOn: settings.keepScreenOn,
    );
    return child;
  }

  /// [SettingsProvider.pollingRates] as a ceiling in Hz; "Auto" — the
  /// default — is null, meaning no ceiling beyond what the adapter itself
  /// can sustain.
  static int? _hzFor(String rate) => switch (rate) {
    '10 Hz' => 10,
    '8 Hz' => 8,
    '4 Hz' => 4,
    '2 Hz' => 2,
    _ => null,
  };
}
