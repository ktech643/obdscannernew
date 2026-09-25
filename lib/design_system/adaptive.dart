import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/platform_info.dart';
import 'spacing.dart';
import 'theme.dart';
import 'tokens.dart';
import 'typography.dart';

/// SPEC Part B.4 — one visual language, two chromes.
///
/// Everything that should feel native — nav bar, tab bar, switches, sheets,
/// alerts, date pickers, haptics, loading, overscroll — is decided here and
/// only here. Feature code never branches on platform (hard rule 12). A
/// test or a preview injects a [FakePlatform] through [AdaptiveScope].
class AdaptiveScope extends InheritedWidget {
  const AdaptiveScope({
    super.key,
    required this.platform,
    required super.child,
  });
  final PlatformInfo platform;

  static PlatformInfo of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveScope>()?.platform ??
      PlatformInfo.current;

  @override
  bool updateShouldNotify(AdaptiveScope old) => old.platform != platform;
}

bool _ios(BuildContext c) => AdaptiveScope.of(c).isIOS;

/// Puts a subtree on the Part B ground: the dark theme, the platform
/// scope, and the deep surface behind it.
///
/// **A pushed route is a sibling of the widget that pushed it, not a
/// descendant.** A screen reached by `Navigator.push` therefore inherits
/// the ambient `MaterialApp.theme`, not the theme of the screen it was
/// pushed from — so any screen that can be pushed wraps itself in this
/// rather than borrowing its parent's. Nesting is harmless: the inner one
/// simply re-applies what is already there.
///
/// It deliberately does *not* add a `SafeArea`. Insets belong to the
/// screen, and a second one here would double the padding on anything
/// already inside one.
class Backlit extends StatelessWidget {
  const Backlit({super.key, required this.child, this.tokens, this.platform});

  final Widget child;
  final TorqueTokens? tokens;

  /// Defaults to whatever scope is already in context, so a test's
  /// [FakePlatform] survives a push.
  final PlatformInfo? platform;

  @override
  Widget build(BuildContext context) {
    // High contrast is the system's word, so every Backlit answers it on its
    // own — the shell's ground and the tabs above it must agree, or the
    // strip under the status bar is a different colour from the screen.
    final t =
        tokens ??
        ((MediaQuery.maybeHighContrastOf(context) ?? false)
            ? TorqueTokens.highContrast
            : TorqueTokens.dark);
    // The status bar's icons follow the ground they sit on. Nothing else
    // in the app sets this, and the system default is dark icons — right
    // for the old light shell, near-invisible on this ground. An
    // AnnotatedRegion only claims the status bar where its own box sits
    // under it, so a Backlit tab that starts below the shell's light top
    // strip leaves that strip's dark icons alone, while a full-bleed
    // Backlit screen (onboarding) gets light ones.
    final overlay = relativeLuminance(t.surfaceDeep) < 0.5
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Theme(
        data: torqueTheme(tokens: t),
        child: AdaptiveScope(
          platform: platform ?? AdaptiveScope.of(context),
          child: ColoredBox(color: t.surfaceDeep, child: child),
        ),
      ),
    );
  }
}

class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_ios(context)) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: t.inkPrimary,
        thumbColor: value ? t.surfaceDeep : null,
      );
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

class AdaptiveLoading extends StatelessWidget {
  const AdaptiveLoading({super.key, this.size = 20, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.inkSecondary;
    if (_ios(context)) {
      return CupertinoActivityIndicator(radius: size / 2, color: c);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: c),
    );
  }
}

/// Bouncing on iOS, clamping on Android — the overscroll the user expects.
ScrollPhysics adaptiveScrollPhysics(BuildContext context) => _ios(context)
    ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
    : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

/// Haptics are a vocabulary: selection ticks, a fault thuds.
class AdaptiveHaptics {
  AdaptiveHaptics._();

  /// SPEC §5.6 "Haptics". Off means every call below is a no-op; the
  /// callers do not check, so there is exactly one place to get it right.
  static bool enabled = true;

  static Future<void> select() =>
      enabled ? HapticFeedback.selectionClick() : Future.value();
  static Future<void> light() =>
      enabled ? HapticFeedback.lightImpact() : Future.value();
  static Future<void> fault() =>
      enabled ? HapticFeedback.heavyImpact() : Future.value();
}

/// The top bar. Centred title and a chevron on iOS; leading title and an
/// arrow on Android. Never elevated on either.
class AdaptiveTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ios = _ios(context);
    return AppBar(
      title: Text(title),
      centerTitle: ios,
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.of(context).canPop()
              ? AdaptiveBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null),
      actions: actions,
    );
  }
}

