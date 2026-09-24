import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart'
    show Icons, InputDecoration, Scaffold, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/db/app_database.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../../protocol/vin_reader.dart';
import 'distance.dart';
import 'garage_controller.dart';

/// Add or edit a vehicle. SPEC §5.5, with §9.6 for the VIN and §9.8 for
/// everything typed.
///
/// Pushed, so it carries its own ground ([Backlit]). Pops with the saved
/// row, or null.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({
    super.key,
    required this.controller,
    this.existing,
    this.prefillVin,
    this.unit = DistanceUnit.km,
  });

  final GarageController controller;

  /// Edit mode when set.
  final VehicleRow? existing;

  /// A VIN the car just reported, offered into the field for a new
  /// vehicle so the user does not retype 17 characters.
  final String? prefillVin;
  final DistanceUnit unit;

  /// §9.8: a name never exceeds 40 characters — it ends up in file names.
  static const nameMax = 40;

  /// §9.8: odometer validated 0–2,000,000 km.
  static const odometerMaxKm = 2000000.0;

  static const yearMin = 1980;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  late final _nickname = TextEditingController(
    text: widget.existing?.nickname ?? '',
  );
  late final _make = TextEditingController(text: widget.existing?.make ?? '');
  late final _model = TextEditingController(text: widget.existing?.model ?? '');
  late final _trim = TextEditingController(text: widget.existing?.trim ?? '');
  late final _year = TextEditingController(
    text: widget.existing?.year?.toString() ?? '',
  );
  late final _odometer = TextEditingController(
    text: widget.existing?.odometerKm == null
        ? ''
        : Distance.display(widget.existing!.odometerKm!, widget.unit),
  );
  late final _plate = TextEditingController(text: widget.existing?.plate ?? '');
  late final _vin = TextEditingController(
    text: widget.existing?.vin ?? widget.prefillVin ?? '',
  );
  late VehicleFuel _fuel = widget.existing?.fuelType ?? VehicleFuel.petrol;

  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [
      _nickname,
      _make,
      _model,
      _trim,
      _year,
      _odometer,
      _plate,
      _vin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ validation

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.isEmpty) return 'Give the car a name.';
    if (n.length > VehicleFormScreen.nameMax) {
      return 'Keep it under ${VehicleFormScreen.nameMax} characters.';
    }
    return null;
  }

  String? get _yearError {
    final raw = _year.text.trim();
    if (raw.isEmpty) return null;
    final y = int.tryParse(raw);
    final max = DateTime.now().year + 1;
    if (y == null || y < VehicleFormScreen.yearMin || y > max) {
      return 'A year between ${VehicleFormScreen.yearMin} and $max.';
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
    final raw = _odometer.text.trim();
    if (raw.isEmpty) return null;
    final km = _odometerKm;
    if (km == null || km < 0 || km > VehicleFormScreen.odometerMaxKm) {
      return 'A reading between 0 and '
          '${Distance.display(VehicleFormScreen.odometerMaxKm, widget.unit)} '
          '${widget.unit.label}.';
    }
    return null;
  }

  /// §9.6 / §9.8 for a typed VIN. Three outcomes: empty is fine, a
  /// well-formed VIN is fine (flagged if its check digit fails), and
  /// anything else is refused with the reason.
  VinResult? get _vinResult => GarageController.judgeTypedVin(_vin.text);

  String? get _vinError {
    final raw = _vin.text.trim();
    if (raw.isEmpty) return null;
    if (_vinResult != null) return null;
    final upper = raw.toUpperCase();
    if (upper.length != 17) return 'A VIN is exactly 17 characters.';
    if (RegExp('[IOQ]').hasMatch(upper)) {
      return 'A VIN never contains I, O or Q — check for 1 and 0.';
    }
    return 'Only letters and digits.';
  }

  /// Not an error — §9.8 says warn, then allow.
  String? get _vinCaution {
    final r = _vinResult;
    if (r == null) return null;
    if (!r.checkDigitValid) {
      return 'The check digit does not match. It will be saved, but not '
          'used to identify the car or decode its make and year.';
    }
    final dup = widget.controller.all.any(
      (v) => v.vin == r.vin && v.id != widget.existing?.id,
    );
    if (dup) return 'Another vehicle in the garage has this VIN.';
    return null;
  }

  bool get _valid =>
      _nicknameError == null &&
      _yearError == null &&
      _odometerError == null &&
      _vinError == null;

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_valid || _saving) return;
    setState(() => _saving = true);

    final vinResult = _vinResult;
    final c = widget.controller;
    final existing = widget.existing;
    try {
      final VehicleRow saved;
      if (existing == null) {
        saved = await c.add(
          nickname: _nickname.text.trim(),
          fuel: _fuel,
          vin: vinResult?.vin,
          vinUnverified: vinResult != null && !vinResult.checkDigitValid,
          make: _make.text.trim(),
          model: _model.text.trim(),
          trim: _trim.text.trim(),
          year: int.tryParse(_year.text.trim()),
          odometerKm: _odometerKm,
          plate: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
        );
      } else {
        final km = _odometerKm;
        final odometerChanged = km != existing.odometerKm;
        // Only the fields on this form, never the row as it was when the
        // form opened: `isPrimary` can change behind an open form (the
        // §9.6 prompt switching cars), and writing the stale copy back
        // left the garage with two primaries or none.
        await c.vehicles.updateDetails(
          existing.id,
          nickname: Value(_nickname.text.trim()),
          fuelType: Value(_fuel),
          vin: Value(vinResult?.vin),
          vinUnverified: Value(vinResult != null && !vinResult.checkDigitValid),
          make: Value(_make.text.trim()),
          model: Value(_model.text.trim()),
          trim: Value(_trim.text.trim()),
          year: Value(int.tryParse(_year.text.trim())),
          // Only a *changed* reading is a new reading; re-saving the form
          // must not make an old odometer look freshly read.
          odometerKm: odometerChanged ? Value(km) : const Value.absent(),
          odometerUpdatedAt: odometerChanged
              ? Value(km == null ? null : DateTime.now().toUtc())
              : const Value.absent(),
          plate: Value(_plate.text.trim().isEmpty ? null : _plate.text.trim()),
        );
        saved = (await c.vehicles.byId(existing.id)) ?? existing;
      }
      if (mounted) Navigator.of(context).pop(saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Backlit(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final t = context.tokens;
    final editing = widget.existing != null;
    return Scaffold(
      backgroundColor: t.surfaceDeep,
      appBar: AdaptiveTopBar(title: editing ? 'Edit vehicle' : 'Add a vehicle'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x16,
          Space.gutter,
          Space.x48,
        ),
        children: [
          _Field(
            label: 'Name',
            hint: 'The Golf',
            controller: _nickname,
            error: _submitted ? _nicknameError : null,
            maxLength: VehicleFormScreen.nameMax,
            onChanged: (_) => setState(() {}),
            autofocus: !editing,
          ),
          _FuelPicker(
            value: _fuel,
            onChanged: (f) => setState(() => _fuel = f),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  label: 'Make',
                  hint: 'Volkswagen',
                  controller: _make,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.x12),
              Expanded(
                child: _Field(
                  label: 'Model',
                  hint: 'Golf',
                  controller: _model,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  label: 'Trim',
                  hint: 'GTD',
                  controller: _trim,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.x12),
              Expanded(
                child: _Field(
                  label: 'Year',
                  hint: '2014',
                  controller: _year,
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  error: _submitted ? _yearError : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          _Field(
            label: 'Odometer (${widget.unit.label})',
            hint: '142380',
            controller: _odometer,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            error: _submitted ? _odometerError : null,
            onChanged: (_) => setState(() {}),
          ),
          _Field(
            label: 'Plate',
            hint: 'Optional',
            controller: _plate,
            capitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          _Field(
            label: 'VIN',
            hint: '17 characters — or leave it for the car to report',
            controller: _vin,
            capitalization: TextCapitalization.characters,
            maxLength: 17,
            error: _vinError,
            caution: _vinCaution,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.x24),
          PrimaryButton(
            label: editing ? 'Save' : 'Add vehicle',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// A labelled input on the Part B panel surface, with its error or caution
/// as a word and a glyph under it — never a red border alone (hard rule 11).
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.caution,
    this.keyboard,
    this.formatters,
    this.maxLength,
    this.capitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? error;
  final String? caution;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final TextCapitalization capitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final note = error ?? caution;
    final tone = error != null ? Tell.red : Tell.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TorqueType.label.copyWith(color: t.inkSecondary)),
          const SizedBox(height: Space.x4),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            inputFormatters: formatters,
            maxLength: maxLength,
            textCapitalization: capitalization,
            autofocus: autofocus,
            onChanged: onChanged,
            style: TorqueType.body.copyWith(color: t.inkPrimary),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.x12,
                vertical: Space.x12,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: Space.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tone.glyph, size: 14, color: t.tell(tone)),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Text(
                    note,
                    style: TorqueType.meta.copyWith(color: t.tell(tone)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FuelPicker extends StatelessWidget {
  const _FuelPicker({required this.value, required this.onChanged});
  final VehicleFuel value;
  final ValueChanged<VehicleFuel> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fuel', style: TorqueType.label.copyWith(color: t.inkSecondary)),
          const SizedBox(height: Space.x8),
          Wrap(
            spacing: Space.x8,
            runSpacing: Space.x8,
            children: [
              for (final f in VehicleFuel.values)
                Semantics(
                  button: true,
                  selected: f == value,
                  label: f.label,
                  onTap: () => onChanged(f),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => onChanged(f),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: Targets.min,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: f == value ? t.inkPrimary : t.surfacePanel,
                            borderRadius: BorderRadius.circular(Radii.button),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x16,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (f == value) ...[
                                    Icon(
                                      Icons.check,
                                      size: 16,
                                      color: t.surfaceDeep,
                                    ),
                                    const SizedBox(width: Space.x4),
                                  ],
                                  Text(
                                    f.label,
                                    style: TorqueType.label.copyWith(
                                      color: f == value
                                          ? t.surfaceDeep
                                          : t.inkPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

extension VehicleFuelLabel on VehicleFuel {
  String get label => switch (this) {
    VehicleFuel.petrol => 'Petrol',
    VehicleFuel.diesel => 'Diesel',
    VehicleFuel.hybrid => 'Hybrid',
    VehicleFuel.electric => 'Electric',
  };
}
