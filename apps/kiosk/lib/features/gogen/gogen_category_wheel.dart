import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../data/catalog/catalog_models.dart';
import '../catalogo/produto_imagem.dart';
import 'gogen_tokens.dart';

/// Roleta cilíndrica HORIZONTAL de categorias (rodapé do menu GoGen). Porta a
/// física do template: projeção de cilindro deitado (item central = ativo),
/// arrasto + inércia + snap, e destaque CONTÍNUO do centro (escala/cor/nitidez
/// graduais). Rola sem começo nem fim (o último liga no primeiro).
///
/// A paleta é PARAMETRIZÁVEL (`trilho`/`corCentro`/`corLateral`) — assim a mesma
/// roleta serve o tema GoGen (flame) e o brasa (dourado no escuro). A arte de
/// cada item vem da própria categoria: imagem ▸ emoji ▸ emoji por palavra-chave.
class GogenCategoryWheel extends StatefulWidget {
  const GogenCategoryWheel({
    super.key,
    required this.categorias,
    required this.selecionadaId,
    required this.onSelecionar,
    this.trilho = GogenColors.grad,
    this.corCentro = Colors.white,
    this.corLateral = GogenColors.ink2,
    this.artClara = false,
  });

  final List<Categoria> categorias;
  final String? selecionadaId;
  final ValueChanged<String> onSelecionar;

  /// Gradiente do trilho de destaque no centro (flame no GoGen, dourado no brasa).
  final Gradient trilho;

  /// Cor do rótulo no centro (ativo) e nas laterais (esmaece até esta).
  final Color corCentro;
  final Color corLateral;

  /// Em fundo escuro (brasa), o emoji/arte precisa de um "prato" claro atrás pra
  /// não sumir. Em fundo claro (GoGen) fica sem prato.
  final bool artClara;

  @override
  State<GogenCategoryWheel> createState() => _GogenCategoryWheelState();
}

class _GogenCategoryWheelState extends State<GogenCategoryWheel>
    with SingleTickerProviderStateMixin {
  // Geometria (espelha o template): espaçamento no centro, faixa visível e o
  // ângulo por item (menor = cilindro de raio maior).
  static const double _p = 208; // espaçamento base (px lógicos)
  static const double _vis = 2.6; // itens visíveis de cada lado
  static const double _thetaDeg = 13;
  static double get _theta => _thetaDeg * math.pi / 180;
  static double get _raio => _p / _theta;

  late final Ticker _ticker;
  double _pos = 0; // posição contínua (qual item está no centro)
  double _target = 0;
  bool _arrastando = false;

  int get _n => widget.categorias.length;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    final i = widget.categorias.indexWhere((c) => c.id == widget.selecionadaId);
    _pos = _target = (i < 0 ? 0 : i).toDouble();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _mod(double n, int m) => ((n % m) + m) % m;
  double _wrap(double d) {
    d = _mod(d, _n);
    return d > _n / 2 ? d - _n : d;
  }

  void _tick(Duration _) {
    final diff = _target - _pos;
    if (diff.abs() < 0.004) {
      _pos = _target;
      _ticker.stop();
      _assentar();
    } else {
      _pos += diff * 0.16; // easing (mesma constante do template)
    }
    setState(() {});
  }

  void _anima() {
    if (!_ticker.isTicking) _ticker.start();
  }

  void _assentar() {
    final idx = _mod(_pos.roundToDouble(), _n).toInt();
    final cat = widget.categorias[idx];
    if (cat.id != widget.selecionadaId) widget.onSelecionar(cat.id);
  }

  void _irPara(int i) {
    _target = _pos.roundToDouble() + _wrap(i - _pos);
    _anima();
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 0) return const SizedBox(height: 212);
    return SizedBox(
      height: 212,
      child: LayoutBuilder(
        builder: (context, c) {
          final cx = c.maxWidth / 2;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              _arrastando = true;
              _ticker.stop();
            },
            onHorizontalDragUpdate: (d) {
              if (!_arrastando) return;
              setState(() => _pos -= d.delta.dx / _p);
            },
            onHorizontalDragEnd: (d) {
              _arrastando = false;
              final v = (d.primaryVelocity ?? 0) / _p; // itens/segundo
              _target = (_pos - v * 0.16).roundToDouble(); // inércia do arremesso
              _anima();
            },
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // trilho de destaque do centro (gradiente flame)
                Positioned(
                  left: cx - 100,
                  top: 9,
                  bottom: 9,
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      gradient: widget.trilho,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x6BFF5A1F),
                            blurRadius: 36,
                            offset: Offset(0, 16)),
                      ],
                    ),
                  ),
                ),
                for (int i = 0; i < _n; i++) ..._itemSeVisivel(i, cx),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _itemSeVisivel(int i, double cx) {
    final d = _wrap(i - _pos);
    final ad = d.abs();
    if (ad > _vis) return const [];
    final ang = d * _theta;
    final x = _raio * math.sin(ang);
    final cos = math.cos(ang);
    final sc = 0.60 + 0.40 * cos;
    final cN = math.max(0.0, 1 - ad); // proximidade do centro (0..1)
    final borda = math.min(1.0, (_vis - ad) / 0.7);
    final opacity = (0.14 + 0.86 * cos * cos) * borda;
    final cor = Color.lerp(widget.corLateral, widget.corCentro, cN)!;
    final cat = widget.categorias[i];

    const w = 196.0;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0008) // perspectiva
      ..translateByDouble(x, 0, 0, 1)
      ..rotateY(-d * _thetaDeg * math.pi / 180)
      ..scaleByDouble(sc, sc * (1 + 0.23 * cN), 1, 1);

    return [
      Positioned(
        left: cx - w / 2,
        top: 27,
        bottom: 27,
        width: w,
        child: Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _irPara(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + 0.38 * cN,
                    child: _Arte(categoria: cat, cN: cN, prato: widget.artClara),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 21 + 3 * cN,
                      color: cor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Arte de uma categoria na roleta: imagem ▸ emoji ▸ emoji por palavra-chave.
/// A `cor` da categoria vira o "prato" atrás do emoji; em fundo escuro (brasa)
/// um prato claro garante contraste mesmo sem cor definida.
class _Arte extends StatelessWidget {
  const _Arte({required this.categoria, required this.cN, required this.prato});
  final Categoria categoria;
  final double cN;
  final bool prato;

  static const double _size = 62;

  @override
  Widget build(BuildContext context) {
    if (categoria.imagemUrl != null) {
      return SizedBox(
        width: _size,
        height: _size,
        child: ProdutoImagem(
          url: categoria.imagemUrl,
          borderRadius: BorderRadius.circular(18),
        ),
      );
    }
    final emoji = categoria.emoji ?? gogenEmojiCategoria(categoria.nome);
    final corCat = gogenCorHex(categoria.cor);
    final fundo = corCat ?? (prato ? Colors.white.withValues(alpha: 0.10) : null);
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration:
          fundo == null ? null : BoxDecoration(color: fundo, shape: BoxShape.circle),
      child: Text(emoji, style: const TextStyle(fontSize: 40)),
    );
  }
}
