import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/scaffold.dart';
import '../pro/paywall_screen.dart';

/// F4 — data & privacy, including the ad disclosure.
///
/// Adding ads forced the privacy label to change. That trade is documented
/// here in the user's words rather than only in App Store metadata.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final e = context.watch<EntitlementProvider>();

    return Screen(
      title: 'Data & privacy',
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Text("Your car's data stays on your iPhone.", style: Type.cardTitleLg),
        const SizedBox(height: 10),
        Text(
          'Codes, live readings, VIN, service history and receipts stay on the '
          'device — and in your own iCloud if you turn it on.',
          style: Type.body16Muted,
        ),
        const SectionHeading('What leaves the device'),
        AppListRow(
          title: 'Ad requests',
          subtitle:
              'Device identifier, region and app usage. Never your codes, '
              'VIN or vehicle data.',
        ),
        AppListRow(
          title: 'Everything else',
          subtitle: 'Nothing. No analytics, no crash reporting, no account.',
        ),
        AppListRow(
          title: 'Personalised ads',
          subtitle: 'Turning this on asks iOS for tracking permission first.',
          trailing: AppSwitch(
            value: s.personalisedAds,
            onChanged: s.setPersonalisedAds,
          ),
        ),
        AppListRow(
          title: 'iCloud sync',
          subtitle: "Your private database. We can't read it.",
          trailing: e.isPro ? null : const Badge('PRO'),
        ),
        const SectionHeading('Your controls'),
        if (!e.isPro)
          AppListRow(
            title: 'Remove ads — go Pro',
            chevron: true,
            onTap: () => openPaywall(context),
          ),
        AppListRow(
          title: 'Export everything as JSON',
          chevron: true,
          onTap: () {},
        ),
        AppListRow(
          title: 'Delete all data',
          titleStyle: Type.rowPrimary.copyWith(color: T.fault),
          chevron: true,
          onTap: () {},
        ),
      ],
    );
  }
}
