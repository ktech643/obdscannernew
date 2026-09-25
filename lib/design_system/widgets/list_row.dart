import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// A section heading over a run of [ListRow]s.
class ListSection extends StatelessWidget {
  const ListSection({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x24,
        Space.gutter,
        Space.x8,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
        ),
      ),
    );
  }
}

/// A row in a list: a title, optionally a line under it and a value on the
/// right, and a chevron when it opens something. Radius 0, hairline under,
/// 48 minimum — lists stay quiet so what they hold can be loud.
///
/// [tone] colours the value; the value must still say in words what the
/// colour means (hard rule 11). [destructive] puts the title in the fault
/// colour, for the one row on a screen that deletes.
///
/// A row with no [onTap] is a *statement* — "what leaves the device" — and
/// reads like one: primary ink, no enabled state. Only [enabled] false
/// makes it a disabled control, dimmed and announced as such. Treating
/// every tapless row as disabled had VoiceOver call the privacy screen's
/// facts "dimmed" and drew them at 3.97:1, under B.8's 4.5:1.
///
/// One node for assistive tech, carrying the tap: a `GestureDetector`
/// under `ExcludeSemantics` is invisible to VoiceOver and TalkBack.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.tone = Tell.none,
    this.trailing,
    this.destructive = false,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Tell tone;
  final Widget? trailing;
  final bool destructive;

  /// False for a control that exists but cannot be used now.
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tappable = onTap != null && enabled;
    return Semantics(
      button: tappable,
      enabled: tappable ? true : (enabled ? null : false),
      onTap: tappable ? onTap : null,
      label: [title, ?value, ?subtitle].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: tappable ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.min),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hairline)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.gutter,
                  vertical: Space.x12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TorqueType.body.copyWith(
                              color: destructive
                                  ? t.tellRed
                                  : enabled
                                  ? t.inkPrimary
                                  : t.inkTertiary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: Space.x4),
                            Text(
                              subtitle!,
                              style: TorqueType.meta.copyWith(
                                color: t.inkSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: Space.x12),
                      Flexible(
                        child: Text(
                          value!,
                          textAlign: TextAlign.end,
                          style: TorqueType.body.copyWith(
                            color: tone == Tell.none
                                ? t.inkSecondary
                                : t.tell(tone),
                          ),
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(width: Space.x8),
                      trailing!,
                    ],
                    if (tappable) ...[
                      const SizedBox(width: Space.x8),
                      Icon(Icons.chevron_right, size: 20, color: t.inkTertiary),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
