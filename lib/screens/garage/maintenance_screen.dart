import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/garage_provider.dart';
import '../../providers/settings_format.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// E2 — the maintenance log, grouped by month with a running year total.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GarageProvider>();
    final s = context.watch<SettingsProvider>();
    final groups = g.recordsByMonth;

    return Screen(
      backLabel: 'Garage',
      onBack: () => Navigator.of(context).pop(),
      title: 'Maintenance log',
      titleTrailing: InlineAction('Filter', onPressed: () {}),
      footer: ScreenFooter(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${g.recordCount} of ${g.freeRecordCeiling} records '
                  'used on Free.',
                  style: Type.footnote,
                ),
              ),
              const SizedBox(width: 12),
              SquareAddButton(
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => const NewServiceRecordScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        Text(
          '${g.active.nickname} · ${s.formatDistance(g.active.odometerKm)}',
          style: Type.rowSecondary,
        ),
        for (final entry in groups.entries) ...[
          SectionHeading(entry.key),
          for (final r in entry.value) _RecordRow(record: r),
        ],
        const SizedBox(height: 18),
        Container(
          decoration: const BoxDecoration(border: T.hairlineTop),
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              Expanded(child: Text('Total · 2026', style: Type.rowPrimary)),
              Text(s.formatMoney(g.yearTotal), style: Type.inlineValueLg),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final ServiceRecord record;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final date =
        '${record.date.day} ${_months[record.date.month - 1]} '
        '${record.date.year}';
    return Container(
      constraints: const BoxConstraints(minHeight: T.touchTargetFloor),
      decoration: const BoxDecoration(border: T.hairlineBottom),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.title,
                        style: Type.rowPrimary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (record.fixedCode != null) ...[
                      const SizedBox(width: 8),
                      // Links the repair back to the code it cleared.
                      Badge('Fixed ${record.fixedCode}', color: T.passText),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    date,
                    s.formatDistance(record.odometerKm),
                    if (record.vendor != null) record.vendor!,
                  ].join(' · '),
                  style: Type.rowSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(s.formatMoney(record.cost), style: Type.inlineValue),
        ],
      ),
    );
  }
}

/// E3 — a new service record.
class NewServiceRecordScreen extends StatefulWidget {
  const NewServiceRecordScreen({super.key});

  @override
  State<NewServiceRecordScreen> createState() => _NewServiceRecordScreenState();
}

class _NewServiceRecordScreenState extends State<NewServiceRecordScreen> {
  int _type = 0;
  bool _reminder = true;
  final _title = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final g = context.read<GarageProvider>();

    return Screen(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          child: Row(
            children: [
              InlineAction(
                'Cancel',
                color: T.neutral700,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'New record',
                  style: Type.cardTitleLg,
                  textAlign: TextAlign.center,
                ),
              ),
              InlineAction(
                'Save',
                onPressed: () {
                  g.addRecord(
                    ServiceRecord(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: _title.text.isEmpty
                          ? GarageProvider.serviceTypes[_type]
                          : _title.text,
                      date: DateTime.now(),
                      odometerKm: g.active.odometerKm,
                      cost: 0,
                      notes: _notes.text,
                    ),
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        Text('TYPE', style: Type.formLabel.copyWith(letterSpacing: 0.9)),
        const SizedBox(height: 10),
        ChoiceChips(
          options: GarageProvider.serviceTypes,
          selected: _type,
          onSelect: (i) => setState(() => _type = i),
        ),
        const SizedBox(height: 18),
        Field(
          label: 'Title',
          controller: _title,
          hint: GarageProvider.serviceTypes[_type],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Field(label: 'Date', hint: '3 Sep 2026'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Field(label: 'Odometer', hint: '142,380', suffix: 'km'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Field(label: 'Cost', hint: '0.00'),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 116,
              child: Field(label: 'Currency', hint: s.currency, enabled: false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Field(label: 'Where', hint: "Marek's"),
        const SizedBox(height: 16),
        Field(
          label: 'Notes  ${_notes.text.length} / 5,000',
          controller: _notes,
          maxLines: 4,
          hint: 'What was done, and why',
        ),
        const SizedBox(height: 16),
        SecondaryButton(
          'Attach a receipt photo',
          onPressed: () {},
          icon: Lu.camera,
        ),
        const SizedBox(height: 18),
        Container(
          decoration: const BoxDecoration(border: T.hairlineTop),
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set the next reminder', style: Type.rowPrimary),
                    const SizedBox(height: 4),
                    Text(
                      '10,000 km or 6 months — whichever first',
                      style: Type.rowSecondary,
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: _reminder,
                onChanged: (v) => setState(() => _reminder = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Mandatory copy: our defaults are a starting point, not the
        // manufacturer's schedule, and saying otherwise costs someone a warranty.
        const NoteBlock(
          "Check your owner's manual — intervals vary by vehicle. Our defaults "
          "are a starting point, not your manufacturer's schedule.",
          tone: Tone.caution,
        ),
      ],
    );
  }
}
