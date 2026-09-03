import 'package:flutter/widgets.dart';

import '../models/enums.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'blueprint.dart';
import 'icons.dart';

/// The 44px iOS status bar, drawn so the frames match the board exactly.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, this.right = 'LTE · 82%', this.lowPower = false});

  final String right;
  final bool lowPower;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: T.statusBarHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: T.gutter),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41', style: Type.statusBar),
          Text(
            lowPower ? 'LOW POWER · 14%' : right,
            style: Type.statusBar.copyWith(
              color: lowPower ? T.cautionText : T.text,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The 5-item tab bar. 78px, hairline top, `--color-neutral-100` ground.
/// The active item carries a 2px accent rule above its glyph.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.active, required this.onSelect});

  final int active;
  final ValueChanged<int> onSelect;

  static const items = <({String label, String icon})>[
    (label: 'Connect', icon: Lu.plug),
    (label: 'Dashboard', icon: Lu.gauge),
    (label: 'Diagnostics', icon: Lu.activity),
    (label: 'Garage', icon: Lu.car),
    (label: 'Settings', icon: Lu.sliders),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: T.tabBarHeight,
    decoration: const BoxDecoration(color: T.neutral100, border: T.hairlineTop),
    child: Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Semantics(
                button: true,
                selected: i == active,
                label: items[i].label,
                child: _TabItem(item: items[i], active: i == active),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.item, required this.active});

  final ({String label, String icon}) item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? T.accent700 : T.neutral700;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 2,
          color: active ? T.accent : const Color(0x00000000),
        ),
        const SizedBox(height: 6),
        Icn(item.icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(item.label, style: Type.tabLabel.copyWith(color: color)),
      ],
    );
  }
}

/// The quiet 36px connection strip above the dashboard: protocol, voltage,
/// polling rate. It becomes a 44px banner when something needs saying.
class ConnectionStrip extends StatelessWidget {
  const ConnectionStrip({
    super.key,
    required this.text,
    this.tone = Tone.ink,
    this.trailing,
  });

  final String text;
  final Tone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final banner = tone != Tone.ink;
    final (Color fg, Color bg, String glyph) = switch (tone) {
      Tone.caution => (T.cautionText, T.cautionTint, Lu.triangleAlert),
      Tone.fault => (T.fault, T.faultTint, Lu.circleAlert),
      Tone.pass => (T.passText, T.passTint, Lu.circleCheck),
      Tone.ink => (T.neutral700, T.bg, Lu.activity),
    };
    return Container(
      height: banner ? T.connectionStripBanner : T.connectionStripQuiet,
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: T.gutter),
      child: Row(
        children: [
          if (banner) ...[
            Icn(glyph, size: 14, color: fg),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              banner ? text : text,
              style: banner
                  ? Type.rowSecondary.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    )
                  : Type.sectionHeading.copyWith(
                      color: T.neutral700,
                      letterSpacing: 1.0,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A telltale chip: glyph + word, never colour alone.
class TelltaleChip extends StatelessWidget {
  const TelltaleChip(this.label, {super.key, this.tone = Tone.ink, this.icon});

  final String label;
  final Tone tone;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color border, String glyph) = switch (tone) {
      Tone.fault => (T.fault, T.fault, Lu.triangleAlert),
      Tone.caution => (T.cautionText, T.cautionBorder, Lu.triangleAlert),
      Tone.pass => (T.passText, T.pass, Lu.circleCheck),
      Tone.ink => (T.neutral700, T.divider, Lu.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        color: switch (tone) {
          Tone.fault => T.faultTint,
          Tone.caution => T.cautionTint,
          Tone.pass => T.passTint,
          Tone.ink => null,
        },
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icn(icon ?? glyph, size: 11, color: fg),
          const SizedBox(width: 5),
          Text(label.toUpperCase(), style: Type.chip(fg)),
        ],
      ),
    );
  }
}

/// A flat badge with no glyph — PRO markers, "FREE", counts. Used where the
/// label itself is the meaning and no semantic colour is involved.
class Badge extends StatelessWidget {
  const Badge(
    this.label, {
    super.key,
    this.color = T.accent700,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 1),
      color: filled ? color : null,
    ),
    child: Text(
      label.toUpperCase(),
      style: Type.chip(filled ? T.neutral100 : color),
    ),
  );
}

/// An uppercase section heading. One of exactly two uppercase uses in the
/// system — the other is a gauge tile's PID label.
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.label, {
    super.key,
    this.trailing,
    this.topPadding = 22,
  });

  final String label;
  final Widget? trailing;
  final double topPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: Type.sectionHeading)),
        ?trailing,
      ],
    ),
  );
}

/// A list row: 46–52px, zero radius, 1px hairline bottom. Rows are rows, not
/// cards.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.severityBar,
    this.titleStyle,
    this.valueStyle,
    this.minHeight = 52,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  /// A 3px bar on the leading edge, used on DTC rows and the adapter list to
  /// carry severity alongside the words.
  final Color? severityBar;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final double minHeight;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: divider
          ? const BoxDecoration(border: T.hairlineBottom)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (severityBar != null) ...[
            Container(width: 3, height: 30, color: severityBar),
            const SizedBox(width: 11),
          ],
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: titleStyle ?? Type.rowPrimary),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Type.rowSecondary),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Text(
              value!,
              style:
                  valueStyle ?? Type.rowPrimary.copyWith(color: T.neutral700),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (chevron) ...[
            const SizedBox(width: 8),
            const Icn(Lu.chevronRight, size: 16, color: T.neutral600),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(button: true, child: row),
    );
  }
}

/// A label/value pair list — freeze frames, adapter details, trip stats.
class ValueList extends StatelessWidget {
  const ValueList(this.entries, {super.key, this.dense = false});

  final List<({String label, String value})> entries;
  final bool dense;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < entries.length; i++)
        Container(
          padding: EdgeInsets.symmetric(vertical: dense ? 7 : 9),
          decoration: BoxDecoration(
            border: i == entries.length - 1 ? null : T.hairlineBottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(entries[i].label, style: Type.rowSecondary)),
              const SizedBox(width: 12),
              Text(
                entries[i].value,
                style: Type.inlineValue,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
    ],
  );
}

/// A tri-stat figure — the health/codes/overdue block on the vehicle overview,
/// and the distance/max/idle block on a trip.
class TriStat extends StatelessWidget {
  const TriStat(this.stats, {super.key});

  final List<({String value, String label, Tone tone})> stats;

  @override
  Widget build(BuildContext context) => Blueprint(
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : const Border(
                          left: BorderSide(color: T.divider, width: 1),
                        ),
                ),
                child: Column(
                  children: [
                    Text(
                      stats[i].value,
                      style: Type.inlineValueLg.copyWith(
                        fontSize: 26,
                        color: switch (stats[i].tone) {
                          Tone.caution => T.cautionText,
                          Tone.fault => T.fault,
                          Tone.pass => T.passText,
                          Tone.ink => T.text,
                        },
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      stats[i].label.toUpperCase(),
                      style: Type.sectionHeading,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
