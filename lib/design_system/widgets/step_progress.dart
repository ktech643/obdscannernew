import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// SPEC B.5 / B.6 — `StepProgress`: the handshake's seven steps as
/// segments, with the **named** current step under them. A spinner says
/// "wait"; a named step says "waiting for the protocol search".
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.steps,
    required this.current,
    this.failedAt,
  });

  final List<String> steps;

  /// Index of the step in progress; `steps.length` means all done.
  final int current;

  /// Index of a failed step, drawn red with its name.
  final int? failedAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final done = current >= steps.length && failedAt == null;
    final label = failedAt != null
        ? 'Failed: ${steps[failedAt!.clamp(0, steps.length - 1)]}'
        : done
        ? 'Done'
        : steps[current.clamp(0, steps.length - 1)];
    return Semantics(
      label: failedAt != null
          ? label
          : done
          ? 'All ${steps.length} steps done'
          : 'Step ${current + 1} of ${steps.length}: $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Expanded(
                    child: SizedBox(
                      height: 4,
                      child: ColoredBox(
                        color: failedAt == i
                            ? t.tellRed
                            : i < current
                            ? t.inkPrimary
                            : i == current && failedAt == null
                            ? t.tellAmber
                            : t.surfacePanel,
                      ),
                    ),
                  ),
                  if (i < steps.length - 1) const SizedBox(width: Space.x4),
                ],
              ],
            ),
            const SizedBox(height: Space.x8),
            Text(
              label,
              style: TorqueType.meta.copyWith(
                color: failedAt != null ? t.tellRed : t.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
