import 'package:flutter/material.dart';

const _seedColor = Color(0xFF3D7FFF);

ThemeData buildAppTheme(Brightness brightness) {
  var colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  if (brightness == Brightness.dark) {
    // Media apps (Stremio, Netflix) go near-black rather than Material's
    // default blue-gray dark surface — reads as more "cinematic".
    colorScheme = colorScheme.copyWith(
      surface: const Color(0xFF0B0C0F),
      surfaceContainerLow: const Color(0xFF121317),
      surfaceContainer: const Color(0xFF17181D),
      surfaceContainerHigh: const Color(0xFF1D1F25),
      surfaceContainerHighest: const Color(0xFF24262D),
    );
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    splashFactory: InkSparkle.splashFactory,
    // Material's default focus tint is subtle enough to be invisible from a
    // couch with a TV remote; every focusable widget below leans on this.
    focusColor: colorScheme.primary.withValues(alpha: 0.35),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ).copyWith(
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: colorScheme.onPrimary, width: 2.5)
              : null,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
  );
}
