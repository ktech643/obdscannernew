import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// SPEC §2.1 / B.5 — the global connection banner. 44px, and it **pushes**
/// content rather than overlaying it: a gauge must never be hidden behind
/// the message that explains why it stopped updating.
///
/// Two semantics nodes: the message (a live region, announced when it
/// changes) and, when present, the action as a real button. The tone's
/// glyph is always shown — a busy pulse sits beside it, never replaces it.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.message,
    this.tone = Tell.none,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final String message;
  final Tell tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a small indicator — connecting, re-scanning.
  final bool busy;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.tell(tone);
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: tone == Tell.none
            ? t.surfacePanel
            : color.withValues(alpha: t.chipFillAlpha),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.gutter),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: '${tone.word.isEmpty ? '' : '${tone.word}. '}$message',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        if (tone != Tell.none) ...[
                          Icon(tone.glyph, size: 16, color: color),
                          const SizedBox(width: Space.x8),
                        ],
                        if (busy) ...[
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: _Pulse(color: color),
                          ),
                          const SizedBox(width: Space.x8),
                        ],
                        Expanded(
                          child: Text(
                            message,
                            style: TorqueType.label.copyWith(
                              color: t.inkPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (actionLabel != null)
                Semantics(
                  button: true,
                  label: actionLabel,
                  onTap: onAction,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: onAction,
                      // The banner is 44 tall by spec; the target is at
                      // least 48 wide and the banner's full height.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: Targets.min,
                          minHeight: height,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.x16,
                          ),
                          child: Center(
                            child: Text(
                              actionLabel!,
                              style: TorqueType.label.copyWith(
                                color: t.tellAmber,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: Space.gutter),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays the banner above [child]. When [banner] is null the child gets the
/// full height; when it appears, the child moves down 44px.
class BannerHost extends StatelessWidget {
  const BannerHost({super.key, required this.banner, required this.child});
  final ConnectionBanner? banner;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedSize(
        duration: Motion.of(context, Motion.layout),
        curve: Motion.easeOut,
        alignment: Alignment.topCenter,
        child: banner ?? const SizedBox(width: double.infinity, height: 0),
      ),
      Expanded(child: child),
    ],
  );
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
    child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    ),
  );
}
