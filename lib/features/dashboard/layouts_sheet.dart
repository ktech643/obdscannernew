import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';
import 'dashboard_layout.dart';
import 'layout_controller.dart';

/// §7.3's "7th gauge tile": contextual, only from a tap on Add at the cap.
/// Never "See Pro" for an electric car (§9.4).
Future<void> showSeventhTileDoor(
  BuildContext context, {
  required VoidCallback? onUpgrade,
  required bool electric,
  int unreported = 0,
}) {
  final hint = unreported == 0
      ? ''
      : ' $unreported of them ${unreported == 1 ? "isn't" : "aren't"} '
            'reported by this car — tap one to show something else.';
  return showAdaptiveAlert(
    context,
    title: '${LayoutPlan.freeTiles} gauges on the free plan',
    message: electric
        ? 'The free plan shows ${LayoutPlan.freeTiles} gauges.$hint'
        : 'More gauges are part of Pro. Your gauges stay as they are.$hint',
    actions: [
      AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
      if (onUpgrade != null && !electric)
        AdaptiveAlertAction(
          label: 'See Pro',
          isDefault: true,
          onPressed: onUpgrade,
        ),
    ],
  );
}

/// The second layout — the same §7.2 row as the seventh tile, and just as
/// contextual. An electric car is told the plan, never sold it (§9.4).
Future<void> showLayoutsDoor(
  BuildContext context, {
  required VoidCallback? onUpgrade,
  required bool electric,
}) => showAdaptiveAlert(
  context,
  title: electric
      ? 'One layout on the free plan'
      : 'Named layouts are part of Pro',
  message: electric
      ? 'The free plan keeps one layout for each car. This one stays as it is.'
      : 'Pro keeps several layouts for each car. This one stays as it is.',
  actions: [
    AdaptiveAlertAction(label: 'Not now', onPressed: () {}),
    if (onUpgrade != null && !electric)
      AdaptiveAlertAction(
        label: 'See Pro',
        isDefault: true,
        onPressed: onUpgrade,
      ),
  ],
);

/// The layouts of the car on screen: which is shown, switch, new, rename,
/// delete. It listens to the controller, so the plan is always the live one.
Future<void> showLayoutsSheet(
  BuildContext context, {
  required DashboardLayoutController layouts,
  required VoidCallback? onUpgrade,
  required bool electric,
}) => showAdaptiveSheet<void>(
  context,
  builder: (_) => _LayoutsSheet(
    layouts: layouts,
    onUpgrade: onUpgrade,
    electric: electric,
    host: context,
  ),
);

class _LayoutsSheet extends StatefulWidget {
  const _LayoutsSheet({
    required this.layouts,
    required this.onUpgrade,
    required this.electric,
    required this.host,
  });
  final DashboardLayoutController layouts;
  final VoidCallback? onUpgrade;
  final bool electric;

  /// The Dashboard's context: doors and the name sheet open from it, after
  /// this sheet has gone.
  final BuildContext host;

  @override
  State<_LayoutsSheet> createState() => _LayoutsSheetState();
}

