import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'providers/app_providers.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/diagnostics_provider.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/icons.dart';
import 'screens/account/account_screens.dart';
import 'screens/connect/compatibility_screens.dart';
import 'screens/diagnostics/readiness_screen.dart';
import 'screens/pro/ad_screens.dart';
import 'screens/pro/paywall_screen.dart';
import 'screens/system/system_screens.dart';

/// The debug-only equivalent of the design board's Tweaks panel.
///
/// Several frames in the handoff are states a real car has to produce — a
/// degraded adapter, a VIN mismatch, an EV with no PIDs. This collapses the
/// wait: it drives the providers directly so every state is reachable without
/// hardware. Compiled out of release builds.
class DevPanel extends StatefulWidget {
  const DevPanel({super.key});

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(color: T.neutral900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: SizedBox(
              height: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('STATES', style: Type.chip(T.neutral400)),
                  const SizedBox(width: 8),
                  Icn(
                    _open ? Lu.chevronDown : Lu.chevronUp,
                    size: 13,
                    color: T.neutral400,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _group('Dashboard', [
                    for (final s in DashboardScenario.values)
                      _chip(
                        s.name,
                        () => context.read<DashboardProvider>().setScenario(s),
                      ),
                  ]),
                  _group('Connection', [
                    _chip(
                      'scan',
                      () => context.read<ConnectionProvider>().startScan(),
                    ),
                    _chip(
                      'handshake',
                      () => context.read<ConnectionProvider>().connect(),
                    ),
                    _chip(
                      'connected',
                      () => context.read<ConnectionProvider>().recover(),
                    ),
                    _chip(
                      'degraded',
                      () => context.read<ConnectionProvider>().degrade(),
                    ),
                    _chip(
                      'lost',
                      () => context.read<ConnectionProvider>().lose(),
                    ),
                    _chip(
                      'bt off',
                      () => context.read<ConnectionProvider>().setBluetooth(
                        on: false,
                      ),
                    ),
                    _chip(
                      'bt denied',
                      () => context.read<ConnectionProvider>().setBluetooth(
                        denied: true,
                      ),
                    ),
                  ]),
                  _group('Speed gate', [
                    _chip(
                      '0 km/h',
                      () => context.read<DashboardProvider>().setSpeed(0),
                    ),
                    _chip(
                      '68 km/h',
                      () => context.read<DashboardProvider>().setSpeed(68),
                    ),
                    _chip(
                      'no PID',
                      () => context.read<DashboardProvider>().setSpeed(null),
                    ),
                  ]),
                  _group('Tier', [
                    _chip(
                      'free',
                      () => context
                          .read<EntitlementProvider>()
                          .continueFreeWithAds(),
                    ),
                    _chip(
                      'pro',
                      () => context.read<EntitlementProvider>().subscribe(),
                    ),
                  ]),
                  _group('Faults', [
                    _chip(
                      'faults',
                      () => context.read<DiagnosticsProvider>().restoreFaults(),
                    ),
                    _chip(
                      'cleared',
                      () => context.read<DiagnosticsProvider>().clearCodes(
                        stationary: true,
                      ),
                    ),
                  ]),
                  _group('System', [
                    _chip('low power', () {
                      final s = context.read<SettingsProvider>();
                      s.setLowPower(!s.lowPowerMode);
                    }),
                    _chip('storage full', () {
                      final s = context.read<SettingsProvider>();
                      s.setStorageFull(!s.storageFull);
                    }),
                  ]),
                  _group('Screens', [
                    _push('paywall', const PaywallScreen()),
                    _push(
                      'choice',
                      ChoiceScreen(onDone: () => Navigator.of(context).pop()),
                    ),
                    _push('rewarded ad', const RewardedAdScreen()),
                    _push('interstitial', const InterstitialAdScreen()),
                    _push('EV dead end', const EvDeadEndScreen()),
                    _push('refund', const RefundCardScreen()),
                    _push('mode 06', const Mode06Screen()),
                    _push('drive cycle', const DriveCycleScreen()),
                    _push('snapshots', const SnapshotHistoryScreen()),
                    _push('sign in', const SignInScreen()),
                    _push('profile', const ProfileScreen()),
                    _push('delete acct', const DeleteAccountScreen()),
                    _push('sync conflict', const SyncConflictScreen()),
                    _push('resume trip', const ResumeTripScreen()),
                    _push('new adapter', const NewAdapterPromptScreen()),
                    _push('VIN mismatch', const VinMismatchScreen()),
                    _push('mac compat', const MacCompatScreen()),
                    _push('adapter list', const AdapterCompatibilityList()),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _group(String label, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Type.chip(T.neutral500).copyWith(fontSize: 8.5),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    ),
  );

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: T.neutral700, width: 1),
      ),
      child: Text(
        label,
        style: Type.chip(T.neutral200).copyWith(letterSpacing: 0.2),
      ),
    ),
  );

  Widget _push(String label, Widget screen) => _chip(
    label,
    () => Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => Material(
          color: T.bg,
          child: SafeArea(bottom: false, child: screen),
        ),
      ),
    ),
  );
}
