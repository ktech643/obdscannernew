import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/db/app_database.dart';
import '../../features/settings/erase_everything.dart';
import '../../models/enums.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

/// Hands the export to the platform share sheet as a `.json` file.
typedef ShareBackup = Future<void> Function(String json, String fileName);

Future<void> _shareWithSystem(String json, String fileName) async {
  await Share.shareXFiles(
    [XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
    fileNameOverrides: [fileName],
    subject: 'Torque backup',
  );
}

/// F4 — data & privacy.
///
/// Every sentence on this screen is a claim about what the app does, so
/// each one is checked against the code rather than the design. An earlier
/// version disclosed ad requests (there are no ads), offered iCloud sync
/// (there is none — Part 6 says no cloud sync at v1), a "Personalised ads"
/// switch that asked iOS for nothing, and said nothing at all about the one
/// thing that *does* leave the phone: the store and RevenueCat checking a
/// purchase (SPEC §8.3, AC-14). Its Export copied a hard-coded sample car
/// rather than the database, and its Delete cleared the preferences and
/// left every row and recording where it was.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, this.shareBackup = _shareWithSystem});

  /// Where Export sends the file. The system share sheet in the app; a
  /// capture in tests, so they can check exactly what would leave.
  final ShareBackup shareBackup;

  @override
  Widget build(BuildContext context) {
    return Screen(
      title: 'Data & privacy',
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Text("Your car's data stays on this phone.", style: Type.cardTitleLg),
        const SizedBox(height: 10),
        Text(
          'Codes, live readings, VINs, service history and trips are stored '
          'on this device and nowhere else. There is no cloud sync and no '
          'account.',
          style: Type.body16Muted,
        ),
        const SectionHeading('What leaves the device'),
        const AppListRow(
          title: 'The adapter in your car',
          subtitle:
              'Commands go to it and readings come back, over Bluetooth or '
              "the adapter's own Wi-Fi. Nothing goes further.",
        ),
        const AppListRow(
          title: 'Purchases',
          subtitle:
              'The App Store or Google Play, and RevenueCat — which checks '
              'whether you have Pro — see an anonymous ID and your purchases. '
              'Never your codes, VIN or vehicle data.',
        ),
        const AppListRow(
          title: 'Everything else',
          subtitle:
              'Nothing. No ads, no analytics, no crash reporting, no '
              'tracking.',
        ),
        const SectionHeading('Your controls'),
        AppListRow(
          title: 'Export everything as JSON',
          subtitle:
              'Every vehicle, scan, service record and trip summary, with '
              'full VINs, as a file you choose where to keep. Trip '
              'recordings are not in it.',
          chevron: true,
          onTap: () => _export(context),
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

  /// SPEC Part 6 — "Full JSON export/import instead [of sync]": every row
  /// of every table, from the database, in the format `BackupCodec.import`
  /// reads back. Nothing is uploaded; the share sheet is the user's choice
  /// of where it goes.
  ///
  /// VINs are whole. A backup is for restoring, and a masked VIN would
  /// restore as a car the garage can never recognise again.
  Future<void> _export(BuildContext context) async {
    final db = context.read<AppDatabase>();
    try {
      final doc = await BackupCodec(db).export();
      final json = const JsonEncoder.withIndent('  ').convert(doc);
      await shareBackup(json, _fileName(DateTime.now()));
    } on Object {
      if (!context.mounted) return;
      Toast.show(
        context,
        "Couldn't read your data to export it. Nothing was shared.",
        tone: Tone.fault,
      );
    }
  }

  static String _fileName(DateTime d) =>
      'torque-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}.json';
}

/// Deleting everything is irreversible, so it is confirmed by naming the
/// consequences before offering the action.
void _confirmDeleteAll(BuildContext context) => showAppSheet<void>(
  context,
  (sheetContext) => _DeleteAllSheet(screenContext: context),
);

class _DeleteAllSheet extends StatefulWidget {
  const _DeleteAllSheet({required this.screenContext});

  /// The privacy screen's context — the sheet's own is gone the moment it
  /// pops, and a failure is reported on the screen underneath.
  final BuildContext screenContext;

  @override
  State<_DeleteAllSheet> createState() => _DeleteAllSheetState();
}

class _DeleteAllSheetState extends State<_DeleteAllSheet> {
  /// One erase at a time: a second tap while the first is still running
  /// would race it through the wipe and the restart.
  bool _busy = false;

  static const _consequences = [
    'Every vehicle, scan, service record and trip recording on this phone '
        'is erased',
    'Your settings go back to their defaults, and the diagnostics log is '
        'emptied',
    'Torque starts again from its first screen',
    'A Pro purchase is kept — it belongs to your App Store or Google Play '
        'account',
    'Nothing is deleted anywhere else, because nothing about your car was '
        'ever sent anywhere else',
  ];

  Future<void> _erase() async {
    setState(() => _busy = true);
    final erase = context.read<EraseEverything>();
    final navigator = Navigator.of(context);
    try {
      // On success the whole app is rebuilt from first run, this sheet
      // included, so there is nothing to pop.
      await erase();
    } on Object {
      if (!mounted) return;
      navigator.pop();
      final screen = widget.screenContext;
      if (!screen.mounted) return;
      Toast.show(
        screen,
        "Torque couldn't finish deleting your data. Try again — it picks up "
        'where it stopped.',
        tone: Tone.fault,
      );
    }
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    eyebrow: 'Data & privacy',
    title: 'Delete all data?',
    children: [
      for (final line in _consequences)
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
        _busy ? 'Deleting…' : 'Delete all data',
        enabled: !_busy,
        onPressed: _erase,
      ),
      const SizedBox(height: 4),
      GhostButton(
        'Cancel',
        color: T.neutral700,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
    ],
  );
}
