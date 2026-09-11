import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/repositories/dtc_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'monetization/revenuecat_service.dart';
import 'providers/app_providers.dart';
import 'providers/persistence.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'providers/garage_provider.dart';
import 'features/live_tabs.dart';
import 'screens/garage/garage_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/settings/settings_screen.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/chrome.dart';
import 'dev_panel.dart';

/// Root. Every provider is registered once, here; nothing constructs its own.
class TorqueApp extends StatelessWidget {
  const TorqueApp({
    super.key,
    required this.store,
    required this.billing,
    required this.db,
  });

  /// Opened before the first frame so every provider can restore its state in
  /// its constructor — no screen renders a default and then flickers.
  final Persistence store;

  /// Configured in main() before runApp; shared so the entitlement provider
  /// sees the same configured instance.
  final RevenueCatService billing;

  /// Opened in main(); the repositories below are thin wrappers over it.
  final AppDatabase db;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => OnboardingProvider(store)),
      ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider(store)),
      ChangeNotifierProvider(create: (_) => DiagnosticsProvider()),
      ChangeNotifierProvider(create: (_) => GarageProvider(store)),
      ChangeNotifierProvider(
        create: (_) => EntitlementProvider(store, billing: billing),
      ),
      ChangeNotifierProvider(create: (_) => AccountProvider(store)),
      ChangeNotifierProvider(create: (_) => SettingsProvider(store)),
      // The one live connection. Connect and Dashboard are the Part B
      // screens on the real protocol engine; the other three tabs are
      // still the older design and still read their own providers.
      Provider<AppDatabase>.value(value: db),
      Provider<DtcRepository>(create: (_) => DtcRepository(db)),
      Provider<VehicleRepository>(create: (_) => VehicleRepository(db)),
      ChangeNotifierProvider(
        create: (c) => LiveSession(
          dtcs: c.read<DtcRepository>(),
          vehicles: c.read<VehicleRepository>(),
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
    // Onboarding has no tab bar, so it takes the top inset itself.
    return SafeArea(bottom: false, child: OnboardingFlow(onDone: () {}));
  }
}

/// The tab shell. Each tab keeps its own navigator so a push inside Garage
/// doesn't unwind when the user checks the Dashboard and comes back.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

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
    const GarageScreen(),
    const SettingsScreen(),
  ];

  void _select(int i) {
    if (i == _tab) {
      // Tapping the active tab pops it to root, the standard iOS behaviour.
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final nav = _navKeys[_tab].currentState;
      if (nav != null && nav.canPop()) nav.pop();
    },
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
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
          // Tab change is 0 ms — no transition. In a diagnostic tool a
          // transition is latency the user has to wait through.
          AppTabBar(active: _tab, onSelect: _select),
          const DevPanel(),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    ),
  );

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
