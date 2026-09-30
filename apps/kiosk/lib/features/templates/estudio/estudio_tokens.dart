import 'package:flutter/material.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// Paleta do **Estúdio** (docs/templates/03-estudio.md §3): fundo claro de estúdio
/// fotográfico, azul elétrico e amarelo. É o único template claro com visual "tech".
const estudioTokens = TemplateTokens(
  bg: Color(0xFFEEF1F5),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFE2E7EF),
  text: Color(0xFF0E1A2B), // azul-marinho quase preto
  muted: Color(0xFF56637A),
  accent: Color(0xFF2F55F4), // azul elétrico
  onAccent: Color(0xFFFFFFFF),
  accent2: Color(0xFFFFC83D), // amarelo
  onAccent2: Color(0xFF0E1A2B),
  line: Color(0xFFD7DEE8),
  line2: Color(0xFFAAB6C6),
  price: Color(0xFF0E1A2B),
  hi: Color(0xFFE6ECFF),
  art: Color(0xFFF1F4F8),
  ok: Color(0xFF1E9E5A),
  err: Color(0xFFD93A3A),
  raio: 38,
  raioBotao: 28,
  raioTecla: 26,
  fonteDisplay: 'Sora',
  fonteTexto: 'Figtree',
  pesoDisplay: FontWeight.w800,
  claro: true,
);

/// Cores dos discos atrás dos produtos: rotação por índice (ou a `categoria.cor`).
const estudioDiscos = [
  Color(0xFF2F55F4),
  Color(0xFFFFC83D),
  Color(0xFFFF7A59),
  Color(0xFF7BC8A4),
];

/// Cores fixas do template que não são tokens (valores do protótipo).
abstract final class EstudioCores {
  static const branco = Color(0xFFFFFFFF);

  /// Fundo dos cartões centrais (produto, peça também).
  static const fundoModal = Color(0xFFF7F9FB);

  /// Topo do cartão do produto, atrás do disco.
  static const fundoHeroi = Color(0xFFE4EAF6);

  /// Círculo decorativo do canto do descanso.
  static const circuloDescanso = Color(0xFFE2E8F3);

  /// Véu escuro atrás dos cartões centrais (`rgba(0,0,0,.58)`).
  static const cortina = Color(0x94000000);

  /// Sombra elíptica no "chão" do palco do descanso.
  static const sombraChao = Color(0x240E1A2B);

  /// Círculo branco translúcido no canto do cartão de destaque.
  static const brilhoDestaque = Color(0x2EFFFFFF);

  /// Sombra grande dos cartões centrais.
  static const sombraModal = Color(0x4D000000);

  /// Fundo do X que fecha o produto.
  static const botaoFechar = Color(0x80000000);

  /// Fenda da impressora do recibo.
  static const fenda = Color(0xFF222222);

  /// Maquininha desenhada (tela e corpo).
  static const telaMaquininha = Color(0xFFCFE8D8);
  static const corpoMaquininha = Color(0xFF1C1E23);

  /// Botão azul "Atualizar" que aparece na tela da Point.
  static const atualizarPoint = Color(0xFF2D7FF9);
}

/// Curva "tech" do template: sai rápido e assenta devagar (`cubic-bezier(.2,.9,.2,1)`).
const curvaEstudio = Cubic(.2, .9, .2, 1);

/// Troca de tela (`cubic-bezier(.2,.8,.2,1)`).
const curvaTela = Cubic(.2, .8, .2, 1);

/// Entrada com um leve "pulo" (`cubic-bezier(.2,1.2,.4,1)`).
const curvaPulo = Cubic(.2, 1.2, .4, 1);

/// Sombra dupla dos cards (§3), convertida para px de tela com o fator `k` da escala.
List<BoxShadow> sombraCard(double k) => [
      BoxShadow(color: const Color(0x0D0E1A2B), blurRadius: 2 * k, offset: Offset(0, 1 * k)),
      BoxShadow(color: const Color(0x120E1A2B), blurRadius: 34 * k, offset: Offset(0, 16 * k)),
    ];

/// Sombra grande dos cartões centrais (produto, peça também).
List<BoxShadow> sombraModal(double k) => [
      BoxShadow(color: EstudioCores.sombraModal, blurRadius: 80 * k, offset: Offset(0, 40 * k)),
    ];

/// Cor do disco na posição [i]: a `categoria.cor` do painel ("#RRGGBB") quando houver,
/// senão a rotação de [estudioDiscos].
Color corDisco(int i, [String? hex]) {
  final h = hex?.trim() ?? '';
  if (h.length == 7 && h.startsWith('#')) {
    final v = int.tryParse(h.substring(1), radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return estudioDiscos[i % estudioDiscos.length];
}

/// Tinta legível sobre um fundo colorido: branco no azul, `text` no amarelo, coral e verde.
Color tintaSobre(Color fundo) =>
    fundo.computeLuminance() < .3 ? EstudioCores.branco : estudioTokens.text;

/// Movimento "cheio": perfil `high` com `animacoes: cheio`. Só nele há inclinação 3D e
/// flutuação; no reduzido/`low` o template fica no essencial (docs/templates/03 §7).
bool movimentoCheio(Movimento m) => m.anima && m.escala >= 1;

/// Duração que some quando o movimento está desligado (o quadro final aparece direto).
Duration duracao(Movimento m, int ms) => m.anima ? m.d(ms) : Duration.zero;

/// Tema CLARO das telas do Estúdio (o tema global do app é escuro).
final ThemeData temaEstudio = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2F55F4),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFC83D),
    onSecondary: Color(0xFF0E1A2B),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0E1A2B),
    error: Color(0xFFD93A3A),
  ),
  scaffoldBackgroundColor: const Color(0xFFEEF1F5),
  fontFamily: 'Figtree',
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFF2F55F4)),
  splashColor: const Color(0x1A2F55F4),
  highlightColor: const Color(0x0A2F55F4),
);
