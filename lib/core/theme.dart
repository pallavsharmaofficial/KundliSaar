import 'package:flutter/material.dart';

/// The palette comes from folk and temple painting rather than the cosmic
/// purple every astrology app wears: haldi and sindoor on a warm ground, ink
/// line work, gold used once per screen.
class Palette {
  static const Color haldi = Color(0xFFE3A008);
  static const Color sindoor = Color(0xFFC1272D);
  static const Color maroon = Color(0xFF6B1D1D);
  static const Color indigo = Color(0xFF1F2A5E);
  static const Color ink = Color(0xFF221A14);
  static const Color parchment = Color(0xFFFDF6E8);
  static const Color parchmentDeep = Color(0xFFF4E6C9);
  static const Color gold = Color(0xFFB8860B);
  static const Color nightGround = Color(0xFF14183A);
  static const Color nightSurface = Color(0xFF1D2350);
  static const Color nightParchment = Color(0xFFF1E4C3);
}

ThemeData buildTheme({required Brightness brightness}) {
  final bool dark = brightness == Brightness.dark;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: Palette.sindoor,
    brightness: brightness,
    primary: dark ? Palette.haldi : Palette.maroon,
    onPrimary: dark ? Palette.ink : Palette.parchment,
    secondary: dark ? Palette.parchmentDeep : Palette.indigo,
    surface: dark ? Palette.nightSurface : Palette.parchment,
    onSurface: dark ? Palette.nightParchment : Palette.ink,
  );

  // Devanagari sets taller than Latin, so the body scale is set for Hindi
  // first and English follows it.
  const String body = 'Mukta';
  const String display = 'Yatra';

  final TextTheme text = TextTheme(
    displaySmall: const TextStyle(
      fontFamily: display,
      fontSize: 30,
      height: 1.3,
    ),
    headlineMedium: const TextStyle(
      fontFamily: display,
      fontSize: 24,
      height: 1.35,
    ),
    titleLarge: const TextStyle(
      fontFamily: body,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleMedium: const TextStyle(
      fontFamily: body,
      fontSize: 19,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: const TextStyle(fontFamily: body, fontSize: 18, height: 1.55),
    bodyMedium: const TextStyle(fontFamily: body, fontSize: 17, height: 1.55),
    labelLarge: const TextStyle(
      fontFamily: body,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Palette.nightGround : Palette.parchment,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Palette.nightGround : Palette.parchment,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? Palette.nightSurface : Colors.white.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? Palette.nightSurface
          : Colors.white.withValues(alpha: 0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.2)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    chipTheme: ChipThemeData(
      labelStyle: text.bodyMedium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.12),
      space: 24,
    ),
  );
}
