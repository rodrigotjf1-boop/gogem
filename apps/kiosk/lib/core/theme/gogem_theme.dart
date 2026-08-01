import 'package:flutter/material.dart';
import '../../data/catalog/aparencia.dart';

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

/// Tema dark "game menu" do totem, com os padrões da marca GoGeM.
ThemeData gogemTheme() => temaDe(Aparencia.padrao);

/// Tema do totem DERIVADO da aparência da loja (Fase 6): cores/raio/fonte
/// configuráveis no admin re-tematizam o app. `onPrimary` é calculado pelo
/// contraste (texto escuro em cores claras, claro em escuras). A fonte só troca
/// de fato se o asset existir no bundle (Tektur vem embutido); senão degrada
/// para a fonte padrão — sem quebrar.
ThemeData temaDe(Aparencia ap) {
  final onPrimary = ap.corPrimaria.computeLuminance() > 0.5
      ? const Color(0xFF1A1206)
      : Colors.white;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ap.corFundo,
    colorScheme: ColorScheme.dark(
      surface: ap.corPainel,
      primary: ap.corPrimaria,
      onPrimary: onPrimary,
      secondary: ap.corDestaque,
      error: GogemColors.heat,
    ),
    fontFamily: ap.fonteDisplay,
  );
  final r = ap.raio;
  // Presets editoriais (Brasa steakhouse / Burger House): tipografia display
  // maior, mais peso e espaçamento (leitura editorial, CAIXA ALTA). O fundo
  // quente/cards ficam na tela do catálogo (que também lê ap.brasa/ap.burger).
  final brasa = ap.editorial;
  final pesoDisplay = brasa ? FontWeight.w800 : FontWeight.w600;
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: TextStyle(
          fontFamily: ap.fonteDisplay,
          fontWeight: pesoDisplay,
          fontSize: brasa ? 72 : 64,
          letterSpacing: brasa ? 1.5 : 0,
          color: GogemColors.ink),
      headlineMedium: TextStyle(
          fontFamily: ap.fonteDisplay,
          fontWeight: pesoDisplay,
          fontSize: brasa ? 38 : 34,
          letterSpacing: brasa ? 2 : 0,
          color: GogemColors.ink),
      titleLarge: TextStyle(
          fontFamily: ap.fonteDisplay,
          fontWeight: pesoDisplay,
          fontSize: brasa ? 25 : 22,
          letterSpacing: brasa ? 0.8 : 0,
          color: GogemColors.ink),
      bodyLarge: const TextStyle(fontSize: 18, color: GogemColors.ink),
      bodyMedium: const TextStyle(fontSize: 16, color: GogemColors.inkDim),
      labelLarge: TextStyle(
          fontFamily: ap.fonteDisplay,
          fontWeight: pesoDisplay,
          fontSize: 18,
          letterSpacing: brasa ? 2 : 1.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ap.corPrimaria,
        foregroundColor: onPrimary,
        minimumSize: const Size(220, 72), // alvo de toque generoso p/ totem
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r + 2)),
        textStyle: TextStyle(
            fontFamily: ap.fonteDisplay, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: 1),
      ),
    ),
  );
}
