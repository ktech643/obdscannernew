import 'package:flutter/widgets.dart';

/// Industry design-system tokens.
///
/// Mirrors `_ds/industry-*/styles.css`. Every colour, space and radius used
/// anywhere in the app resolves to a value here — nothing is hardcoded at the
/// call site.
class T {
  T._();

  // ---------------------------------------------------------------- colour
  static const bg = Color(0xFFF2F2F3);
  static const surface = Color(0xFFE9E9EA);
  static const text = Color(0xFF1D1F20);
  static const accent = Color(0xFF5980A6);
  static const accent2 = Color(0xFF728FAB);

  /// `--color-divider`: ink at 16%. Every hairline in the system.
  static const divider = Color(0x291D1F20);

  static const neutral100 = Color(0xFFF5F5F8);
  static const neutral200 = Color(0xFFE7E7EA);
  static const neutral300 = Color(0xFFD4D4D7);
  static const neutral400 = Color(0xFFB7B7BA);
  static const neutral500 = Color(0xFF98989B);
  static const neutral600 = Color(
    0xFF7A7A7D,
  ); // 3.82:1 — chrome only, never text
  static const neutral700 = Color(0xFF5D5D60); // 5.87:1 — all secondary text
  static const neutral800 = Color(0xFF424244);
  static const neutral900 = Color(0xFF2B2B2D);

  static const accent100 = Color(0xFFEEF6FF);
  static const accent200 = Color(0xFFD6EBFF);
  static const accent300 = Color(0xFFB5D9FD);
  static const accent400 = Color(0xFF94BCE3);
  static const accent500 = Color(0xFF749DC4);
  static const accent600 = Color(0xFF597EA3);

  /// The only accent safe behind text, and the primary-button fill.
  static const accent700 = Color(0xFF416180);
  static const accent800 = Color(0xFF2C455D);
  static const accent900 = Color(0xFF1D2D3D);

  // ------------------------------------------------- telltale semantics
  // ISO 2575. These are the only colours outside the steel accent, and they
  // never appear decoratively — always with a glyph *and* a word.
  static const fault = Color(0xFF96352E);
  static const cautionBorder = Color(0xFFC08A18);
  static const cautionText = Color(0xFF8F6410);
  static const pass = Color(0xFF3F7350);
  static const passText = Color(0xFF2F5A3E);

  /// Range-bar bands. Used on the range bar only, never as a fill elsewhere.
  static const bandNormal = accent300;
  static const bandCaution = Color(0xFFE3C689);
  static const bandCritical = Color(0xFFD5A19A);

  static Color faultTint = _mix(fault, 0.14);
  static Color cautionTint = _mix(cautionBorder, 0.12);
  static Color passTint = _mix(pass, 0.15);
  static Color accentTint = _mix(accent, 0.10);

  static Color _mix(Color c, double pct) => c.withValues(alpha: pct);

  // --------------------------------------------------------------- layout
  /// Screen gutter. Onboarding and account screens use [gutterWide].
  static const gutter = 20.0;
  static const gutterWide = 24.0;

  /// Between gauge tiles.
  static const gridGutter = 12.0;

  static const statusBarHeight = 44.0;
  static const connectionStripQuiet = 36.0;
  static const connectionStripBanner = 44.0;
  static const tabBarHeight = 78.0;
  static const gaugeTileHeight = 124.0;

  static const primaryButtonHeight = 52.0;
  static const secondaryButtonHeight = 48.0;
  static const ghostButtonHeight = 44.0;

  /// Deliberately 4pt above Apple's HIG floor — the user may be wearing
  /// gloves or have oily hands.
  static const touchTargetFloor = 48.0;

  static const adBannerWidth = 320.0;
  static const adBannerHeight = 50.0;

  // --------------------------------------------------------------- radius
  // Nothing is rounded. 4px is the ceiling, and only on buttons and inputs.
  static const radiusSm = Radius.circular(2);
  static const radiusMd = Radius.circular(4);
  static const rSm = BorderRadius.all(radiusSm);
  static const rMd = BorderRadius.all(radiusMd);
  static const rZero = BorderRadius.zero;

  // ------------------------------------------------------------- hairline
  static const hairline = BorderSide(color: divider, width: 1);
  static Border get hairlineBox => const Border.fromBorderSide(hairline);
  static const hairlineBottom = Border(bottom: hairline);
  static const hairlineTop = Border(top: hairline);
}
