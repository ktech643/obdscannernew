import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';

/// The rows Settings and its sub-screens are made of, on the Part B design
/// system: a section heading, and a row that opens something, states
/// something, or — in the fault colour — deletes something.

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});
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
      child: Text(
        title,
        style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
      ),
    );
  }
}

class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? value;

  /// A line of explanation under the title — what a row does or means.
  final String? subtitle;
  final VoidCallback? onTap;

  /// The title in the fault colour: a row that deletes.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      onTap: onTap,
      label: [title, ?value, ?subtitle].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
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
                            color: t.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (enabled) ...[
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
