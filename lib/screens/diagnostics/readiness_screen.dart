import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/diagnostics_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';

/// D5 — readiness monitors. Three states, each with a glyph *and* a word:
/// Complete, Not complete, and Not supported by this vehicle. The third is the
/// one most apps collapse into the second, and it is not the same thing.
class ReadinessScreen extends StatelessWidget {
  const ReadinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    return Screen(
      title: 'Readiness monitors',
      backLabel: 'Diagnostics',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          SecondaryButton(
            'What completes a monitor?',
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const DriveCycleScreen(),
              ),
            ),
          ),
        ],
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${dx.completeCount}',
              style: Type.subScreenTitle.copyWith(fontSize: 34),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'of ${DiagnosticsProvider.monitors.length} complete · '
                '${dx.notSupportedCount} not supported',
                style: Type.bodyMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // The emissions verdict always carries its caveat. Rules genuinely
        // vary, and a confident wrong answer here costs someone a test fee.
        const NoteBlock(
          'Most US states allow one incomplete monitor at an emissions test. '
          'Rules vary by state and country — this is general guidance, not a '
          'guarantee.',
        ),
        SectionHeading(dx.monitorSetLabel),
        for (final m in DiagnosticsProvider.monitors) _MonitorRow(monitor: m),
        const SizedBox(height: 18),
        Text(
          'Monitors complete themselves as you drive. Exact drive cycles are '
          'manufacturer-specific — a mix of cold starts, steady 80 km/h '
          'cruising and town driving over a few days usually does it.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({required this.monitor});

  final ReadinessMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final (String word, Color color, String glyph) = switch (monitor.state) {
      MonitorState.complete => ('Complete', T.passText, Lu.circleCheck),
      MonitorState.notComplete => (
        'Not complete',
        T.cautionText,
        Lu.circleDashed,
      ),
      MonitorState.notSupported => ('Not supported', T.neutral700, Lu.minus),
    };
    return AppListRow(
      title: monitor.name,
      leading: Icn(glyph, size: 17, color: color),
      value: word.toUpperCase(),
      valueStyle: Type.chip(color),
      minHeight: 48,
    );
  }
}

/// I2 — the drive-cycle helper. General guidance only, and it says so: exact
/// cycles are manufacturer-specific and we do not have them.
class DriveCycleScreen extends StatelessWidget {
  const DriveCycleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dx = context.watch<DiagnosticsProvider>();
    return Screen(
      title: 'Drive cycle helper',
      backLabel: 'Readiness',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Text(
          'General guidance for completing readiness monitors. Exact drive '
          'cycles are manufacturer-specific — check your service manual for '
          'the precise one.',
          style: Type.bodyMuted,
        ),
        const SizedBox(height: 22),
        const NumberedFact(
          1,
          'Cold start',
          detail: 'Coolant below 50 °C, idle for 30–60 s before moving.',
        ),
        const NumberedFact(
          2,
          'Steady cruise',
          detail:
              '10 minutes at a constant 80 km/h — completes catalyst and '
              'O2 sensor.',
        ),
        const NumberedFact(
          3,
          'Stop-and-go',
          detail:
              'Town driving with several full stops — completes EVAP and '
              'secondary air.',
        ),
        const NumberedFact(
          4,
          'Highway pull',
          detail:
              'A steady incline or moderate acceleration at speed — '
              'completes EGR.',
        ),
        const SizedBox(height: 8),
        NoteBlock(
          'Catalyst and oxygen sensor remain — try the steady-cruise step above.',
          title:
              '${dx.completeCount} of ${DiagnosticsProvider.monitors.length} '
              'monitors complete',
        ),
      ],
    );
  }
}

/// I1 — Mode 06. Raw test results against ECU-reported limits, clearly framed
/// as advanced, and explicit where the adapter cannot answer.
class Mode06Screen extends StatelessWidget {
  const Mode06Screen({super.key});

  @override
  Widget build(BuildContext context) => Screen(
    backLabel: 'Diagnostics',
    onBack: () => Navigator.of(context).pop(),
    children: [
      Row(
        children: [
          Text('Mode 06', style: Type.screenTitle),
          const SizedBox(width: 10),
          const Badge('PRO'),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Raw on-board test results against ECU-reported limits. Advanced — '
        'most of these mean nothing without a service manual.',
        style: Type.bodyMuted,
      ),
      const SizedBox(height: 20),
      const _Mode06Header(),
      for (final t in DiagnosticsProvider.mode06) _Mode06Row(test: t),
      const SizedBox(height: 18),
      Text(
        "If the adapter or vehicle doesn't support Mode 06, we say so — "
        'never an empty table pretending to be a clean result.',
        style: Type.footnote,
      ),
    ],
  );
}

class _Mode06Header extends StatelessWidget {
  const _Mode06Header();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: T.hairlineBottom),
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text('TID / COMPONENT', style: Type.sectionHeading),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'VALUE',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'LIMIT',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            'RESULT',
            style: Type.sectionHeading,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

class _Mode06Row extends StatelessWidget {
  const _Mode06Row({required this.test});

  final Mode06Test test;

  @override
  Widget build(BuildContext context) {
    final unsupported = test.value == null;
    if (unsupported) {
      return Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: const BoxDecoration(border: T.hairlineBottom),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(test.name, style: Type.rowPrimary)),
            Text('Not supported by this adapter', style: Type.rowSecondary),
          ],
        ),
      );
    }
    final fail = test.result == 'FAIL';
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: const BoxDecoration(border: T.hairlineBottom),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(test.name, style: Type.rowPrimary)),
          Expanded(
            flex: 2,
            child: Text(
              test.value!,
              style: Type.inlineValue,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              test.limit!,
              style: Type.inlineValue.copyWith(color: T.neutral700),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                test.result!,
                style: Type.chip(fail ? T.fault : T.passText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// I3 — snapshot history. Written automatically before every clear, so the
/// data a mechanic needs survives the user's decision to erase it.
class SnapshotHistoryScreen extends StatelessWidget {
  const SnapshotHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Saved snapshots',
    backLabel: 'Garage',
    onBack: () => Navigator.of(context).pop(),
    children: [
      Text(
        'A full copy of codes, freeze frame and readiness is saved '
        'automatically every time you clear codes.',
        style: Type.bodyMuted,
      ),
      const SizedBox(height: 18),
      for (final s in DiagnosticsProvider.snapshots)
        AppListRow(
          title: s.summary,
          subtitle: '${s.when} · ${_km(s.odometerKm)} km',
          trailing: s.beforeClear
              ? const TelltaleChip('Before clear', tone: Tone.ink)
              : null,
          chevron: true,
          onTap: () {},
        ),
      const SizedBox(height: 16),
      Text(
        'Tap any snapshot to see the full codes, freeze frame and readiness '
        'state exactly as they were.',
        style: Type.footnote,
      ),
    ],
  );

  static String _km(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
