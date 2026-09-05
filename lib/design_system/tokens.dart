import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SPEC Part B.3 — the colour system *is* the diagnostic system.
///
/// ISO 2575 is already installed in every driver's head: red stop, amber
/// caution, green working, blue information. Colour is never decorative;
/// if nothing is wrong, the screen is monochrome. Amber is the brand accent
/// because it is the hue of the check-engine lamp — primary action and
/// caution only, nowhere else. Chrome (tabs, switches, spinners, progress)
/// is ink.
///
/// Depth comes from surface value plus a 1px top-edge highlight, never a
/// shadow. There is deliberately no light variant: this is backlit
/// instrument glass, read in a parked car at night at arm's length. There
/// is a high-contrast variant (B.8), resolved automatically from
/// `MediaQuery.highContrast`.
@immutable
class TorqueTokens extends ThemeExtension<TorqueTokens> {
  const TorqueTokens({
    required this.surfaceDeep,
    required this.surfaceRaised,
    required this.surfacePanel,
    required this.hairline,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.tellRed,
    required this.tellAmber,
    required this.tellGreen,
    required this.tellBlue,
    this.chipFillAlpha = 0.15,
    this.bandAlpha = 0.22,
    this.dimmedOpacity = 0.4,
  });

  /// Canvas.
  final Color surfaceDeep;

  /// Tiles, sheets.
  final Color surfaceRaised;

  /// Inputs, selected rows, tile headers.
  final Color surfacePanel;

  /// 1px rules.
  final Color hairline;

  /// Text. ≥ 4.5:1 on every surface.
  final Color inkPrimary;

  /// Secondary text. ≥ 4.5:1 on every surface.
  final Color inkSecondary;

  /// Chrome only — chevrons, disabled labels, hint glyphs. Never running
  /// text: it clears 3:1, not 4.5:1.
  final Color inkTertiary;

  /// Fault, MIL on.
  final Color tellRed;

  /// Caution — and the brand accent.
  final Color tellAmber;

  /// Pass, in range.
  final Color tellGreen;

  /// Informational, recording.
  final Color tellBlue;

  /// Chip and banner tint strength.
  final double chipFillAlpha;

  /// The normal band on a range bar.
  final double bandAlpha;

  /// What a stale readout fades to.
  final double dimmedOpacity;

  static const dark = TorqueTokens(
    surfaceDeep: Color(0xFF0A1418),
    surfaceRaised: Color(0xFF10202A),
    surfacePanel: Color(0xFF17303C),
    hairline: Color(0xFF22404E),
    inkPrimary: Color(0xFFEAF3F6),
    inkSecondary: Color(0xFF93AFBB),
    inkTertiary: Color(0xFF5B7885),
    tellRed: Color(0xFFFF4A45),
    tellAmber: Color(0xFFFFB020),
    tellGreen: Color(0xFF33D17A),
    tellBlue: Color(0xFF4FC3F7),
  );

