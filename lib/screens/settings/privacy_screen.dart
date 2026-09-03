import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/feedback.dart';
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
          onTap: () => copyToClipboard(
            context,
            _exportJson(context),
            'Copied your data as JSON. Paste it anywhere to keep a copy.',
          ),
        ),
        AppListRow(
          title: 'Delete all data',
          titleStyle: Type.rowPrimary.copyWith(color: T.fault),
          chevron: true,
          onTap: () => _confirmDeleteAll(context),
        ),
      ],
    );
  }
}

/// The whole local database, as JSON. Generated on the device and put on the
/// clipboard — nothing is uploaded, which is the point of the screen it sits
/// on.
String _exportJson(BuildContext context) {
  final g = context.read<GarageProvider>();
  final s = context.read<SettingsProvider>();
  final v = g.active;
  return const JsonEncoder.withIndent('  ').convert({
    'exportedAt': DateTime.now().toIso8601String(),
    'generatedOn': 'this iPhone',
    'units': {'distance': s.distance.name, 'temperature': s.temperature.name},
    'vehicles': [
      {
        'nickname': v.nickname,
        'year': v.year,
        'make': v.make,
        'model': v.model,
        'fuel': v.fuel.name,
        'odometerKm': v.odometerKm,
        // The VIN follows the same masking rule as every other screen.
        'vin': s.maskVin ? v.maskedVin : v.vin,
      },
    ],
    'serviceRecords': [for (final r in g.records) r.toJson()],
  });
}

/// Deleting the local database is irreversible and takes the garage with it,
/// so it is confirmed the same way the account deletion is — by naming the
/// consequences before offering the action.
void _confirmDeleteAll(BuildContext context) => showAppSheet<void>(context, (
  sheetContext,
) {
  return SheetBody(
    eyebrow: 'Data & privacy',
    title: 'Delete all data?',
    children: [
      for (final line in const [
        'Every vehicle, service record, receipt and saved snapshot on this '
            'iPhone is erased',
        'Your units, layout and tile themes reset to defaults',
        'Torque returns to first run the next time you open it',
        'Nothing is deleted anywhere else, because nothing was ever sent '
            'anywhere else',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icn(Lu.triangleAlert, size: 15, color: T.cautionText),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text(line, style: Type.body15)),
            ],
          ),
        ),
      const SizedBox(height: 4),
      DestructiveButton(
        'Delete all data',
        onPressed: () async {
          final navigator = Navigator.of(sheetContext);
          final settings = context.read<SettingsProvider>();
          final onboarding = context.read<OnboardingProvider>();
          await settings.deleteAllData();
          onboarding.reset();
          navigator.pop();
        },
      ),
      const SizedBox(height: 4),
      GhostButton(
        'Cancel',
        color: T.neutral700,
        onPressed: () => Navigator.of(sheetContext).pop(),
      ),
    ],
  );
});
