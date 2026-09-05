import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// SPEC B.5 — `DtcRow`: radius 0, 72px minimum, a 3px severity bar on the
/// left. The code in `titleMd`, the description under it, the status as a
/// word. Unknown codes say they are unknown (hard rule 7) — the caller
/// passes that text; this row never invents one.
class DtcRow extends StatelessWidget {
  const DtcRow({
    super.key,
    required this.code,
    required this.description,
    required this.severity,
    this.status,
    this.onTap,
  });

  final String code;
  final String description;

  /// `Tell.none` for a code with no known severity.
  final Tell severity;

  /// "Stored", "Pending", "Permanent", "Cleared, came back".
  final String? status;
  final VoidCallback? onTap;

  static const minHeight = 72.0;
  static const barWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = severity == Tell.none ? t.hairline : t.tell(severity);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border(bottom: BorderSide(color: t.hairline, width: 1)),
        ),
        // IntrinsicHeight bounds the row to its tallest child, so the
        // stretched severity bar has a height to stretch to.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: barWidth,
                child: ColoredBox(color: color),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x16,
                    vertical: Space.x12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Code and severity word hug; the status takes the
                          // rest and ellipsizes, so nothing overflows at 2.0.
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  code,
                                  style: TorqueType.titleMd.copyWith(
                                    color: t.inkPrimary,
                                  ),
                                ),
                                if (severity != Tell.none) ...[
                                  const SizedBox(width: Space.x8),
                                  Icon(severity.glyph, size: 14, color: color),
                                  const SizedBox(width: Space.x4),
                                  Flexible(
                                    child: Text(
                                      severity.word,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TorqueType.meta.copyWith(
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(width: Space.x8),
                            Expanded(
                              child: Text(
                                status!,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TorqueType.meta.copyWith(
                                  color: t.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.x4),
                      Text(
                        description,
                        style: TorqueType.body.copyWith(color: t.inkSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: Space.x12),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: t.inkTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final labelled = Semantics(
      button: onTap != null,
      onTap: onTap,
      label: [
        code,
        if (severity != Tell.none) severity.word,
        description,
        ?status,
      ].join(', '),
      child: ExcludeSemantics(child: row),
    );
    if (onTap == null) return labelled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: labelled,
    );
  }
}
