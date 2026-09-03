import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/garage_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

/// E4 — reminders. Overdue in amber, the timing belt flagged CRITICAL, and an
/// explanation of why the odometer has to be estimated rather than read.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    return Screen(
      title: 'Reminders',
      backLabel: 'Garage',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          PrimaryButton(
            'New reminder',
            onPressed: () => notImplementedHere(
              context,
              'Reminder editing lands with the next Garage pass.',
            ),
          ),
        ],
      ),
      children: [
        if (!g.notificationsEnabled) ...[
          // A reminder that cannot notify is not a reminder. Say so, and give
          // the fix inline.
          NoteBlock(
            "Reminders won't notify you — notifications are off for Torque.",
            tone: Tone.caution,
            child: SecondaryButton('Enable', onPressed: g.enableNotifications),
          ),
          const SizedBox(height: 20),
        ],
        for (final r in GarageProvider.reminders) _ReminderRow(reminder: r),
        const SectionHeading('How mileage reminders work'),
        Text(
          "The odometer isn't a standard OBD2 reading, so Torque can't read it "
          'off the car. We estimate from trip distance between sessions and ask '
          'you to confirm when a drive ends.',
          style: Type.bodyMuted,
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) => AppListRow(
    title: reminder.title,
    subtitle: reminder.detail,
    titleStyle: Type.rowPrimary.copyWith(
      color: reminder.paused
          ? T.neutral700
          : reminder.overdue
          ? T.cautionText
          : T.text,
    ),
    severityBar: reminder.overdue
        ? T.cautionBorder
        : reminder.critical
        ? T.fault
        : null,
    trailing: reminder.critical
        ? const TelltaleChip('Critical', tone: Tone.fault)
        : reminder.overdue
        ? const TelltaleChip('Overdue', tone: Tone.caution)
        : null,
    chevron: true,
    onTap: () => notImplementedHere(
      context,
      'Reminder editing lands with the next Garage pass.',
    ),
  );
}
