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
import 'vehicle_form_screen.dart' show VehicleFormScreen;

extension ServiceTypeLabel on ServiceType {
  String get label => switch (this) {
    ServiceType.maintenance => 'Service',
    ServiceType.repair => 'Repair',
    ServiceType.inspection => 'Inspection',
    ServiceType.tyres => 'Tyres',
    ServiceType.other => 'Other',
  };
}

/// SPEC §5.5 — the maintenance log: what was done to the car, when, at
/// what reading, for how much. Newest first, straight off the database, so
/// a record added on the form is on the list the moment it is saved.
///
/// §7.2: ten records on the free plan, and the eleventh is a §7.3 paywall
/// trigger. The ones already there are never locked — they stay readable,
/// editable and deletable whatever the plan (§7.5: a downgrade never takes
/// data away).
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.garage,
    required this.vehicle,
    this.unit = DistanceUnit.km,
    this.currencyCode = 'USD',
    this.isPro = false,
    this.onUpgrade,
  });

  final GarageController garage;
  final VehicleRow vehicle;
  final DistanceUnit unit;

  /// For new records; an existing record keeps the currency it was
  /// written in.
  final String currencyCode;
  final bool isPro;
  final VoidCallback? onUpgrade;

  /// §7.2 "Maintenance entries: 10".
  static const freeRecords = 10;

  ServiceRepository get _services => garage.services!;

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: AdaptiveTopBar(title: 'Maintenance log'),
          body: StreamBuilder<List<ServiceRecordRow>>(
            stream: _services.watchRecords(vehicle.id),
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
              return ListView(
                physics: adaptiveScrollPhysics(context),
                padding: const EdgeInsets.only(bottom: Space.x48),
                children: [
                  if (rows.isEmpty)
                    const EmptyStateView(
                      title: 'Nothing recorded yet',
                      why:
                          'Services, repairs, inspections and tyres — with the '
                          'date, the reading and the cost. It all stays on '
                          'this phone.',
                      icon: Icons.build_outlined,
                    )
                  else ...[
                    ListSection(title: vehicle.nickname),
                    for (final r in rows)
                      ListRow(
                        title: r.title,
                        subtitle: _subtitle(r),
                        value: r.cost == null
                            ? null
                            : Money.format(r.cost!, r.currencyCode),
                        onTap: () => _open(context, r),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(Space.gutter),
                    child: PrimaryButton(
                      label: 'Add a record',
                      icon: Icons.add,
                      onPressed: () => _add(context, rows.length),
                    ),
                  ),
                  if (!isPro)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      child: Text(
                        '${rows.length} of $freeRecords records on the free '
                        'plan.',
                        style: TorqueType.meta.copyWith(color: t.inkTertiary),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    ),
  );

  String _subtitle(ServiceRecordRow r) => [
    formatDay(r.date),
    r.type.label,
    if (r.odometerKm != null)
      '${Distance.display(r.odometerKm!, unit)} ${unit.label}',
    if (r.vendor != null && r.vendor!.isNotEmpty) r.vendor!,
  ].join(' · ');

  Future<void> _add(BuildContext context, int count) async {
    if (!isPro && count >= freeRecords) {
      await showAdaptiveAlert(
        context,
        title: '$freeRecords records on the free plan',
        message:
            'More maintenance records are part of Pro. Every record you '
            'have stays, and you can still edit or delete any of them.',
        actions: [
          AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
          if (onUpgrade != null)
            AdaptiveAlertAction(
              label: 'See Pro',
              isDefault: true,
              onPressed: onUpgrade!,
            ),
        ],
      );
      return;
    }
    await _open(context, null);
  }

  Future<void> _open(BuildContext context, ServiceRecordRow? existing) =>
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => ServiceRecordFormScreen(
            garage: garage,
            vehicle: vehicle,
            existing: existing,
            unit: unit,
            currencyCode: currencyCode,
          ),
        ),
      );
}

/// Add or edit one maintenance record. §9.8 for what is typed: the table's
/// own limits (title 1–200, notes ≤ 5,000), the vehicle form's odometer
/// bound, a date no later than today — a record is something that happened.
class ServiceRecordFormScreen extends StatefulWidget {
  const ServiceRecordFormScreen({
    super.key,
    required this.garage,
    required this.vehicle,
    this.existing,
    this.unit = DistanceUnit.km,
    this.currencyCode = 'USD',
    this.today,
  });

  final GarageController garage;
  final VehicleRow vehicle;
  final ServiceRecordRow? existing;
  final DistanceUnit unit;
  final String currencyCode;

  /// For tests; the device's date otherwise.
  final DateTime? today;

  static const titleMax = 200;
  static const vendorMax = 100;
  static const notesMax = 5000;

  @override
  State<ServiceRecordFormScreen> createState() =>
      _ServiceRecordFormScreenState();
}

class _ServiceRecordFormScreenState extends State<ServiceRecordFormScreen> {
  ServiceRecordRow? get _e => widget.existing;

  late ServiceType _type = _e?.type ?? ServiceType.maintenance;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late DateTime _date = (_e?.date ?? _today).toLocal();
  late final _odometer = TextEditingController(
    text: _e?.odometerKm == null
        ? ''
        : Distance.display(_e!.odometerKm!, widget.unit),
  );
  late final _cost = TextEditingController(
    text: _e?.cost == null ? '' : _e!.cost!.toStringAsFixed(2),
  );
  late final _vendor = TextEditingController(text: _e?.vendor ?? '');
  late final _notes = TextEditingController(text: _e?.notes ?? '');

