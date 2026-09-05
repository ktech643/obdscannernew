import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/platform/platform_info.dart';
import 'spacing.dart';
import 'tokens.dart';

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
  static Future<void> select() => HapticFeedback.selectionClick();
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> fault() => HapticFeedback.heavyImpact();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_ios(context)) {
      return CupertinoTabBar(
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
}) {
  final t = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
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
  final lo = first ?? DateTime(1990);
  final hi = last ?? DateTime.now().add(const Duration(days: 365 * 5));
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
