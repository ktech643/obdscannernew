import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/repositories/dtc_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/repositories/layout_repository.dart';
import 'data/repositories/trip_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'monetization/revenuecat_service.dart';
import 'providers/app_providers.dart';
import 'providers/persistence.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/garage_provider.dart';
import 'features/live_tabs.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'design_system/design_system.dart';
import 'features/settings/erase_everything.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';

/// Root. Every provider is registered once, here; nothing constructs its own.
class TorqueApp extends StatefulWidget {
  const TorqueApp({
    super.key,
    required this.store,
    required this.billing,
    required this.db,
    required this.docsDir,
    required this.tempDir,
    this.tripLaunch,
  });

  /// Opened before the first frame so every provider can restore its state in
  /// its constructor — no screen renders a default and then flickers.
  final Persistence store;

  /// Configured in main() before runApp; shared so the entitlement provider
  /// sees the same configured instance.
  final RevenueCatService billing;

  /// Opened in main(); the repositories below are thin wrappers over it.
  final AppDatabase db;

  /// Where trip files (and later attachments) live — never in the
  /// database (Part 6).
  final Directory docsDir;

  /// Where shares are staged; swept by "Delete all data".
  final Directory tempDir;

  /// The trip launch pass `main()` started. Null in tests, which then do
  /// no file I/O under the fake clock; every rebuild after "Delete all
  /// data" gets the same, already completed, future.
  final Future<void>? tripLaunch;

  @override
  State<TorqueApp> createState() => _TorqueAppState();
}

class _TorqueAppState extends State<TorqueApp> {
  /// Bumped by "Delete all data". The whole provider tree below is keyed on
  /// it, so every provider — and the live session, and every navigator — is
  /// disposed and built again from the emptied storage, exactly as on a
  /// first launch. Resetting providers one field at a time is how the old
  /// settings survived the last delete.
  int _generation = 0;

  void _restart() => setState(() => _generation++);

  Persistence get store => widget.store;
  RevenueCatService get billing => widget.billing;
  AppDatabase get db => widget.db;
  Directory get docsDir => widget.docsDir;

  @override
  Widget build(BuildContext context) => MultiProvider(
    key: ValueKey(_generation),
    providers: [
      ChangeNotifierProvider(create: (_) => OnboardingProvider(store)),
      ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider(store)),
      ChangeNotifierProvider(create: (_) => DiagnosticsProvider()),
      ChangeNotifierProvider(create: (_) => GarageProvider(store)),
      ChangeNotifierProvider(
        create: (_) => EntitlementProvider(store, billing: billing),
      ),
      ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
      // The one live connection. Connect and Dashboard are the Part B
      // screens on the real protocol engine; the other three tabs are
      // still the older design and still read their own providers.
      Provider<AppDatabase>.value(value: db),
      Provider<DtcRepository>(create: (_) => DtcRepository(db)),
      Provider<VehicleRepository>(create: (_) => VehicleRepository(db)),
      Provider<ServiceRepository>(create: (_) => ServiceRepository(db)),
      Provider<TripRepository>(
        create: (_) => TripRepository(db, TripFiles(docsDir)),
      ),
      ChangeNotifierProvider(
        create: (c) => LiveSession(
          dtcs: c.read<DtcRepository>(),
          vehicles: c.read<VehicleRepository>(),
          services: c.read<ServiceRepository>(),
          trips: c.read<TripRepository>(),
          layouts: LayoutRepository(db),
          tripLaunch: widget.tripLaunch,
        ),
      ),
      Provider<EraseEverything>(
        create: (c) => EraseEverything(
          db: db,
          trips: c.read<TripRepository>(),
          store: store,
          live: c.read<LiveSession>(),
          tempDir: widget.tempDir,
          onErased: _restart,
        ),
      ),
    ],
    child: MaterialApp(
      title: 'Torque OBD2',
      debugShowCheckedModeBanner: false,
      // Portrait-only, light-only. The design has one theme by intent: a
      // light technical ground is what the whole system is tuned against.
      theme: ThemeData(
        fontFamily: Type.body,
        scaffoldBackgroundColor: T.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: T.accent,
          brightness: Brightness.light,
          surface: T.bg,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: const Color(0x00000000),
      ),
      builder: (context, child) =>
          Material(color: T.bg, child: child ?? const SizedBox.shrink()),
      home: const _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OnboardingProvider>();
    if (o.complete) return const AppShell();
    // Onboarding handles its own safe area and Backlit theme.
    return const OnboardingFlow(onDone: _onboardingDone);
  }

