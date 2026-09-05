import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// SPEC B.5 — `TelltaleChip`: radius 8, height 24 at text scale 1.0, a 15%
/// fill of its tone. A glyph and a word, always — colour never carries the
/// meaning alone. The chip grows with large text rather than clipping the
/// word.
class TelltaleChip extends StatelessWidget {
  const TelltaleChip({
    super.key,
    required this.tone,
    required this.label,
    this.glyph,
  });

  final Tell tone;
  final String label;

  /// Overrides the tone's default glyph.
  final IconData? glyph;

  static const height = 24.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone == Tell.none ? t.inkSecondary : t.tell(tone);
    final icon = glyph ?? (tone == Tell.none ? null : tone.glyph);
    return Semantics(
      label: tone.word.isEmpty ? label : '${tone.word}: $label',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone == Tell.none
                  ? t.surfacePanel
                  : color.withValues(alpha: t.chipFillAlpha),
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x8,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: Space.x4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TorqueType.meta.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
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