  bool _submitted = false;
  bool _saving = false;

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get _currency => _e?.currencyCode ?? widget.currencyCode;

  @override
  void dispose() {
    for (final c in [_title, _odometer, _cost, _vendor, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _titleError {
    final v = _title.text.trim();
    if (v.isEmpty) return 'Say what was done.';
    if (v.length > ServiceRecordFormScreen.titleMax) {
      return 'Keep it under ${ServiceRecordFormScreen.titleMax} characters.';
    }
    return null;
  }

  double? get _odometerKm {
    final raw = _odometer.text.trim();
    if (raw.isEmpty) return null;
    final v = Distance.parse(raw);
    return v == null ? null : Distance.toKm(v, widget.unit);
  }

  String? get _odometerError {
    if (_odometer.text.trim().isEmpty) return null;
    final km = _odometerKm;
    if (km == null || km < 0 || km > VehicleFormScreen.odometerMaxKm) {
      return 'A reading between 0 and '
          '${Distance.display(VehicleFormScreen.odometerMaxKm, widget.unit)} '
          '${widget.unit.label}.';
    }
    return null;
  }

  double? get _costValue {
    final raw = _cost.text.trim();
    return raw.isEmpty ? null : Money.parse(raw);
  }

  String? get _costError {
    if (_cost.text.trim().isEmpty) return null;
    final v = _costValue;
    if (v == null || v < 0 || v > Money.max) {
      return 'An amount, like 42.50.';
    }
    return null;
  }

  String? get _notesError =>
      _notes.text.length > ServiceRecordFormScreen.notesMax
      ? 'Keep notes under ${ServiceRecordFormScreen.notesMax} characters.'
      : null;

  bool get _valid =>
      _titleError == null &&
      _odometerError == null &&
      _costError == null &&
      _notesError == null;

  Future<void> _pickDate() async {
    final picked = await showAdaptiveDatePicker(
      context,
      initial: _date,
      first: DateTime(1980),
      last: _today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_valid) return;
    setState(() => _saving = true);
    final services = widget.garage.services!;
    final km = _odometerKm;
    final vendor = _vendor.text.trim();
    final notes = _notes.text.trim();
    try {
      final e = _e;
      if (e == null) {
        await services.addRecord(
          vehicleId: widget.vehicle.id,
          type: _type,
          title: _title.text.trim(),
          date: _date,
          odometerKm: km,
          cost: _costValue,
          currencyCode: _currency,
          vendor: vendor.isEmpty ? null : vendor,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        // The row as it is on disk, with only this form's fields changed:
        // attachments and linked codes are not on the form and stay.
        await services.updateRecord(
          e.copyWith(
            type: _type,
            title: _title.text.trim(),
            date: _date,
            odometerKm: Value(km),
            cost: Value(_costValue),
            vendor: Value(vendor.isEmpty ? null : vendor),
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      }
      // A higher reading than the car's is the newest reading there is —
      // and reminders due by distance are judged against it.
      final current = _vehicleNow();
      if (km != null &&
          (current?.odometerKm == null || km > current!.odometerKm!)) {
        await widget.garage.updateOdometer(widget.vehicle.id, km);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  VehicleRow? _vehicleNow() {
    for (final v in widget.garage.all) {
      if (v.id == widget.vehicle.id) return v;
    }
    return widget.vehicle;
  }

  Future<void> _delete() async {
    await widget.garage.services!.deleteRecord(_e!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        final editing = _e != null;
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: AdaptiveTopBar(
            title: editing ? 'Edit record' : 'Add a record',
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
              ChoiceChips<ServiceType>(
                label: 'Kind',
                values: ServiceType.values,
                value: _type,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _type = v),
              ),
              LabelledField(
                label: 'What was done',
                hint: 'Oil and filter',
                controller: _title,
                maxLength: ServiceRecordFormScreen.titleMax,
                capitalization: TextCapitalization.sentences,
                autofocus: !editing,
                error: _submitted ? _titleError : null,
                onChanged: (_) => setState(() {}),
              ),
              LabelledDateField(
                label: 'Date',
                date: _date,
                format: formatDay,
                onPick: _pickDate,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Odometer (${widget.unit.label})',
                      hint: 'Optional',
                      controller: _odometer,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      error: _submitted ? _odometerError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Space.x12),
                  Expanded(
                    child: LabelledField(
                      label: 'Cost ($_currency)',
                      hint: 'Optional',
                      controller: _cost,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      error: _submitted ? _costError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              LabelledField(
                label: 'Where',
                hint: 'Optional — the garage or "myself"',
                controller: _vendor,
                maxLength: ServiceRecordFormScreen.vendorMax,
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              LabelledField(
                label: 'Notes',
                hint: 'Optional — parts, part numbers, what they said',
                controller: _notes,
                maxLines: null,
                maxLength: ServiceRecordFormScreen.notesMax,
                capitalization: TextCapitalization.sentences,
                error: _submitted ? _notesError : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.x8),
              PrimaryButton(
                label: editing ? 'Save' : 'Add record',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              if (editing) ...[
                const SizedBox(height: Space.x16),
                DestructiveButton(
                  label: 'Delete this record',
                  confirmLabel: 'Tap again to delete it',
                  enabled: !_saving,
                  onConfirmed: _delete,
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
