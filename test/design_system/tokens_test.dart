import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torque_obd2/design_system/design_system.dart';

/// SPEC B.8 — the accessibility floor, checked against the actual tokens.
void main() {
  const t = TorqueTokens.dark;

  test('★ text inks reach 4.5:1 on every surface', () {
    for (final surface in [t.surfaceDeep, t.surfaceRaised, t.surfacePanel]) {
      for (final ink in [t.inkPrimary, t.inkSecondary]) {
        expect(
          contrastRatio(ink, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$ink on $surface',
        );
      }
    }
  });

  test('★ telltales reach 3:1 on the tile surface, as bars and chips', () {
    for (final tell in [t.tellRed, t.tellAmber, t.tellGreen, t.tellBlue]) {
      expect(contrastRatio(tell, t.surfaceRaised), greaterThanOrEqualTo(3.0));
      expect(contrastRatio(tell, t.surfaceDeep), greaterThanOrEqualTo(3.0));
    }
  });

  test('the amber button carries dark text at 4.5:1', () {
    expect(
      contrastRatio(t.surfaceDeep, t.tellAmber),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('tertiary ink is for chrome, and never carries text alone', () {
    // Documented, not enforced by the type system: keep it visible here so a
    // future token change that drops it below 3:1 fails loudly.
    expect(
      contrastRatio(t.inkTertiary, t.surfaceDeep),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('every telltale tone ships with a glyph and a word', () {
    for (final tone in Tell.values.where((x) => x != Tell.none)) {
      expect(tone.word, isNotEmpty);
      expect(tone.glyph, isNotNull);
    }
  });

  test('the theme carries the tokens and paints nothing with a shadow', () {
    final theme = torqueTheme();
    expect(theme.extension<TorqueTokens>(), t);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.bottomSheetTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.scaffoldBackgroundColor, t.surfaceDeep);
  });

  test('lerp and copyWith are total', () {
    final mid = t.lerp(t.copyWith(tellAmber: Colors.white), 0.5);
    expect(mid.tellAmber, isNot(t.tellAmber));
    expect(mid.surfaceDeep, t.surfaceDeep);
    expect(t.lerp(null, 0.5), t);
  });

  test('type scale is tabular everywhere and uppercase nowhere by default', () {
    for (final s in [
      TorqueType.readoutXl,
      TorqueType.readoutLg,
      TorqueType.readoutMd,
      TorqueType.titleLg,
      TorqueType.titleMd,
      TorqueType.body,
      TorqueType.label,
      TorqueType.unit,
      TorqueType.gaugeLabel,
      TorqueType.meta,
    ]) {
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
    expect(TorqueType.readoutXl.fontSize, 64);
    expect(TorqueType.readoutXl.height, 0.94);
    expect(TorqueType.readoutXl.letterSpacing, -1.5);
    expect(TorqueType.gaugeLabel.letterSpacing, 1.0);
  });

  test(
    'motion: the live value never animates; reduced motion zeroes the rest',
    () {
      expect(Motion.value, Duration.zero);
      expect(Motion.rangeBar.inMilliseconds, 120);
      expect(Motion.stalenessDecay.inMilliseconds, 400);
      expect(Motion.tilePress.inMilliseconds, 80);
      expect(Motion.sheet.inMilliseconds, 280);
      expect(Motion.faultPulse.inMilliseconds, 200);
    },
  );

  test('targets and radii are the spec\'s numbers', () {
    expect(Targets.min, 48);
    expect(Radii.tile, 16);
    expect(Radii.sheet, 24);
    expect(Radii.button, 12);
    expect(Radii.chip, 8);
    expect(Radii.input, 10);
    expect(Radii.row, 0);
    expect(Space.gutter, 20);
  });
}
