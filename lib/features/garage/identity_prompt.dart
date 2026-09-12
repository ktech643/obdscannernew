import 'package:flutter/widgets.dart';

import '../../data/db/app_database.dart';
import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../../session/obd_session.dart';
import 'garage_controller.dart';
import 'vehicle_form_screen.dart';
import 'vehicle_identity.dart';

/// SPEC §9.6 — "two vehicles, one adapter: compare VIN on connect, prompt
/// on mismatch before recording."
///
/// Sits above the tab stack and watches the garage. The moment a connect
/// leaves a verdict the user has to answer, this puts the question up as a
/// sheet that cannot be swiped away: until it is answered nothing is
/// recorded under any vehicle, so there is no safe default to fall back
/// to — only the two choices on the sheet.
class IdentityPromptHost extends StatefulWidget {
  const IdentityPromptHost({
    super.key,
    required this.garage,
    required this.session,
    required this.child,
    this.unit = DistanceUnit.km,
    this.isPro = false,
  });

  final GarageController garage;
  final ObdSession session;
  final Widget child;
  final DistanceUnit unit;

  /// §7.2: one vehicle free. The sheet's "add it as a new vehicle" is
  /// the same door as the garage's, and has the same lock on it.
  final bool isPro;

  @override
  State<IdentityPromptHost> createState() => _IdentityPromptHostState();
}

class _IdentityPromptHostState extends State<IdentityPromptHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.garage.addListener(_maybeShow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void didUpdateWidget(IdentityPromptHost old) {
    super.didUpdateWidget(old);
    if (old.garage != widget.garage) {
      old.garage.removeListener(_maybeShow);
      widget.garage.addListener(_maybeShow);
    }
  }

  @override
  void dispose() {
    widget.garage.removeListener(_maybeShow);
    super.dispose();
  }

  Future<void> _maybeShow() async {
    final verdict = widget.garage.pendingIdentity;
    if (verdict == null || _showing || !mounted) return;
    _showing = true;
    try {
      final answer = await showAdaptiveSheet<IdentityAnswer>(
        context,
        dismissible: false,
        builder: (_) => IdentitySheet(
          verdict: verdict,
          garage: widget.garage,
          session: widget.session,
          isPro: widget.isPro,
        ),
      );
      // "Add it as a new vehicle" is answered by the form, not the sheet —
      // and while the form is up this host must stay quiet, or the
      // question comes straight back up on top of it. That is why the
      // form is pushed from here, inside the same guard.
      if (answer == IdentityAnswer.addVehicle && mounted) {
        final saved = await Navigator.of(context).push<VehicleRow>(
          PageRouteBuilder<VehicleRow>(
            pageBuilder: (_, _, _) => VehicleFormScreen(
              controller: widget.garage,
              prefillVin: verdict.vin,
              unit: widget.unit,
            ),
          ),
        );
        if (saved != null) {
          await widget.garage.answerIdentity(saved.id, session: widget.session);
        }
      }
    } finally {
      _showing = false;
    }
    // A cancelled form leaves the question open. Ask again.
    if (mounted && widget.garage.pendingIdentity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// How the sheet was closed.
enum IdentityAnswer {
  /// The garage was told which vehicle this is (or to keep the primary).
  answered,

  /// The user wants a new vehicle for this VIN; the host opens the form.
  addVehicle,
}

/// The question, with the two honest answers for each kind of verdict.
///
/// The VIN on screen is masked — it identifies the car and, through it,
/// the owner — but the *decision* is stated in full: which vehicle the
/// records go under from here on.
class IdentitySheet extends StatelessWidget {
  const IdentitySheet({
    super.key,
    required this.verdict,
    required this.garage,
    required this.session,
    this.isPro = false,
  });

  final IdentityVerdict verdict;
  final GarageController garage;
  final ObdSession session;
  final bool isPro;

  /// §5.5's copy for the gate, word for word with the garage's alert.
  static const proNote = 'Adding a second vehicle is part of Pro.';

  Future<void> _answer(BuildContext context, String? vehicleId) async {
    Navigator.of(context).pop(IdentityAnswer.answered);
    await garage.answerIdentity(vehicleId, session: session);
  }

  void _addVehicle(BuildContext context) =>
      Navigator.of(context).pop(IdentityAnswer.addVehicle);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final primary = garage.primary;
    final match = verdict.match;

    final (
      String title,
      String body,
      List<Widget> actions,
    ) = switch (verdict.kind) {
      IdentityKind.other => (
        'This is ${match!.nickname}',
        'The car answered with the VIN on record for ${match.nickname}, '
            'not ${primary!.nickname}. Nothing is recorded until you say '
            'which vehicle this is.',
        [
          PrimaryButton(
            label: 'Switch to ${match.nickname}',
            onPressed: () => _answer(context, match.id),
          ),
          const SizedBox(height: Space.x8),
          Center(
            child: GhostButton(
              label: 'Record under ${primary.nickname} anyway',
              onPressed: () => _answer(context, null),
            ),
          ),
        ],
      ),
      // The free plan has one vehicle, and this would be the second: the
      // door is named but locked, and the other answer is the button.
      IdentityKind.unknown when primary != null && !isPro => (
        'A car the garage does not know',
        'The VIN this car reported is not on any vehicle here. '
            '${primary.nickname} is the primary vehicle, and its VIN is '
            'different. Nothing is recorded until you say which this is.',
        [
          Text(proNote, style: TorqueType.meta.copyWith(color: t.inkTertiary)),
          const SizedBox(height: Space.x12),
          PrimaryButton(
            label: 'Record under ${primary.nickname} anyway',
            onPressed: () => _answer(context, null),
          ),
        ],
      ),
      IdentityKind.unknown when primary != null => (
        'A car the garage does not know',
        'The VIN this car reported is not on any vehicle here. '
            '${primary.nickname} is the primary vehicle, and its VIN is '
            'different. Nothing is recorded until you say which this is.',
        [
          PrimaryButton(
            label: 'Add it as a new vehicle',
            onPressed: () => _addVehicle(context),
          ),
          const SizedBox(height: Space.x8),
          Center(
            child: GhostButton(
              label: 'Record under ${primary.nickname} anyway',
              onPressed: () => _answer(context, null),
            ),
          ),
        ],
      ),
      _ => (
        'Add this car?',
        'The car reported its VIN. Add it as a vehicle and every scan, '
            'trip and service record is kept under it. Until then nothing '
            'is recorded.',
        [
          PrimaryButton(
            label: 'Add a vehicle',
            onPressed: () => _addVehicle(context),
          ),
          const SizedBox(height: Space.x8),
          Center(
            child: GhostButton(
              label: 'Not now',
              onPressed: () => _answer(context, null),
            ),
          ),
        ],
      ),
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x24,
          Space.gutter,
          Space.x16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: Space.x8),
            Text(body, style: TorqueType.body.copyWith(color: t.inkSecondary)),
            if (!verdict.trusted) ...[
              const SizedBox(height: Space.x8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Tell.amber.glyph, size: 14, color: t.tellAmber),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Text(
                      'This VIN failed its check digit on two reads. It is '
                      'compared as reported, but not trusted to decode the '
                      'car.',
                      style: TorqueType.meta.copyWith(color: t.inkSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.x24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
