import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'diner_tokens.dart';

/// Uma lâmpada do letreiro: centro (px de tela) e o índice dela na fileira — o atraso da
/// "perseguição" é `indice × 80 ms` (cada fileira recomeça do 0, como no protótipo).
class Lampada {
  const Lampada(this.centro, this.indice);
  final Offset centro;
  final int indice;
}

/// Todas as lâmpadas de um letreiro num único `CustomPainter` (docs/templates/05 §8):
/// UM controller de 1,6 s em [t]; cada lâmpada calcula a fase e a opacidade da tabela de
/// keyframes (acesa de 0 a 40 %, apagada a 25 % e sem brilho de 50 a 90 %). A lista de
/// pontos é alocada uma vez por tamanho, nada é criado por quadro.
/// [t] nulo = versão estática: todas acesas.
class LampadasPainter extends CustomPainter {
  LampadasPainter({
    required this.pontos,
    required this.raio,
    required this.brilho,
    this.t,
  })  : _g = Paint()..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, raio * .65),
        super(repaint: t);

  final Animation<double>? t;
  final List<Lampada> pontos;
  final double raio;

  /// Halo amarelo das acesas (desligado no perfil fraco).
  final bool brilho;
  final _p = Paint();
  final Paint _g;

  static const _corBrilho = Color(0xB3FFD35A);

  /// Opacidade na fase `f` (0..1) do ciclo.
  static double opacidade(double f) => f < .40
      ? 1
      : f < .50
          ? 1 - (f - .40) * 7.5
          : f < .90
              ? .25
              : .25 + (f - .90) * 7.5;

  @override
  void paint(Canvas c, Size s) {
    final v = t?.value;
    for (final l in pontos) {
      var a = 1.0;
      if (v != null) {
        a = opacidade((v - l.indice * 0.05) % 1.0);
      }
      if (brilho && a > .9) {
        _g.color = _corBrilho;
        c.drawCircle(l.centro, raio * 1.6, _g);
      }
      _p.color = dinerLampada.withAlpha((255 * a).round().clamp(0, 255));
      c.drawCircle(l.centro, raio, _p);
    }
  }

  @override
  bool shouldRepaint(covariant LampadasPainter o) =>
      !identical(o.pontos, pontos) || o.raio != raio || o.brilho != brilho || o.t != t;
}

/// Piso quadriculado: casas de [casa] px alternando [escura]/[clara] (o
/// `repeating-conic-gradient` do protótipo: canto superior direito e inferior esquerdo de
/// cada ladrilho escuros). Com [deslocamento] (0..1) a faixa anda um ladrilho por ciclo.
class XadrezPainter extends CustomPainter {
  XadrezPainter({
    required this.casa,
    required this.escura,
    required this.clara,
    this.deslocamento,
  }) : super(repaint: deslocamento);

  final double casa;
  final Color escura;
  final Color clara;
  final Animation<double>? deslocamento;
  final _p = Paint();

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Offset.zero & s);
    _p.color = clara;
    c.drawRect(Offset.zero & s, _p);
    _p.color = escura;
    final dx = (deslocamento?.value ?? 0) * casa * 2;
    final colunas = (s.width / casa).ceil() + 3;
    final linhas = (s.height / casa).ceil() + 1;
    for (var i = -2; i < colunas; i++) {
      for (var j = 0; j < linhas; j++) {
        if ((i + j).isOdd) {
          c.drawRect(Rect.fromLTWH(i * casa + dx, j * casa, casa, casa), _p);
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant XadrezPainter o) =>
      o.casa != casa || o.escura != escura || o.clara != clara || o.deslocamento != deslocamento;
}

/// Listras verticais do fundo da jukebox (`surface2`/`bg` de [largura] px).
class ListrasPainter extends CustomPainter {
  ListrasPainter({required this.largura, required this.a, required this.b});
  final double largura;
  final Color a;
  final Color b;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = b;
    c.drawRect(Offset.zero & s, p);
    p.color = a;
    for (var x = 0.0; x < s.width; x += largura * 2) {
      c.drawRect(Rect.fromLTWH(x, 0, largura, s.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant ListrasPainter o) => o.largura != largura || o.a != a || o.b != b;
}

/// Linha pontilhada horizontal (bolinhas de [espessura] px, uma a cada 2 × espessura),
/// centrada na altura do widget — o "dotted" do cardápio.
class PontilhadoPainter extends CustomPainter {
  PontilhadoPainter({required this.cor, required this.espessura});
  final Color cor;
  final double espessura;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = cor;
    final r = espessura / 2;
    final y = s.height / 2;
    for (var x = r; x <= s.width - r; x += espessura * 2) {
      c.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant PontilhadoPainter o) => o.cor != cor || o.espessura != espessura;
}

/// Borda tracejada arredondada (especial do dia, "Combina com seu pedido", cartão da senha).
class TracejadoPainter extends CustomPainter {
  TracejadoPainter({required this.cor, required this.espessura, required this.raio});
  final Color cor;
  final double espessura;
  final double raio;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    final m = espessura / 2;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(m, m, s.width - espessura, s.height - espessura),
      Radius.circular((raio - m).clamp(0, double.infinity)),
    );
    final traco = espessura * 2.6;
    final vao = espessura * 1.6;
    for (final metrica in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        final fim = (d + traco).clamp(0, metrica.length).toDouble();
        c.drawPath(metrica.extractPath(d, fim), p);
        d += traco + vao;
      }
    }
  }

  @override
  bool shouldRepaint(covariant TracejadoPainter o) => o.cor != cor || o.espessura != espessura || o.raio != raio;
}
