import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/enums.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'icons.dart';

/// A brief confirmation strip, pushed in above the tab bar.
///
/// Used where an action completes locally and the user needs to know it
/// happened — a copy, an export, a saved record. It states what occurred; it
/// is never an "Oops!" and never a spinner.
class Toast {
  Toast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Tone tone = Tone.ink,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    dismiss();

    final entry = OverlayEntry(
      builder: (context) => _ToastBody(message: message, tone: tone),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message, required this.tone});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, String glyph) = switch (tone) {
      Tone.caution => (T.cautionText, T.cautionTint, Lu.triangleAlert),
      Tone.fault => (T.fault, T.faultTint, Lu.circleAlert),
      Tone.pass => (T.passText, T.passTint, Lu.circleCheck),
      Tone.ink => (T.accent800, T.accent100, Lu.info),
    };
    return Positioned(
      left: T.gutter,
      right: T.gutter,
      bottom: T.tabBarHeight + MediaQuery.paddingOf(context).bottom + 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Icn(glyph, size: 15, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Type.body15.copyWith(fontSize: 13.5, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copies text and confirms it, so "Copy" is not a control that appears to do
/// nothing.
Future<void> copyToClipboard(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  Toast.show(context, confirmation, tone: Tone.pass);
}

/// States plainly that something is handled outside the app.
///
/// The alternative — a button that silently does nothing — is worse than an
/// honest "this lives in iOS Settings", and this app's whole argument is that
/// it tells you what is actually happening.
void notImplementedHere(BuildContext context, String what) =>
    Toast.show(context, what, tone: Tone.ink);
