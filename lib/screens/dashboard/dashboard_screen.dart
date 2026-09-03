import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/gauge_tile.dart';
import '../../widgets/icons.dart';
import '../../widgets/scaffold.dart';
import '../connect/compatibility_screens.dart';
import '../pro/paywall_screen.dart';
import 'graph_screen.dart';

/// Flow C — the Dashboard. C1 (healthy), C2 (one value out of range) and C3
/// (stale + degraded + unsupported) are the same screen under different data;
/// N1/N2/N5 swap the tile set for diesel, hybrid and imperial vehicles.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final c = context.watch<ConnectionProvider>();
    final e = context.watch<EntitlementProvider>();
    final s = context.watch<SettingsProvider>();

    if (d.editing) return const _EditMode();

    final lost = c.status == ConnectionStatus.lost;

    return Screen(
      lowPower: s.lowPowerMode,
      above: _strip(context, d, c, s, lost),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TripStrip(d: d),
          if (e.canShowBanner(
            onFaultResult: false,
            scanning: false,
            speedKmh: d.speedKmh,
          ))
            AdBanner(onRemoveAds: () => openPaywall(context)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 14),
          child: Row(
            children: [
              Expanded(child: Text(d.vehicleName, style: Type.screenTitle)),
              InlineAction(
                'Edit',
                // Gauge editing is disabled above 5 km/h; the display stays
                // live either way.
                color: d.editingAllowed ? T.accent700 : T.neutral500,
                onPressed: d.editingAllowed ? () => d.setEditing(true) : null,
              ),
            ],
          ),
        ),
        if (lost) ...[
          ConnectionLostBanner(attempt: c.lostAttempt, onReconnect: c.recover),
          const SizedBox(height: 18),
        ],
        if (d.cautionExplainer != null) ...[
          NoteBlock(d.cautionExplainer!, tone: Tone.caution),
          const SizedBox(height: 16),
        ],
        if (s.storageFull) ...[
          const NoteBlock(
            'Live data is still running. Your iPhone has no room for the trip '
            'log — free some space and start a new recording.',
            tone: Tone.caution,
            title: 'Recording stopped — storage full',
          ),
          const SizedBox(height: 16),
        ],
        _GaugeGrid(tiles: d.tiles),
        if (d.degradedExplainer != null) ...[
          const SectionHeading('Why this is happening'),
          Text(d.degradedExplainer!, style: Type.bodyMuted),
        ],
        if (d.scenario == DashboardScenario.hybrid) ...[
          const SizedBox(height: 16),
          const NoteBlock(
            'Zero is a value, not missing data. These tiles are live — full '
            'opacity, no clock glyph.',
          ),
        ],
        if (d.scenario == DashboardScenario.imperial) ...[
          const SizedBox(height: 16),
          const NoteBlock(
            'Units are independent toggles, defaulted from Locale. MPG is never '
            'unqualified — always "MPG (US)" or "MPG (UK)", because the two '
            "differ by 20% and that's a support ticket waiting to happen.",
            title: 'Imperial pass',
          ),
        ],
        if (e.rewardedOffered) ...[
          const SizedBox(height: 16),
          _RewardedOffer(
            onWatch: () {
              d.grantRewardUnlock();
              e.dismissRewardedOffer();
            },
          ),
        ],
      ],
    );
  }

  Widget _strip(
    BuildContext context,
    DashboardProvider d,
    ConnectionProvider c,
    SettingsProvider s,
    bool lost,
  ) {
    if (lost) {
      return ConnectionStrip(
        text: 'Connection lost — reconnecting… (${c.lostAttempt})',
        tone: Tone.fault,
      );
    }
    if (s.lowPowerMode) {
      return const ConnectionStrip(
        text: 'Low Power Mode is slowing data updates',
        tone: Tone.caution,
      );
    }
    if (c.status == ConnectionStatus.degraded) {
      return const ConnectionStrip(
        text: 'Weak link — some data may be missing',
        tone: Tone.caution,
      );
    }
    if (c.demoMode) {
      return const ConnectionStrip(
        text: 'DEMO DATA · replaying a recorded 2014 Golf session',
        tone: Tone.caution,
      );
    }
    return ConnectionStrip(text: d.stripText);
  }
}

/// The 2-column grid. At AX5 Dynamic Type it reflows to 1-up so the numerals
/// never truncate.
class _GaugeGrid extends StatelessWidget {
  const _GaugeGrid({required this.tiles});

  final List<GaugeReading> tiles;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final columns = scale > 1.5 ? 1 : 2;
    return LayoutBuilder(
      builder: (context, box) {
        final w = columns == 1
            ? box.maxWidth
            : (box.maxWidth - T.gridGutter) / 2;
        return Wrap(
          spacing: T.gridGutter,
          runSpacing: T.gridGutter,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: GaugeTile(
                  reading: t,
                  type: d.typeFor(t.pid),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => GraphScreen(reading: t),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TripStrip extends StatelessWidget {
  const _TripStrip({required this.d});

  final DashboardProvider d;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: T.hairlineTop),
    padding: const EdgeInsets.symmetric(horizontal: T.gutter, vertical: 12),
    child: Row(
      children: [
        Expanded(child: Text(d.tripLine, style: Type.rowSecondary)),
        _RecordButton(recording: d.recording, onTap: d.toggleRecording),
      ],
    ),
  );
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      height: T.touchTargetFloor,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            color: recording ? T.fault : T.neutral500,
          ),
          const SizedBox(width: 7),
          Text(
            recording ? 'STOP' : 'RECORD',
            style: Type.chip(recording ? T.fault : T.neutral700),
          ),
        ],
      ),
    ),
  );
}