class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: Icon(_ios(context) ? CupertinoIcons.chevron_back : Icons.arrow_back),
    onPressed: onPressed,
  );
}

class AdaptiveTab {
  const AdaptiveTab({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// The bottom tab bar. Tab change has no animation on either platform.
class AdaptiveTabBar extends StatelessWidget {
  const AdaptiveTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<AdaptiveTab> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  /// The labels do not grow with the user's text size. Five labels share
  /// the width of a phone: at 2.0 "Diagnostics" wrapped and the iOS item
  /// overflowed its fixed 46 pt (AC-16), and even Android's own clamp of
  /// 1.3 wraps "Diagnostics" on a 390 pt phone. The system tab bars on both
  /// platforms keep their labels at one size for the same reason; every
  /// label is still read in full by VoiceOver and TalkBack.
  static const maxTextScale = 1.0;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxTextScale,
    child: Builder(builder: _bar),
  );

  Widget _bar(BuildContext context) {
    final t = context.tokens;
    if (_ios(context)) {
      // Barlow, like every other word in Part B — the Cupertino default is
      // the system font, which is also why a test could not measure it.
      return CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          textTheme: CupertinoTheme.of(context).textTheme.copyWith(
            tabLabelTextStyle: TorqueType.meta.copyWith(fontSize: 10),
          ),
        ),
        child: CupertinoTabBar(
          backgroundColor: t.surfaceRaised,
          activeColor: t.inkPrimary,
          inactiveColor: t.inkSecondary,
          border: Border(top: BorderSide(color: t.hairline, width: 1)),
          currentIndex: index,
          onTap: onSelected,
          items: [
            for (final tab in tabs)
              BottomNavigationBarItem(
                icon: Icon(tab.icon),
                activeIcon: Icon(tab.selectedIcon ?? tab.icon),
                label: tab.label,
              ),
          ],
        ),
      );
    }
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      animationDuration: Duration.zero,
      destinations: [
        for (final tab in tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon ?? tab.icon),
            label: tab.label,
          ),
      ],
    );
  }
}

/// A sheet: radius 24 on top, 280 ms spring-ish present, surfaceRaised.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool useRootNavigator = false,
}) {
  final t = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
    // On the root navigator the sheet sits above the tab bar too, so
    // nothing outside it — a tab, Android back routed to a tab's
    // navigator — can take it away while it must stay.
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: t.surfaceRaised,
    barrierColor: t.surfaceDeep.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, Motion.sheet),
      curve: Curves.easeOutBack,
      reverseDuration: Motion.of(context, Motion.sheet),
    ),
    builder: builder,
  );
}

class AdaptiveAlertAction {
  const AdaptiveAlertAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.isDefault = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool destructive;
  final bool isDefault;
}

/// An alert names what happened and what to do (B.6). Cupertino dialog on
/// iOS, Material on Android; the same words on both.
Future<void> showAdaptiveAlert(
  BuildContext context, {
  required String title,
  required String message,
  required List<AdaptiveAlertAction> actions,
}) {
  final t = context.tokens;
  if (_ios(context)) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          for (final a in actions)
            CupertinoDialogAction(
              isDestructiveAction: a.destructive,
              isDefaultAction: a.isDefault,
              onPressed: () {
                Navigator.of(ctx).pop();
                a.onPressed();
              },
              child: Text(a.label),
            ),
        ],
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        for (final a in actions)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: a.destructive ? t.tellRed : t.tellAmber,
              minimumSize: const Size(Targets.min, Targets.min),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              a.onPressed();
            },
            child: Text(a.label),
          ),
      ],
    ),
  );
}

/// A date picker: the Cupertino wheel in a sheet on iOS, the Material
/// dialog on Android.
Future<DateTime?> showAdaptiveDatePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
}) async {
  // The pickers assert first <= initial <= last. A date saved from
  // elsewhere can sit outside the range a form offers; widen it rather
  // than crash on the way into an edit.
  var lo = first ?? DateTime(1990);
  var hi = last ?? DateTime.now().add(const Duration(days: 365 * 5));
  if (initial.isBefore(lo)) lo = initial;
  if (initial.isAfter(hi)) hi = initial;
  if (_ios(context)) {
    var picked = initial;
    final ok = await showAdaptiveSheet<bool>(
      context,
      builder: (ctx) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Done'),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                minimumDate: lo,
                maximumDate: hi,
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true ? picked : null;
  }
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: lo,
    lastDate: hi,
  );
}
