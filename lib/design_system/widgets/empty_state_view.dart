import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

/// SPEC B.6 — Empty: what's absent, why, one action. Never a sad face.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.why,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.tone = Tell.none,
  });

  final String title;
  final String why;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Green for a positive empty ("No codes stored").
  final Tell tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone == Tell.none ? t.inkTertiary : t.tell(tone);
    final body = Padding(
      padding: const EdgeInsets.all(Space.x24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || tone != Tell.none) ...[
            Icon(icon ?? tone.glyph, size: 28, color: color),
            const SizedBox(height: Space.x12),
          ],
          Text(title, style: TorqueType.titleMd.copyWith(color: t.inkPrimary)),
          const SizedBox(height: Space.x4),
          Text(why, style: TorqueType.body.copyWith(color: t.inkSecondary)),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.x24),
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
    // As a whole screen's body it can be taller than the screen — text
    // scale 2.0 on a 320 × 568 phone overflowed by 11 px (AC-16) — so it
    // scrolls there. Inside a list it is just a child of the list.
    return LayoutBuilder(
      builder: (context, c) => c.hasBoundedHeight
          ? SingleChildScrollView(child: body)
          : body,
    );
  }
}
