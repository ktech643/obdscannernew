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

/// Economy as the user reads it: L/100 km when they drive in kilometres,
/// and both mpg figures when they drive in miles — "mpg" is a different
/// number in the US and the UK, and the app does not know which they mean.
String formatEconomy(double litresPer100Km, DistanceUnit unit) {
  if (unit == DistanceUnit.km) {
    return '${litresPer100Km.toStringAsFixed(1)} L/100 km';
  }
  final us = FuelSummary.usMpg(litresPer100Km).toStringAsFixed(1);
  final uk = FuelSummary.ukMpg(litresPer100Km).toStringAsFixed(1);
  return '$us mpg US · $uk mpg UK';
}

/// SPEC §5.5 — the fuel log, economy **between full fill-ups only**
/// ([FuelSummary]). A part fill is logged and counted into the next full
/// tank's figure, never given one of its own; the first full tank has none
/// because nothing is known about what was in the tank before it — and the
/// screen says so instead of leaving a blank.
class FuelLogScreen extends StatelessWidget {
  const FuelLogScreen({
    super.key,
    required this.garage,
    required this.vehicle,
    this.unit = DistanceUnit.km,
    this.currencyCode = 'USD',
  });

  final GarageController garage;
  final VehicleRow vehicle;
  final DistanceUnit unit;
  final String currencyCode;

  ServiceRepository get _services => garage.services!;

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: const AdaptiveTopBar(title: 'Fuel log'),
          body: StreamBuilder<List<FuelEntryRow>>(
            stream: _services.watchFuel(vehicle.id),
            builder: (context, snap) {
              final rows = snap.data;
              if (rows == null) {
                return const Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Column(
                    children: [
                      Skeleton(height: 72),
                      SizedBox(height: Space.x8),
                      Skeleton(height: 48),
                    ],
                  ),
                );
              }
              return _list(context, t, rows);
            },
          ),
        );
      },
    ),
  );

  Widget _list(BuildContext context, TorqueTokens t, List<FuelEntryRow> rows) {
    final summary = FuelSummary.of(rows);
    final byId = {for (final e in summary.economy) e.entry.id: e};
    // Newest first on screen; the summary is oldest first by odometer.
    final shown = [...summary.economy.reversed];
    final avg = summary.averageLitresPer100Km;
    return ListView(
      physics: adaptiveScrollPhysics(context),
      padding: const EdgeInsets.only(bottom: Space.x48),
      children: [
        if (rows.isEmpty)
          const EmptyStateView(
            title: 'No fill-ups yet',
            why:
                'Log each fill with the reading on the odometer. Economy '
                'appears from the second full tank on — it needs two to '
                'measure between.',
            icon: Icons.local_gas_station_outlined,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x16,
              Space.gutter,
              0,
            ),
            child: RaisedSurface(
              padding: const EdgeInsets.all(Space.x16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AVERAGE ECONOMY',
                    style: TorqueType.gaugeLabel.copyWith(
                      color: t.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.x8),
                  Text(
                    avg == null ? '—' : formatEconomy(avg, unit),
                    style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
                  ),
                  const SizedBox(height: Space.x4),
                  Text(
                    avg == null
                        ? 'Needs two full tanks to measure between.'
                        : 'Over '
                              '${Distance.display(summary.spanKm, unit)} '
                              '${unit.label}, between full fill-ups only.',
                    style: TorqueType.meta.copyWith(color: t.inkSecondary),
                  ),
                ],
              ),
            ),
          ),
        if (rows.isNotEmpty) const ListSection(title: 'Fill-ups'),
        for (final e in shown)
          ListRow(
            title: formatDay(e.entry.date),
            subtitle: _subtitle(e.entry),
            value: _economyWord(byId[e.entry.id]!, e.entry),
            onTap: () => _open(context, e.entry),
          ),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: PrimaryButton(
            label: 'Add a fill-up',
            icon: Icons.add,
            onPressed: () => _open(context, null),
          ),
        ),
      ],
    );
  }

  String _subtitle(FuelEntryRow e) => [
    '${Distance.display(e.odometerKm, unit)} ${unit.label}',
    '${e.litres.toStringAsFixed(1)} L',
    if (e.cost != null) Money.format(e.cost!, e.currencyCode),
    if (e.partFill) 'part fill',
  ].join(' · ');

  /// Always a word: a figure, or why there is none.
  String _economyWord(FuelEconomy e, FuelEntryRow row) {
    final v = e.litresPer100Km;
    if (v != null) return formatEconomy(v, unit);
    return row.partFill ? 'Counted in the next full tank' : 'Starts the count';
  }

  Future<void> _open(BuildContext context, FuelEntryRow? existing) =>
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => FuelEntryFormScreen(
            garage: garage,
            vehicle: vehicle,
            existing: existing,
            unit: unit,
            currencyCode: currencyCode,
          ),
        ),
      );
}

