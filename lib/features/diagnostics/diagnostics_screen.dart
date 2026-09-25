import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../data/dtc_dictionary.dart';
import '../../design_system/design_system.dart';
import '../../protocol/dtc_decoder.dart';
import '../../protocol/readiness_decoder.dart';
import '../../session/health_score.dart';
import '../../session/obd_session.dart';
import '../session_banner.dart';
import '../../models/enums.dart' show DistanceUnit, TemperatureUnit;
import 'clear_codes_sheet.dart';
import 'freeze_frame_view.dart';
import 'code_detail_screen.dart';
import 'diagnostics_controller.dart';

/// The one-line answer at the top of the screen, with its tone.
class DiagnosticsHeadline {
  const DiagnosticsHeadline(this.title, this.tone, {this.note});
  final String title;
  final Tell tone;

  /// The qualification, when there is one. Never decoration: it exists to
  /// stop the title being read as more than it is.
  final String? note;
}

/// SPEC §5.4's table, reproduced literally, plus the rows it does not
/// cover — because real cars produce all of them.
///
/// The count is of **distinct codes**. A code can be stored and permanent
/// at once, which is two true facts about one fault; counting it twice in
/// the headline would overstate what is wrong with the car.
DiagnosticsHeadline headlineFor(DtcReadResult r) {
  final codes = r.all.map((d) => d.code).toSet();
  final n = codes.length;
  final plural = n == 1 ? '1 code' : '$n codes';

  // An unanswered mode means codes may exist that were never seen. Nothing
  // green may be said until every mode has answered (hard rule: an empty
  // list and an unasked question are not the same).
  if (n == 0 && !r.complete) {
    return const DiagnosticsHeadline(
      'Scan incomplete',
      Tell.amber,
      note:
          'No codes came back, but not every mode answered — so this is '
          'not a clean result.',
    );
  }

  if (r.milOn == true) {
    return DiagnosticsHeadline(
      n == 0
          ? 'Check Engine light is on — no codes stored'
          : 'Check Engine light is on — $plural',
      Tell.red,
      note: n == 0
          ? 'The light is lit but the engine ECU reported no codes. The '
                'fault may sit in a module this scan does not reach.'
          : null,
    );
  }

  if (n == 0) {
    return DiagnosticsHeadline(
      r.milOn == null ? 'No codes found' : 'No problems found',
      Tell.green,
      note: r.milOn == null
          ? 'The car did not report the warning light, so this covers the '
                'codes only.'
          : null,
    );
  }

  if (r.stored.isEmpty && r.permanent.isEmpty) {
    final count = r.pending.map((d) => d.code).toSet().length;
    return DiagnosticsHeadline(
      '${count == 1 ? '1 pending code' : '$count pending codes'} — '
      'being monitored',
      Tell.amber,
    );
  }

  return DiagnosticsHeadline(
    '$plural found',
    Tell.amber,
    note: r.milOn == false
        ? 'The Check Engine light is off.'
        : 'The car did not report the Check Engine light.',
  );
}

/// The tone a code's row carries.
///
/// Severity comes from the dictionary when the code is in it. When it is
/// not, the code's *mode* decides — a stored code is confirmed by the ECU
/// and is treated as a fault rather than as harmless, because "we have no
/// rating" is not evidence of mildness (hard rule 7).
Tell toneFor(RawDtc dtc, DtcDefinition? def) {
  if (dtc.mode == DtcMode.pending) return Tell.amber;
  return switch (def?.severity) {
    DtcSeverity.low => Tell.amber,
    DtcSeverity.medium => Tell.amber,
    _ => Tell.red,
  };
}

