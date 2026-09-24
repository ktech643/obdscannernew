import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart' show DistanceUnit, DistanceUnitX;
import '../garage/distance.dart';
import '../../session/obd_session.dart';
import 'diagnostics_controller.dart';

/// SPEC §5.4 / §9.5 — the clear, two-step guarded.
///
/// Everything this does to the car is stated **uncollapsed**, before the
/// button is reachable. There is no "show details": the readiness reset is
/// the consequence people are caught out by, and a disclosure triangle is
/// how you hide it while claiming you didn't.
///
/// The speed gate is a hard gate and it reads the car rather than the bus
/// (hard rule 4): a stale zero from a stop sign ten seconds ago is exactly
/// the reading that must not open it.
class ClearCodesSheet extends StatefulWidget {
  const ClearCodesSheet({
    super.key,
    required this.controller,
    this.distance = DistanceUnit.km,
  });

  /// SPEC §5.6 — the gate quotes the car's speed in the user's unit.
  final DistanceUnit distance;

  final DiagnosticsController controller;

  @override
  State<ClearCodesSheet> createState() => _ClearCodesSheetState();
}

enum _Stage { checking, gated, ready, clearing, done }

class _ClearCodesSheetState extends State<ClearCodesSheet> {
  DiagnosticsController get _c => widget.controller;

  _Stage _stage = _Stage.checking;
  double? _speed;
  ClearResult? _outcome;

  @override
  void initState() {
    super.initState();
    _checkSpeed();
  }

  Future<void> _checkSpeed() async {
    setState(() => _stage = _Stage.checking);
    final speed = await _c.readSpeed();
    if (!mounted) return;
    setState(() {
      _speed = speed;
      // Null is "we could not ask", which is not zero. The gate stays shut.
      _stage = speed == 0 ? _Stage.ready : _Stage.gated;
    });
  }

