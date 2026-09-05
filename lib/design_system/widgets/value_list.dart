import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// One row of a [ValueList]. [tone] colours the value and adds its word for
/// a screen reader; a null [value] renders "Not available" with [reason]
/// — B.6's Partial state, the normal state in OBD2.
class ValueRow {
  const ValueRow(this.label, this.value, {this.tone = Tell.none, this.reason});
  final String label;
  final String? value;
  final Tell tone;
  final String? reason;
}

/// SPEC B.5 — `ValueList`: dense label/value rows, hairlines between,
/// radius 0. Lists stay quiet; the boldness was spent on the Dashboard.
/// Both columns are flexible, so a long protocol name or a VIN at text
/// scale 2.0 wraps rather than overflows.
class ValueList extends StatelessWidget {
  const ValueList({super.key, required this.rows});
  final List<ValueRow> rows;

  static const rowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _Row(row: rows[i], tokens: t),
          if (i < rows.length - 1)
            SizedBox(height: 1, child: ColoredBox(color: t.hairline)),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.tokens});
  final ValueRow row;
  final TorqueTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final absent = row.value == null;
    // "Not available" is content, not chrome: secondary ink, ≥ 4.5:1.
    final color = absent
        ? t.inkSecondary
        : row.tone == Tell.none
        ? t.inkPrimary
        : t.tell(row.tone);
    final text = absent ? 'Not available' : row.value!;
    return Semantics(
      label: [
        row.label,
        if (row.tone != Tell.none && !absent) row.tone.word,
        text,
        if (absent && row.reason != null) row.reason!,
      ].join(', '),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ValueList.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    row.label,
                    style: TorqueType.body.copyWith(color: t.inkSecondary),
                  ),
                ),
                const SizedBox(width: Space.x12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (row.tone != Tell.none && !absent) ...[
                            Icon(row.tone.glyph, size: 14, color: color),
                            const SizedBox(width: Space.x4),
                          ],
                          Flexible(
                            child: Text(
                              text,
                              textAlign: TextAlign.end,
                              style: TorqueType.body.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                      if (absent && row.reason != null)
                        Text(
                          row.reason!,
                          textAlign: TextAlign.end,
                          style: TorqueType.meta.copyWith(
                            color: t.inkSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
