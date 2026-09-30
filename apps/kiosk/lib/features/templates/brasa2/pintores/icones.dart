import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Ícones de traço do protótipo (viewBox 24×24, `stroke-linecap/linejoin: round`), os
/// mesmos de `docs/templates/referencia/prototipo-app.js` (`IC`). Desenhados com
/// `CustomPainter`, sem imagem nem fonte de ícones — o traço fino é parte da cara do
/// Brasa 2.0. Cada desenho é convertido em `Path` UMA vez e fica em cache.
enum BrasaIcone {
  voltar,
  fechar,
  mais,
  menos,
  lixeira,
  sacola,
  cartao,
  dinheiro,
  pix,
  check,
  impressora,
  toque,
  comerAqui,
  paraLevar,
  chama,
  estrela,
  relogio,
  apagar,
  seta,
  usuario,
  documento,
  brilho,
  chevron,
  ondas,
  recibo,
}

/// Desenho de cada ícone: caminhos SVG, círculos (cx, cy, r) e retângulos (x, y, w, h, rx).
class _Desenho {
  const _Desenho({this.caminhos = const [], this.circulos = const [], this.retangulos = const []});
  final List<String> caminhos;
  final List<List<double>> circulos;
  final List<List<double>> retangulos;
}

const _desenhos = <BrasaIcone, _Desenho>{
  BrasaIcone.voltar: _Desenho(caminhos: ['M15 18l-6-6 6-6']),
  BrasaIcone.fechar: _Desenho(caminhos: ['M18 6L6 18M6 6l12 12']),
  BrasaIcone.mais: _Desenho(caminhos: ['M12 5v14M5 12h14']),
  BrasaIcone.menos: _Desenho(caminhos: ['M5 12h14']),
  BrasaIcone.lixeira: _Desenho(caminhos: ['M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14']),
  BrasaIcone.sacola:
      _Desenho(caminhos: ['M5 8h14l-1 12H6L5 8z', 'M9 8V6a3 3 0 0 1 6 0v2']),
  BrasaIcone.cartao: _Desenho(
    retangulos: [
      [2.5, 5, 19, 14, 2.5]
    ],
    caminhos: ['M2.5 10h19M6.5 15h4'],
  ),
  BrasaIcone.dinheiro: _Desenho(
    retangulos: [
      [2.5, 6, 19, 12, 2]
    ],
    circulos: [
      [12, 12, 2.8]
    ],
    caminhos: ['M6 9.5v5M18 9.5v5'],
  ),
  BrasaIcone.pix: _Desenho(caminhos: [
    'M12 2.8l4.2 4.2-4.2 4.2L7.8 7z',
    'M12 12.8l4.2 4.2-4.2 4.2-4.2-4.2z',
    'M2.8 12l4.2-4.2 4.2 4.2-4.2 4.2z',
    'M12.8 12l4.2-4.2 4.2 4.2-4.2 4.2z',
  ]),
  BrasaIcone.check: _Desenho(caminhos: ['M5 12.5l4.5 4.5L19 7.5']),
  BrasaIcone.impressora: _Desenho(
    caminhos: ['M7 9V3h10v6', 'M7 14h10v7H7z'],
    retangulos: [
      [3, 9, 18, 8, 2]
    ],
  ),
  BrasaIcone.toque: _Desenho(caminhos: [
    'M9 11V5.5a1.5 1.5 0 0 1 3 0V11',
    'M12 10.5a1.5 1.5 0 0 1 3 0V12a1.5 1.5 0 0 1 3 0v3.5A5.5 5.5 0 0 1 12.5 21h-1a5 5 0 0 1-4-2L4.6 15a1.6 1.6 0 0 1 2.4-2.1L9 15',
  ]),
  BrasaIcone.comerAqui: _Desenho(caminhos: [
    'M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10',
    'M17 21V3c-2 1-3 4-3 8h3',
  ]),
  BrasaIcone.paraLevar: _Desenho(caminhos: [
    'M6 8h12l-1.2 13H7.2L6 8z',
    'M9 8V6a3 3 0 0 1 6 0v2',
    'M10 13h4',
  ]),
  BrasaIcone.chama: _Desenho(caminhos: [
    'M12 22c4 0 7-2.8 7-7 0-3.5-2.4-5.6-3.6-8.5-.9 1.9-2 2.8-3.4 3-.2-3-1.6-5.6-4-7.5.3 4-3 6.2-3 11 0 4.2 3 9 7 9z',
  ]),
  BrasaIcone.estrela: _Desenho(caminhos: [
    'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
  ]),
  BrasaIcone.relogio: _Desenho(
    circulos: [
      [12, 12, 9]
    ],
    caminhos: ['M12 7v5l3 2'],
  ),
  BrasaIcone.apagar: _Desenho(caminhos: ['M21 5H9l-6 7 6 7h12z', 'M12.5 9.5l5 5M17.5 9.5l-5 5']),
  BrasaIcone.seta: _Desenho(caminhos: ['M5 12h14M13 6l6 6-6 6']),
  BrasaIcone.usuario: _Desenho(
    circulos: [
      [12, 8, 4]
    ],
    caminhos: ['M4 21c1-4.5 4.5-7 8-7s7 2.5 8 7'],
  ),
  BrasaIcone.documento: _Desenho(
    retangulos: [
      [3, 5, 18, 14, 2]
    ],
    circulos: [
      [9, 11, 2.2]
    ],
    caminhos: ['M5.8 16c.6-1.6 1.8-2.4 3.2-2.4s2.6.8 3.2 2.4M14.5 10h4M14.5 13.5h3'],
  ),
  BrasaIcone.brilho: _Desenho(caminhos: [
    'M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8',
  ]),
  BrasaIcone.chevron: _Desenho(caminhos: ['M9 6l6 6-6 6']),
  BrasaIcone.ondas: _Desenho(caminhos: [
    'M8.5 8.5a5 5 0 0 1 0 7M12 5a10 10 0 0 1 0 14M15.5 2a15 15 0 0 1 0 20',
  ]),
  BrasaIcone.recibo: _Desenho(caminhos: ['M6 3h12v18l-3-2-3 2-3-2-3 2z', 'M9 8h6M9 12h6']),
};

