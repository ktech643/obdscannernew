import 'package:flutter/widgets.dart';

/// SPEC Part B.3 — Barlow, two widths.
///
/// Condensed for readouts and titles, regular for prose and chrome. Every
/// style carries tabular figures: a live value whose digits shift sideways
/// as they change is a legibility failure at arm's length. Uppercase
/// appears in exactly one place — the PID name on a gauge tile.
class TorqueType {
  TorqueType._();

  static const condensed = 'BarlowCondensed';
  static const regular = 'Barlow';

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static TextStyle _s(
    String family,
    double size,
    double height,
    FontWeight weight,
    double spacing,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: spacing,
    fontFeatures: _tabular,
  );

  /// 64 / 0.94 / w600 / -1.5 — the primary gauge value.
  static final readoutXl = _s(condensed, 64, 0.94, FontWeight.w600, -1.5);
  static final readoutLg = _s(condensed, 40, 1.00, FontWeight.w600, -1.0);
  static final readoutMd = _s(condensed, 28, 1.07, FontWeight.w600, -0.5);
  static final titleLg = _s(condensed, 26, 1.23, FontWeight.w600, -0.3);

  /// Section headings, DTC codes.
  static final titleMd = _s(condensed, 19, 1.32, FontWeight.w600, 0);
  static final body = _s(regular, 16, 1.50, FontWeight.w400, 0);
  static final label = _s(regular, 14, 1.29, FontWeight.w500, 0);
  static final unit = _s(regular, 13, 1.23, FontWeight.w500, 0.4);

  /// UPPERCASE — tile PID names only. The caller upper-cases the string.
  static final gaugeLabel = _s(regular, 12, 1.17, FontWeight.w600, 1.0);
  static final meta = _s(regular, 12, 1.33, FontWeight.w400, 0);
}
