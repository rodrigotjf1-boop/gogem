import 'package:flutter/material.dart';

/// Paleta oficial GoGeM (manual da marca v2 — Robô-Totem).
abstract final class GogemColors {
  static const bg = Color(0xFF0F1713);
  static const panel = Color(0xFF16211B);
  static const line = Color(0xFF2A3A31);
  static const cheese = Color(0xFFFFC24B);
  static const cheeseDeep = Color(0xFFE8963B);
  static const cheeseLight = Color(0xFFFFDE8A);
  static const cheeseGlow = Color(0xFFFFF0C2);
  static const mint = Color(0xFF3ECF8E);
  static const mintDeep = Color(0xFF1FA96B);
  static const ink = Color(0xFFEDF3EE);
  static const inkDim = Color(0xFF9BB0A5);
  static const heat = Color(0xFFFF6B4A);
  static const paper = Color(0xFFF7F5EC);
}

/// Tema dark "game menu" do totem.
ThemeData gogemTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GogemColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: GogemColors.panel,
      primary: GogemColors.cheese,
      onPrimary: Color(0xFF1A1206),
      secondary: GogemColors.mint,
      error: GogemColors.heat,
    ),
    fontFamily: 'Tektur',
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
          fontFamily: 'Tektur', fontWeight: FontWeight.w600, fontSize: 64, color: GogemColors.ink),
      headlineMedium: const TextStyle(
          fontFamily: 'Tektur', fontWeight: FontWeight.w600, fontSize: 34, color: GogemColors.ink),
      titleLarge: const TextStyle(
          fontFamily: 'Tektur', fontWeight: FontWeight.w600, fontSize: 22, color: GogemColors.ink),
      bodyLarge: const TextStyle(fontSize: 18, color: GogemColors.ink),
      bodyMedium: const TextStyle(fontSize: 16, color: GogemColors.inkDim),
      labelLarge: const TextStyle(
          fontFamily: 'Tektur', fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: 1.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GogemColors.cheese,
        foregroundColor: const Color(0xFF1A1206),
        minimumSize: const Size(220, 72), // alvo de toque generoso p/ totem
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
            fontFamily: 'Tektur', fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: 1),
      ),
    ),
  );
}
