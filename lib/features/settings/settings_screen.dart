import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../live_tabs.dart';
import '../pro/paywall_screen.dart';
import 'diagnostics_log_screen.dart';
import 'privacy_screen.dart';

/// SPEC §5.6 — Settings on the Part B design system.
///
/// Every sub-screen it pushes is Part B too. There is no Account section:
/// the app has no account (§8.3), and the row that used to be here signed
/// anyone in as a hard-coded stranger. Nothing here mentions ads — there
/// are none.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final ent = context.watch<EntitlementProvider>();
    final live = context.watch<LiveSession>();

    return ListView(
      physics: adaptiveScrollPhysics(context),
      padding: const EdgeInsets.only(bottom: Space.x48),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x24,
            Space.gutter,
            Space.x8,
          ),
          child: Text(
            'Settings',
            style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
          ),
        ),
        const ListSection(title: 'Units'),
        ListRow(
          title: 'Distance',
          value: settings.distance.label,
          onTap: () => _pickDistance(context, settings),
        ),
        ListRow(
          title: 'Temperature',
          value: settings.temperature.label,
          onTap: () => _pickTemperature(context, settings),
        ),
        ListRow(
          title: 'Currency',
          subtitle: 'For new costs. A record keeps the one it was written in.',
          value: settings.currency,
          onTap: () => _pickCurrency(context, settings),
        ),
        const ListSection(title: 'Connection'),
        ListRow(
          title: 'Polling rate',
          value: settings.pollingRate,
          onTap: () => _pickPollingRate(context, settings),
        ),
        _SwitchRow(
          title: 'Auto-reconnect',
          value: settings.autoReconnect,
          onChanged: settings.setAutoReconnect,
        ),
        _SwitchRow(
          title: 'Keep the screen on',
          value: settings.keepScreenOn,
          onChanged: settings.setKeepScreenOn,
        ),
        _SwitchRow(
          title: 'Haptics',
          value: settings.haptics,
          onChanged: settings.setHaptics,
        ),
        const ListSection(title: 'Subscription'),
        ListRow(
          title: ent.isPro ? 'Torque Pro' : 'Torque Free',
          value: ent.isPro
              ? 'Unlimited gauges, vehicles and recording'
              : '6 gauges · 1 vehicle · 2-minute recordings',
        ),
        if (!ent.isPro)
          ListRow(title: 'Go Pro', onTap: () => openProPaywall(context)),
        ListRow(
          title: 'Restore purchases',
          onTap: () => _restorePurchases(context, ent),
        ),
        if (ent.isPro)
          ListRow(title: 'Manage subscription', onTap: ent.manageSubscription),
        const ListSection(title: 'Your data'),
        ListRow(title: 'Data & privacy', onTap: () => _openPrivacy(context)),
        ListRow(
          title: 'Diagnostics log',
          value: '${live.log.length} events',
          onTap: () => _openDiagnosticsLog(context, live),
        ),
      ],
    );
  }

  void _pickDistance(BuildContext context, SettingsProvider settings) =>
      _showChoiceSheet(
        context,
        title: 'Distance',
        options: [
          for (final u in DistanceUnit.values)
            _Choice(label: u.label, value: u),
        ],
        selected: settings.distance,
        onSelect: settings.setDistance,
      );

  void _pickCurrency(BuildContext context, SettingsProvider settings) =>
      _showChoiceSheet(
        context,
        title: 'Currency',
        options: [
          for (final c in {...SettingsProvider.currencies, settings.currency})
            _Choice(label: c, value: c),
        ],
        selected: settings.currency,
        onSelect: settings.setCurrency,
      );

  void _pickTemperature(BuildContext context, SettingsProvider settings) =>
      _showChoiceSheet(
        context,
        title: 'Temperature',
        options: [
          for (final u in TemperatureUnit.values)
            _Choice(label: u.label, value: u),
        ],
        selected: settings.temperature,
        onSelect: settings.setTemperature,
      );

  void _pickPollingRate(BuildContext context, SettingsProvider settings) =>
      _showChoiceSheet(
        context,
        title: 'Polling rate',
        options: [
          for (final r in SettingsProvider.pollingRates)
            _Choice(
              label: r,
              value: r,
              subtitle: r == 'Auto'
                  ? 'Drops the rate when the adapter falls behind'
                  : null,
            ),
        ],
        selected: settings.pollingRate,
        onSelect: settings.setPollingRate,
      );

  Future<void> _restorePurchases(
    BuildContext context,
    EntitlementProvider ent,
  ) async {
    final ok = await ent.restore();
    if (!context.mounted) return;
    await showAdaptiveAlert(
      context,
      title: ok ? 'Purchases restored' : 'Nothing to restore',
      message: ok
          ? 'Your previous purchases are active again.'
          : "We couldn't find any purchases to restore for this store account.",
      actions: [
        AdaptiveAlertAction(label: 'OK', onPressed: () {}, isDefault: true),
      ],
    );
  }

  void _openPrivacy(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const PrivacyScreen()),
    );
  }

  void _openDiagnosticsLog(BuildContext context, LiveSession live) {
    // No VIN handed in: the log masks every VIN it carried itself. Handing
    // in the primary's, captured here, missed every other car's.
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => DiagnosticsLogScreen(log: live.log),
      ),
    );
  }
}

void _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<_Choice<T>> options,
  required T selected,
  required ValueChanged<T> onSelect,
}) => showAdaptiveSheet<void>(
  context,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.x16,
      Space.gutter,
      Space.x24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TorqueType.titleMd.copyWith(
            color: sheetContext.tokens.inkPrimary,
          ),
        ),
        const SizedBox(height: Space.x16),
        for (final option in options)
          _SheetRadioRow<T>(
            value: option.value,
            label: option.label,
            subtitle: option.subtitle,
            selected: selected,
            onSelect: (v) {
              onSelect(v);
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    ),
  ),
);

class _Choice<T> {
  const _Choice({required this.label, required this.value, this.subtitle});
  final String label;
  final T value;
  final String? subtitle;
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      toggled: value,
      label: title,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.min),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hairline)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.gutter,
                  vertical: Space.x8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TorqueType.body.copyWith(color: t.inkPrimary),
                      ),
                    ),
                    const SizedBox(width: Space.x12),
                    AdaptiveSwitch(value: value, onChanged: onChanged),
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

class _SheetRadioRow<T> extends StatelessWidget {
  const _SheetRadioRow({
    required this.value,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onSelect,
  });

  final T value;
  final String label;
  final String? subtitle;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = value == selected;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      onTap: () => onSelect(value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => onSelect(value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Targets.min),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: active ? t.tellAmber : t.inkTertiary,
                    ),
                  ),
                  const SizedBox(width: Space.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TorqueType.body.copyWith(
                            color: t.inkPrimary,
                            fontWeight: active
                                ? FontWeight.w500
                                : FontWeight.w400,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