  /// B.8 — iOS "Increase Contrast" / Android high-contrast text. Brighter
  /// inks, visible rules, stronger tints, a lighter stale dim.
  static const highContrast = TorqueTokens(
    surfaceDeep: Color(0xFF05090B),
    surfaceRaised: Color(0xFF0E1C25),
    surfacePanel: Color(0xFF17303C),
    hairline: Color(0xFF5B7885),
    inkPrimary: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFC5D6DD),
    inkTertiary: Color(0xFF93AFBB),
    tellRed: Color(0xFFFF5F5A),
    tellAmber: Color(0xFFFFC04D),
    tellGreen: Color(0xFF4DE08E),
    tellBlue: Color(0xFF6FD0FA),
    chipFillAlpha: 0.30,
    bandAlpha: 0.40,
    dimmedOpacity: 0.6,
  );

  /// The 1px top-edge highlight that stands in for elevation.
  Color get edgeHighlight => Colors.white.withValues(alpha: 0.06);

  /// The colour for a telltale tone. Ink for "nothing to say".
  Color tell(Tell tone) => switch (tone) {
    Tell.none => inkSecondary,
    Tell.red => tellRed,
    Tell.amber => tellAmber,
    Tell.green => tellGreen,
    Tell.blue => tellBlue,
  };

  @override
  TorqueTokens copyWith({
    Color? surfaceDeep,
    Color? surfaceRaised,
    Color? surfacePanel,
    Color? hairline,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? tellRed,
    Color? tellAmber,
    Color? tellGreen,
    Color? tellBlue,
    double? chipFillAlpha,
    double? bandAlpha,
    double? dimmedOpacity,
  }) => TorqueTokens(
    surfaceDeep: surfaceDeep ?? this.surfaceDeep,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfacePanel: surfacePanel ?? this.surfacePanel,
    hairline: hairline ?? this.hairline,
    inkPrimary: inkPrimary ?? this.inkPrimary,
    inkSecondary: inkSecondary ?? this.inkSecondary,
    inkTertiary: inkTertiary ?? this.inkTertiary,
    tellRed: tellRed ?? this.tellRed,
    tellAmber: tellAmber ?? this.tellAmber,
    tellGreen: tellGreen ?? this.tellGreen,
    tellBlue: tellBlue ?? this.tellBlue,
    chipFillAlpha: chipFillAlpha ?? this.chipFillAlpha,
    bandAlpha: bandAlpha ?? this.bandAlpha,
    dimmedOpacity: dimmedOpacity ?? this.dimmedOpacity,
  );

  @override
  TorqueTokens lerp(TorqueTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return TorqueTokens(
      surfaceDeep: c(surfaceDeep, other.surfaceDeep),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfacePanel: c(surfacePanel, other.surfacePanel),
      hairline: c(hairline, other.hairline),
      inkPrimary: c(inkPrimary, other.inkPrimary),
      inkSecondary: c(inkSecondary, other.inkSecondary),
      inkTertiary: c(inkTertiary, other.inkTertiary),
      tellRed: c(tellRed, other.tellRed),
      tellAmber: c(tellAmber, other.tellAmber),
      tellGreen: c(tellGreen, other.tellGreen),
      tellBlue: c(tellBlue, other.tellBlue),
      chipFillAlpha: d(chipFillAlpha, other.chipFillAlpha),
      bandAlpha: d(bandAlpha, other.bandAlpha),
      dimmedOpacity: d(dimmedOpacity, other.dimmedOpacity),
    );
  }
}

/// ISO 2575 telltale tones. `none` is monochrome: nothing to report.
enum Tell { none, red, amber, green, blue }

extension TellX on Tell {
  /// Every semantic colour ships with a glyph and a word (B.8). The glyph.
  IconData get glyph => switch (this) {
    Tell.none => Icons.remove,
    Tell.red => Icons.error_outline,
    Tell.amber => Icons.warning_amber_outlined,
    Tell.green => Icons.check,
    Tell.blue => Icons.info_outline,
  };

  /// The word.
  String get word => switch (this) {
    Tell.none => '',
    Tell.red => 'Fault',
    Tell.amber => 'Caution',
    Tell.green => 'OK',
    Tell.blue => 'Info',
  };
}

extension TorqueTokensContext on BuildContext {
  /// The active tokens: the high-contrast set when the platform asks for
  /// it, else the theme's, else [TorqueTokens.dark] so a widget rendered
  /// outside `torqueTheme()` (a golden, a preview) still paints.
  TorqueTokens get tokens {
    if (MediaQuery.maybeHighContrastOf(this) == true) {
      return TorqueTokens.highContrast;
    }
    return Theme.of(this).extension<TorqueTokens>() ?? TorqueTokens.dark;
  }
}

/// WCAG 2.x relative luminance and contrast, used by the accessibility
/// floor test and available to any widget that needs to pick an ink.
double relativeLuminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
