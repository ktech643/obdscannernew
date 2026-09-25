import 'dart:convert';

import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/share_file.dart';
import '../../data/backup/backup_codec.dart';
import '../../data/db/app_database.dart';
import '../../design_system/design_system.dart';
import 'erase_everything.dart';

/// Hands the export to the platform share sheet as a `.json` file.
/// [origin] anchors the iPad popover; see [ShareFile].
typedef ShareBackup = Future<void> Function(
  String json,
  String fileName,
  Rect? origin,
);

Future<void> _shareWithSystem(String json, String fileName, Rect? origin) =>
    ShareFile.text(
      json,
      fileName: fileName,
      mimeType: 'application/json',
      subject: 'Torque backup',
      origin: origin,
    );

/// SPEC §5.6 Data & privacy, on the Part B design system — the last
/// sub-screen off the Industry stack.
///
/// Every sentence here is a claim about what the code does, and each one
/// is checked against the code rather than the design. The screen this
/// replaces once disclosed ad requests (there are no ads), offered iCloud
/// sync (there is none — Part 6 says no cloud sync at v1) and said nothing
/// about the one thing that *does* leave the phone: the store and
/// RevenueCat checking a purchase (§8.3, AC-14).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, this.shareBackup = _shareWithSystem});

  /// Where Export sends the file. The system share sheet in the app; a
  /// capture in tests, so they can check exactly what would leave.
  final ShareBackup shareBackup;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Backlit(
      child: Scaffold(
        backgroundColor: t.surfaceDeep,
        appBar: const AdaptiveTopBar(title: 'Data & privacy'),
        body: ListView(
          physics: adaptiveScrollPhysics(context),
          padding: const EdgeInsets.only(bottom: Space.x48),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x16,
                Space.gutter,
                Space.x8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your car's data stays on this phone.",
                    style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
                  ),
                  const SizedBox(height: Space.x12),
                  Text(
                    'Codes, live readings, VINs, service history and trips '
                    'are stored on this device, and Torque sends them nowhere '
                    '— there is no cloud sync and no account. Your phone\'s '
                    'own backup, to iCloud or Google, includes them as it does '
                    'every app\'s data, if you have it turned on.',
                    style: TorqueType.body.copyWith(color: t.inkSecondary),
                  ),
                ],
              ),
            ),
            const ListSection(title: 'What leaves the device'),
            const ListRow(
              title: 'The adapter in your car',
              subtitle:
                  'Commands go to it and readings come back, over Bluetooth '
                  "or the adapter's own Wi-Fi. Nothing goes further.",
            ),
            const ListRow(
              title: 'Purchases',
              subtitle:
                  'The App Store or Google Play, and RevenueCat — which '
                  'checks whether you have Pro — see an anonymous ID and '
                  'your purchases. Never your codes, VIN or vehicle data.',
            ),
            const ListRow(
              title: 'Everything else',
              subtitle:
                  'Nothing. No ads, no analytics, no crash reporting, no '
                  'tracking.',
            ),
            const ListSection(title: 'Your controls'),
            // Its own context: on iPad the share sheet is a popover anchored
            // to the row that opened it.
            Builder(
              builder: (row) => ListRow(
                title: 'Export everything as JSON',
                subtitle:
                    'Every vehicle, scan, service record, reminder, fuel '
                    'entry and trip summary, with full VINs, as a file you '
                    'choose where to keep. Trip recordings are not in it.',
                onTap: () => _export(context, ShareFile.originOf(row)),
              ),
            ),
            ListRow(
              title: 'Delete all data',
              destructive: true,
              onTap: () => _confirmDeleteAll(context),
            ),
          ],
        ),
      ),
    );
  }

  /// SPEC Part 6 — "Full JSON export/import instead [of sync]": every row
  /// of every table, from the database, in the format `BackupCodec.import`
  /// reads back. Nothing is uploaded; the share sheet is the user's choice
  /// of where it goes.
  ///
  /// VINs are whole. A backup is for restoring, and a masked VIN would
  /// restore as a car the garage can never recognise again.
  Future<void> _export(BuildContext context, Rect? origin) async {
    final db = context.read<AppDatabase>();
    final String json;
    try {
      json = const JsonEncoder.withIndent('  ')
          .convert(await BackupCodec(db).export());
    } on Object {
      if (!context.mounted) return;
      await _failed(
        context,
        "Couldn't read your data",
        'Nothing was shared. Try again; if it keeps failing, the database '
            'may be damaged.',
      );
      return;
    }
    // Two failures, two messages: the read and the sheet are different
    // things, and blaming the data for a sheet that would not open sent
    // an iPad user looking in the wrong place.
    try {
      await shareBackup(json, _fileName(DateTime.now()), origin);
    } on Object {
      if (!context.mounted) return;
      await _failed(
        context,
        "Couldn't open the share sheet",
        'Nothing was shared.',
      );
    }
  }

  Future<void> _failed(BuildContext context, String title, String message) =>
      showAdaptiveAlert(
        context,
        title: title,
        message: message,
        actions: [
          AdaptiveAlertAction(label: 'OK', isDefault: true, onPressed: () {}),
        ],
      );

  static String _fileName(DateTime d) =>
      'torque-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}.json';
}

/// Deleting everything is irreversible, so it is confirmed by naming the
/// consequences before offering the action — and the action itself is
/// two taps (B.5). Not dismissible by the backdrop: the way out is Cancel.
void _confirmDeleteAll(BuildContext context) => showAdaptiveSheet<void>(
  context,
  dismissible: false,
  useRootNavigator: true,
  builder: (_) => _DeleteAllSheet(screenContext: context),
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
    'Torque never sent anything about your car anywhere. A copy in your '
        'phone\'s own backup, to iCloud or Google, is not erased by this',
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
      await showAdaptiveAlert(
        screen,
        title: "Torque couldn't finish deleting your data",
        message: 'Try again — it picks up where it stopped.',
        actions: [
          AdaptiveAlertAction(label: 'OK', isDefault: true, onPressed: () {}),
        ],
      );
    }
  }

  /// While the erase runs the sheet cannot be dismissed: the route is not
  /// dismissible, and this `PopScope` refuses Android back while busy —
  /// two guards, either of which holds on its own. A sheet popped
  /// mid-erase had nowhere to report a failure and let a second erase
  /// start under the first.
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x24,
            Space.gutter,
            Space.x24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete all data?',
                  style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
                ),
                const SizedBox(height: Space.x16),
                for (final line in _consequences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.x12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 18,
                          color: t.tellAmber,
                        ),
                        const SizedBox(width: Space.x12),
                        Expanded(
                          child: Text(
                            line,
                            style: TorqueType.body.copyWith(
                              color: t.inkPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.x12),
                DestructiveButton(
                  label: _busy ? 'Deleting…' : 'Delete all data',
                  confirmLabel: 'Tap again to delete everything',
                  enabled: !_busy,
                  onConfirmed: _erase,
                ),
                const SizedBox(height: Space.x8),
                GhostButton(
                  label: 'Cancel',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
