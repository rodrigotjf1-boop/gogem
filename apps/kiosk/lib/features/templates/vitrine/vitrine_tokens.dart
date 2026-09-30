import 'package:flutter/widgets.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// Paleta do template **Vitrine** (cardápio em stories) — docs/templates/02 §3.
/// Fundo quase preto, laranja-tomate na ação e amarelo nos preços e selos.
const vitrineTokens = TemplateTokens(
  bg: Color(0xFF0A0A0A),
  surface: Color(0xFF181818),
  surface2: Color(0xFF262626),
  text: Color(0xFFFFFFFF),
  muted: Color(0xB3FFFFFF), // branco 70%
  accent: Color(0xFFFF5B2E), // laranja-tomate
  onAccent: Color(0xFFFFFFFF),
  accent2: Color(0xFFFFD23F), // amarelo (preços, selos)
  onAccent2: Color(0xFF111111),
  line: Color(0x24FFFFFF),
  line2: Color(0x4DFFFFFF),
  price: Color(0xFFFFD23F),
  hi: Color(0x24FF5B2E),
  art: Color(0xFF1E1E1E),
  ok: Color(0xFF5EE08F),
  err: Color(0xFFFF6B5B),
  raio: 40,
  raioBotao: 999, // botões sempre pílula
  raioTecla: 28,
  fonteDisplay: 'Syne',
  fonteTexto: 'Onest',
  pesoDisplay: FontWeight.w800,
);

/// Vidro com blur: `BackdropFilter` + este branco translúcido + borda [vitrineVidroBorda].
const vitrineVidro = Color(0x24FFFFFF);
const vitrineVidroBorda = Color(0x4DFFFFFF);

/// Vidro SEM blur (perfil fraco): cor sólida translúcida, mesma borda.
const vitrineVidroSemBlur = Color(0xD9161616);

/// Fundo da folha do produto e do cartão flutuante (`--bg-modal`, 86%).
const vitrineFolha = Color(0xDB101010);

/// Tinta escura sobre o chip selecionado (branco).
const vitrineTinta111 = Color(0xFF111111);

/// Degradê de leitura sobre as fotos do feed (§5): escurece o topo e o pé da foto.
const vitrineDegradeLeitura = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x8C000000), Color(0x00000000), Color(0x00000000), Color(0xE6000000)],
  stops: [0, .22, .44, .80],
);

/// Movimento "cheio": Ken Burns e recorte flutuando só com animação e sem o modo reduzido
/// (a tabela §7 manda parar os dois em `reduzido`, no perfil `low` e em `off`).
bool vitrineMovimentoCheio(Movimento m) => m.anima && m.escala >= 1;

/// Estilos do template, já convertidos para a tela (`context.dz`).
extension EstilosVitrine on BuildContext {
  /// Título em Syne 800 com o espaçamento do protótipo (−0,04 em por padrão).
  TextStyle vDisplay(double px, {Color? cor, double? altura, double espacoEm = -.04}) =>
      vitrineTokens
          .display(dz(px), cor: cor, altura: altura)
          .copyWith(letterSpacing: dz(px) * espacoEm);

  /// Texto em Onest.
  TextStyle vTexto(double px,
          {FontWeight peso = FontWeight.w600, Color? cor, double? altura, double espacoEm = 0}) =>
      vitrineTokens.texto(dz(px), peso: peso, cor: cor, altura: altura, espaco: dz(px) * espacoEm);

  /// Kicker: Onest 800, CAIXA ALTA, espaçado (0,12–0,16 em).
  TextStyle vKicker(double px, {Color? cor, double espacoEm = .12}) =>
      vTexto(px, peso: FontWeight.w800, cor: cor ?? vitrineTokens.accent, espacoEm: espacoEm);
}
