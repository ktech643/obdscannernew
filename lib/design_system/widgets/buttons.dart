import 'dart:async';

import 'package:flutter/widgets.dart';

import '../adaptive.dart';
import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// SPEC B.5 — `PrimaryButton`: radius 12, height 56, amber. **Its width
/// never changes when loading**: the label stays in the layout, invisible,
/// and the indicator sits on top. A button that shrinks under the thumb is
/// a missed tap. The label scales down rather than overflows at large text.
///
/// The tap action is on the Semantics node itself, so TalkBack and
/// VoiceOver can activate it; the GestureDetector handles touch only.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// Full width by default; false hugs the label.
  final bool expand;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: t.surfaceDeep),
          const SizedBox(width: Space.x8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TorqueType.label.copyWith(
                color: t.surfaceDeep,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, loading' : label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: onPressed == null && !loading ? 0.4 : 1,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: Space.x24),
              decoration: BoxDecoration(
                color: t.tellAmber,
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Keeps the width; never painted while loading.
                  Opacity(opacity: loading ? 0 : 1, child: content),
                  if (loading) AdaptiveLoading(color: t.surfaceDeep),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SPEC B.5 — `DestructiveButton`: a red outline that fills solid only at
/// step two. First tap arms it and changes the label to [confirmLabel];
/// the second tap, within [armedFor], fires [onConfirmed]. It disarms
/// itself if the user hesitates. Clearing codes goes through this.
class DestructiveButton extends StatefulWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.confirmLabel = 'Tap again to confirm',
    this.armedFor = const Duration(seconds: 4),
    this.enabled = true,
  });

  final String label;
  final String confirmLabel;
  final VoidCallback onConfirmed;
  final Duration armedFor;
  final bool enabled;

  static const height = 56.0;

  @override
  State<DestructiveButton> createState() => _DestructiveButtonState();
}

class _DestructiveButtonState extends State<DestructiveButton> {
  bool _armed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _tap() {
    if (!widget.enabled) return;
    if (_armed) {
      _disarm?.cancel();
      setState(() => _armed = false);
      widget.onConfirmed();
      return;
    }
    setState(() => _armed = true);
    _disarm?.cancel();
    _disarm = Timer(widget.armedFor, () {
      if (mounted) setState(() => _armed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = _armed ? widget.confirmLabel : widget.label;
    final fg = _armed ? t.surfaceDeep : t.tellRed;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: _armed ? '$label. Destructive.' : label,
      liveRegion: _armed,
      onTap: widget.enabled ? _tap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _tap,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.tilePress),
              height: DestructiveButton.height,
              padding: const EdgeInsets.symmetric(horizontal: Space.x24),
              decoration: BoxDecoration(
                color: _armed ? t.tellRed : null,
                border: Border.all(color: t.tellRed, width: 1.5),
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Tell.red.glyph, size: 18, color: fg),
                  const SizedBox(width: Space.x8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TorqueType.label.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text action — "Skip", "Not now". Exactly 48px tall, no chrome.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Targets.min,
              minWidth: Targets.min,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x16),
              // Both factors, or the box fills its parent's height and an
              // onboarding "Skip" becomes an invisible column-wide target.
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: TorqueType.label.copyWith(
                    // Disabled text is exempt from the 4.5:1 floor.
                    color: onPressed == null ? t.inkTertiary : t.tellAmber,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
