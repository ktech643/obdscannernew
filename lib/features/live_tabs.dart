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
import '../platform/background_service.dart';
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
import 'garage/fuel_log_screen.dart';
import 'garage/garage_screen.dart';
import 'garage/identity_prompt.dart';
import 'garage/maintenance_screen.dart';
import 'garage/reminders_screen.dart';
import 'garage/service_intervals.dart' show Money;
import 'garage/trip_recordings_screen.dart';
import 'pro/paywall_screen.dart';
import '../data/repositories/layout_repository.dart';
import 'dashboard/dashboard_layout.dart';
import 'dashboard/layout_controller.dart';
import 'dashboard/speed_gate.dart';
import 'garage/vehicle_form_screen.dart';
import 'settings/settings_screen.dart';
import 'trips/trip_clock.dart';
import 'trips/trip_link.dart';
import 'trips/trip_recorder.dart';
import 'trips/trip_store.dart';
import 'trips/trip_strip.dart';

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
    LayoutRepository? layouts,
    ScreenWake? screenWake,
    WidgetsBinding? binding,
    PlatformInfo? platform,
    BackgroundService? background,
    Future<void>? tripLaunch,
    TripStore? tripStore,
    TripClock? tripClock,
  }) : log = ProtocolLog(),
       screenWake = screenWake ?? ScreenWake(),
       _discovery = discovery ?? RealAdapterDiscovery() {
    final plat = platform ?? PlatformInfo.current;
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
    speedGate = SpeedGate(
      speed: this.session.bus.of(SpeedGate.pid),
      clock: this.session.clock,
      link: this.session,
      isLive: () => this.session.isLive,
    );
    dashboard = DashboardLayoutController(
      repository: layouts,
      publish: this.session.setVisible,
      publishQuiet: this.session.setQuiet,
      moving: speedGate.moving,
    );
    // §5.3 "iOS bluetooth-central at 0.5 Hz for active recordings only":
    // how slowly a recording polls while the app is in the background.
    this.session.backgroundInterval = plat.backgroundPollInterval;
    final g = garage;
    final store = tripStore ?? (trips == null ? null : DbTripStore(trips));
    recorder = g == null || store == null
        ? null
        : TripRecorder(
            link: SessionTripLink(this.session),
            store: store,
            dashboard: dashboard,
            background: background ?? BackgroundService(platform: plat),
            platform: plat,
            launch: tripLaunch,
            clock: tripClock,
          );
    final r = recorder;
    if (g != null && r != null) g.beforeDelete = r.releaseVehicle;
    _syncLayoutTarget();
    r?.follow(_tripOwner());
    garage?.addListener(_syncVehicle);
    _wasLive = this.session.isLive;
    this.session.addListener(_onSession);
    // Hard rule 9 and AC-11 in the running app: the lifecycle is heard
    // here, where the session is, rather than by a screen that may not be
    // built. Not seeded from the binding's current state — that leaks
    // between tests, and the app is in front when this is first built.
    _lifecycle = AppLifecycleListener(
      binding: binding ?? WidgetsBinding.instance,
      onStateChange: _onLifecycle,
      onResume: () => unawaited(recorder?.onResumed()),
    );
  }

  /// SPEC §5.3 "Record" — null only in tests that give no garage or trips.
  late final TripRecorder? recorder;

  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  /// §9.7 "AppLifecycleState.hidden treated as paused". Inactive is still
  /// on screen — Control Center, a call, the notification shade, split
  /// screen — and keeps the gauges live.
  static bool isForeground(AppLifecycleState state) => switch (state) {
    AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };

  void _onLifecycle(AppLifecycleState state) {
    final fg = isForeground(state);
    if (fg == _foreground) return;
    _foreground = fg;
    // The recorder first, so what it holds is on disk before iOS may
    // suspend the app; then what is asked of the car; then whether it is
    // asked at all (§4.5 "App backgrounded with no active recording → stop
    // polling entirely").
    recorder?.setForeground(fg);
    dashboard.foreground = fg;
    session.setBackgrounded(!fg);
    _syncWake();
  }

  /// Whose trip a recording would be. Nothing is recorded under a car
  /// until the car on the wire has been judged to be it (§9.6).
  TripOwner _tripOwner() {
    if (_demo) return const OwnerDemo();
    final g = garage;
    if (g == null) return const OwnerNone();
    if (!g.loaded) return const OwnerLoading();
    final p = g.primary;
    if (p == null) return const OwnerNone();
    return g.identitySettled
        ? OwnerVehicle(p.id, p.nickname)
        : OwnerPending(p.id);
  }

  /// SPEC §5.3 — the Dashboard's layouts, for whichever car is primary:
  /// the one thing that decides what the car is asked for.
  late final DashboardLayoutController dashboard;

  /// SPEC §8.4 — whether the phone's car is moving, from Speed.
  late final SpeedGate speedGate;

  /// Whose layouts the Dashboard shows: the demo's while Demo Mode runs,
  /// else the primary's once the garage has been read. While a §9.6 question
  /// is open the primary stays: the sheet cannot be dismissed, so nothing
  /// can be edited until it is answered.
  void _syncLayoutTarget() {
    final g = garage;
    dashboard.setTarget(
      _demo
          ? const DemoTarget()
          : g == null
          ? const NoVehicleTarget()
          : !g.loaded
          ? const LoadingTarget()
          : g.primary == null
          ? const NoVehicleTarget()
          : VehicleTarget(g.primary!),
    );
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

  /// §5.3 "Keep awake while foreground and connected".
  void _syncWake() =>
      unawaited(screenWake.set(_keepScreenOn && session.isLive && _foreground));

  bool _wasLive = false;

  /// The vehicle a scan is recorded under is the garage's primary — and
  /// *nothing* while a §9.6 identity question is open, because until it is
  /// answered the app does not know which car it is talking to.
  ///
  /// And nothing in Demo Mode: the recording is not the user's car, and a
  /// demo scan or clear filed under their vehicle would sit in its history
  /// as if it had happened to it.
  void _syncVehicle() {
    _syncLayoutTarget();
    recorder?.follow(_tripOwner());
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
    bool? isPro,
  }) {
    if (isPro != null) {
      dashboard.isPro = isPro;
      recorder?.isPro = isPro;
    }
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
    // A real trip is saved before any demo sample exists.
    await recorder?.stop();
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
    // The listener first: a lifecycle change after this must not restart
    // polling on a session being torn down.
    _lifecycle.dispose();
    recorder?.detach();
    recorder?.dispose();
    unawaited(screenWake.set(false));
    session.removeListener(_onSession);
    garage?.removeListener(_syncVehicle);
    _discovery.dispose();
    diagnostics.dispose();
    dashboard.dispose();
    speedGate.dispose();
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
  Widget build(BuildContext context) =>
      Backlit(child: SafeArea(bottom: false, child: child));
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
    // SPEC §5.6 — the unit toggles reach the gauges. Watched here, at the
    // tab, so a change in Settings rebuilds the specs and nothing else.
    final settings = context.watch<SettingsProvider>();
    final garage = live.garage;
    // Layouts and trips are kept per car; with none yet, the form that
    // adds one.
    final VoidCallback? addVehicle = garage == null
        ? null
        : () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => VehicleFormScreen(
                controller: garage,
                unit: settings.distance,
              ),
            ),
          );
    final recorder = live.recorder;
    return _Backlit(
      child: DashboardScreen(
        session: live.session,
        layouts: live.dashboard,
        onConnect: onConnect,
        adapterName: live.isDemo ? DemoMode.adapter.name : null,
        distance: settings.distance,
        temperature: settings.temperature,
        onUpgrade: () => openProPaywall(context),
        onAddVehicle: addVehicle,
        // The plan reaches the strip through the recorder, not a watch.
        tripStrip: recorder == null
            ? null
            : TripStrip(
                recorder: recorder,
                layouts: live.dashboard,
                distance: settings.distance,
                electric: () => looksElectric(
                  live.dashboard.target,
                  live.session.supportedPids,
                ),
                onUpgrade: () => openProPaywall(context),
                onAddVehicle: addVehicle,
              ),
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
        distance: context.watch<SettingsProvider>().distance,
        temperature: context.watch<SettingsProvider>().temperature,
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
        temperature: context.watch<SettingsProvider>().temperature,
        isPro: context.watch<EntitlementProvider>().isPro,
        onConnect: onConnect,
        adapterName: live.isDemo ? DemoMode.adapter.name : null,
        onUpgrade: () => openProPaywall(context),
        links: _links(garage, live.recorder),
      ),
    );
  }

  /// SPEC §5.5 — the Garage's logs, each for the vehicle its row was
  /// tapped for. The unit, the currency and the plan are read in the
  /// route's own context, where the providers are, so an open log follows
  /// them: bought Pro through the log's own door, the cap lifts on that
  /// same screen — read once here, it did not until the log was reopened.
  /// A form opened from a log keeps the unit it opened with; what is typed
  /// in it is in that unit.
  GarageLinks _links(GarageController garage, TripRecorder? recorder) =>
      GarageLinks(
        maintenance: (ctx, vehicle) {
          final settings = ctx.watch<SettingsProvider>();
          return MaintenanceScreen(
            garage: garage,
            vehicle: vehicle,
            unit: settings.distance,
            currencyCode: Money.codeOf(settings.currency),
            isPro: ctx.watch<EntitlementProvider>().isPro,
            onUpgrade: () => openProPaywall(ctx),
          );
        },
        reminders: (ctx, vehicle) => RemindersScreen(
          garage: garage,
          vehicle: vehicle,
          unit: ctx.watch<SettingsProvider>().distance,
        ),
        fuel: (ctx, vehicle) {
          final settings = ctx.watch<SettingsProvider>();
          return FuelLogScreen(
            garage: garage,
            vehicle: vehicle,
            unit: settings.distance,
            currencyCode: Money.codeOf(settings.currency),
          );
        },
        trips: garage.trips == null
            ? null
            : (ctx, vehicle) => TripRecordingsScreen(
                trips: garage.trips!,
                vehicle: vehicle,
                isRecording: (id) => recorder?.recordingTripId == id,
                unit: ctx.watch<SettingsProvider>().distance,
                isPro: ctx.watch<EntitlementProvider>().isPro,
              ),
      );
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
      child: IdentityPromptHost(
        garage: garage,
        session: live.session,
        unit: context.watch<SettingsProvider>().distance,
        isPro: context.watch<EntitlementProvider>().isPro,
        onUpgrade: () => openProPaywall(context),
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
      // The plan reaches the Dashboard's layouts live — its listeners are
      // all below this widget, so a notify during this build is safe.
      isPro: context.watch<EntitlementProvider>().isPro,
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