  Future<void> _clear() async {
    setState(() => _stage = _Stage.clearing);
    final outcome = await _c.clear();
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
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
            children: _stage == _Stage.done
                ? _result(context, t)
                : _consent(context, t),
          ),
        ),
      ),
    );
  }

  List<Widget> _consent(BuildContext context, TorqueTokens t) {
    final permanent = _c.unclearable;
    return [
      Text(
        'Clear codes',
        style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
      ),
      const SizedBox(height: Space.x16),

      // §5.4 — stated, uncollapsed, in this order. The emissions one is
      // the consequence that costs people money, so it carries the tone.
      const _Consequence(
        icon: Icons.lightbulb_outline,
        text: 'Turns off the Check Engine light.',
      ),
      const _Consequence(
        icon: Icons.delete_outline,
        text:
            'Erases the freeze-frame data — the snapshot of what the car '
            'was doing when the fault happened. A mechanic uses that.',
      ),
      const _Consequence(
        icon: Icons.warning_amber_outlined,
        tone: Tell.amber,
        text:
            'Resets the readiness monitors. The car will likely fail an '
            'emissions test until it has been driven 50–100 miles.',
      ),
      const _Consequence(
        icon: Icons.build_outlined,
        text:
            'Does not fix the fault. If the fault is still there, the code '
            'comes back.',
      ),

      if (permanent.isNotEmpty)
        _Consequence(
          icon: Icons.lock_outline,
          text:
              '${permanent.length == 1 ? 'One permanent code' : '${permanent.length} permanent codes'} '
              '(${permanent.map((d) => d.code).join(', ')}) will not clear. '
              'Only the ECU can release those, once it has seen the fault '
              'stay fixed.',
        ),

      const SizedBox(height: Space.x16),
      Text(
        _c.dtcs == null || _c.vehicleId == null
            ? switch (_c.notRecording) {
                NotRecording.demo =>
                  'This is Demo Mode — a recorded car — so nothing is saved '
                      'to your garage.',
                NotRecording.identityUnsettled =>
                  'These codes are not being saved — the app has not been '
                      'told which vehicle this is yet, so there will be no '
                      'record of what was cleared.',
                NotRecording.noVehicle =>
                  'These codes are not being saved — no vehicle is selected '
                      'in the Garage yet, so there will be no record of what '
                      'was cleared.',
              }
            : 'The codes are saved to this vehicle’s history first, before '
                  'anything is sent to the car.',
        style: TorqueType.meta.copyWith(color: t.inkTertiary),
      ),
      const SizedBox(height: Space.x24),
      ..._action(context, t),
    ];
  }

  List<Widget> _action(BuildContext context, TorqueTokens t) {
    switch (_stage) {
      case _Stage.checking:
        return [
          Row(
            children: [
              const AdaptiveLoading(size: 16),
              const SizedBox(width: Space.x12),
              // Flexible, or the sentence runs off the edge rather than
              // wrapping at text scale 2.0 (B.8).
              Expanded(
                child: Text(
                  'Checking the car is stopped…',
                  style: TorqueType.body.copyWith(color: t.inkSecondary),
                ),
              ),
            ],
          ),
        ];

      case _Stage.gated:
        return [
          _Gate(speed: _speed, distance: widget.distance),
          const SizedBox(height: Space.x16),
          PrimaryButton(label: 'Check again', onPressed: _checkSpeed),
        ];

      case _Stage.ready:
        return [
          DestructiveButton(
            label: 'Clear codes',
            confirmLabel: 'Tap again to clear',
            onConfirmed: _clear,
          ),
          const SizedBox(height: Space.x8),
          Center(
            child: GhostButton(
              label: 'Keep the codes',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ];

      case _Stage.clearing:
        return [
          Row(
            children: [
              const AdaptiveLoading(size: 16),
              const SizedBox(width: Space.x12),
              // Flexible, or the sentence runs off the edge rather than
              // wrapping at text scale 2.0 (B.8).
              Expanded(
                child: Text(
                  'Clearing, then reading the codes back…',
                  style: TorqueType.body.copyWith(color: t.inkSecondary),
                ),
              ),
            ],
          ),
        ];

      case _Stage.done:
        return const [];
    }
  }

  /// What actually happened — never "cleared" without the re-read behind
  /// it. §9.5: report the truth.
  List<Widget> _result(BuildContext context, TorqueTokens t) {
    final outcome = _outcome!;
    final (Tell tone, String title, String body) = switch (outcome) {
      // The re-read may still show permanent codes, which is what
      // permanent means. Saying "came back with none" then listing one
      // would read as a contradiction, so the copy accounts for it.
      ClearResult.cleared => (
        Tell.green,
        'Cleared',
        _c.unclearable.isEmpty
            ? 'The codes were cleared and the car came back with none. The '
                  'readiness monitors have reset — give it 50–100 miles '
                  'before an emissions test.'
            : 'The stored and pending codes were cleared. '
                  '${_c.unclearable.map((d) => d.code).join(', ')} is '
                  'permanent and stays until the ECU releases it. The '
                  'readiness monitors have reset — give it 50–100 miles '
                  'before an emissions test.',
      ),
      ClearResult.codesReturned => (
        Tell.amber,
        'Cleared, and the codes came back',
        'The car accepted the clear, then reported the same codes again. '
            'That means the fault is happening right now, not that the '
            'clear failed.',
      ),
      ClearResult.refused => (
        Tell.amber,
        'The car refused',
        'Most ECUs will not clear codes with the engine running. Turn the '
            'engine off, leave the ignition at ON, and try again. Nothing '
            'was changed.',
      ),
      ClearResult.interrupted => (
        Tell.amber,
        'Could not be verified',
        'The clear was sent but the codes could not be read back, so '
            'whether it worked is unknown. The codes from before are '
            'saved, and Diagnostics will offer to check again.',
      ),
    };
    return [
      Icon(tone.glyph, size: 28, color: t.tell(tone)),
      const SizedBox(height: Space.x12),
      Text(title, style: TorqueType.titleLg.copyWith(color: t.inkPrimary)),
      const SizedBox(height: Space.x8),
      Text(body, style: TorqueType.body.copyWith(color: t.inkSecondary)),
      const SizedBox(height: Space.x24),
      PrimaryButton(
        label: 'Done',
        onPressed: () => Navigator.of(context).pop(outcome),
      ),
    ];
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence({
    required this.icon,
    required this.text,
    this.tone = Tell.none,
  });

  final IconData icon;
  final String text;
  final Tell tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone == Tell.none ? t.inkTertiary : t.tell(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Space.x12),
          Expanded(
            child: Text(
              text,
              style: TorqueType.body.copyWith(
                color: tone == Tell.none ? t.inkSecondary : t.inkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §9.5 — the hard gate. Clearing codes at speed means the ECU drops a
/// live fault mid-drive, so the button is not reachable until the car says
/// it is stopped.
class _Gate extends StatelessWidget {
  const _Gate({required this.speed, required this.distance});
  final DistanceUnit distance;

  /// Null when the car could not be asked — which is not permission.
  final double? speed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RaisedSurface(
      padding: const EdgeInsets.all(Space.x16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Tell.red.glyph, size: 18, color: t.tellRed),
          const SizedBox(width: Space.x12),
          Expanded(
            child: Text(
              speed == null
                  ? 'The car did not report its speed, so there is no way '
                        'to tell it is stopped. Codes cannot be cleared '
                        'until it does.'
                  : 'The car is moving at '
                        '${Distance.fromKm(speed!, distance).round()} '
                        '${distance.speedLabel}. Stop and put it in park '
                        'before clearing codes.',
              style: TorqueType.body.copyWith(color: t.inkPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