  static void _onboardingDone() {
    // The provider has already flipped onboardingComplete; nothing else to do.
  }
}

/// The five tabs, for anything that needs to name them.
class AppShellTabs {
  AppShellTabs._();
  static List<String> get labels => [for (final t in AppShell.tabs) t.label];
}

/// The tab shell. Each tab keeps its own navigator so a push inside Garage
/// doesn't unwind when the user checks the Dashboard and comes back.
///
/// The chrome is Part B's: `AdaptiveTabBar` on the design system's ground,
/// which also runs under the status bar and the home indicator so the
/// screens sit on one dark surface instead of on a light strip. Every tab —
/// and every route pushed inside one — is under `LiveIdentityPrompt`'s
/// `Backlit`, so all of them get the Part B theme; the root `Material` in
/// `MaterialApp.builder` is the only Industry thing still underneath.
/// The earlier debug panel is gone: every control on it drove the old
/// Provider stack, which none of these tabs read.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const tabs = [
    AdaptiveTab(
      label: 'Connect',
      icon: Icons.power_outlined,
      selectedIcon: Icons.power,
    ),
    AdaptiveTab(
      label: 'Dashboard',
      icon: Icons.speed_outlined,
      selectedIcon: Icons.speed,
    ),
    AdaptiveTab(
      label: 'Diagnostics',
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
    ),
    AdaptiveTab(
      label: 'Garage',
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car,
    ),
    AdaptiveTab(label: 'Settings', icon: Icons.tune),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 1; // opens on Dashboard
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  late final _tabs = <Widget>[
    LiveConnectTab(onConnected: () => _select(1)),
    LiveDashboardTab(onConnect: () => _select(0)),
    LiveDiagnosticsTab(onConnect: () => _select(0)),
    LiveGarageTab(onConnect: () => _select(0)),
    const LiveSettingsTab(),
  ];

  void _select(int i) {
    if (i == _tab) {
      // Tapping the active tab pops it to root, the standard iOS behaviour
      // — but never past a route that refuses to go (a PopScope that says
      // no, like the Delete-all sheet while it erases). `popUntil` alone
      // ignores that refusal.
      _navKeys[i].currentState?.popUntil(
        (r) => r.isFirst || r.popDisposition == RoutePopDisposition.doNotPop,
      );
    } else {
      setState(() => _tab = i);
    }
  }

  /// Android back, in order: the tab's own stack, asked politely
  /// (`maybePop`, so a route's PopScope is heard — `pop` is not); then
  /// back to the Dashboard from any other tab's root; then out of the app.
  /// An earlier version called `pop`, which removed a sheet that had said
  /// it must stay, and did nothing at all at a tab's root.
  Future<void> _back() async {
    // `maybePop` answers false for a root route with nothing to say, and
    // true when a route popped or a PopScope refused — the Dashboard's, to
    // leave edit mode — which `canPop()` first never let it hear.
    final nav = _navKeys[_tab].currentState;
    if (nav != null && await nav.maybePop()) return;
    if (_tab != 1) {
      setState(() => _tab = 1);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = MediaQuery.highContrastOf(context)
        ? TorqueTokens.highContrast
        : TorqueTokens.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      // The ground runs under the status bar too, so its icons are claimed
      // here, where the box that sits under them is.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ColoredBox(
          color: tokens.surfaceDeep,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LiveSettingsSync(
                    child: LiveIdentityPrompt(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            Navigator(
                              key: _navKeys[i],
                              onGenerateRoute: (settings) => PageRouteBuilder(
                                settings: settings,
                                pageBuilder: (_, _, _) => _tabs[i],
                                transitionsBuilder: _slide,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tab change is 0 ms — no transition. In a diagnostic tool a
                // transition is latency the user has to wait through. The
                // bar pads itself for the home indicator.
                Backlit(
                  child: AdaptiveTabBar(
                    tabs: AppShell.tabs,
                    index: _tab,
                    onSelected: _select,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _slide(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
    Widget child,
  ) => SlideTransition(
    position: Tween(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: a, child: child),
  );
}
