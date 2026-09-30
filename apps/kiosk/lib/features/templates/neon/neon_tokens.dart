import 'package:flutter/widgets.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// Paleta do **Neon 2.0** (docs/templates/04-neon-2.md §3): preto, verde-limão e magenta,
/// títulos largos em CAIXA ALTA (Unbounded) e texto em Rubik.
const neonTokens = TemplateTokens(
  bg: Color(0xFF07070C),
  surface: Color(0xFF12121C),
  surface2: Color(0xFF1C1C2A),
  text: Color(0xFFF4F4FA),
  muted: Color(0xFFA4A4BC),
  accent: Color(0xFFC8FF2E), // verde-limão
  onAccent: Color(0xFF07070C),
  accent2: Color(0xFFFF3EA5), // magenta
  onAccent2: Color(0xFF07070C),
  line: Color(0xFF262638),
  line2: Color(0xFF43435C),
  price: Color(0xFFC8FF2E),
  hi: Color(0x14C8FF2E),
  art: Color(0xFF161622),
  ok: Color(0xFFC8FF2E),
  err: Color(0xFFFF5577),
  raio: 24,
  raioBotao: 16,
  raioTecla: 14,
  fonteDisplay: 'Unbounded',
  fonteTexto: 'Rubik',
  pesoDisplay: FontWeight.w800,
  displayCaixaAlta: true,
);

/// 3ª cor do néon: só nos gradientes de brilho (anéis, borda girando, confete).
const neonCiano = Color(0xFF3EE0FF);

/// Fundo das folhas e cartões por cima da tela (produto, peça-também) — `--bg-modal`.
const neonFolha = Color(0xFF0C0C14);

/// Fundo interno do destaque do cardápio.
const neonFundoDestaque = Color(0xFF0E0E17);

/// Área da foto nos tiles; o recorte ganha um fundo mais fechado com brilho radial.
const neonFundoFoto = Color(0xFF171724);
const neonFundoRecorte = Color(0xFF141420);

/// Brilho verde padrão (`BoxShadow` com desfoque) — só no perfil forte, ver [NeonMov.brilho].
const neonBrilho = Color(0x73C8FF2E);

/// As regras de movimento do Neon (docs/templates/04-neon-2.md §7).
extension NeonMov on Movimento {
  /// Loops contínuos (faixas, anéis, borda girando, cintilação, flutuação, piscas): só no
  /// perfil forte com animação cheia. Em `reduzido`, `low` e `off` tudo fica no quadro
  /// estático — no Tinker Board nenhum desses `AnimationController` pode rodar.
  bool get loops => anima && particulas;

  /// Brilhos de néon (sombras com desfoque): desligados no perfil `low` (sem blur).
  bool get brilho => blur;
}

/// Unbounded (títulos, preços grandes, senha). [espaco] em `em` (−0,02 nos títulos).
TextStyle neonDisplay(
  double tamanho, {
  Color? cor,
  double altura = 1.0,
  double espaco = -.02,
  FontWeight peso = FontWeight.w800,
  List<Shadow>? sombras,
}) =>
    TextStyle(
      fontFamily: neonTokens.fonteDisplay,
      fontSize: tamanho,
      fontWeight: peso,
      height: altura,
      letterSpacing: espaco * tamanho,
      color: cor ?? neonTokens.text,
      shadows: sombras,
    );

/// Rubik (corpo, abas, botões). [espaco] em `em`.
TextStyle neonTexto(
  double tamanho, {
  FontWeight peso = FontWeight.w400,
  Color? cor,
  double? altura,
  double espaco = 0,
}) =>
    TextStyle(
      fontFamily: neonTokens.fonteTexto,
      fontSize: tamanho,
      fontWeight: peso,
      height: altura,
      letterSpacing: espaco * tamanho,
      color: cor ?? neonTokens.text,
    );

/// Os mesmos tokens com outra cor de texto (o CPF válido fica em `accent`, §6.6).
TemplateTokens neonComTexto(Color texto) => TemplateTokens(
      bg: neonTokens.bg,
      surface: neonTokens.surface,
      surface2: neonTokens.surface2,
      text: texto,
      muted: neonTokens.muted,
      accent: neonTokens.accent,
      onAccent: neonTokens.onAccent,
      accent2: neonTokens.accent2,
      onAccent2: neonTokens.onAccent2,
      line: neonTokens.line,
      line2: neonTokens.line2,
      price: neonTokens.price,
      hi: neonTokens.hi,
      art: neonTokens.art,
      ok: neonTokens.ok,
      err: neonTokens.err,
      raio: neonTokens.raio,
      raioBotao: neonTokens.raioBotao,
      raioTecla: neonTokens.raioTecla,
      fonteDisplay: neonTokens.fonteDisplay,
      fonteTexto: neonTokens.fonteTexto,
      pesoDisplay: neonTokens.pesoDisplay,
      displayCaixaAlta: neonTokens.displayCaixaAlta,
    );
