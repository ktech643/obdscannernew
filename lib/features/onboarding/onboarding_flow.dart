import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show Checkbox, Icons, InputDecoration, TextField, TextInputAction, TextInputType, Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/platform/platform_info.dart';
import '../../data/db/app_database.dart' show VehicleRow;
import '../../data/repositories/vehicle_repository.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../garage/distance.dart';
import '../garage/vehicle_form_screen.dart' show VehicleFormScreen;

/// SPEC §5.1 — first-run onboarding on the Part B design system.
///
/// Four frames: what this does, the adapter explainer, add your car, and
/// the non-skippable safety acknowledgement. The flow writes the
/// `onboardingComplete` flag only after the safety checkbox is checked.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Backlit(
    child: SafeArea(
      bottom: false,
      child: _pageFor(context),
    ),
  );

  Widget _pageFor(BuildContext context) {
    final step = context.watch<OnboardingProvider>().step;
    return switch (step) {
      0 => _A1WhatThisDoes(key: const ValueKey('a1')),
      1 => _A2Adapter(key: const ValueKey('a2')),
      2 => _A3AddYourCar(key: const ValueKey('a3')),
      _ => _A4Safety(onDone: onDone, key: const ValueKey('a4')),
    };
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, this.skippable = true});
  final int step;
  final bool skippable;

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x24),
      child: Row(
        children: [
          Text(
            '$step OF ${o.totalSteps}',
            style: TorqueType.meta.copyWith(color: t.inkSecondary),
          ),
          const Spacer(),
          if (skippable)
            GhostButton(
              label: 'Skip',
              onPressed: () {
                AdaptiveHaptics.light();
                o.skip();
              },
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.count});
  final int active;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            width: i == active ? 18 : 6,
            height: 3,
            decoration: BoxDecoration(
              color: i == active ? t.tellAmber : t.surfacePanel,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          if (i < count - 1) const SizedBox(width: Space.x4),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- A1
class _A1WhatThisDoes extends StatelessWidget {
  const _A1WhatThisDoes({super.key});

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    return _Page(
      step: 1,
      children: [ // ignore: sort_child_properties_last
        const _SchematicChain(),
        const SizedBox(height: Space.x32),
        Text(
          "Read your car's error codes and watch live engine data.",
          style: TorqueType.titleLg.copyWith(
            color: context.tokens.inkPrimary,
          ),
        ),
        const SizedBox(height: Space.x12),
        Text(
          'Torque plugs into the diagnostic port every car built since 1996 '
          'already has, and translates what the engine computer is saying into '
          'plain English.',
          style: TorqueType.body.copyWith(color: context.tokens.inkSecondary),
        ),
        const SizedBox(height: Space.x24),
        const _Dots(active: 0, count: 4),
      ],
      footer: PrimaryButton(
        label: 'Next',
        onPressed: () {
          AdaptiveHaptics.light();
          o.next();
        },
      ),
    );
  }
}

class _SchematicChain extends StatelessWidget {
  const _SchematicChain();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        const Expanded(child: _SchematicCell(label: 'Phone', icon: Icons.smartphone)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x8),
          child: SizedBox(
            width: 26,
            height: 1,
            child: CustomPaint(painter: _DashedPainter(color: t.inkTertiary)),
          ),
        ),
        const Expanded(child: _SchematicCell(label: 'Adapter', icon: Icons.bluetooth)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x8),
          child: SizedBox(
            width: 26,
            height: 1,
            child: CustomPaint(painter: _DashedPainter(color: t.inkTertiary)),
          ),
        ),
        const Expanded(child: _SchematicCell(label: 'Your car', icon: Icons.directions_car)),
      ],
    );
  }
}

