import 'dart:convert';

import 'package:flutter/material.dart' show IconButton, Icons, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design_system/design_system.dart';
import '../../providers/app_providers.dart';
import '../../protocol/protocol_log.dart';

/// Hands the rendered log to the platform share sheet as a `.txt` file.
typedef ShareLogText = Future<void> Function(String text);

Future<void> _shareWithSystem(String text) async {
  await Share.shareXFiles(
    [XFile.fromData(utf8.encode(text), mimeType: 'text/plain')],
    fileNameOverrides: const ['torque-diagnostics-log.txt'],
    subject: 'Torque diagnostics log',
  );
}

/// SPEC §10.4 — the in-app diagnostics log: "Last 500 protocol events …
/// Copy · Share `.txt` · Clear. VIN masked … unless the user opts in."
///
/// Shows the events exactly as they happened. **Every VIN the log carried
/// is masked** — in the raw frames, as hex, and in the decoded column —
/// unless the user turns on "Include the VIN". The VINs come from the log
/// itself ([ProtocolLog.knownVins]), read at render time: an earlier
/// version masked only the garage primary's VIN, captured when the screen
/// opened, and showed every other car's VIN in full.
class DiagnosticsLogScreen extends StatelessWidget {
  const DiagnosticsLogScreen({
    super.key,
    required this.log,
    this.share = _shareWithSystem,
  });

  final ProtocolLog log;

  /// Where Share sends the text. The system share sheet in the app; a
  /// capture in tests, so they can check exactly what would leave.
  final ShareLogText share;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = context.tokens;
    return Backlit(
      child: Scaffold(
        backgroundColor: t.surfaceDeep,
        appBar: AdaptiveTopBar(
          title: 'Diagnostics log',
          actions: [
            IconButton(
              tooltip: 'Share as a text file',
              icon: Icon(Icons.ios_share, color: t.inkPrimary),
              onPressed: () => share(_text(settings)),
            ),
            IconButton(
              tooltip: 'Copy the log',
              icon: Icon(Icons.copy_outlined, color: t.inkPrimary),
              onPressed: () => _copy(context, settings),
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
                    'connected. Nothing leaves this device unless you copy or '
                    'share it.',
              );
            }
            final mask = settings.maskVin ? log.mask : (String s) => s;
            return ListView.builder(
              physics: adaptiveScrollPhysics(context),
              padding: const EdgeInsets.all(Space.gutter),
              itemCount: events.length,
              itemBuilder: (context, i) =>
                  _EventRow(event: events[i], mask: mask),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x8,
              Space.gutter,
              Space.x16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IncludeVinRow(settings: settings),
                const SizedBox(height: Space.x8),
                Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _LogListenable(log),
                        builder: (context, _) => Text(
                          _status(log.length, log.dropped),
                          style: TorqueType.meta.copyWith(
                            color: t.inkSecondary,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _text(SettingsProvider settings) => log.render(
    includeVin: !settings.maskVin,
    header: 'Torque diagnostics log',
  );

  String _status(int length, int dropped) {
    if (dropped == 0) return '$length events';
    return '$length events · $dropped older ones not kept';
  }

  Future<void> _copy(BuildContext context, SettingsProvider settings) async {
    await Clipboard.setData(ClipboardData(text: _text(settings)));
    if (!context.mounted) return;
    await showAdaptiveAlert(
      context,
      title: 'Copied',
      message: settings.maskVin
          ? 'The log is on the clipboard, with the VIN masked. It stays on '
                'this device unless you paste it somewhere.'
          : 'The log is on the clipboard, and it includes the full VIN. It '
                'stays on this device unless you paste it somewhere.',
      actions: [
        AdaptiveAlertAction(label: 'OK', onPressed: () {}, isDefault: true),
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
        AdaptiveAlertAction(label: 'Keep', onPressed: () {}, isDefault: true),
        AdaptiveAlertAction(
          label: 'Clear',
          destructive: true,
          onPressed: () => log.clear(),
        ),
      ],
    );
  }
}

/// §10.4's opt-in, stated before anything is copied or shared rather than
/// after. Off — masked — by default.
class _IncludeVinRow extends StatelessWidget {
  const _IncludeVinRow({required this.settings});
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final include = !settings.maskVin;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Include the VIN',
                  style: TorqueType.body.copyWith(color: t.inkPrimary),
                ),
                Text(
                  include
                      ? 'Shown in full here and in anything you copy or share.'
                      : 'Masked here and in anything you copy or share.',
                  style: TorqueType.meta.copyWith(color: t.inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x12),
          AdaptiveSwitch(
            value: include,
            onChanged: (v) => settings.setMaskVin(!v),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.mask});
  final ProtocolEvent event;

  /// Applied to *both* columns. The decoded column of a Mode 09 reply is
  /// the VIN in plain text, and masking only the raw frames left it there
  /// in full for anyone the screen was shown to.
  final String Function(String) mask;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stamp = _stamp(event.at.toLocal());
    final arrow = event.outbound ? '→' : '←';
    final color = event.outbound ? t.inkSecondary : t.inkPrimary;
    final raw = mask(event.raw.replaceAll('\r', '⏎').replaceAll('\n', ''));
    final parsed = event.parsed == null ? null : mask(event.parsed!);
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
              Text(arrow, style: TorqueType.meta.copyWith(color: color)),
              const SizedBox(width: Space.x8),
              Expanded(
                child: Text(raw, style: TorqueType.meta.copyWith(color: color)),
              ),
            ],
          ),
          if (parsed != null || event.latencyMs != null)
            Padding(
              padding: const EdgeInsets.only(left: 96, top: Space.x4),
              child: Text(
                [
                  ?parsed,
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
