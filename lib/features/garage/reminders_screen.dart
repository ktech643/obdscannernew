import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/service_repository.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import 'distance.dart';
import 'garage_controller.dart';
import 'service_intervals.dart';

/// SPEC §5.5 — reminders: what is due, by date or by reading, and what
/// repeats. Overdue first, because that is the question the screen is
/// opened to answer; then due soon, coming up, paused, done.
///
/// The overdue rule is [reminderStatus], the same one behind the Garage
/// card's count and the health score's −5 each, so the three never
/// disagree about the same reminder.
///
/// Not here yet: the local notifications §5.5 names. They need a
/// notifications plugin and the permission flow (§9.3's Android 13 prompt
/// already exists for the foreground service); until then a reminder is
/// something the app shows, not something it pings.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({
    super.key,
    required this.garage,
    required this.vehicle,
    this.unit = DistanceUnit.km,
    this.now,
  });

  final GarageController garage;
  final VehicleRow vehicle;
  final DistanceUnit unit;

  /// For tests; the device's clock otherwise.
  final DateTime Function()? now;

  ServiceRepository get _services => garage.services!;

  /// The vehicle as the garage has it now — its odometer moves while this
  /// screen is open (a service record, a connect), and "due by distance"
  /// is judged against it.
  VehicleRow get _vehicle {
    for (final v in garage.all) {
      if (v.id == vehicle.id) return v;
    }
    return vehicle;
  }

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: const AdaptiveTopBar(title: 'Reminders'),
          body: ListenableBuilder(
            listenable: garage,
            builder: (context, _) => StreamBuilder<List<ReminderRow>>(
              stream: _services.watchReminders(vehicle.id),
              builder: (context, snap) {
                final rows = snap.data;
                if (rows == null) {
                  return const Padding(
                    padding: EdgeInsets.all(Space.gutter),
                    child: Column(
                      children: [
                        Skeleton(height: 48),
                        SizedBox(height: Space.x8),
                        Skeleton(height: 48),
                      ],
                    ),
                  );
                }
                return _list(context, t, rows);
              },
            ),
          ),
        );
      },
    ),
  );

  Widget _list(BuildContext context, TorqueTokens t, List<ReminderRow> rows) {
    final at = (now ?? DateTime.now)();
    final odo = _vehicle.odometerKm;
    final grouped = <ReminderStatus, List<ReminderRow>>{};
    for (final r in rows) {
      grouped
          .putIfAbsent(reminderStatus(r, odometerKm: odo, now: at), () => [])
          .add(r);
    }
    return ListView(
      physics: adaptiveScrollPhysics(context),
      padding: const EdgeInsets.only(bottom: Space.x48),
      children: [
        if (rows.isEmpty)
          const EmptyStateView(
            title: 'No reminders yet',
            why:
                'Oil, brakes, the timing belt, the inspection — by date, by '
                'reading, or both. They count towards the health score when '
                'they are overdue.',
            icon: Icons.notifications_none,
          ),
        for (final status in ReminderStatus.values)
          if (grouped[status] case final list?) ...[
            ListSection(title: _heading(status)),
            for (final r in list)
              ListRow(
                title: r.title,
                subtitle: _describe(r),
                value: _word(r, status, odo, at),
                tone: switch (status) {
                  ReminderStatus.overdue => r.critical ? Tell.red : Tell.amber,
                  ReminderStatus.dueSoon => Tell.amber,
                  _ => Tell.none,
                },
                onTap: () => _actions(context, r, status),
              ),
          ],
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: PrimaryButton(
            label: 'Add a reminder',
            icon: Icons.add,
            onPressed: () => _add(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Text(
            'Suggested intervals are a starting point. '
            '${ServicePreset.manualNote}',
            style: TorqueType.meta.copyWith(color: t.inkTertiary),
          ),
        ),
      ],
    );
  }

  static String _heading(ReminderStatus s) => switch (s) {
    ReminderStatus.overdue => 'Overdue',
    ReminderStatus.dueSoon => 'Due soon',
    ReminderStatus.upcoming => 'Coming up',
    ReminderStatus.paused => 'Paused',
    ReminderStatus.done => 'Done',
  };

  /// "Every 10,000 km or 6 months · next at 152,380 km or 24 Mar 2027".
  String _describe(ReminderRow r) {
    final every = [
      if (r.repeatEveryKm != null)
        '${Distance.display(r.repeatEveryKm!, unit)} ${unit.label}',
      if (r.repeatEveryDays != null)
        _months(ServicePreset.monthsForDays(r.repeatEveryDays!)),
    ];
    final next = [
      if (r.dueOdometerKm != null)
        '${Distance.display(r.dueOdometerKm!, unit)} ${unit.label}',
      if (r.dueDate != null) formatDay(r.dueDate!),
    ];
    return [
      if (every.isNotEmpty) 'Every ${every.join(' or ')}',
      if (next.isNotEmpty && r.completedAt == null)
        'next at ${next.join(' or ')}',
      if (r.completedAt != null) 'done ${formatDay(r.completedAt!)}',
      if (r.critical) 'critical',
    ].join(' · ');
  }

  static String _months(int m) => m % 12 == 0 && m >= 12
      ? '${m ~/ 12} year${m == 12 ? '' : 's'}'
      : '$m month${m == 1 ? '' : 's'}';

  /// The status as a word, with the distance or time left when it is
  /// coming up — the colour never has to say it alone.
  String _word(ReminderRow r, ReminderStatus s, double? odo, DateTime at) {
    switch (s) {
      case ReminderStatus.overdue:
        return 'Overdue';
      case ReminderStatus.paused:
        return 'Paused';
      case ReminderStatus.done:
        return 'Done';
      case ReminderStatus.dueSoon:
      case ReminderStatus.upcoming:
        final left = <String>[
          if (r.dueOdometerKm != null && odo != null)
            'in ${Distance.display(r.dueOdometerKm! - odo, unit)} ${unit.label}',
          if (r.dueDate != null) _inTime(r.dueDate!.difference(at)),
        ];
        final word = s == ReminderStatus.dueSoon ? 'Due soon' : 'Due';
        return left.isEmpty ? word : '$word ${left.first}';
    }
  }

  static String _inTime(Duration d) {
    final days = d.inDays;
    if (days < 1) return 'today';
    if (days < 14) return 'in $days day${days == 1 ? '' : 's'}';
    if (days < 60) return 'in ${(days / 7).round()} weeks';
    return 'in ${(days / 30.4375).round()} months';
  }

  Future<void> _actions(
    BuildContext context,
    ReminderRow r,
    ReminderStatus status,
  ) => showAdaptiveSheet<void>(
    context,
    builder: (sheet) {
      final t = sheet.tokens;
      void then(Future<void> Function() f) {
        Navigator.of(sheet).pop();
        f();
      }

      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x24,
                Space.gutter,
                Space.x8,
              ),
              child: Text(
                r.title,
                style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
              ),
            ),
            if (status != ReminderStatus.done)
              ListRow(
                title: 'Mark as done',
                subtitle: r.repeatEveryKm != null || r.repeatEveryDays != null
                    ? 'It repeats, so the next one is set from today and '
                          'the current reading.'
                    : null,
                onTap: () => then(
                  () =>
                      _services.complete(r.id, odometerKm: _vehicle.odometerKm),
                ),
              ),
            if (status != ReminderStatus.done)
              ListRow(
                title: r.paused ? 'Resume' : 'Pause',
                subtitle: r.paused
                    ? null
                    : 'A paused reminder is never overdue.',
                onTap: () => then(() => _services.setPaused(r.id, !r.paused)),
              ),
            ListRow(
              title: 'Edit',
              onTap: () => then(() => _open(context, existing: r)),
            ),
            ListRow(
              title: 'Delete',
              destructive: true,
              onTap: () => then(() => _confirmDelete(context, r)),
            ),
            const SizedBox(height: Space.x16),
          ],
        ),
      );
    },
  );

  Future<void> _confirmDelete(BuildContext context, ReminderRow r) =>
      showAdaptiveAlert(
        context,
        title: 'Delete “${r.title}”?',
        message: 'The reminder goes. Nothing recorded in the log changes.',
        actions: [
          AdaptiveAlertAction(label: 'Keep', isDefault: true, onPressed: () {}),
          AdaptiveAlertAction(
            label: 'Delete',
            destructive: true,
            onPressed: () => _services.deleteReminder(r.id),
          ),
        ],
      );

  /// A §5.5 preset, or something else.
  Future<void> _add(BuildContext context) async {
    final picked = await showAdaptiveSheet<_Pick>(
      context,
      builder: (sheet) {
        final t = sheet.tokens;
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x24,
                  Space.gutter,
                  Space.x8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to remind you about',
                      style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                    ),
                    const SizedBox(height: Space.x8),
                    Text(
                      ServicePreset.manualNote,
                      style: TorqueType.meta.copyWith(color: t.inkSecondary),
                    ),
                  ],
                ),
              ),
              for (final p in ServicePreset.all)
                ListRow(
                  title: p.title,
                  subtitle: _presetRule(p),
                  onTap: () => Navigator.of(sheet).pop(_Pick(p)),
                ),
              ListRow(
                title: 'Something else',
                onTap: () => Navigator.of(sheet).pop(const _Pick(null)),
              ),
              const SizedBox(height: Space.x16),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    await _open(context, preset: picked.preset);
  }

  String _presetRule(ServicePreset p) => [
    if (p.everyKm != null)
      '${Distance.display(p.everyKm!, unit)} ${unit.label}',
    if (p.everyMonths != null) _months(p.everyMonths!),
  ].join(' or ');

  Future<void> _open(
    BuildContext context, {
    ReminderRow? existing,
    ServicePreset? preset,
  }) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => ReminderFormScreen(
        services: _services,
        vehicle: _vehicle,
        existing: existing,
        preset: preset,
        unit: unit,
        today: now?.call(),
      ),
    ),
  );
}

