import 'package:flutter/material.dart';

/// Nigerian green — the app's brand seed color. Keep this if you touch
/// nothing else here.
const kSeedColor = Color(0xFF00A651);

/// Brand purple used for the SplitNaija wordmark and other purple accents
/// (splash screen, highlights).
const kBrandPurple = Color(0xFF6C2BD9);

/// Palette for the pie-chart / "sharing" motif used on the loading screen.
/// Each color represents a "slice" coming together.
const kPieColors = <Color>[
  Color(0xFF6C2BD9), // purple
  Color(0xFF00A651), // Nigerian green
  Color(0xFFFF6B35), // orange
  Color(0xFFFFC93C), // yellow
  Color(0xFF1FA2A6), // teal
];

const kFontFamily = 'Plus Jakarta Sans';

/// Corner radius for the auth flow (get started, login, signup, password
/// screens) — deliberately squarer than [kRadius] used elsewhere in the app.
const kAuthRadius = 10.0;

/// Caps form/content width on tablets, desktop, and web so fields and
/// buttons don't stretch edge-to-edge on a wide window — phones (which are
/// narrower than this) are completely unaffected.
const kMaxContentWidth = 480.0;

const kSpacingXs = 4.0;
const kSpacingSm = 8.0;
const kSpacingMd = 16.0;
const kSpacingLg = 24.0;
const kSpacingXl = 32.0;
const kSpacingXxl = 40.0;
const kRadius = 16.0;

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

  final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
  final textTheme = baseTextTheme.copyWith(
    displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      margin: const EdgeInsets.symmetric(vertical: kSpacingXs),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: kSpacingMd),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
      secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: kSpacingSm, vertical: kSpacingXs),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kSpacingSm)),
    ),
  );
}