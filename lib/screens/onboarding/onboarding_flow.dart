import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/platform/platform_info.dart';
import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/icons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';

/// Flow A — first run. Four frames: what this does, the adapter explainer,
/// add your car, and the non-skippable safety acknowledgement.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OnboardingProvider>();
    return switch (o.step) {
      0 => const _A1WhatThisDoes(),
      1 => const _A2Adapter(),
      2 => const _A3AddYourCar(),
      _ => _A4Safety(onDone: onDone),
    };
  }
}

/// The `1 OF 4 / Skip` progress header. Onboarding uses the 24px gutter.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, this.skippable = true});

  final int step;
  final bool skippable;

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 22),
      child: Row(
        children: [
          Text('$step OF ${o.totalSteps}', style: Type.sectionHeading),
          const Spacer(),
          if (skippable) InlineAction('Skip', onPressed: o.skip),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- A1
class _A1WhatThisDoes extends StatelessWidget {
  const _A1WhatThisDoes();

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        divider: false,
        children: [PrimaryButton('Next', onPressed: o.next)],
      ),
      children: [
        const _Progress(step: 1),
        // The schematic: phone → adapter → car, three blueprint cells joined
        // by dashed rules.
        const _SchematicChain(),
        const SizedBox(height: 32),
        Text(
          "Read your car's error codes and watch live engine data.",
          style: Type.onboardingHeadline,
        ),
        const SizedBox(height: 14),
        Text(
          'Torque plugs into the diagnostic port every car built since 1996 '
          'already has, and translates what the engine computer is saying into '
          'plain English.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 26),
        const _Dots(active: 0, count: 4),
      ],
    );
  }
}

class _SchematicChain extends StatelessWidget {
  const _SchematicChain();

  @override
  Widget build(BuildContext context) => const Padding(
    // Registration marks sit 6px outside each box; the row needs that
    // clearance at both ends or they clip against the screen gutter.
    padding: EdgeInsets.symmetric(horizontal: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _SchematicCell(label: 'iPhone', icon: Lu.smartphone),
        ),
        _DashedRule(),
        Expanded(
          child: _SchematicCell(label: 'Adapter', icon: Lu.plug),
        ),
        _DashedRule(),
        Expanded(
          child: _SchematicCell(label: 'Your car', icon: Lu.car),
        ),
      ],
    ),
  );
}

class _SchematicCell extends StatelessWidget {
  const _SchematicCell({required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) => Blueprint(
    height: 92,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icn(icon, size: 26, color: T.accent),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: Type.sectionHeading.copyWith(letterSpacing: 0.9),
          maxLines: 1,
        ),
      ],
    ),
  );
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  static const width = 26.0;

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: width,
    height: 1,
    child: CustomPaint(painter: _DashedPainter()),
  );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = T.neutral500
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.count});

  final int active;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: i == active ? 18 : 6,
          height: 3,
          margin: const EdgeInsets.only(right: 5),
          color: i == active ? T.accent700 : T.neutral300,
        ),
    ],
  );
}

// ---------------------------------------------------------------- A2
/// The most important screen in the app. If a user buys the wrong adapter,
/// nothing else here matters.
class _A2Adapter extends StatelessWidget {
  const _A2Adapter();

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    // SPEC §5.1: this screen is platform-branched. On Android almost any
    // ELM327 adapter works; on iOS only BLE/Wi-Fi, and the classic-Bluetooth
    // incompatibility has to be explained up front.
    final android = PlatformInfo.current.isAndroid;
    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        divider: false,
        children: [
          PrimaryButton('I have one', onPressed: o.next),
          const SizedBox(height: 8),
          GhostButton(
            'Help me pick one',
            onPressed: () => notImplementedHere(
              context,
              'Opens the bundled adapter list — no lookup leaves your device.',
            ),
          ),
        ],
      ),
      children: [
        const _Progress(step: 2),
        Text('You need an adapter', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          android
              ? 'Torque talks to your car through an OBD2 adapter that plugs in '
                    'under the dash. Almost any ELM327 adapter works — Bluetooth, '
                    'Bluetooth LE, or Wi-Fi.'
              : 'Torque talks to your car through an OBD2 adapter that plugs in '
                    'under the dash. On iPhone it must be a Bluetooth LE or Wi-Fi '
                    'adapter.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        if (android)
          const _CompareCell(
            verdict: 'Works',
            items: ['Bluetooth', 'Bluetooth LE', 'Wi-Fi'],
            tone: Tone.pass,
          )
        else
          IntrinsicHeight(
            // The two cells must match height whichever has more content, and
            // stretch needs a bounded cross axis to resolve against.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: _CompareCell(
                    verdict: 'Works',
                    items: ['Bluetooth LE', 'Wi-Fi'],
                    tone: Tone.pass,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: _CompareCell(
                    verdict: "Can't work",
                    items: ['Bluetooth Classic'],
                    footnote: 'the cheap Android kind',
                    tone: Tone.fault,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (!android)
          const NoteBlock(
            'Pairing an adapter in iPhone Settings does not make it work with '
            'apps. Apple gives no app access to Classic Bluetooth — that is a '
            'platform rule, not a Torque limitation.',
          ),
        const SizedBox(height: 22),
        Text('Where the port is', style: Type.cardTitle),
        const SizedBox(height: 10),
        const _PortDiagram(),
        const SizedBox(height: 10),
        Text(
          "Driver's side, under the dash, within 60 cm of the steering wheel. "
          '16 pins, trapezoid.',
          style: Type.bodyMuted,
        ),
        const SizedBox(height: 20),
        const _Dots(active: 1, count: 4),
      ],
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
  final Tone tone;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final pass = tone == Tone.pass;
    return Blueprint(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icn(
                pass ? Lu.circleCheck : Lu.circleX,
                size: 16,
                color: pass ? T.passText : T.fault,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  verdict,
                  style: Type.rowPrimary.copyWith(
                    color: pass ? T.passText : T.fault,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(i, style: Type.inlineValue),
            ),
          if (footnote != null) ...[
            const SizedBox(height: 5),
            Text(footnote!, style: Type.footnote),
          ],
        ],
      ),
    );
  }
}

