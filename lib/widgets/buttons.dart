import 'package:flutter/widgets.dart';

import '../models/enums.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'blueprint.dart';
import 'chrome.dart';
import 'icons.dart';

/// The solid accent primary button — the single deliberate exception to the
/// "cards and figures are transparent line drawings" rule. 52px, full width,
/// 4px radius, `--color-accent-700` so the label clears 4.5:1.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return _Tappable(
      onPressed: onPressed,
      child: Container(
        height: T.primaryButtonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: enabled ? T.accent700 : T.neutral400,
          borderRadius: T.rMd,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icn(icon!, size: 17, color: T.neutral100),
              const SizedBox(width: 9),
            ],
            Text(label, style: Type.button(T.neutral100)),
          ],
        ),
      ),
    );
  }
}

/// 48px, hairline outline, transparent.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: onPressed,
    child: Container(
      height: T.secondaryButtonHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: T.text, width: 1),
        borderRadius: T.rMd,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icn(icon!, size: 17, color: T.text),
            const SizedBox(width: 9),
          ],
          Text(label, style: Type.button(T.text)),
        ],
      ),
    ),
  );
}

/// A destructive action, outlined in fault red and never filled — the
/// destructive choice must not be the visually dominant one.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton(
    this.label, {
    super.key,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onPressed != null;
    final color = on ? T.fault : T.neutral400;
    return _Tappable(
      onPressed: on ? onPressed : null,
      child: Container(
        height: T.secondaryButtonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1),
          borderRadius: T.rMd,
        ),
        alignment: Alignment.center,
        child: Text(label, style: Type.button(color)),
      ),
    );
  }
}

/// 44px plain text. Cancel and other recessive actions.
class GhostButton extends StatelessWidget {
  const GhostButton(
    this.label, {
    super.key,
    this.onPressed,
    this.color = T.accent700,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final String? icon;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: onPressed,
    child: SizedBox(
      height: T.ghostButtonHeight,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icn(icon!, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Text(label, style: Type.button(color, size: 15)),
        ],
      ),
    ),
  );
}

/// A small inline text action — "Edit", "Skip", "Stop", "See Pro".
class InlineAction extends StatelessWidget {
  const InlineAction(
    this.label, {
    super.key,
    this.onPressed,
    this.color = T.accent700,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: onPressed,
    // The visible label is small, but the tap target is not.
    minHeight: T.touchTargetFloor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(label, style: Type.button(color, size: 14)),
    ),
  );
}

/// The square 56px accent add button used in the maintenance log.
class SquareAddButton extends StatelessWidget {
  const SquareAddButton({super.key, this.onPressed, this.size = 56});

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: onPressed,
    child: Container(
      width: size,
      height: size,
      color: T.accent700,
      alignment: Alignment.center,
      child: const Icn(Lu.plus, size: 22, color: T.neutral100),
    ),
  );
}

/// A segmented control — km/mi, °C/°F, PDF/CSV. Zero radius; the selected
/// segment takes the `--color-accent-700` fill.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.height = 36,
    this.expand = false,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var i = 0; i < options.length; i++)
        _Tappable(
          onPressed: () => onSelect(i),
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == selected ? T.accent700 : null,
              border: i == 0
                  ? null
                  : const Border(left: BorderSide(color: T.divider, width: 1)),
            ),
            child: Text(
              options[i],
              style: Type.button(
                i == selected ? T.neutral100 : T.neutral700,
                size: 14,
              ),
            ),
          ),
        ),
    ];
    return Blueprint(
      corners: false,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: expand
              ? [for (final c in children) Expanded(child: c)]
              : children,
        ),
      ),
    );
  }
}

/// Chips used for picking a service type. Wraps; zero radius.
class ChoiceChips extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < options.length; i++)
        _Tappable(
          onPressed: () => onSelect(i),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == selected ? T.accent700 : null,
              border: Border.all(
                color: i == selected ? T.accent700 : T.divider,
                width: 1,
              ),
            ),
            child: Text(
              options[i],
              style: Type.button(
                i == selected ? T.neutral100 : T.text,
                size: 14,
              ),
            ),
          ),
        ),
    ],
  );
}

/// A toggle. Zero radius track, 1px border, accent fill when on — no iOS pill.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: () => onChanged(!value),
    child: Semantics(
      toggled: value,
      child: Container(
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          color: value ? T.accent700 : T.neutral300,
          border: Border.all(
            color: value ? T.accent700 : T.neutral400,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: value ? T.neutral100 : T.neutral100,
          ),
        ),
      ),
    ),
  );
}