class _Pick {
  const _Pick(this.preset);
  final ServicePreset? preset;
}

/// Add or edit one reminder.
///
/// A reminder needs something to be due by: a date, a reading, or an
/// interval to set them from. From a preset, the next due date is today
/// plus the interval and the next reading is the car's plus the interval —
/// both shown, both editable, and the owner's-manual line is on the form.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({
    super.key,
    required this.services,
    required this.vehicle,
    this.existing,
    this.preset,
    this.unit = DistanceUnit.km,
    this.today,
  });

  final ServiceRepository services;
  final VehicleRow vehicle;
  final ReminderRow? existing;
  final ServicePreset? preset;
  final DistanceUnit unit;
  final DateTime? today;

  static const titleMax = 200;

  /// Bounds on what an interval can be: a reminder every 50 km is a typo,
  /// and one every 500,000 km or 20 years will never fire.
  static const minEveryKm = 100.0;
  static const maxEveryKm = 500000.0;
  static const maxEveryMonths = 240;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  ReminderRow? get _e => widget.existing;
  ServicePreset? get _p => widget.preset;
  DistanceUnit get _unit => widget.unit;

  late final _title = TextEditingController(text: _e?.title ?? _p?.title ?? '');
  late final _detail = TextEditingController(text: _e?.detail ?? '');
  late final _everyKm = TextEditingController(
    text: _kmText(_e?.repeatEveryKm ?? _p?.everyKm),
  );
  late final _everyMonths = TextEditingController(
    text: () {
      final days = _e?.repeatEveryDays ?? _p?.everyDays;
      return days == null ? '' : '${ServicePreset.monthsForDays(days)}';
    }(),
  );
  late final _dueKm = TextEditingController(text: _kmText(_initialDueKm()));
  late DateTime? _dueDate = _initialDueDate();
  late bool _critical = _e?.critical ?? _p?.critical ?? false;

  bool _submitted = false;
  bool _saving = false;

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _kmText(double? km) => km == null ? '' : Distance.display(km, _unit);

  double? _initialDueKm() {
    if (_e != null) return _e!.dueOdometerKm;
    final every = _p?.everyKm;
    final odo = widget.vehicle.odometerKm;
    return every == null || odo == null ? null : odo + every;
  }

  DateTime? _initialDueDate() {
    if (_e != null) return _e!.dueDate?.toLocal();
    final days = _p?.everyDays;
    return days == null ? null : _today.add(Duration(days: days));
  }

  @override
  void dispose() {
    for (final c in [_title, _detail, _everyKm, _everyMonths, _dueKm]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _km(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = Distance.parse(raw);
    return v == null ? double.nan : Distance.toKm(v, _unit);
  }

  int? get _months {
    final raw = _everyMonths.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw) ?? -1;
  }

  String? get _titleError {
    final v = _title.text.trim();
    if (v.isEmpty) return 'Say what it is for.';
    if (v.length > ReminderFormScreen.titleMax) {
      return 'Keep it under ${ReminderFormScreen.titleMax} characters.';
    }
    return null;
  }

  String? get _everyKmError {
    final km = _km(_everyKm);
    if (km == null) return null;
    if (km.isNaN ||
        km < ReminderFormScreen.minEveryKm ||
        km > ReminderFormScreen.maxEveryKm) {
      return 'Between '
          '${Distance.display(ReminderFormScreen.minEveryKm, _unit)} and '
          '${Distance.display(ReminderFormScreen.maxEveryKm, _unit)} '
          '${_unit.label}.';
    }
    return null;
  }

  String? get _everyMonthsError {
    final m = _months;
    if (m == null) return null;
    if (m < 1 || m > ReminderFormScreen.maxEveryMonths) {
      return 'Between 1 and ${ReminderFormScreen.maxEveryMonths} months.';
    }
    return null;
  }

  String? get _dueKmError {
    final km = _km(_dueKm);
    if (km == null) return null;
    if (km.isNaN || km < 0 || km > 2000000) {
      return 'A reading between 0 and '
          '${Distance.display(2000000, _unit)} ${_unit.label}.';
    }
    return null;
  }

  /// Nothing to be due by: no date, no reading, no interval to set them.
  String? get _triggerError =>
      _dueDate == null &&
          _km(_dueKm) == null &&
          _km(_everyKm) == null &&
          _months == null
      ? 'Give it a date, a reading or an interval — otherwise it can never '
            'be due.'
      : null;

  bool get _valid =>
      _titleError == null &&
      _everyKmError == null &&
      _everyMonthsError == null &&
      _dueKmError == null &&
      _triggerError == null;

  Future<void> _pickDate() async {
    final picked = await showAdaptiveDatePicker(
      context,
      initial: _dueDate ?? _today.add(const Duration(days: 30)),
      first: _today.subtract(const Duration(days: 365 * 5)),
      last: _today.add(const Duration(days: 365 * 20)),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_valid) return;
    setState(() => _saving = true);
    final everyKm = _km(_everyKm);
    final months = _months;
    final everyDays = months == null
        ? null
        : ServicePreset.daysForMonths(months);
    var dueKm = _km(_dueKm);
    var dueDate = _dueDate;
    // An interval with no first due point starts from now: that is what
    // "every 10,000 km" means to someone adding it today.
    final odo = widget.vehicle.odometerKm;
    if (dueKm == null && everyKm != null && odo != null) dueKm = odo + everyKm;
    if (dueDate == null && everyDays != null) {
      dueDate = _today.add(Duration(days: everyDays));
    }
    final detail = _detail.text.trim();
    try {
      final e = _e;
      if (e == null) {
        await widget.services.addReminder(
          vehicleId: widget.vehicle.id,
          title: _title.text.trim(),
          detail: detail.isEmpty ? null : detail,
          dueDate: dueDate,
          dueOdometerKm: dueKm,
          repeatEveryDays: everyDays,
          repeatEveryKm: everyKm,
          critical: _critical,
        );
      } else {
        await widget.services.updateReminder(
          e.copyWith(
            title: _title.text.trim(),
            detail: Value(detail.isEmpty ? null : detail),
            dueDate: Value(dueDate),
            dueOdometerKm: Value(dueKm),
            repeatEveryDays: Value(everyDays),
            repeatEveryKm: Value(everyKm),
            critical: _critical,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        final editing = _e != null;
        final km = TextInputType.numberWithOptions(decimal: true);
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: AdaptiveTopBar(
            title: editing ? 'Edit reminder' : 'Add a reminder',
          ),
          body: ListView(
            physics: adaptiveScrollPhysics(context),
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x16,
              Space.gutter,
              Space.x48,
            ),
            children: [
              if (_p != null) ...[
                Text(
                  ServicePreset.manualNote,
                  style: TorqueType.meta.copyWith(color: t.tellAmber),
                ),
                const SizedBox(height: Space.x16),
              ],
              LabelledField(
                label: 'Reminder',
                hint: 'Oil and filter',
                controller: _title,
                maxLength: ReminderFormScreen.titleMax,
                capitalization: TextCapitalization.sentences,
                autofocus: !editing && _p == null,
                error: _submitted ? _titleError : null,
                onChanged: (_) => setState(() {}),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Every (${_unit.label})',
                      hint: 'Optional',
                      controller: _everyKm,
                      keyboard: km,
                      error: _submitted ? _everyKmError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Space.x12),
                  Expanded(
                    child: LabelledField(
                      label: 'Every (months)',
                      hint: 'Optional',
                      controller: _everyMonths,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      error: _submitted ? _everyMonthsError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              LabelledField(
                label: 'Next due at (${_unit.label})',
                hint: widget.vehicle.odometerKm == null
                    ? 'Optional'
                    : 'Now ${_kmText(widget.vehicle.odometerKm)}',
                controller: _dueKm,
                keyboard: km,
                error: _submitted ? _dueKmError : null,
                onChanged: (_) => setState(() {}),
              ),
              LabelledDateField(
                label: 'Next due on',
                date: _dueDate,
                format: formatDay,
                onPick: _pickDate,
                onClear: _dueDate == null
                    ? null
                    : () => setState(() => _dueDate = null),
              ),
              LabelledField(
                label: 'Notes',
                hint: 'Optional — the part, the garage, the grade of oil',
                controller: _detail,
                maxLines: null,
                capitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              Semantics(
                toggled: _critical,
                label: 'Critical — shown in red when overdue',
                onTap: () => setState(() => _critical = !_critical),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Critical — shown in red when overdue',
                          style: TorqueType.body.copyWith(color: t.inkPrimary),
                        ),
                      ),
                      AdaptiveSwitch(
                        value: _critical,
                        onChanged: (v) => setState(() => _critical = v),
                      ),
                    ],
                  ),
                ),
              ),
              if (_submitted && _triggerError != null) ...[
                const SizedBox(height: Space.x16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Tell.red.glyph, size: 14, color: t.tellRed),
                    const SizedBox(width: Space.x4),
                    Expanded(
                      child: Text(
                        _triggerError!,
                        style: TorqueType.meta.copyWith(color: t.tellRed),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.x24),
              PrimaryButton(
                label: editing ? 'Save' : 'Add reminder',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        );
      },
    ),
  );
}
