import 'package:flutter/material.dart';

import 'spacing.dart';
import 'tokens.dart';
import 'typography.dart';

/// The one [ThemeData] the app runs on. Dark only — backlit instrument
/// glass. No shadow anywhere: elevation is zero on every component and
/// depth comes from surface value plus the 1px top-edge highlight.
ThemeData torqueTheme({TorqueTokens tokens = TorqueTokens.dark}) {
  final scheme = ColorScheme.dark(
    primary: tokens.tellAmber,
    onPrimary: tokens.surfaceDeep,
    secondary: tokens.tellBlue,
    onSecondary: tokens.surfaceDeep,
    surface: tokens.surfaceRaised,
    onSurface: tokens.inkPrimary,
    onSurfaceVariant: tokens.inkSecondary,
    surfaceContainerHighest: tokens.surfacePanel,
    outline: tokens.hairline,
    outlineVariant: tokens.hairline,
    error: tokens.tellRed,
    onError: tokens.surfaceDeep,
  );

  TextStyle ink(TextStyle s, Color c) => s.copyWith(color: c);

  final text = TextTheme(
    displayLarge: ink(TorqueType.readoutXl, tokens.inkPrimary),
    displayMedium: ink(TorqueType.readoutLg, tokens.inkPrimary),
    displaySmall: ink(TorqueType.readoutMd, tokens.inkPrimary),
    headlineMedium: ink(TorqueType.titleLg, tokens.inkPrimary),
    titleMedium: ink(TorqueType.titleMd, tokens.inkPrimary),
    bodyLarge: ink(TorqueType.body, tokens.inkPrimary),
    bodyMedium: ink(TorqueType.body, tokens.inkPrimary),
    labelLarge: ink(TorqueType.label, tokens.inkPrimary),
    labelMedium: ink(TorqueType.unit, tokens.inkSecondary),
    labelSmall: ink(TorqueType.gaugeLabel, tokens.inkSecondary),
    bodySmall: ink(TorqueType.meta, tokens.inkSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.surfaceDeep,
    canvasColor: tokens.surfaceDeep,
    fontFamily: TorqueType.regular,
    textTheme: text,
    extensions: [tokens],
    // Tile press is a scale, not a ripple.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    dividerTheme: DividerThemeData(
      color: tokens.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surfaceDeep,
      foregroundColor: tokens.inkPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: ink(TorqueType.titleMd, tokens.inkPrimary),
    ),
    cardTheme: CardThemeData(
      color: tokens.surfaceRaised,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.tile)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surfaceRaised,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surfaceRaised,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.sheet)),
      ),
      titleTextStyle: ink(TorqueType.titleMd, tokens.inkPrimary),
      contentTextStyle: ink(TorqueType.body, tokens.inkSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfacePanel,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.input)),
        borderSide: BorderSide.none,
      ),
      hintStyle: ink(TorqueType.body, tokens.inkSecondary),
      labelStyle: ink(TorqueType.label, tokens.inkSecondary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? tokens.surfaceDeep
            : tokens.inkSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? tokens.inkPrimary
            : tokens.surfacePanel,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(),
      tileColor: Colors.transparent,
      textColor: tokens.inkPrimary,
      iconColor: tokens.inkSecondary,
      minVerticalPadding: Space.x12,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surfaceRaised,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: tokens.surfacePanel,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => ink(
          TorqueType.meta,
          s.contains(WidgetState.selected)
              ? tokens.inkPrimary
              : tokens.inkSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? tokens.inkPrimary
              : tokens.inkSecondary,
        ),
      ),
    ),
    // Monochrome chrome (B.3): amber is for primary action and caution.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.inkPrimary,
      linearTrackColor: tokens.surfacePanel,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.surfacePanel,
      contentTextStyle: ink(TorqueType.body, tokens.inkPrimary),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.button)),
      ),
    ),
  );
}
