import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The Industry type scale, transcribed from the handoff table.
///
/// Two widths of one superfamily: Barlow Condensed for anything numeric or
/// title-like, Barlow for prose and chrome. Every numeral is tabular — a live
/// value that shifts horizontally as digits change is a legibility failure at
/// arm's length.
class Type {
  Type._();

  static const heading = 'BarlowCondensed';
  static const body = 'Barlow';

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static TextStyle _h(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w600,
    double tracking = -0.02,
    Color color = T.text,
  }) => TextStyle(
    fontFamily: heading,
    fontSize: size,
    height: lineHeight,
    fontWeight: weight,
    letterSpacing: size * tracking,
    color: color,
    fontFeatures: _tabular,
  );

  static TextStyle _b(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    double trackingEm = 0,
    Color color = T.text,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    height: lineHeight,
    fontWeight: weight,
    letterSpacing: size * trackingEm,
    color: color,
    fontFeatures: _tabular,
  );

  // ------------------------------------------------------------- numerals
  /// 46 / 0.84 / 600 / −0.02em — the gauge-tile numeral.
  static TextStyle gaugeNumeral(Color color) => _h(46, 0.84, color: color);

  /// 56 / 0.9 — the full-screen readout.
  static const readout = TextStyle(
    fontFamily: heading,
    fontSize: 56,
    height: 0.9,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.12,
    color: T.text,
    fontFeatures: _tabular,
  );

  /// 76 / 0.85 / −0.03em — the health score.
  static TextStyle healthScore(Color color) => TextStyle(
    fontFamily: heading,
    fontSize: 76,
    height: 0.85,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.28,
    color: color,
    fontFeatures: _tabular,
  );

  // --------------------------------------------------------------- titles
  static final screenTitle = _h(30, 1.0);
  static final onboardingHeadline = _h(32, 1.05);
  static final onboardingHeadlineLg = _h(34, 1.05);
  static final subScreenTitle = _h(26, 1.0);
  static final cardTitle = _h(21, 1.1, tracking: 0);
  static final cardTitleLg = _h(23, 1.1, tracking: 0);

  /// DTC codes get positive tracking — they are read character by character.
  static final dtcCode = _h(19, 1.1, tracking: 0.02);
  static final inlineValue = _h(17, 1.0, tracking: 0);
  static final inlineValueLg = _h(20, 1.0, tracking: 0);

  // ----------------------------------------------------------------- body
  static final body15 = _b(15, 1.5);
  static final body16 = _b(16, 1.5);
  static final bodyMuted = _b(15, 1.5, color: T.neutral700);
  static final body16Muted = _b(16, 1.5, color: T.neutral700);

  static final rowPrimary = _b(15, 1.25, weight: FontWeight.w500);
  static final rowPrimary16 = _b(16, 1.25, weight: FontWeight.w500);
  static final rowSecondary = _b(13, 1.4, color: T.neutral700);

  static final formLabel = _b(
    13,
    1.0,
    weight: FontWeight.w500,
    color: T.neutral700,
  );
  static final footnote = _b(12, 1.5, color: T.neutral700);
  static final footnoteTight = _b(12, 1.45, color: T.neutral700);

  // --------------------------------------------------------------- chrome
  /// The PID name on a gauge tile. One of exactly two uppercase uses.
  static final pidLabel = _b(
    10,
    1.2,
    weight: FontWeight.w600,
    trackingEm: 0.13,
    color: T.neutral700,
  );

  /// The note in a gauge tile's top-right corner.
  static TextStyle gaugeNote(Color color) =>
      _b(9, 1.2, weight: FontWeight.w600, trackingEm: 0.08, color: color);

  /// Section heading inside a screen. The other uppercase use.
  static final sectionHeading = _b(
    10,
    1.0,
    weight: FontWeight.w600,
    trackingEm: 0.16,
    color: T.neutral600,
  );

  static final statusBar = _b(13, 1.0, weight: FontWeight.w600);
  static final tabLabel = _b(
    10,
    1.0,
    weight: FontWeight.w600,
    trackingEm: 0.04,
  );

  /// Chips: telltales, PRO badges, state markers.
  static TextStyle chip(Color color) =>
      _b(9.5, 1.0, weight: FontWeight.w600, trackingEm: 0.08, color: color);

  static TextStyle button(Color color, {double size = 16}) =>
      _b(size, 1.0, weight: FontWeight.w600, color: color);

  /// Protocol frames and AT commands in the diagnostics log.
  static final mono = TextStyle(
    fontFamily: body,
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: T.text,
    fontFeatures: _tabular,
  );
}
