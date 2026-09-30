import 'package:flutter/widgets.dart';
import '../template_tokens.dart';

/// Paleta, raios e fontes do template **Brasa 2.0** (docs/templates/01 §3): steakhouse
/// escuro, laranja brasa, âmbar nos preços, títulos em DM Serif Display e texto em Manrope.
const brasa2Tokens = TemplateTokens(
  bg: Color(0xFF120E0C),
  surface: Color(0xFF1E1815),
  surface2: Color(0xFF2A221D),
  text: Color(0xFFF7EFE6),
  muted: Color(0xFFB9A897),
  accent: Color(0xFFEC7433), // laranja brasa
  onAccent: Color(0xFF1A0C04),
  accent2: Color(0xFFF4B63F), // âmbar (preços, selos)
  onAccent2: Color(0xFF1A0C04),
  line: Color(0xFF34291F),
  line2: Color(0xFF5B4A3E),
  price: Color(0xFFF4B63F),
  hi: Color(0x21EC7433), // item selecionado
  art: Color(0xFF241C18),
  ok: Color(0xFF6FCF97),
  err: Color(0xFFFF7A6B),
  raio: 30,
  raioBotao: 22,
  raioTecla: 24,
  fonteDisplay: 'DMSerifDisplay',
  fonteTexto: 'Manrope',
  pesoDisplay: FontWeight.w400,
);

/// Fundo da folha do produto e do cartão da peça-também.
const brasa2FundoModal = Color(0xFF16110E);

/// Fundo do descanso (atrás da foto) e do brilho das fotos.
const brasa2FundoDescanso = Color(0xFF0C0907);
const brasa2FundoBrilho = Color(0xFF221A16);
const brasa2FundoHeroi = Color(0xFF1B1411);

/// Véu escuro atrás da folha do produto e do cartão da peça-também.
const brasa2Veu = Color(0x94000000);

/// Brilho quente atrás das fotos: `RadialGradient(center 50%/62%, raio .62,
/// [0x6BEC7433, transparente])` sobre [brasa2FundoBrilho] (docs/templates/01 §3).
const brasa2Brilho = RadialGradient(
  center: Alignment(0, .24),
  radius: .62,
  colors: [Color(0x6BEC7433), Color(0x00EC7433)],
);

/// Brilho do topo da folha do produto (mais forte: .55 de alfa; no protótipo o raio é 58%
/// do canto mais distante, que numa faixa de 1080×500 dá ~.72 do lado menor).
const brasa2BrilhoHeroi = RadialGradient(
  center: Alignment(0, .24),
  radius: .72,
  colors: [Color(0x8CEC7433), Color(0x00EC7433)],
);

/// Curva das entradas do protótipo (`cubic-bezier(.2,.8,.2,1)`).
const brasa2CurvaEntrada = Cubic(.2, .8, .2, 1);

/// Curva da folha do produto (`cubic-bezier(.2,.9,.2,1)`).
const brasa2CurvaFolha = Cubic(.2, .9, .2, 1);

/// Curva do "pop" (`cubic-bezier(.2,1.2,.4,1)`): passa um pouco do ponto e volta.
const brasa2CurvaPop = Cubic(.2, 1.2, .4, 1);

/// Cores do confete da confirmação: acento, âmbar, tinta e branco.
const brasa2CoresConfete = [
  Color(0xFFEC7433),
  Color(0xFFF4B63F),
  Color(0xFFF7EFE6),
  Color(0xFFFFFFFF),
];
