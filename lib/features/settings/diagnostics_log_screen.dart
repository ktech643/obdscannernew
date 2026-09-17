import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../providers/app_providers.dart';
import '../../protocol/protocol_log.dart';

/// SPEC §10.4 — the in-app diagnostics log.
///
/// Shows the last [ProtocolLog.capacity] events exactly as they happened,
/// with the VIN masked in both plain and hex form when the user has a
/// primary vehicle and has not turned masking off.
class DiagnosticsLogScreen extends StatelessWidget {
  const DiagnosticsLogScreen({super.key, required this.log, this.vin});

  final ProtocolLog log;

  /// The current vehicle's VIN, used only for masking. Null when there is
  /// no settled vehicle or the car never answered Mode 09.
  final String? vin;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Backlit(
      child: Scaffold(
        backgroundColor: context.tokens.surfaceDeep,
        appBar: AdaptiveTopBar(
          title: 'Diagnostics log',
          actions: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copy(context, settings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Icon(
                  Icons.copy_outlined,
                  color: context.tokens.inkPrimary,
                ),
              ),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _LogListenable(log),
          builder: (context, _) {
            final events = log.events;
            if (events.isEmpty) {
              return const EmptyStateView(
                title: 'No events yet',
                why:
                    'Commands and replies appear here once the adapter is '
                    'connected. Nothing is uploaded unless you copy it.',
              );
            }
            return ListView.builder(
              physics: adaptiveScrollPhysics(context),
              padding: const EdgeInsets.all(Space.gutter),
              itemCount: events.length,
              itemBuilder:
                  (context, i) => _EventRow(
                    event: events[i],
                    vin: vin,
                    mask: settings.maskVin,
                  ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x12,
              Space.gutter,
              Space.x16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _LogListenable(log),
                    builder:
                        (context, _) => Text(
                          _status(log.length, log.dropped),
                          style: TorqueType.meta.copyWith(
                            color: context.tokens.inkSecondary,
                          ),
                        ),
                  ),
                ),
                GhostButton(
                  label: 'Clear',
                  onPressed: () => _confirmClear(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(int length, int dropped) {
    if (dropped == 0) return '$length events';
    return '$length events · $dropped older ones not kept';
  }

  Future<void> _copy(BuildContext context, SettingsProvider settings) async {
    final text = log.render(
      vin: vin,
      includeVin: !settings.maskVin,
      header: 'Torque diagnostics log',
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    await showAdaptiveAlert(
      context,
      title: 'Copied',
      message:
          'The log is on the clipboard. It stays on this device unless you '
          'paste it somewhere.',
      actions: [
        AdaptiveAlertAction(
          label: 'OK',
          onPressed: () {},
          isDefault: true,
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    await showAdaptiveAlert(
      context,
      title: 'Clear the log?',
      message:
          'This removes every recorded event. It cannot be undone, but a '
          'running session will keep adding new events.',
      actions: [
        AdaptiveAlertAction(
          label: 'Keep',
          onPressed: () {},
          isDefault: true,
        ),
        AdaptiveAlertAction(
          label: 'Clear',
          destructive: true,
          onPressed: () => log.clear(),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.vin, required this.mask});
  final ProtocolEvent event;
  final String? vin;
  final bool mask;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stamp = _stamp(event.at.toLocal());
    final arrow = event.outbound ? '→' : '←';
    final color = event.outbound ? t.inkSecondary : t.inkPrimary;
    var raw = event.raw.replaceAll('\r', '⏎').replaceAll('\n', '');
    if (mask && vin != null) raw = ProtocolLog.maskVinIn(raw, vin!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  stamp,
                  style: TorqueType.meta.copyWith(color: t.inkTertiary),
                ),
              ),
              const SizedBox(width: Space.x8),
              Text(
                arrow,
                style: TorqueType.meta.copyWith(color: color),
              ),
              const SizedBox(width: Space.x8),
              Expanded(
                child: Text(
                  raw,
                  style: TorqueType.meta.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (event.parsed != null || event.latencyMs != null)
            Padding(
              padding: const EdgeInsets.only(left: 96, top: Space.x4),
              child: Text(
                [
                  if (event.parsed != null) event.parsed!,
                  if (event.latencyMs != null) '${event.latencyMs} ms',
                ].join(' · '),
                style: TorqueType.meta.copyWith(color: t.inkTertiary),
              ),
            ),
        ],
      ),
    );
  }

  String _stamp(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final d = (t.millisecond ~/ 100).toString();
    return '$h:$m:$s.$d';
  }
}

/// Bridges [ProtocolLog]'s listener API to a [Listenable] without making
/// the protocol layer depend on Flutter.
class _LogListenable implements Listenable {
  _LogListenable(this._log);
  final ProtocolLog _log;

  @override
  void addListener(VoidCallback listener) => _log.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _log.removeListener(listener);
}
