import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';
import '../account/account_screens.dart';
import '../pro/paywall_screen.dart';
import 'diagnostics_log_screen.dart';
import 'privacy_screen.dart';

Route<void> _route(Widget child) =>
    PageRouteBuilder(pageBuilder: (_, _, _) => child);

/// F5 — settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final e = context.watch<EntitlementProvider>();
    final a = context.watch<AccountProvider>();
    final c = context.read<ConnectionProvider>();

    return Screen(
      title: 'Settings',
      footer:
          e.canShowBanner(onFaultResult: false, scanning: false, speedKmh: 0)
          ? AdBanner(onRemoveAds: () => openPaywall(context))
          : null,
      children: [
        const SectionHeading('Units', topPadding: 4),
        AppListRow(
          title: 'Distance',
          trailing: Segmented(
            options: const ['km', 'mi'],
            selected: s.distance.index,
            onSelect: (i) => s.setDistance(DistanceUnit.values[i]),
          ),
        ),
        AppListRow(
          title: 'Temperature',
          trailing: Segmented(
            options: const ['°C', '°F'],
            selected: s.temperature.index,
            onSelect: (i) => s.setTemperature(TemperatureUnit.values[i]),
          ),
        ),
        const SectionHeading('Connection'),
        AppListRow(
          title: 'Polling rate',
          value: s.pollingRate,
          chevron: true,
          onTap: () {},
        ),
        AppListRow(
          title: 'Auto-reconnect',
          trailing: AppSwitch(
            value: s.autoReconnect,
            onChanged: s.setAutoReconnect,
          ),
        ),
        AppListRow(
          title: 'Keep the screen on',
          trailing: AppSwitch(
            value: s.keepScreenOn,
            onChanged: s.setKeepScreenOn,
          ),
        ),
        const SectionHeading('Subscription'),
        AppListRow(
          title: e.isPro ? 'Torque Pro' : 'Free with ads',
          subtitle: e.isPro
              ? 'Unlimited gauges · unlimited recording · no ads'
              : '6 gauges · 2-min recordings · 1 vehicle · banner ads',
        ),
        if (!e.isPro)
          AppListRow(
            title: 'Remove ads',
            chevron: true,
            onTap: () => openPaywall(context),
          ),
        AppListRow(title: 'Restore purchases', chevron: true, onTap: () {}),
        const SectionHeading('Account'),
        AppListRow(
          title: a.status == AccountStatus.signedOut
              ? 'Sign in'
              : a.displayName,
          subtitle: a.status == AccountStatus.signedOut
              ? 'Optional — the app works fully signed out'
              : a.email,
          chevron: true,
          onTap: () => Navigator.of(context).push(
            _route(
              a.status == AccountStatus.signedOut
                  ? const SignInScreen()
                  : const ProfileScreen(),
            ),
          ),
        ),
        const SectionHeading('Your data'),
        AppListRow(
          title: 'Data & privacy',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const PrivacyScreen())),
        ),
        AppListRow(
          title: 'Diagnostics log',
          value: '500 events',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const DiagnosticsLogScreen())),
        ),
        const SectionHeading('Demo'),
        AppListRow(
          title: c.demoMode ? 'Exit Demo Mode' : 'Demo Mode',
          subtitle: 'Replays a recorded 2014 Golf session — no adapter needed',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const DemoModeScreen())),
        ),
      ],
    );
  }
}

/// F7 — Demo Mode. This ships: a reviewer will not have an adapter or a car,
/// and without it the app appears non-functional under Guideline 2.1.
class DemoModeScreen extends StatelessWidget {
  const DemoModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionProvider>();
    return Screen(
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      above: c.demoMode
          ? const ConnectionStrip(
              text: 'DEMO DATA · replaying a recorded 2014 Golf session',
              tone: Tone.caution,
            )
          : null,
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            c.demoMode ? 'Explore the demo' : 'Start Demo Mode',
            onPressed: () {
              if (!c.demoMode) c.enterDemoMode();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
          GhostButton(
            c.demoMode
                ? 'Exit demo · connect my own adapter'
                : 'Connect my own adapter',
            onPressed: () {
              c.exitDemoMode();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      children: [
        Text('Try it without an adapter', style: Type.subScreenTitle),
        const SizedBox(height: 12),
        Text(
          'Demo Mode replays a real recorded session so you can see exactly '
          'what Torque does before buying any hardware. Every number is '
          'watermarked as demo data.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 20),
        AppListRow(
          title: 'P0301',
          subtitle: 'Cylinder 1 misfire detected',
          titleStyle: Type.dtcCode,
          severityBar: T.fault,
        ),
        AppListRow(
          title: 'P0133',
          subtitle: 'Oxygen sensor slow response · pending',
          titleStyle: Type.dtcCode,
          severityBar: T.cautionBorder,
        ),
        const SectionHeading('Also in this demo'),
        Text(
          'Freeze frame · readiness monitors · health score breakdown · the '
          'clear-codes consequence sheet · a maintenance log with nine records.',
          style: Type.bodyMuted,
        ),
      ],
    );
  }
}
