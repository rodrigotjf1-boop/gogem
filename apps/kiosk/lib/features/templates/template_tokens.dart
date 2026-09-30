import 'package:flutter/widgets.dart';

/// Paleta, raios e fontes de um template do totem (docs/templates/00 §3.3).
///
/// Cada template define a sua como `const`. Cor com alfa fixo vai em `Color(0xAARRGGBB)`;
/// alfa dinâmico, com `withAlpha(...)` — nunca `withOpacity`/`withValues` (CLAUDE.md).
class TemplateTokens {
  const TemplateTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accent2,
    required this.onAccent2,
    required this.line,
    required this.line2,
    required this.price,
    required this.hi,
    required this.art,
    required this.ok,
    required this.err,
    required this.raio,
    required this.raioBotao,
    required this.raioTecla,
    required this.fonteDisplay,
    required this.fonteTexto,
    this.pesoDisplay = FontWeight.w400,
    this.displayCaixaAlta = false,
    this.claro = false,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color accent2;
  final Color onAccent2;
  final Color line;
  final Color line2;
  final Color price;

  /// Fundo do item selecionado (o acento em transparência).
  final Color hi;

  /// Fundo atrás das fotos de produto.
  final Color art;
  final Color ok;
  final Color err;

  /// Raios em px de desenho (tela de 1080 de largura) — converta com `context.dz`.
  final double raio;
  final double raioBotao;
  final double raioTecla;

  final String fonteDisplay;
  final String fonteTexto;
  final FontWeight pesoDisplay;

  /// Títulos em CAIXA ALTA (Neon 2.0).
  final bool displayCaixaAlta;

  /// Template de fundo claro (Estúdio, Diner 58).
  final bool claro;

  /// Estilo de título na fonte display do template.
  TextStyle display(double tamanho, {Color? cor, double? altura, FontStyle? estilo}) =>
      TextStyle(
        fontFamily: fonteDisplay,
        fontSize: tamanho,
        fontWeight: pesoDisplay,
        fontStyle: estilo,
        height: altura,
        color: cor ?? text,
      );

  /// Estilo de texto corrido na fonte de texto do template.
  TextStyle texto(double tamanho,
          {FontWeight peso = FontWeight.w600, Color? cor, double? altura, double? espaco}) =>
      TextStyle(
        fontFamily: fonteTexto,
        fontSize: tamanho,
        fontWeight: peso,
        height: altura,
        letterSpacing: espaco,
        color: cor ?? text,
      );

  /// Título respeitando a caixa do template.
  String caixa(String s) => displayCaixaAlta ? s.toUpperCase() : s;
}