final Map<BrasaIcone, Path> _cache = {};

/// O `Path` do ícone no viewBox 24×24 (montado uma vez).
Path caminhoDoIcone(BrasaIcone i) => _cache.putIfAbsent(i, () {
      final d = _desenhos[i]!;
      final p = Path();
      for (final c in d.caminhos) {
        p.addPath(caminhoSvg(c), Offset.zero);
      }
      for (final c in d.circulos) {
        p.addOval(Rect.fromCircle(center: Offset(c[0], c[1]), radius: c[2]));
      }
      for (final r in d.retangulos) {
        p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r[0], r[1], r[2], r[3]), Radius.circular(r[4])));
      }
      return p;
    });

/// Converte o atributo `d` de um `<path>` SVG (M, L, H, V, C, S, A, Z — absolutos e
/// relativos, com repetição implícita) num `Path`.
Path caminhoSvg(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final p = Path();
  var i = 0;
  var cmd = 'M';
  var atual = Offset.zero;
  var inicio = Offset.zero;
  Offset? ultimoControle;
  bool ehComando(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (ehComando(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final base = rel ? atual : Offset.zero;
    switch (cmd.toUpperCase()) {
      case 'M':
        atual = base + Offset(n(), n());
        inicio = atual;
        p.moveTo(atual.dx, atual.dy);
        // Pares seguidos a um M são linhas.
        cmd = rel ? 'l' : 'L';
        ultimoControle = null;
      case 'L':
        atual = base + Offset(n(), n());
        p.lineTo(atual.dx, atual.dy);
        ultimoControle = null;
      case 'H':
        atual = Offset((rel ? atual.dx : 0) + n(), atual.dy);
        p.lineTo(atual.dx, atual.dy);
        ultimoControle = null;
      case 'V':
        atual = Offset(atual.dx, (rel ? atual.dy : 0) + n());
        p.lineTo(atual.dx, atual.dy);
        ultimoControle = null;
      case 'C':
        final c1 = base + Offset(n(), n());
        final c2 = base + Offset(n(), n());
        final fim = base + Offset(n(), n());
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, fim.dx, fim.dy);
        ultimoControle = c2;
        atual = fim;
      case 'S':
        final c1 = ultimoControle == null ? atual : atual * 2 - ultimoControle;
        final c2 = base + Offset(n(), n());
        final fim = base + Offset(n(), n());
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, fim.dx, fim.dy);
        ultimoControle = c2;
        atual = fim;
      case 'A':
        final rx = n();
        final ry = n();
        final rot = n();
        final grande = n() != 0;
        final horario = n() != 0;
        final fim = base + Offset(n(), n());
        p.arcToPoint(fim,
            radius: Radius.elliptical(rx, ry),
            rotation: rot * math.pi / 180,
            largeArc: grande,
            clockwise: horario);
        atual = fim;
        ultimoControle = null;
      case 'Z':
        p.close();
        atual = inicio;
        ultimoControle = null;
      default:
        i++;
    }
  }
  return p;
}

/// Um ícone de traço do protótipo, na cor e espessura pedidas.
class IconeBrasa extends StatelessWidget {
  const IconeBrasa(
    this.icone, {
    super.key,
    required this.tamanho,
    required this.cor,
    this.traco = 2.2,
  });

  final BrasaIcone icone;

  /// Lado em px de TELA (já convertido com `context.dz`).
  final double tamanho;
  final Color cor;

  /// Espessura do traço em unidades do viewBox (24).
  final double traco;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: CustomPaint(painter: _IconePainter(icone, cor, traco)),
      );
}

class _IconePainter extends CustomPainter {
  _IconePainter(this.icone, this.cor, this.traco);
  final BrasaIcone icone;
  final Color cor;
  final double traco;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 24;
    canvas.save();
    canvas.scale(k);
    canvas.drawPath(
      caminhoDoIcone(icone),
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = traco
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconePainter o) => o.icone != icone || o.cor != cor || o.traco != traco;
}