class _LayoutsSheetState extends State<_LayoutsSheet> {
  DashboardLayoutController get c => widget.layouts;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_watch);
  }

  @override
  void dispose() {
    c.removeListener(_watch);
    super.dispose();
  }

  /// Gone when the car starts moving (§8.4 — delete and new switched the
  /// grid at speed from a sheet opened while parked) or is not this car
  /// any more: a new car empties the layouts until they are read. After
  /// the frame: a listener outside the Dashboard must not be rebuilt in
  /// the middle of its build.
  void _watch() {
    if (_closing || !mounted) return;
    if (c.gated || c.active == null) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Closes this sheet before the door, so nothing under the paywall shows
  /// a plan frozen at the moment it opened.
  void _door() {
    Navigator.of(context).pop();
    if (widget.host.mounted) {
      showLayoutsDoor(
        widget.host,
        onUpgrade: widget.onUpgrade,
        electric: widget.electric,
      );
    }
  }

  void _name({
    required String title,
    required String initial,
    required EditOutcome Function(String name) onSave,
  }) => showLayoutNameSheet(
    context,
    title: title,
    initial: initial,
    onSave: onSave,
    onNeedsPro: _door,
    layouts: c,
  );

  @override
  Widget build(BuildContext context) {
    final active = c.active;
    if (active == null) return const SizedBox.shrink();
    // The lock is the §7.3 door's mark — shown, and said — but never on an
    // electric car (§9.4).
    final locked = !c.isPro && !widget.electric;
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        physics: adaptiveScrollPhysics(context),
        children: [
          const ListSection(title: 'Layouts'),
          for (final l in c.layouts)
            l.id == active.id
                ? ListRow(title: l.name, value: 'Showing')
                : ListRow(
                    title: l.name,
                    trailing: locked
                        ? const TelltaleChip(tone: Tell.none, label: 'Pro')
                        : null,
                    trailingLabel: locked ? 'Pro' : null,
                    onTap: () {
                      if (c.select(c.ref, l.id) == EditOutcome.needsPro) {
                        _door();
                      }
                    },
                  ),
          ListRow(
            title: 'New layout',
            subtitle: 'Starts as a copy of this one',
            trailing: locked
                ? const TelltaleChip(tone: Tell.none, label: 'Pro')
                : null,
            trailingLabel: locked ? 'Pro' : null,
            onTap: () {
              if (!LayoutPlan.canHaveAnotherLayout(
                c.layouts.length,
                isPro: c.isPro,
              )) {
                _door();
                return;
              }
              _name(
                title: 'New layout',
                initial: 'Layout ${c.layouts.length + 1}',
                onSave: (name) => c.createLayout(c.ref, name),
              );
            },
          ),
          ListRow(
            title: 'Rename “${active.name}”',
            onTap: () => _name(
              title: 'Rename layout',
              initial: active.name,
              onSave: (name) => c.rename(c.ref, active.id, name),
            ),
          ),
          if (c.layouts.length > 1)
            Padding(
              padding: const EdgeInsets.all(Space.gutter),
              // Keyed by the layout: armed, then another layout chosen, the
              // same button — still armed — deleted the new one.
              child: DestructiveButton(
                key: ValueKey('delete ${active.id}'),
                label: 'Delete “${active.name}”',
                confirmLabel: 'Tap again to delete “${active.name}”',
                onConfirmed: () => c.deleteLayout(c.ref, active.id),
              ),
            ),
          const SizedBox(height: Space.x16),
        ],
      ),
    );
  }
}

/// A layout's name: 1–40 characters, the counter shown near the limit.
Future<void> showLayoutNameSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required EditOutcome Function(String name) onSave,
  VoidCallback? onNeedsPro,
  DashboardLayoutController? layouts,
}) => showAdaptiveSheet<void>(
  context,
  builder: (_) => _NameSheet(
    title: title,
    initial: initial,
    onSave: onSave,
    onNeedsPro: onNeedsPro,
    layouts: layouts,
  ),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.initial,
    required this.onSave,
    this.onNeedsPro,
    this.layouts,
  });
  final String title;
  final String initial;
  final EditOutcome Function(String name) onSave;

  /// The plan changed while the sheet was open: the door, not a silent
  /// close that lost what was typed.
  final VoidCallback? onNeedsPro;

  /// Heard for §8.4: no typing a name above 5 km/h.
  final DashboardLayoutController? layouts;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  late final LayoutRef? _ref = widget.layouts?.ref;
  String? _error;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.layouts?.addListener(_watch);
  }

  /// Gone when the car starts moving, or when the layout it names is not
  /// the one shown any more — another car chosen in the Garage while it
  /// waited: Save was refused as stale and the sheet closed without a word.
  void _watch() {
    final c = widget.layouts;
    if (_closing || !mounted || c == null) return;
    if (!c.gated && c.ref == _ref) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.layouts?.removeListener(_watch);
    _name.dispose();
    super.dispose();
  }

  /// Every refusal says why; only a save that happened closes quietly.
  void _save() {
    final o = widget.onSave(_name.text);
    final why = switch (o) {
      EditOutcome.invalidName => 'A layout needs a name',
      EditOutcome.nameTooLong =>
        'Keep it to ${DashboardLayout.nameMax} characters — an emoji counts '
            'as two',
      EditOutcome.moving => 'Not while the car is moving',
      _ => null,
    };
    if (why != null) {
      setState(() => _error = why);
      return;
    }
    Navigator.of(context).pop();
    if (o == EditOutcome.needsPro) widget.onNeedsPro?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x24,
          Space.gutter,
          Space.x16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: Space.x16),
            LabelledField(
              label: 'Layout name',
              controller: _name,
              maxLength: DashboardLayout.nameMax,
              autofocus: true,
              error: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            PrimaryButton(label: 'Save', icon: Icons.check, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