/// A square checkbox with a Lucide tick.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: value ? T.accent700 : T.text, width: 1),
              color: value ? T.accent700 : null,
            ),
            child: value
                ? const Center(
                    child: Icn(Lu.check, size: 14, color: T.neutral100),
                  )
                : null,
          ),
          if (label != null) ...[
            const SizedBox(width: 11),
            Expanded(child: Text(label!, style: Type.body15)),
          ],
        ],
      ),
    ),
  );
}

/// A radio option row — export format, plan choice.
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => _Tappable(
    onPressed: onSelect,
    child: Container(
      constraints: const BoxConstraints(minHeight: T.touchTargetFloor),
      decoration: const BoxDecoration(border: T.hairlineBottom),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? T.accent700 : T.neutral500,
                width: 1,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(width: 10, height: 10, color: T.accent700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Type.rowPrimary),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Type.rowSecondary),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// An explanatory block. `Tone.ink` renders the accent informational fill;
/// caution and fault carry their tint, border and a glyph.
class NoteBlock extends StatelessWidget {
  const NoteBlock(
    this.text, {
    super.key,
    this.tone = Tone.ink,
    this.title,
    this.icon,
    this.child,
  });

  final String text;
  final Tone tone;
  final String? title;
  final String? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color fill, Color border, String glyph) = switch (tone) {
      Tone.caution => (
        T.cautionText,
        T.cautionTint,
        T.cautionBorder,
        Lu.triangleAlert,
      ),
      Tone.fault => (T.fault, T.faultTint, T.fault, Lu.circleAlert),
      Tone.pass => (T.passText, T.passTint, T.pass, Lu.circleCheck),
      Tone.ink => (T.accent800, T.accent100, T.accent400, Lu.info),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icn(icon ?? glyph, size: 15, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: Type.rowPrimary.copyWith(color: fg)),
                  const SizedBox(height: 5),
                ],
                Text(
                  text,
                  style: Type.body15.copyWith(
                    fontSize: 13.5,
                    height: 1.45,
                    color: fg,
                  ),
                ),
                if (child != null) ...[const SizedBox(height: 10), child!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered fact — the "three things to check" and "common causes" patterns.
class NumberedFact extends StatelessWidget {
  const NumberedFact(this.index, this.text, {super.key, this.detail});

  final int index;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Text(
            index.toString().padLeft(2, '0'),
            style: Type.inlineValue.copyWith(color: T.accent700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Type.body15),
              if (detail != null) ...[
                const SizedBox(height: 3),
                Text(detail!, style: Type.rowSecondary),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// The 320×50 anchored ad banner. The height is reserved whether or not a
/// creative has loaded, so nothing shifts underneath it. Always labelled, and
/// always carrying a "Remove ads" affordance.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key, this.onRemoveAds});

  final VoidCallback? onRemoveAds;

  @override
  Widget build(BuildContext context) => Container(
    height: T.adBannerHeight + 16,
    color: T.bg,
    padding: const EdgeInsets.symmetric(horizontal: T.gutter, vertical: 8),
    child: Row(
      children: [
        const Badge('AD', color: T.neutral600),
        const SizedBox(width: 10),
        const Expanded(
          child: Plate(
            height: T.adBannerHeight,
            child: Text('320 × 50', style: TextStyle(fontSize: 0)),
          ),
        ),
        const SizedBox(width: 10),
        _Tappable(
          onPressed: onRemoveAds,
          child: SizedBox(
            width: 46,
            child: Text(
              'Remove\nads',
              style: Type.chip(T.accent700).copyWith(letterSpacing: 0.2),
            ),
          ),
        ),
      ],
    ),
  );
}

/// An empty state: a headline saying what's absent, one sentence of why, one
/// action. Never an apology, never a mascot.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.headline,
    required this.why,
    this.action,
  });

  final String headline;
  final String why;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Blueprint(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: Type.cardTitle),
        const SizedBox(height: 7),
        Text(why, style: Type.bodyMuted),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// Shared hit-target and press treatment for every control above.
class _Tappable extends StatefulWidget {
  const _Tappable({required this.child, this.onPressed, this.minHeight});

  final Widget child;
  final VoidCallback? onPressed;
  final double? minHeight;

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    var child = widget.child;
    if (widget.minHeight != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.minHeight!),
        child: Center(child: child),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _down = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) => setState(() => _down = false),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _down = false),
      child: Semantics(
        button: true,
        enabled: widget.onPressed != null,
        child: AnimatedOpacity(
          opacity: _down ? 0.72 : 1,
          duration: Duration(milliseconds: reduceMotion ? 0 : 80),
          child: child,
        ),
      ),
    );
  }
}