/// The 16-pin trapezoid, drawn rather than photographed — the shape is what
/// the user has to recognise under the dash.
class _PortDiagram extends StatelessWidget {
  const _PortDiagram();

  @override
  Widget build(BuildContext context) => Blueprint(
    height: 104,
    child: CustomPaint(painter: _PortPainter(), size: Size.infinite),
  );
}

class _PortPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = T.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const w = 168.0, h = 52.0;
    final l = (size.width - w) / 2, t = (size.height - h) / 2;
    // Trapezoid: wider along the top edge, matching the SAE J1962 connector.
    final path = Path()
      ..moveTo(l, t)
      ..lineTo(l + w, t)
      ..lineTo(l + w - 14, t + h)
      ..lineTo(l + 14, t + h)
      ..close();
    canvas.drawPath(path, stroke);

    // Two rows of eight pins.
    final pin = Paint()..color = T.accent.withValues(alpha: 0.55);
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 8; i++) {
        final inset = row == 0 ? 20.0 : 24.0;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- A3
class _A3AddYourCar extends StatefulWidget {
  const _A3AddYourCar();

  @override
  State<_A3AddYourCar> createState() => _A3AddYourCarState();
}

class _A3AddYourCarState extends State<_A3AddYourCar> {
  int _unit = 0;

  @override
  Widget build(BuildContext context) {
    final o = context.read<OnboardingProvider>();
    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        divider: false,
        children: [
          PrimaryButton('Save and continue', onPressed: o.next),
          const SizedBox(height: 8),
          GhostButton("I'll do this later", onPressed: o.next),
        ],
      ),
      children: [
        const _Progress(step: 3),
        Text('Add your car', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          'All optional, all editable later. The Garage works with no adapter '
          'plugged in at all.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        const Field(label: 'Nickname', hint: 'The Golf'),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: Field(label: 'Make', hint: 'Volkswagen'),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Field(label: 'Year', hint: '2014'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Field(label: 'Model', hint: 'Golf GTD'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Field(label: 'Odometer', hint: '142,380'),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Segmented(
                options: const ['km', 'mi'],
                selected: _unit,
                height: 42,
                onSelect: (i) => setState(() => _unit = i),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "We'll read the VIN off the car once you connect and fill in what we "
          'can. Nothing is sent anywhere — the decode happens on your iPhone.',
          style: Type.footnote,
        ),
        const SizedBox(height: 20),
        const _Dots(active: 2, count: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------- A4
/// Non-skippable. The one screen with no Skip affordance.
class _A4Safety extends StatelessWidget {
  const _A4Safety({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OnboardingProvider>();
    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        divider: false,
        children: [
          PrimaryButton(
            'Agree and continue',
            onPressed: o.safetyAcknowledged
                ? () {
                    o.finish();
                    onDone();
                  }
                : null,
          ),
        ],
      ),
      children: [
        const _Progress(step: 4, skippable: false),
        Text('Before you start', style: Type.onboardingHeadline),
        const SizedBox(height: 16),
        const NoteBlock(
          'Have a passenger read the data, or park first. Torque disables gauge '
          'editing above 5 km/h and will not clear codes unless the car is '
          'stationary.',
          tone: Tone.caution,
          title: "Don't use this app while driving.",
        ),
        const SizedBox(height: 22),
        const NumberedFact(
          1,
          'Reading data is passive. Torque never writes to your engine computer '
          '— the one exception is clearing codes, which you trigger yourself.',
        ),
        const NumberedFact(
          2,
          'A code points to a symptom, not always the cause. This app is not a '
          "substitute for a mechanic's diagnosis.",
        ),
        const NumberedFact(
          3,
          'Unplug your adapter when the car is parked for more than a few days '
          '— some draw power constantly.',
        ),
        const SizedBox(height: 4),
        // The permission primer. iOS is only asked after the user knows why.
        const NoteBlock(
          'Next, iPhone will ask for Bluetooth. Torque uses it only to reach '
          'your adapter — there is no other use and no location access.',
          icon: Lu.bluetooth,
        ),
        const SizedBox(height: 18),
        AppCheckbox(
          value: o.safetyAcknowledged,
          onChanged: o.setSafetyAcknowledged,
          label: "I understand and I won't use this while driving",
        ),
        const SizedBox(height: 12),
        const _Dots(active: 3, count: 4),
      ],
    );
  }
}
