import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Uma brasa: posição e velocidade em px de DESENHO (tela de 1080 de largura).
class _Brasa {
  _Brasa(this._r) {
    renascer(inicio: true);
  }

  final math.Random _r;
  double x = 0, y = 0, raio = 0, vy = 0, vx = 0, vida = 0, max = 0, fase = 0;

  /// Nasce embaixo (y 1500–1900); na primeira leva já espalhada (700–1900), para a tela
  /// não começar vazia — como no protótipo.
  void renascer({bool inicio = false}) {
    x = 200 + _r.nextDouble() * 680;
    y = inicio ? 700 + _r.nextDouble() * 1200 : 1500 + _r.nextDouble() * 400;
    raio = 1.5 + _r.nextDouble() * 3.5;
    vy = .6 + _r.nextDouble() * 1.8;
    vx = (_r.nextDouble() - .5) * .6;
    vida = 0;
    max = 380 + _r.nextDouble() * 500;
    fase = _r.nextDouble() * 6;
  }

  /// Um quadro: sobe, oscila em x e envelhece. Morre acima de y = 200 ou no fim da vida.
  void passo() {
    vida++;
    y -= vy;
    x += vx + math.sin((vida + fase * 50) / 40) * .5;
    if (vida >= max || y < 200) renascer();
  }

  double get alfa => (1 - vida / max).clamp(0.0, 1.0);
}

/// Brasas subindo sobre a foto do descanso (docs/templates/01 §6.1 e §8): 90 partículas
/// numa lista alocada UMA vez, avançadas por um `Ticker` e desenhadas por um único
/// `CustomPainter` com `BlendMode.plus`. Só existe com `Movimento.particulas` — quem monta
/// decide; aqui não há versão estática.
class Brasas extends StatefulWidget {
  const Brasas({super.key, this.quantidade = 90, this.semente = 11});

  final int quantidade;
  final int semente;

  @override
  State<Brasas> createState() => _BrasasState();
}

class _BrasasState extends State<Brasas> with SingleTickerProviderStateMixin {
  late final List<_Brasa> _brasas;
  final _quadro = ValueNotifier<int>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.semente);
    _brasas = List.generate(widget.quantidade, (_) => _Brasa(r), growable: false);
    _ticker = createTicker((_) {
      for (final b in _brasas) {
        b.passo();
      }
      _quadro.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _quadro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('brasas'),
            size: Size.infinite,
            painter: BrasasPainter(_brasas, _quadro),
          ),
        ),
      );
}

/// Desenha as brasas (a posição é avançada fora do `paint`, pelo `Ticker`).
class BrasasPainter extends CustomPainter {
  /// [quadro] avisa a cada passo do `Ticker` (é o `repaint`).
  BrasasPainter(this._brasas, ValueListenable<int> quadro) : super(repaint: quadro);

  final List<_Brasa> _brasas;
  final _p = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas c, Size s) {
    // Largura e altura escalam à parte: em tela baixa (paisagem) as brasas continuam
    // subindo do pé da tela, e não somem abaixo dela.
    final k = s.width / 1080;
    final ky = s.height / 1920;
    for (final b in _brasas) {
      final a = b.alfa;
      if (a <= 0) continue;
      final centro = Offset(b.x * k, b.y * ky);
      final r = b.raio * 4 * k;
      _p.shader = ui.Gradient.radial(centro, r, [
        Color.fromARGB((255 * a).round(), 255, 214, 140),
        Color.fromARGB((178 * a).round(), 255, 120, 40),
        const Color(0x00FF5014),
      ], const [0, .35, 1]);
      c.drawCircle(centro, r, _p);
    }
  }

  @override
  bool shouldRepaint(covariant BrasasPainter o) => !identical(o._brasas, _brasas);
}
