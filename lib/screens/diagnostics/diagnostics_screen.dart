import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/diagnostics_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';
import 'clear_codes_sheet.dart';
import 'code_detail_screen.dart';
import 'health_score_screen.dart';
import 'readiness_screen.dart';

/// Flow D — Diagnostics. D1 (no faults) and D2 (faults found) are the same
/// screen; which one you see is the answer, not a different feature.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    return dx.hasFaults ? const _FaultsFound() : const _NoFaults();
  }
}

Route<void> _route(Widget child) =>
    PageRouteBuilder(pageBuilder: (_, _, _) => child);

/// D1 — deliberately almost colourless. If a vehicle has no faults, this
/// screen contains no colour at all beyond a single green tick.
class _NoFaults extends StatelessWidget {
  const _NoFaults();

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    return Screen(
      title: 'Diagnostics',
      footer: ScreenFooter(
        children: [SecondaryButton('Scan again', onPressed: dx.rescan)],
      ),
      children: [
        const Icn(Lu.circleCheck, size: 40, color: T.passText),
        const SizedBox(height: 16),
        Text('No problems found', style: Type.subScreenTitle),
        const SizedBox(height: 8),
        Text(dx.faultSubline, style: Type.bodyMuted),
        const SizedBox(height: 22),
        ValueList([
          (label: 'Stored codes', value: '0'),
          (label: 'Pending codes', value: '0'),
          (label: 'Permanent codes', value: '0'),
          (label: 'Check engine light', value: 'Off'),
          (label: 'Health score', value: '${dx.healthScore}'),
          (
            label: 'Readiness monitors',
            value:
                '${dx.completeCount} / ${DiagnosticsProvider.monitors.length}',
          ),
        ]),
        const SizedBox(height: 20),
        // An empty result is a result. Say what was checked, not just that
        // nothing turned up.
        Text(
          'An empty result is a result. Nothing was hidden and nothing failed — '
          'the engine computer reported no faults on any of the three code lists.',
          style: Type.footnote,
        ),
        const SizedBox(height: 18),
        AppListRow(
          title: 'Readiness monitors',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const ReadinessScreen())),
        ),
        AppListRow(
          title: 'Health score',
          value: '${dx.healthScore}',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const HealthScoreScreen())),
        ),
        // Restoring the fault set keeps the D2 flow reachable after a clear.
        const SizedBox(height: 10),
        GhostButton(
          'Simulate a new fault',
          color: T.neutral700,
          onPressed: dx.restoreFaults,
        ),
      ],
    );
  }
}

/// D2 — faults found.
class _FaultsFound extends StatelessWidget {
  const _FaultsFound();

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    final d = context.watch<DashboardProvider>();

    return Screen(
      title: 'Diagnostics',
      footer: ScreenFooter(
        children: [
          // Reading and clearing codes are free forever, on every tier, with
          // no ad in the way — and no ad may render over this result.
          DestructiveButton(
            'Clear codes',
            onPressed: () => showClearCodesSheet(context),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            const Icn(Lu.triangleAlert, size: 26, color: T.fault),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Check Engine light is on',
                style: Type.subScreenTitle.copyWith(color: T.fault),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(dx.faultSubline, style: Type.bodyMuted),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const TelltaleChip('MIL on', tone: Tone.fault),
            TelltaleChip('${dx.pendingCount} pending', tone: Tone.caution),
            const TelltaleChip('Freeze frame saved', tone: Tone.ink),
          ],
        ),
        const SizedBox(height: 20),
        for (final code in dx.codes) _DtcRow(dtc: code),
        const SizedBox(height: 14),
        Text(
          'Ranked by severity — fix the misfire first.',
          style: Type.footnote,
        ),
        const SizedBox(height: 18),
        AppListRow(
          title: 'Readiness monitors',
          value: '${dx.completeCount} / ${DiagnosticsProvider.monitors.length}',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const ReadinessScreen())),
        ),
        AppListRow(
          title: 'Health score',
          value: '${dx.healthScore}',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const HealthScoreScreen())),
        ),
        if (!d.stationary) ...[
          const SizedBox(height: 16),
          // The clear-codes gate is stated before the user reaches for it.
          NoteBlock(
            'Clearing codes needs the car stationary. Speed reads '
            '${d.speedKmh?.toStringAsFixed(0) ?? '—'} km/h.',
            tone: Tone.caution,
          ),
        ],
      ],
    );
  }
}

/// A DTC row: a 3px severity bar, the code, its description, and its status in
/// words. Codes with no bundled definition say so — we never invent one.
class _DtcRow extends StatelessWidget {
  const _DtcRow({required this.dtc});

  final Dtc dtc;

  Color get _severityColor => switch (dtc.severity) {
    DtcSeverity.severe => T.fault,
    DtcSeverity.moderate => T.cautionBorder,
    DtcSeverity.minor => T.accent,
    DtcSeverity.unknown => T.neutral400,
  };

  /// The severity bar is a colour, and colour never carries meaning alone —
  /// so VoiceOver gets the severity as a word.
  String get _semanticLabel => [
    dtc.code,
    dtc.description,
    if (dtc.hasDefinition)
      switch (dtc.severity) {
        DtcSeverity.severe => 'severe',
        DtcSeverity.moderate => 'moderate',
        DtcSeverity.minor => 'minor',
        DtcSeverity.unknown => 'severity unknown',
      },
    if (dtc.hasDefinition) dtc.statusDetail ?? dtc.statusLine,
  ].join(', ');

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: dtc.hasDefinition,
    label: _semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: dtc.hasDefinition
          ? () => Navigator.of(context).push(_route(CodeDetailScreen(dtc: dtc)))
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: T.touchTargetFloor),
        decoration: const BoxDecoration(border: T.hairlineBottom),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 40, color: _severityColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dtc.code, style: Type.dtcCode),
                  const SizedBox(height: 4),
                  Text(
                    dtc.description,
                    style: dtc.hasDefinition
                        ? Type.rowPrimary
                        : Type.rowPrimary.copyWith(
                            color: T.neutral700,
                            fontStyle: FontStyle.italic,
                          ),
                  ),
                  if (dtc.hasDefinition) ...[
                    const SizedBox(height: 4),
                    Text(
                      dtc.statusDetail ?? dtc.statusLine,
                      style: Type.rowSecondary,
                    ),
                  ],
                ],
              ),
            ),
            if (dtc.hasDefinition) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icn(Lu.chevronRight, size: 16, color: T.neutral600),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