/// Add or edit one fill-up. The odometer and the litres are required —
/// economy is nothing without both. A reading lower than a fill-up already
/// logged is a caution, not a refusal: adding an old receipt is normal.
class FuelEntryFormScreen extends StatefulWidget {
  const FuelEntryFormScreen({
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
  final FuelEntryRow? existing;
  final DistanceUnit unit;
  final String currencyCode;
  final DateTime? today;

  /// Bounds on one fill: a tenth of a litre is a drip, and past 500 L it
  /// is a lorry or a typo.
  static const minLitres = 0.1;
  static const maxLitres = 500.0;

  @override
  State<FuelEntryFormScreen> createState() => _FuelEntryFormScreenState();
}

class _FuelEntryFormScreenState extends State<FuelEntryFormScreen> {
  FuelEntryRow? get _e => widget.existing;

  late DateTime _date = (_e?.date ?? _today).toLocal();
  late final _odometer = TextEditingController(
    text: _e == null ? '' : Distance.display(_e!.odometerKm, widget.unit),
  );
  late final _litres = TextEditingController(
    text: _e == null ? '' : _e!.litres.toStringAsFixed(2),
  );
  late final _cost = TextEditingController(
    text: _e?.cost == null ? '' : _e!.cost!.toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: _e?.notes ?? '');
  late bool _partFill = _e?.partFill ?? false;

  bool _submitted = false;
  bool _saving = false;

  /// The highest reading already logged, other than this one — for the
  /// caution, read once when the form opens.
  double? _highest;

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get _currency => _e?.currencyCode ?? widget.currencyCode;

  @override
  void initState() {
    super.initState();
    widget.garage.services!.fuel(widget.vehicle.id).then((all) {
      if (!mounted) return;
      final others = all.where((f) => f.id != _e?.id);
      if (others.isEmpty) return;
      setState(
        () => _highest = others
            .map((f) => f.odometerKm)
            .reduce((a, b) => a > b ? a : b),
      );
    });
  }

  @override
  void dispose() {
    for (final c in [_odometer, _litres, _cost, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _odometerKm {
    final v = Distance.parse(_odometer.text.trim());
    return v == null ? null : Distance.toKm(v, widget.unit);
  }

  String? get _odometerError {
    if (_odometer.text.trim().isEmpty) return 'The reading at this fill-up.';
    final km = _odometerKm;
    if (km == null || km < 0 || km > VehicleFormScreen.odometerMaxKm) {
      return 'A reading between 0 and '
          '${Distance.display(VehicleFormScreen.odometerMaxKm, widget.unit)} '
          '${widget.unit.label}.';
    }
    return null;
  }

  String? get _odometerCaution {
    final km = _odometerKm;
    final top = _highest;
    if (km == null || top == null || km >= top) return null;
    return 'Lower than a fill-up already logged at '
        '${Distance.display(top, widget.unit)} ${widget.unit.label} — fine '
        'if this is an older receipt.';
  }

  double? get _litresValue => Money.parse(_litres.text);

  String? get _litresError {
    if (_litres.text.trim().isEmpty) return 'How many litres went in.';
    final v = _litresValue;
    if (v == null ||
        v < FuelEntryFormScreen.minLitres ||
        v > FuelEntryFormScreen.maxLitres) {
      return 'Between ${FuelEntryFormScreen.minLitres} and '
          '${FuelEntryFormScreen.maxLitres.toStringAsFixed(0)} litres.';
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
    if (v == null || v < 0 || v > Money.max) return 'An amount, like 62.40.';
    return null;
  }

  bool get _valid =>
      _odometerError == null && _litresError == null && _costError == null;

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
    final km = _odometerKm!;
    final notes = _notes.text.trim();
    try {
      final e = _e;
      if (e == null) {
        await services.addFuel(
          vehicleId: widget.vehicle.id,
          date: _date,
          odometerKm: km,
          litres: _litresValue!,
          cost: _costValue,
          currencyCode: _currency,
          partFill: _partFill,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await services.updateFuel(
          e.copyWith(
            date: _date,
            odometerKm: km,
            litres: _litresValue!,
            cost: Value(_costValue),
            partFill: _partFill,
            notes: Value(notes.isEmpty ? null : notes),
          ),
        );
      }
      final current = _vehicleNow();
      if (current?.odometerKm == null || km > current!.odometerKm!) {
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
    await widget.garage.services!.deleteFuel(_e!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Backlit(
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        final editing = _e != null;
        const number = TextInputType.numberWithOptions(decimal: true);
        return Scaffold(
          backgroundColor: t.surfaceDeep,
          appBar: AdaptiveTopBar(
            title: editing ? 'Edit fill-up' : 'Add a fill-up',
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
              LabelledDateField(
                label: 'Date',
                date: _date,
                format: formatDay,
                onPick: _pickDate,
              ),
              LabelledField(
                label: 'Odometer (${widget.unit.label})',
                // The car's reading now, as the reminder form gives it —
                // an example number here read as one the app believed.
                hint: switch (_vehicleNow()?.odometerKm) {
                  null => 'The reading on the dash',
                  final km => 'Now ${Distance.display(km, widget.unit)}',
                },
                controller: _odometer,
                keyboard: number,
                autofocus: !editing,
                error: _submitted ? _odometerError : null,
                caution: _odometerCaution,
                onChanged: (_) => setState(() {}),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Litres',
                      hint: '42.5',
                      controller: _litres,
                      keyboard: number,
                      error: _submitted ? _litresError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Space.x12),
                  Expanded(
                    child: LabelledField(
                      label: 'Cost ($_currency)',
                      hint: 'Optional',
                      controller: _cost,
                      keyboard: number,
                      error: _submitted ? _costError : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              Semantics(
                toggled: _partFill,
                label: 'Not filled to the top',
                onTap: () => setState(() => _partFill = !_partFill),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.x16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Not filled to the top',
                                style: TorqueType.body.copyWith(
                                  color: t.inkPrimary,
                                ),
                              ),
                              Text(
                                'Its litres are counted into the next full '
                                'tank; it gets no figure of its own.',
                                style: TorqueType.meta.copyWith(
                                  color: t.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdaptiveSwitch(
                          value: _partFill,
                          onChanged: (v) => setState(() => _partFill = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              LabelledField(
                label: 'Notes',
                hint: 'Optional — the station, the grade',
                controller: _notes,
                maxLines: null,
                capitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.x8),
              PrimaryButton(
                label: editing ? 'Save' : 'Add fill-up',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              if (editing) ...[
                const SizedBox(height: Space.x16),
                DestructiveButton(
                  label: 'Delete this fill-up',
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
