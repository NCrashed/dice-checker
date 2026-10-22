import 'package:flutter/material.dart';

import 'stats.dart';

abstract final class Palette {
  static const bg = Color(0xFF0F1013);
  static const surface = Color(0xFF181A1F);
  static const surfaceHigh = Color(0xFF22252C);
  static const line = Color(0xFF2E323A);
  static const text = Color(0xFFECE8E1);
  static const muted = Color(0xFF8B909A);
  static const brass = Color(0xFFE8B04B);
  static const fair = Color(0xFF4FC3A1);
  static const bias = Color(0xFFFF6B5B);
  static const unclear = Color(0xFF9AA0AA);

  static Color verdict(Verdict v) => switch (v) {
    Verdict.strongFair || Verdict.fair => fair,
    Verdict.biased || Verdict.strongBiased => bias,
    _ => unclear,
  };

  /// Colour for a log10 Bayes factor where positive means "effect/bias".
  static Color evidence(double log10Bf10) => log10Bf10 >= 0.5
      ? bias
      : log10Bf10 <= -0.5
      ? fair
      : unclear;
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.brass, brightness: Brightness.dark).copyWith(
    primary: Palette.brass,
    onPrimary: const Color(0xFF241A05),
    surface: Palette.bg,
    surfaceContainerLowest: Palette.bg,
    surfaceContainerLow: Palette.surface,
    surfaceContainer: Palette.surface,
    surfaceContainerHigh: Palette.surfaceHigh,
    surfaceContainerHighest: Palette.surfaceHigh,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    outline: Palette.line,
    outlineVariant: Palette.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Palette.line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.surface,
      selectedColor: Palette.brass.withValues(alpha: 0.18),
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Palette.brass,
      labelColor: Palette.text,
      unselectedLabelColor: Palette.muted,
      dividerColor: Palette.line,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Palette.brass,
      foregroundColor: Color(0xFF241A05),
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
  );
}
