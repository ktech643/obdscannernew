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
/// contextual.
Future<void> showLayoutsDoor(
  BuildContext context, {
  required VoidCallback? onUpgrade,
  required bool electric,
}) => showAdaptiveAlert(
  context,
  title: 'Named layouts are part of Pro',
  message: 'Pro keeps several layouts for each car. This one stays as it is.',
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

class _LayoutsSheet extends StatelessWidget {
  const _LayoutsSheet({
    required this.layouts,
    required this.onUpgrade,
    required this.electric,
    required this.host,
  });
  final DashboardLayoutController layouts;
  final VoidCallback? onUpgrade;
  final bool electric;

  /// The Dashboard's context: the door opens from it, after this sheet has
  /// gone.
  final BuildContext host;

  /// Closes this sheet before the door, so nothing under the paywall shows
  /// a plan frozen at the moment it opened.
  void _door(BuildContext context) {
    Navigator.of(context).pop();
    if (host.mounted) {
      showLayoutsDoor(host, onUpgrade: onUpgrade, electric: electric);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: layouts,
    builder: (context, _) {
      final c = layouts;
      final active = c.active;
      if (active == null) return const SizedBox.shrink();
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
                      trailing: c.isPro
                          ? null
                          : const TelltaleChip(tone: Tell.none, label: 'Pro'),
                      onTap: () {
                        final o = c.select(c.ref, l.id);
                        if (o == EditOutcome.needsPro) _door(context);
                      },
                    ),
            ListRow(
              title: 'New layout',
              subtitle: 'Starts as a copy of this one',
              trailing: c.isPro
                  ? null
                  : const TelltaleChip(tone: Tell.none, label: 'Pro'),
              onTap: () {
                if (!LayoutPlan.canHaveAnotherLayout(
                  c.layouts.length,
                  isPro: c.isPro,
                )) {
                  _door(context);
                  return;
                }
                showLayoutNameSheet(
                  context,
                  title: 'New layout',
                  initial: 'Layout ${c.layouts.length + 1}',
                  onSave: (name) => c.createLayout(c.ref, name),
                );
              },
            ),
            ListRow(
              title: 'Rename “${active.name}”',
              onTap: () => showLayoutNameSheet(
                context,
                title: 'Rename layout',
                initial: active.name,
                onSave: (name) => c.rename(c.ref, active.id, name),
              ),
            ),
            if (c.layouts.length > 1)
              Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: DestructiveButton(
                  label: 'Delete “${active.name}”',
                  onConfirmed: () => c.deleteLayout(c.ref, active.id),
                ),
              ),
            const SizedBox(height: Space.x16),
          ],
        ),
      );
    },
  );
}

/// A layout's name: 1–40 characters, the counter shown near the limit.
Future<void> showLayoutNameSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required EditOutcome Function(String name) onSave,
}) => showAdaptiveSheet<void>(
  context,
  builder: (_) => _NameSheet(title: title, initial: initial, onSave: onSave),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.initial,
    required this.onSave,
  });
  final String title;
  final String initial;
  final EditOutcome Function(String name) onSave;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final o = widget.onSave(_name.text);
    if (o == EditOutcome.invalidName) {
      setState(() => _error = 'A layout needs a name');
      return;
    }
    Navigator.of(context).pop();
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
