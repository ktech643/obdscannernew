import 'package:flutter/material.dart' show Icons, InputDecoration, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../spacing.dart';
import '../tokens.dart';
import '../typography.dart';

/// A labelled input on the Part B panel surface, with its error or caution
/// as a word and a glyph under it — never a red border alone (hard rule
/// 11). An error wins over a caution; a caution is advice, not a refusal.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.caution,
    this.keyboard,
    this.formatters,
    this.maxLength,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? error;
  final String? caution;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final int? maxLines;
  final TextCapitalization capitalization;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final note = error ?? caution;
    final tone = error != null ? Tell.red : Tell.amber;
    // One node per field: its label, its text and its note. Side by side
    // in a Row, two loose labels merged into one static node and left each
    // text field named by its hint, or by nothing once it held a value.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TorqueType.label.copyWith(color: t.inkSecondary),
            ),
            const SizedBox(height: Space.x4),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => TextField(
                controller: controller,
                keyboardType: keyboard,
                inputFormatters: formatters,
                maxLength: maxLength,
                maxLines: maxLines,
                minLines: maxLines == null ? 3 : null,
                textCapitalization: capitalization,
                textInputAction: textInputAction,
                autofocus: autofocus,
                onChanged: onChanged,
                style: TorqueType.body.copyWith(color: t.inkPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  // §9.8: "cap 5,000 with a counter". Hidden, a pasted note
                  // was cut to the limit without a word; it shows from 80 %.
                  counterText: _nearLimit ? null : '',
                  counterStyle: TorqueType.meta.copyWith(color: t.inkSecondary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.x12,
                    vertical: Space.x12,
                  ),
                ),
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: Space.x4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tone.glyph, size: 14, color: t.tell(tone)),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Text(
                      note,
                      style: TorqueType.meta.copyWith(color: t.tell(tone)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _nearLimit =>
      maxLength != null && controller.text.length >= maxLength! * 0.8;
}

/// One-of-several, as chips: the selected one filled, with a check — the
/// check is what says "selected" without colour (hard rule 11).
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.label,
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TorqueType.label.copyWith(color: t.inkSecondary)),
          const SizedBox(height: Space.x8),
          Wrap(
            spacing: Space.x8,
            runSpacing: Space.x8,
            children: [
              for (final v in values)
                Semantics(
                  button: true,
                  selected: v == value,
                  inMutuallyExclusiveGroup: true,
                  label: labelOf(v),
                  onTap: () => onChanged(v),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => onChanged(v),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: Targets.min,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: v == value ? t.inkPrimary : t.surfacePanel,
                            borderRadius: BorderRadius.circular(Radii.button),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x16,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (v == value) ...[
                                    Icon(
                                      Tell.green.glyph,
                                      size: 16,
                                      color: t.surfaceDeep,
                                    ),
                                    const SizedBox(width: Space.x4),
                                  ],
                                  Text(
                                    labelOf(v),
                                    style: TorqueType.label.copyWith(
                                      color: v == value
                                          ? t.surfaceDeep
                                          : t.inkPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A date shown as a field, changed with the platform's picker through
/// [onPick]. [onClear], when given, offers to remove it — for a date that
/// is optional. [format] turns the date into the words shown and read out.
class LabelledDateField extends StatelessWidget {
  const LabelledDateField({
    super.key,
    required this.label,
    required this.date,
    required this.format,
    required this.onPick,
    this.onClear,
    this.empty = 'No date',
  });

  final String label;
  final DateTime? date;
  final String Function(DateTime) format;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = date == null ? empty : format(date!);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The button's own label says it; read here too, it was "Date,
          // Date, 25 Sep 2026".
          ExcludeSemantics(
            child: Text(
              label,
              style: TorqueType.label.copyWith(color: t.inkSecondary),
            ),
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '$label, $shown',
                  onTap: onPick,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onPick,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: Targets.min,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.surfacePanel,
                            borderRadius: BorderRadius.circular(Radii.input),
                          ),
                          child: Padding(
                            // A filled TextField puts 4 more than its
                            // contentPadding before the text, so 16 here
                            // lines the date up with the fields above it.
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x16,
                              vertical: Space.x12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    shown,
                                    style: TorqueType.body.copyWith(
                                      // A text field's hint ink: tertiary
                                      // on the panel is 2.93:1.
                                      color: date == null
                                          ? t.inkSecondary
                                          : t.inkPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: t.inkSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: Space.x8),
                Semantics(
                  button: true,
                  label: 'Clear $label',
                  onTap: onClear,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: SizedBox(
                        width: Targets.min,
                        height: Targets.min,
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: t.inkSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