class _SchematicCell extends StatelessWidget {
  const _SchematicCell({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RaisedSurface(
      padding: const EdgeInsets.symmetric(vertical: Space.x16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: t.tellAmber),
          const SizedBox(height: Space.x12),
          Text(
            label.toUpperCase(),
            style: TorqueType.gaugeLabel.copyWith(color: t.inkSecondary),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}

// ---------------------------------------------------------------- A2
class _A2Adapter extends StatelessWidget {
  const _A2Adapter({super.key});

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    final platform = PlatformInfo.current;
    final android = platform.isAndroid;
    return _Page(
      step: 2,
      children: [ // ignore: sort_child_properties_last
        Text(
          'You need an adapter',
          style: TorqueType.titleLg.copyWith(color: context.tokens.inkPrimary),
        ),
        const SizedBox(height: Space.x12),
        Text(
          android
              ? 'Torque talks to your car through an OBD2 adapter that plugs in '
                'under the dash. Almost any ELM327 adapter works — Bluetooth, '
                'Bluetooth LE, or Wi-Fi.'
              : 'Torque talks to your car through an OBD2 adapter that plugs in '
                'under the dash. On iPhone it must be a Bluetooth LE or Wi-Fi '
                'adapter.',
          style: TorqueType.body.copyWith(color: context.tokens.inkSecondary),
        ),
        const SizedBox(height: Space.x24),
        if (android)
          const _CompareCell(
            verdict: 'Works',
            items: ['Bluetooth', 'Bluetooth LE', 'Wi-Fi'],
            tone: Tell.green,
          )
        else
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CompareCell(
                    verdict: 'Works',
                    items: ['Bluetooth LE', 'Wi-Fi'],
                    tone: Tell.green,
                  ),
                ),
                SizedBox(width: Space.x12),
                Expanded(
                  child: _CompareCell(
                    verdict: "Can't work",
                    items: ['Bluetooth Classic'],
                    footnote: 'the cheap Android kind',
                    tone: Tell.red,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.x16),
        if (!android) const _NoteBlock(
          'Pairing an adapter in iPhone Settings does not make it work with '
          'apps. Apple gives no app access to Classic Bluetooth — that is a '
          'platform rule, not a Torque limitation.',
        ),
        if (!android) const SizedBox(height: Space.x16),
        Text(
          'Where the port is',
          style: TorqueType.titleMd.copyWith(color: context.tokens.inkPrimary),
        ),
        const SizedBox(height: Space.x8),
        const _PortDiagram(),
        const SizedBox(height: Space.x8),
        Text(
          "Driver's side, under the dash, within 60 cm of the steering wheel. "
          '16 pins, trapezoid.',
          style: TorqueType.body.copyWith(color: context.tokens.inkSecondary),
        ),
        const SizedBox(height: Space.x16),
        const _Dots(active: 1, count: 4),
      ],
      footer: Column(
        children: [
          PrimaryButton(
            label: 'I have one',
            onPressed: () {
              AdaptiveHaptics.light();
              o.next();
            },
          ),
          const SizedBox(height: Space.x8),
          GhostButton(
            label: 'Help me pick one',
            onPressed: () => _notImplemented(context),
          ),
        ],
      ),
    );
  }
}

class _CompareCell extends StatelessWidget {
  const _CompareCell({
    required this.verdict,
    required this.items,
    required this.tone,
    this.footnote,
  });

  final String verdict;
  final List<String> items;
  final Tell tone;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pass = tone == Tell.green;
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                pass ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: t.tell(tone),
              ),
              const SizedBox(width: Space.x8),
              Expanded(
                child: Text(
                  verdict,
                  style: TorqueType.body.copyWith(
                    color: t.tell(tone),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x12),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: Text(
                i,
                style: TorqueType.body.copyWith(color: t.inkPrimary),
              ),
            ),
          if (footnote != null) ...[
            const SizedBox(height: Space.x4),
            Text(
              footnote!,
              style: TorqueType.meta.copyWith(color: t.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PortDiagram extends StatelessWidget {
  const _PortDiagram();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 104,
    child: RaisedSurface(
      child: CustomPaint(
        painter: _PortPainter(color: context.tokens.tellAmber),
        size: Size.infinite,
      ),
    ),
  );
}

class _PortPainter extends CustomPainter {
  const _PortPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const w = 168.0, h = 52.0;
    final l = (size.width - w) / 2, t = (size.height - h) / 2;
    final path = Path()
      ..moveTo(l, t)
      ..lineTo(l + w, t)
      ..lineTo(l + w - 14, t + h)
      ..lineTo(l + 14, t + h)
      ..close();
    canvas.drawPath(path, stroke);

    final pin = Paint()..color = color.withValues(alpha: 0.55);
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 8; i++) {
        const inset = 20.0;
        final y = t + 16 + row * 20;
        final x = l + inset + i * ((w - inset * 2) / 7);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 4, height: 7),
          pin,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PortPainter old) => old.color != color;
}

// ---------------------------------------------------------------- A3
class _A3AddYourCar extends StatefulWidget {
  const _A3AddYourCar({super.key});

  @override
  State<_A3AddYourCar> createState() => _A3AddYourCarState();
}

class _A3AddYourCarState extends State<_A3AddYourCar> {
  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _odometer = TextEditingController();
  /// Seeded from Settings, not hard-coded: a user who chose miles on an
  /// earlier pass and relaunched before agreeing to the safety step must
  /// not land on a form that shows their kilometres under "km" and then
  /// writes km back over their preference.
  late DistanceUnit _unit;

  /// What the odometer field showed after prefill, or after a unit
  /// toggle re-rendered it. A field the user never edited is not a new
  /// reading: saving it must not round the stored figure or move its
  /// "last read" date to now.
  String? _odometerShown;

  /// The car already in the garage, when there is one: a relaunch before
  /// the safety step was agreed lands here again. The form shows it and
  /// saves over it. An earlier version created a fresh vehicle on every
  /// pass — a second car past the §7.2 one-vehicle limit, with no paywall,
  /// and not the primary.
  VehicleRow? _existing;

  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _unit = context.read<SettingsProvider>().distance;
    unawaited(_prefill());
  }

  /// Fills only the fields still empty: the query resolves after the
  /// first frame, and anything the user has typed by then is theirs.
  Future<void> _prefill() async {
    final existing = await context.read<VehicleRepository>().primary();
    if (!mounted || existing == null) return;
    setState(() {
      _existing = existing;
      if (_nickname.text.isEmpty) _nickname.text = existing.nickname;
      if (_make.text.isEmpty) _make.text = existing.make;
      if (_model.text.isEmpty) _model.text = existing.model;
      if (_year.text.isEmpty) _year.text = existing.year?.toString() ?? '';
      if (_odometer.text.isEmpty && existing.odometerKm != null) {
        _odometer.text = Distance.display(existing.odometerKm!, _unit);
        _odometerShown = _odometer.text;
      }
    });
  }

  /// A unit toggle converts the figure in the field; it never relabels
  /// it. 160,934 under km is 100,000 under mi, not 160,934 mi.
  void _setUnit(DistanceUnit next) {
    if (next == _unit) return;
    final v = Distance.parse(_odometer.text.trim());
    // Untouched before the toggle means untouched after it. A field the
    // user had edited stays edited: an earlier version re-marked every
    // converted figure as the prefill, so an edit followed by a toggle
    // was taken for "not changed" and never saved.
    final untouched =
        _odometerShown != null && _odometer.text.trim() == _odometerShown;
    setState(() {
      if (v != null) {
        _odometer.text = Distance.display(Distance.toKm(v, _unit), next);
        if (untouched) _odometerShown = _odometer.text;
      }
      _unit = next;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _odometer.dispose();
    super.dispose();
  }

  // The same limits as the Garage's own form (§9.8): the row this screen
  // writes is the row that form edits later.

  bool get _anythingButName =>
      [_make, _model, _year, _odometer].any((c) => c.text.trim().isNotEmpty);

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.length > VehicleFormScreen.nameMax) {
      return 'Keep it under ${VehicleFormScreen.nameMax} characters.';
    }
    if (n.isEmpty && _anythingButName) {
      return "Give the car a name, or choose \"I'll do this later\".";
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

  /// Kilometres for the row. [Distance.parse] reads `142,380`, `142 380`
  /// and the comma-decimal `142380,5`; an earlier version stripped every
  /// comma, so that last one saved as 1,423,805.
  double? get _odometerKm {
    final raw = _odometer.text.trim();
    if (raw.isEmpty) return null;
    final v = Distance.parse(raw);
    return v == null ? null : Distance.toKm(v, _unit);
  }

  String? get _odometerError {
    if (_odometer.text.trim().isEmpty) return null;
    final km = _odometerKm;
    if (km == null || km < 0 || km > VehicleFormScreen.odometerMaxKm) {
      return 'A reading between 0 and '
          '${Distance.display(VehicleFormScreen.odometerMaxKm, _unit)} '
          '${_unit.label}.';
    }
    return null;
  }

  bool get _valid =>
      _nicknameError == null && _yearError == null && _odometerError == null;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_valid) return;
    final vehicles = context.read<VehicleRepository>();
    final onboarding = context.read<OnboardingProvider>();
    final settings = context.read<SettingsProvider>();
    final nickname = _nickname.text.trim();
    setState(() => _saving = true);
    try {
      settings.setDistance(_unit);
      if (nickname.isNotEmpty) {
        final km = _odometerKm;
        final year = int.tryParse(_year.text.trim());
        final existing = _existing ?? await vehicles.primary();
        if (existing == null) {
          await vehicles.create(
            nickname: nickname,
            fuel: VehicleFuel.petrol,
            make: _make.text.trim(),
            model: _model.text.trim(),
            year: year,
            odometerKm: km,
          );
        } else {
          // Only an edited reading is a new reading (the Garage form's
          // rule): an untouched prefilled figure keeps its exact value
          // and its real date.
          final odometerEdited =
              km != null && _odometer.text.trim() != _odometerShown;
          await vehicles.updateDetails(
            existing.id,
            nickname: Value(nickname),
            make: Value(_make.text.trim()),
            model: Value(_model.text.trim()),
            year: Value(year),
            odometerKm: odometerEdited ? Value(km) : const Value.absent(),
            odometerUpdatedAt: odometerEdited
                ? Value(DateTime.now())
                : const Value.absent(),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    AdaptiveHaptics.light();
    onboarding.next();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    final settings = context.read<SettingsProvider>();
    return _Page(
      step: 3,
      children: [ // ignore: sort_child_properties_last
        Text(
          'Add your car',
          style: TorqueType.titleLg.copyWith(color: context.tokens.inkPrimary),
        ),
        const SizedBox(height: Space.x12),
        Text(
          'All optional, all editable later. The Garage works with no adapter '
          'plugged in at all.',
          style: TorqueType.body.copyWith(color: context.tokens.inkSecondary),
        ),
        const SizedBox(height: Space.x24),
        _Field(
          label: 'Nickname',
          hint: 'The Golf',
          controller: _nickname,
          maxLength: VehicleFormScreen.nameMax,
          error: _submitted ? _nicknameError : null,
        ),
        const SizedBox(height: Space.x16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(label: 'Make', hint: 'Volkswagen', controller: _make),
            ),
            const SizedBox(width: Space.x12),
            SizedBox(
              width: 96,
              child: _Field(
                label: 'Year',
                hint: '2014',
                controller: _year,
                keyboardType: TextInputType.number,
                error: _submitted ? _yearError : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.x16),
        _Field(label: 'Model', hint: 'Golf GTD', controller: _model),
        const SizedBox(height: Space.x16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                label: 'Odometer',
                hint: '142,380',
                controller: _odometer,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                error: _submitted ? _odometerError : null,
              ),
            ),
            const SizedBox(width: Space.x12),
            Padding(
              // Level with the field, under its label.
              padding: const EdgeInsets.only(top: 22),
              child: _Segmented(
                options: const ['km', 'mi'],
                selected: _unit.index,
                onSelect: (i) {
                  HapticFeedback.selectionClick();
                  _setUnit(DistanceUnit.values[i]);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.x16),
        Text(
          "We'll read the VIN off the car once you connect and fill in what we "
          'can. Nothing is sent anywhere — the decode happens on this phone.',
          style: TorqueType.meta.copyWith(color: context.tokens.inkSecondary),
        ),
        const SizedBox(height: Space.x16),
        const _Dots(active: 2, count: 4),
      ],
      footer: Column(
        children: [
          PrimaryButton(
            label: 'Save and continue',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: Space.x8),
          GhostButton(
            label: "I'll do this later",
            onPressed: _saving
                ? null
                : () {
                    AdaptiveHaptics.light();
                    // Persist the unit choice even if they skip the form.
                    settings.setDistance(_unit);
                    o.next();
                  },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.maxLength,
    this.error,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final int? maxLength;

  /// Shown under the field, in the fault colour, once the user has tried
  /// to save. The Garage's form shows its errors the same way.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TorqueType.gaugeLabel.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: Space.x8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLength: maxLength,
          style: TorqueType.body.copyWith(color: t.inkPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TorqueType.body.copyWith(color: t.inkTertiary),
            counterText: '',
          ).applyDefaults(Theme.of(context).inputDecorationTheme),
        ),
        if (error != null) ...[
          const SizedBox(height: Space.x4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Tell.red.glyph, size: 14, color: t.tell(Tell.red)),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Text(
                  error!,
                  style: TorqueType.meta.copyWith(color: t.tell(Tell.red)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: Space.x16),
              decoration: BoxDecoration(
                color: i == selected ? t.surfacePanel : null,
                border: Border.all(
                  color: i == selected ? t.hairline : t.surfacePanel,
                ),
                borderRadius: BorderRadius.horizontal(
                  left: i == 0 ? const Radius.circular(Radii.input) : Radius.zero,
                  right: i == options.length - 1 ? const Radius.circular(Radii.input) : Radius.zero,
                ),
              ),
              child: Center(
                child: Text(
                  options[i],
                  style: TorqueType.body.copyWith(
                    color: i == selected ? t.inkPrimary : t.inkTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- A4
class _A4Safety extends StatelessWidget {
  const _A4Safety({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OnboardingProvider>();
    final t = context.tokens;
    return _Page(
      step: 4,
      skippable: false,
      children: [ // ignore: sort_child_properties_last
        Text(
          'Before you start',
          style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
        ),
        const SizedBox(height: Space.x16),
        _NoteBlock(
          'Have a passenger read the data, or park first. Torque disables gauge '
          'editing above 5 km/h and will not clear codes unless the car is '
          'stationary.',
          tone: Tell.amber,
          title: "Don't use this app while driving.",
        ),
        const SizedBox(height: Space.x24),
        const _NumberedFact(
          1,
          'Reading data is passive. Torque never writes to your engine computer '
          '— the one exception is clearing codes, which you trigger yourself.',
        ),
        const _NumberedFact(
          2,
          'A code points to a symptom, not always the cause. This app is not a '
          "substitute for a mechanic's diagnosis.",
        ),
        const _NumberedFact(
          3,
          'Unplug your adapter when the car is parked for more than a few days '
          '— some draw power constantly.',
        ),
        const SizedBox(height: Space.x4),
        const _NoteBlock(
          'Next, your phone will ask for Bluetooth. Torque uses it only to '
          'reach '
          'your adapter — there is no other use and no location access.',
        ),
        const SizedBox(height: Space.x16),
        // The action sits on the Semantics node itself: a GestureDetector
        // under ExcludeSemantics is invisible to TalkBack and VoiceOver, so
        // an earlier version's checkbox could be read but never ticked.
        Semantics(
          checked: o.safetyAcknowledged,
          label: "I understand and I won't use this while driving",
          onTap: () => o.setSafetyAcknowledged(!o.safetyAcknowledged),
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => o.setSafetyAcknowledged(!o.safetyAcknowledged),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: o.safetyAcknowledged,
                    onChanged: (v) => o.setSafetyAcknowledged(v ?? false),
                    activeColor: t.tellAmber,
                    checkColor: t.surfaceDeep,
                    materialTapTargetSize: null,
                  ),
                  const SizedBox(width: Space.x8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.x8),
                      child: Text(
                        "I understand and I won't use this while driving",
                        style: TorqueType.body.copyWith(color: t.inkPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.x12),
        const _Dots(active: 3, count: 4),
      ],
      footer: PrimaryButton(
        label: 'Agree and continue',
        onPressed:
            o.safetyAcknowledged
                ? () {
                  AdaptiveHaptics.light();
                  o.finish();
                  onDone();
                }
                : null,
      ),
    );
  }
}

class _NumberedFact extends StatelessWidget {
  const _NumberedFact(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: t.surfacePanel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TorqueType.label.copyWith(color: t.inkPrimary),
              ),
            ),
          ),
          const SizedBox(width: Space.x12),
          Expanded(
            child: Text(
              text,
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock(
    this.text, {
    this.tone = Tell.none,
    this.title,
  });

  final String text;
  final Tell tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone == Tell.none ? t.inkSecondary : t.tell(tone);
    return RaisedSurface(
      color: tone == Tell.none ? t.surfacePanel : t.surfaceRaised,
      padding: const EdgeInsets.all(Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(
                  tone == Tell.none ? Icons.info_outline : tone.glyph,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: Space.x8),
                Expanded(
                  child: Text(
                    title!,
                    style: TorqueType.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x8),
          ],
          Text(
            text,
            style: TorqueType.body.copyWith(color: t.inkSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- page shell
class _Page extends StatelessWidget {
  const _Page({
    required this.step,
    required this.footer,
    required this.children,
    this.skippable = true,
  });

  final int step;
  final List<Widget> children;
  final Widget footer;
  final bool skippable;

  /// Onboarding has no Scaffold, so nothing resizes for the keyboard: the
  /// page pads itself by the keyboard's height, which lifts the footer
  /// above it and lets the scroll view bring a focused field into view.
  /// A tap anywhere outside a field dismisses the keyboard — the iOS
  /// number pad has no Done key, so this is the only way off it.
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: Padding(
    padding: EdgeInsets.fromLTRB(
      Space.gutter,
      Space.x16,
      Space.gutter,
      MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Progress(step: step, skippable: skippable),
        Expanded(
          child: SingleChildScrollView(
            physics: adaptiveScrollPhysics(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: Space.x16,
            bottom: Space.x24,
          ),
          child: footer,
        ),
      ],
    ),
    ),
  );
}

void _notImplemented(BuildContext context) => showAdaptiveAlert(
  context,
  title: 'Coming soon',
  message:
      'The bundled adapter compatibility list is the next piece. For now, any '
      'Bluetooth LE or Wi-Fi ELM327 adapter works on iPhone; Android also '
      'supports Bluetooth Classic.',
  actions: [
    AdaptiveAlertAction(
      label: 'OK',
      onPressed: () {},
      isDefault: true,
    ),
  ],
);
