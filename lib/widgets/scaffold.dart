import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'blueprint.dart';
import 'icons.dart';

/// Every screen in the app: status bar, optional title, scrolling body on the
/// screen gutter, and optional pinned footer.
///
/// The tab bar is supplied by the shell, not by individual screens.
class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.children,
    this.title,
    this.titleTrailing,
    this.gutter = T.gutter,
    this.footer,
    this.above,
    this.lowPower = false,
    this.backLabel,
    this.onBack,
    this.subtitle,
    this.scrollable = true,
  });

  final List<Widget> children;
  final String? title;
  final Widget? titleTrailing;
  final String? subtitle;
  final double gutter;

  /// Pinned below the scroll area — primary actions, ad banners.
  final Widget? footer;

  /// Pinned above the scroll area and below the status bar — connection
  /// strips and banners, which push content rather than overlaying it.
  final Widget? above;

  /// Tints the connection strip and trims polling when iOS is throttling.
  final bool lowPower;
  final String? backLabel;
  final VoidCallback? onBack;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (backLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: SizedBox(
                  height: T.touchTargetFloor,
                  child: Row(
                    children: [
                      const Icn(Lu.chevronLeft, size: 16, color: T.accent700),
                      const SizedBox(width: 4),
                      Text(
                        backLabel!,
                        style: Type.button(T.accent700, size: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (title != null)
            Padding(
              padding: EdgeInsets.only(
                top: backLabel == null ? 6 : 0,
                bottom: subtitle == null ? 16 : 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(title!, style: Type.screenTitle)),
                  ?titleTrailing,
                ],
              ),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(subtitle!, style: Type.bodyMuted),
            ),
          ...children,
          const SizedBox(height: 28),
        ],
      ),
    );

    return ColoredBox(
      color: T.bg,
      child: Column(
        children: [
          ?above,
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: body,
                  )
                : body,
          ),
          ?footer,
        ],
      ),
    );
  }
}

/// A pinned footer holding one or two actions on the screen gutter.
class ScreenFooter extends StatelessWidget {
  const ScreenFooter({
    super.key,
    required this.children,
    this.gutter = T.gutter,
    this.divider = true,
  });

  final List<Widget> children;
  final double gutter;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: divider ? T.hairlineTop : null),
    padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 14),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// A labelled text field. 4px radius — the ceiling in this system.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;

  /// A unit or currency marker inside the field, e.g. `km`, `£`.
  final String? suffix;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? helper;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: Type.formLabel.copyWith(letterSpacing: 0.9),
      ),
      const SizedBox(height: 7),
      Container(
        constraints: const BoxConstraints(minHeight: T.touchTargetFloor),
        decoration: BoxDecoration(
          border: Border.all(color: T.divider, width: 1),
          borderRadius: T.rMd,
          color: enabled ? null : T.neutral200,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: EditableTextField(
                controller: controller,
                hint: hint,
                obscure: obscure,
                keyboardType: keyboardType,
                maxLines: maxLines,
                onChanged: onChanged,
                enabled: enabled,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 8),
              Text(suffix!, style: Type.rowSecondary),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 6),
        Text(helper!, style: Type.footnote),
      ],
    ],
  );
}

/// Thin wrapper over the framework's text input so the whole system shares one
/// type ramp and cursor treatment.
class EditableTextField extends StatefulWidget {
  const EditableTextField({
    super.key,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<EditableTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: EditableText(
          controller: _controller,
          focusNode: _focus,
          style: Type.rowPrimary16,
          cursorColor: T.accent700,
          backgroundCursorColor: T.neutral300,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          readOnly: !widget.enabled,
          onChanged: widget.onChanged,
          selectionColor: T.accent300,
        ),
      ),
      if (_controller.text.isEmpty && widget.hint != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.hint!,
                style: Type.rowPrimary16.copyWith(color: T.neutral500),
              ),
            ),
          ),
        ),
    ],
  );
}

/// A modal sheet over a dimmed screen. 280 ms spring; instant under Reduce
/// Motion. Zero radius, like everything else.
Future<R?> showAppSheet<R>(BuildContext context, WidgetBuilder builder) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context, rootNavigator: true).push<R>(
    PageRouteBuilder<R>(
      opaque: false,
      barrierColor: T.neutral900.withValues(alpha: 0.55),
      barrierDismissible: true,
      transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 280),
      reverseTransitionDuration: Duration(milliseconds: reduceMotion ? 0 : 200),
      pageBuilder: (context, a, b) => SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: builder(context),
        ),
      ),
      transitionsBuilder: (context, a, b, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// The sheet body: hairline-topped, `--color-bg` ground, gutter padding.
class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.children,
    this.title,
    this.eyebrow,
  });

  final List<Widget> children;
  final String? title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(color: T.bg, border: T.hairlineTop),
    padding: const EdgeInsets.fromLTRB(T.gutter, 20, T.gutter, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: Type.sectionHeading),
          const SizedBox(height: 10),
        ],
        if (title != null) ...[
          Text(title!, style: Type.subScreenTitle),
          const SizedBox(height: 16),
        ],
        ...children,
      ],
    ),
  );
}

/// A vehicle photo placeholder. Real imagery has not been supplied, so this is
/// a square hairline box with the accent duotone wash rather than a
/// stock-photo stand-in.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.size = 72, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Blueprint(
    corners: false,
    width: size,
    height: size,
    fill: T.accent100,
    child: Center(
      child: Icn(Lu.image, size: size * 0.3, color: T.accent500),
    ),
  );
}
