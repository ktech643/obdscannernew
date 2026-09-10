import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform/platform_info.dart';
import '../design_system/design_system.dart';
import '../session/adapter_discovery.dart';
import '../session/obd_session.dart';
import 'connect/connect_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'demo/demo_mode.dart';

/// Holds the one live [ObdSession] and the discovery feeding it, so the
/// Connect and Dashboard tabs are looking at the same connection.
///
/// This is a `ChangeNotifier` only for *which* discovery is in use —
/// swapping to the recorded one when Demo Mode starts. The session's own
/// state changes are broadcast by the session itself.
class LiveSession extends ChangeNotifier {
  LiveSession({ObdSession? session, AdapterDiscovery? discovery})
    : session = session ?? ObdSession(),
      _discovery = discovery ?? RealAdapterDiscovery();

  final ObdSession session;

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