/// SPEC §5.4 — Diagnostics.
///
/// One screen answers one question: is anything wrong with this car. The
/// codes, the readiness monitors and the health score are all working out
/// on the page, shown so the answer can be checked rather than believed.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.controller,
    this.onConnect,
    this.adapterName,
    this.distance = DistanceUnit.km,
    this.temperature = TemperatureUnit.celsius,
  });

  final DiagnosticsController controller;

  /// Opens the Connect screen from the banner and the offline state.
  final VoidCallback? onConnect;
  final String? adapterName;

  /// SPEC §5.6 — the user's units: the speed in the clear gate, and the
  /// freeze frame's readings.
  final DistanceUnit distance;
  final TemperatureUnit temperature;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  DiagnosticsController get _c => widget.controller;
  ObdSession get _session => _c.session;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _session.addListener(_onChange);
    // §9.5: a clear that never finished is the first thing this screen
    // has to know about, before anything else is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.refreshUnreconciled();
    });
  }

  @override
  void didUpdateWidget(DiagnosticsScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      old.controller.session.removeListener(_onChange);
      _c.addListener(_onChange);
      _session.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _session.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openClearSheet() async {
    final outcome = await showAdaptiveSheet<ClearResult>(
      context,
      builder: (_) => ClearCodesSheet(controller: _c, distance: widget.distance),
    );
    if (outcome != null) AdaptiveHaptics.light();
  }

  Future<void> _openDetail(RawDtc dtc) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => CodeDetailScreen(
        dtc: dtc,
        definition: _c.definitionFor(dtc.code),
        alsoIn: _c.result == null
            ? const []
            : _c.result!.all
                  .where((d) => d.code == dtc.code && d.mode != dtc.mode)
                  .map((d) => d.mode)
                  .toList(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BannerHost(
      banner: bannerFor(
        _session,
        onConnect: widget.onConnect,
        adapterName: widget.adapterName,
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    // B.6 Loading — the scan's real steps, named as they happen (§5.4).
    if (_c.phase == ScanPhase.running) {
      return _Scanning(controller: _c);
    }

    final result = _c.result;

    if (result == null) {
      if (!_session.isLive) {
        // B.6 Offline/Error — never a network error; the app is whole
        // without a connection, it just cannot ask the car anything.
        return EmptyStateView(
          title: 'Not connected',
          why:
              'A scan reads the codes out of the car, so it needs the '
              'adapter plugged in and the ignition on.',
          icon: Icons.link_off,
          actionLabel: widget.onConnect == null ? null : 'Choose an adapter',
          onAction: widget.onConnect,
        );
      }
      return EmptyStateView(
        title: 'Ready to scan',
        why:
            'Reads stored, pending and permanent codes, the warning light '
            'and the readiness monitors. Takes a few seconds.',
        icon: Icons.search,
        actionLabel: 'Scan now',
        onAction: _c.busy ? null : _c.scan,
      );
    }

    return _Result(
      distance: widget.distance,
      temperature: widget.temperature,
      controller: _c,
      result: result,
      onScan: _c.busy || !_session.isLive ? null : _c.scan,
      onClear: _c.busy || !_session.isLive ? null : _openClearSheet,
      onOpenCode: _openDetail,
    );
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning({required this.controller});
  final DiagnosticsController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanning',
            style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
          ),
          const SizedBox(height: Space.x4),
          Text(
            controller.stepLabel ?? '',
            style: TorqueType.body.copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: Space.x24),
          StepProgress(
            steps: [for (final s in ScanStep.all) s.label],
            current: controller.stepIndex,
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.controller,
    required this.result,
    required this.onScan,
    required this.onClear,
    required this.onOpenCode,
    required this.distance,
    required this.temperature,
  });

  final DiagnosticsController controller;
  final DtcReadResult result;
  final DistanceUnit distance;
  final TemperatureUnit temperature;
  final VoidCallback? onScan;
  final VoidCallback? onClear;
  final void Function(RawDtc) onOpenCode;

  @override
  Widget build(BuildContext context) {
    final headline = headlineFor(result);
    final codes = [...result.stored, ...result.pending, ...result.permanent];
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.x48),
      children: [
        if (controller.unreconciled.isNotEmpty)
          _UnverifiedClear(controller: controller),
        _Headline(headline: headline, scannedAt: controller.scannedAt),
        if (!result.complete) _Incomplete(modes: result.failedModes),
        if (controller.lastClear != null)
          _ClearOutcome(
            outcome: controller.lastClear!,
            surviving: result.permanent,
          ),
        if (codes.isNotEmpty) ...[
          const SizedBox(height: Space.x8),
          for (final dtc in codes)
            DtcRow(
              code: dtc.code,
              description: DtcText.describe(
                dtc,
                controller.definitionFor(dtc.code),
              ),
              severity: toneFor(dtc, controller.definitionFor(dtc.code)),
              status: DtcText.statusWord(dtc.mode),
              onTap: () => onOpenCode(dtc),
            ),
        ],
        if (controller.freezeFrame != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x24,
              Space.gutter,
              0,
            ),
            child: FreezeFrameView(
              frame: controller.freezeFrame!,
              distance: distance,
              temperature: temperature,
              note: controller.recording
                  ? FreezeFrameNote.kept
                  : FreezeFrameNote.notKept,
            ),
          ),
        if (result.readiness != null) _Readiness(report: result.readiness!),
        if (controller.health != null) _Health(score: controller.health!),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            children: [
              PrimaryButton(label: 'Scan again', onPressed: onScan),
              // Clearing is deliberately the quiet action. It erases the
              // evidence a mechanic would use and fixes nothing, so it
              // never competes with reading the car again for the thumb.
              if (result.stored.isNotEmpty || result.pending.isNotEmpty) ...[
                const SizedBox(height: Space.x8),
                GhostButton(label: 'Clear codes', onPressed: onClear),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.headline, required this.scannedAt});
  final DiagnosticsHeadline headline;
  final DateTime? scannedAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = headline.tone == Tell.none
        ? t.inkPrimary
        : t.tell(headline.tone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x24,
        Space.gutter,
        Space.x16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(headline.tone.glyph, size: 28, color: color),
          const SizedBox(height: Space.x12),
          Text(
            headline.title,
            style: TorqueType.titleLg.copyWith(color: t.inkPrimary),
          ),
          if (headline.note != null) ...[
            const SizedBox(height: Space.x8),
            Text(
              headline.note!,
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            ),
          ],
          if (scannedAt != null) ...[
            const SizedBox(height: Space.x8),
            Text(
              'Read ${_timeOfDay(scannedAt!)}',
              style: TorqueType.meta.copyWith(color: t.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

String _timeOfDay(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// A mode that did not answer. Named, because "no pending codes" and "we
/// could not ask about pending codes" are different answers.
class _Incomplete extends StatelessWidget {
  const _Incomplete({required this.modes});
  final Set<String> modes;

  static String _name(String mode) => switch (mode) {
    '03' => 'stored codes',
    '07' => 'pending codes',
    '0A' => 'permanent codes',
    _ => 'the warning light and monitors',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final names = modes.map(_name).toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: RaisedSurface(
        padding: const EdgeInsets.all(Space.x16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Tell.amber.glyph, size: 18, color: t.tellAmber),
            const SizedBox(width: Space.x12),
            Expanded(
              child: Text(
                'The car did not answer about ${_join(names)}. '
                'Those are unknown, not clear.',
                style: TorqueType.body.copyWith(color: t.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _join(List<String> parts) => switch (parts.length) {
  0 => '',
  1 => parts.first,
  2 => '${parts[0]} and ${parts[1]}',
  _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
};

/// §9.5 — a `beforeClear` snapshot still pending. The app died, or the
/// link dropped, between writing it and verifying the clear.
class _UnverifiedClear extends StatelessWidget {
  const _UnverifiedClear({required this.controller});
  final DiagnosticsController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final live = controller.session.isLive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x16,
        Space.gutter,
        0,
      ),
      child: RaisedSurface(
        padding: const EdgeInsets.all(Space.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Tell.amber.glyph, size: 18, color: t.tellAmber),
                const SizedBox(width: Space.x8),
                Text(
                  'A clear was never verified',
                  style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
                ),
              ],
            ),
            const SizedBox(height: Space.x8),
            Text(
              'Codes were sent to be cleared, but the app never got to '
              'read them back. They may be gone, or they may not. The '
              'codes from before that clear are saved.',
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            ),
            const SizedBox(height: Space.x16),
            PrimaryButton(
              label: live ? 'Check now' : 'Connect to check',
              expand: false,
              onPressed: live && !controller.busy ? controller.reconcile : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the last clear actually did — never "cleared" on its own.
class _ClearOutcome extends StatelessWidget {
  const _ClearOutcome({required this.outcome, this.surviving = const []});
  final ClearResult outcome;

  /// Permanent codes still present in the verifying re-read. `cleared`
  /// means no stored and no pending codes — permanent ones are *expected*
  /// to survive — so this line must not claim the car came back empty
  /// while those codes are listed directly beneath it.
  final List<RawDtc> surviving;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (String text, Tell tone) = switch (outcome) {
      ClearResult.cleared when surviving.isNotEmpty => (
        'Stored and pending codes cleared. '
            '${surviving.map((d) => d.code).join(', ')} '
            '${surviving.length == 1 ? 'is permanent and stays' : 'are permanent and stay'} '
            'until the ECU releases '
            '${surviving.length == 1 ? 'it' : 'them'}.',
        Tell.green,
      ),
      ClearResult.cleared => (
        'Codes cleared, and the re-read came back empty.',
        Tell.green,
      ),
      ClearResult.codesReturned => (
        'The clear was accepted, but the codes came straight back — the '
        'fault is still happening.',
        Tell.amber,
      ),
      ClearResult.refused => (
        'The car refused to clear. Turn the engine off and the ignition '
        'to ON, then try again.',
        Tell.amber,
      ),
      ClearResult.interrupted => (
        'The clear could not be verified. The codes above are the last '
        'confirmed reading.',
        Tell.amber,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.x16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.glyph, size: 18, color: t.tell(tone)),
          const SizedBox(width: Space.x12),
          Expanded(
            child: Text(
              text,
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// §4.7 — three states, never two. "Not supported by this car" is not
/// "not finished", and merging them tells an owner their car will fail an
/// emissions test when it will not.
class _Readiness extends StatelessWidget {
  const _Readiness({required this.report});
  final ReadinessReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x24,
        Space.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Readiness monitors',
            style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
          ),
          const SizedBox(height: Space.x4),
          Text(
            '${report.completeCount} of ${report.supportedCount} finished'
            '${report.ignitionType == IgnitionType.compression ? ' · diesel monitor set' : ''}',
            style: TorqueType.body.copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: Space.x12),
          ValueList(
            rows: [
              for (final m in report.monitors)
                switch (m.state) {
                  MonitorState.complete => ValueRow(
                    m.name,
                    'Complete',
                    tone: Tell.green,
                  ),
                  MonitorState.notComplete => ValueRow(
                    m.name,
                    'Not finished',
                    tone: Tell.amber,
                  ),
                  MonitorState.notSupported => ValueRow(
                    m.name,
                    null,
                    reason: 'Not supported by this car',
                  ),
                },
            ],
          ),
          const SizedBox(height: Space.x8),
          Text(
            report.likelyPassesEmissions
                ? 'Usually enough to take an emissions test — but the '
                      'rules vary by state and country.'
                : 'An emissions test would usually be refused in this '
                      'state — but the rules vary by state and country.',
            style: TorqueType.meta.copyWith(color: t.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// §5.4 — the score, **always with its full breakdown**. The number on its
/// own would be indistinguishable from one that was made up.
class _Health extends StatelessWidget {
  const _Health({required this.score});
  final HealthScore score;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tone = score.value >= 85
        ? Tell.green
        : score.value >= 60
        ? Tell.amber
        : Tell.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x24,
        Space.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health score',
            style: TorqueType.titleMd.copyWith(color: t.inkPrimary),
          ),
          const SizedBox(height: Space.x8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${score.value}',
                style: TorqueType.readoutLg.copyWith(color: t.tell(tone)),
              ),
              const SizedBox(width: Space.x4),
              Text(
                '/ 100',
                style: TorqueType.body.copyWith(color: t.inkTertiary),
              ),
              const SizedBox(width: Space.x8),
              TelltaleChip(tone: tone, label: tone.word),
            ],
          ),
          const SizedBox(height: Space.x12),
          if (score.deductions.isEmpty)
            Text(
              'Nothing was deducted.',
              style: TorqueType.body.copyWith(color: t.inkSecondary),
            )
          else
            ValueList(
              rows: [
                for (final d in score.deductions)
                  ValueRow(d.reason, '−${d.points}'),
              ],
            ),
          if (score.notMeasured.isNotEmpty) ...[
            const SizedBox(height: Space.x12),
            Text(
              'Not counted, because it could not be read:',
              style: TorqueType.meta.copyWith(color: t.inkTertiary),
            ),
            const SizedBox(height: Space.x4),
            for (final gap in score.notMeasured)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x4),
                child: Text(
                  '· $gap',
                  style: TorqueType.meta.copyWith(color: t.inkSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
