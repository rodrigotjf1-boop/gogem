import 'package:flutter/widgets.dart';
import '../template_tokens.dart';

/// Paleta, raios e fontes do **Diner 58** (docs/templates/05 §3). Template CLARO: creme,
/// vermelho de lanchonete, menta e marrom-café nos contornos e nas sombras "duras".
const dinerTokens = TemplateTokens(
  bg: Color(0xFFFFF4E2), // creme
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFFBE6C8),
  text: Color(0xFF2A1512), // marrom-café (contornos e sombras "duras")
  muted: Color(0xFF6E4E45),
  accent: Color(0xFFD3202A), // vermelho diner
  onAccent: Color(0xFFFFF4E2),
  accent2: Color(0xFF8FD5C7), // menta
  onAccent2: Color(0xFF2A1512),
  line: Color(0xFFEED6B6),
  line2: Color(0xFFC9A987),
  price: Color(0xFFD3202A),
  hi: Color(0xFFFFE7E3),
  art: Color(0xFFFDEBD0),
  ok: Color(0xFF1E8F6E),
  err: Color(0xFFD3202A),
  raio: 30,
  raioBotao: 999,
  raioTecla: 22,
  fonteDisplay: 'Bungee',
  fonteTexto: 'Nunito',
  pesoDisplay: FontWeight.w400,
  claro: true,
);

/// Os mesmos tokens com a tinta em creme: textos e etapas sobre o cabeçalho vermelho do
/// cardápio (o `Etapas` comum pinta o passo atual com `text` e os outros com `muted`).
const dinerTokensInvertidos = TemplateTokens(
  bg: Color(0xFFD3202A),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFFBE6C8),
  text: Color(0xFFFFF4E2),
  muted: Color(0xFFFFF4E2),
  accent: Color(0xFFFFF4E2),
  onAccent: Color(0xFFD3202A),
  accent2: Color(0xFF8FD5C7),
  onAccent2: Color(0xFF2A1512),
  line: Color(0x40FFF4E2),
  line2: Color(0x73FFF4E2),
  price: Color(0xFFFFF4E2),
  hi: Color(0x29FFF4E2),
  art: Color(0xFFFDEBD0),
  ok: Color(0xFF1E8F6E),
  err: Color(0xFFD3202A),
  raio: 30,
  raioBotao: 999,
  raioTecla: 22,
  fonteDisplay: 'Bungee',
  fonteTexto: 'Nunito',
  pesoDisplay: FontWeight.w400,
  claro: false,
);

/// Cursiva do letreiro ("Diner", "Aberto", "Toque para começar", "Especial do dia").
const dinerCursiva = 'Yellowtail';

/// Lâmpada acesa do letreiro; o brilho em volta é [dinerBrilho].
const dinerLampada = Color(0xFFFFE7A0);
const dinerBrilho = Color(0xFFFFD35A);

/// Sombra 3D do letreiro (0/18, sem desfoque).
const dinerVermelhoEscuro = Color(0xFF8F141B);

/// Fundo dos cartões centrais (produto, peça também) — `--bg-modal` do protótipo.
const dinerModal = Color(0xFFFFF8EE);

/// Luz acesa do botão jukebox.
const dinerLuzJukebox = Color(0xFFFF4040);

/// Véu escuro atrás dos cartões centrais (rgba(0,0,0,.58) sobre o creme do protótipo).
const dinerVeu = Color(0xFF6B655D);

/// Faixa vermelha do cabeçalho vista através do véu.
const dinerVeuCabecalho = Color(0xFF5A1117);

/// Sombra "dura" de contorno: cor sólida deslocada para baixo, sem desfoque.
BoxShadow sombraDura(double dy, {Color cor = const Color(0xFF2A1512)}) =>
    BoxShadow(color: cor, offset: Offset(0, dy), blurRadius: 0);

/// Estilo na cursiva do template.
TextStyle dinerScript(double tamanho, {Color? cor, List<Shadow>? sombras, double altura = 1}) => TextStyle(
      fontFamily: dinerCursiva,
      fontSize: tamanho,
      fontWeight: FontWeight.w400,
      height: altura,
      color: cor ?? dinerTokens.accent,
      shadows: sombras,
    );