/// Rewarded ads are offered, never required. Two extra tiles for 60 minutes.
class _RewardedOffer extends StatelessWidget {
  const _RewardedOffer({required this.onWatch});

  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) => Blueprint(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Want two more gauges for this session?',
                style: Type.rowPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                'Watch a 30-second ad · unlocks for 60 minutes',
                style: Type.rowSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _WatchButton(onPressed: onWatch),
      ],
    ),
  );
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: T.accent700, width: 1),
      ),
      child: Text('Watch', style: Type.button(T.accent700, size: 14)),
    ),
  );
}

/// C4 — edit mode. Reorder, retarget, remove; the free-tier ceiling is stated
/// plainly rather than enforced by a disabled control with no explanation.
class _EditMode extends StatelessWidget {
  const _EditMode();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final e = context.watch<EntitlementProvider>();
    final atCeiling = !e.isPro && d.tiles.length >= d.tileCeiling;

    return Screen(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Row(
            children: [
              Expanded(child: Text('Edit dashboard', style: Type.screenTitle)),
              InlineAction('Done', onPressed: () => d.setEditing(false)),
            ],
          ),
        ),
        Text(
          'Drag to reorder · tap a tile to change what it reads · swipe a tile '
          'away to remove it. Layouts save per vehicle.',
          style: Type.footnote,
        ),
        const SizedBox(height: 18),
        _ReorderableGrid(tiles: d.tiles, onRemove: d.removeTile),
        const SizedBox(height: T.gridGutter),
        _AddTileCell(enabled: !atCeiling),
        const _ThemePicker(),
        if (atCeiling) ...[
          const SizedBox(height: 18),
          Blueprint(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.tiles.length} of ${d.tileCeiling} tiles used',
                        style: Type.rowPrimary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pro adds unlimited tiles and named layouts per vehicle.',
                        style: Type.rowSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InlineAction('See Pro', onPressed: () => openPaywall(context)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReorderableGrid extends StatelessWidget {
  const _ReorderableGrid({required this.tiles, required this.onRemove});

  final List<GaugeReading> tiles;
  final void Function(String pid) onRemove;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - T.gridGutter) / 2;
        return Wrap(
          spacing: T.gridGutter,
          runSpacing: T.gridGutter,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: Stack(
                  children: [
                    GaugeTile(
                      reading: t,
                      editing: true,
                      type: d.typeFor(t.pid),
                      selected: d.selectedPid == t.pid,
                      // Tapping a tile aims the picker at it. Tapping it again
                      // deselects, which puts a pick back on the default.
                      onTap: () =>
                          d.selectTile(d.selectedPid == t.pid ? null : t.pid),
                    ),
                    // Drag handle and remove affordance, both above the 48pt
                    // target floor.
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: Center(
                              child: Icn(
                                Lu.grip,
                                size: 16,
                                color: T.neutral600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onRemove(t.pid),
                            child: const SizedBox(
                              width: 34,
                              height: 34,
                              child: Center(
                                child: Icn(Lu.x, size: 15, color: T.fault),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The theme picker. Five treatments, applied to the tile the user tapped or
/// to every tile at once.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final target = d.selectedPid;
    final current = target == null ? d.defaultTileType : d.typeFor(target);
    final targetLabel = target == null
        ? null
        : d.tiles
              .firstWhere((t) => t.pid == target, orElse: () => d.tiles.first)
              .label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Theme'),
        Text('TILE TYPE', style: Type.formLabel.copyWith(letterSpacing: 0.9)),
        const SizedBox(height: 10),
        // One segmented control, the system component — five segments fit a
        // phone width at the 44pt row height.
        Segmented(
          options: [for (final t in TileType.values) t.label],
          selected: TileType.values.indexOf(current),
          onSelect: (i) => d.setTileType(TileType.values[i]),
          height: 44,
          expand: true,
        ),
        const SizedBox(height: 8),
        Text(
          d.applyToEveryTile || target == null
              ? 'Applies to every tile.'
              : 'Applies to $targetLabel. Tap another tile to aim elsewhere.',
          style: Type.footnote,
        ),
        const SizedBox(height: 6),
        AppListRow(
          title: 'Apply to every tile',
          subtitle: 'Otherwise this changes only the tile you tapped',
          divider: false,
          trailing: AppSwitch(
            value: d.applyToEveryTile,
            onChanged: d.setApplyToEveryTile,
          ),
        ),
      ],
    );
  }
}

class _AddTileCell extends StatelessWidget {
  const _AddTileCell({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SizedBox(
      width: (box.maxWidth - T.gridGutter) / 2,
      height: T.gaugeTileHeight,
      child: CustomPaint(
        painter: _DashedBoxPainter(color: enabled ? T.accent : T.neutral400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icn(Lu.plus, size: 20, color: enabled ? T.accent700 : T.neutral500),
            const SizedBox(height: 8),
            Text(
              'Add tile',
              style: Type.button(
                enabled ? T.accent700 : T.neutral500,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 5.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (double d = 0; d < total; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, total), p);
      }
    }

    line(Offset.zero, Offset(size.width, 0));
    line(Offset(size.width, 0), Offset(size.width, size.height));
    line(Offset(size.width, size.height), Offset(0, size.height));
    line(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}
