import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';
import 'produto_arte.dart';

/// Barra inferior do catálogo: sacola com contador, "Sua sacola · N itens", total e
/// "Ver sacola" (docs/templates/00 §3.5). Quando o total muda, dá um "pulo"
/// (1 → 1,04 → 0,98 → 1 em 500 ms). [alvo] marca o ícone da sacola, destino do voo.
class BarraSacola extends StatefulWidget {
  const BarraSacola({
    super.key,
    required this.itens,
    required this.totalCentavos,
    required this.onVerSacola,
    required this.tokens,
    this.alvo,
    this.mov = Movimento.parado,
    this.fundo,
    this.tinta,
    this.botaoFundo,
    this.botaoTinta,
    this.raio,
  });

  final int itens;
  final int totalCentavos;
  final VoidCallback onVerSacola;
  final TemplateTokens tokens;
  final GlobalKey? alvo;
  final Movimento mov;
  final Color? fundo;
  final Color? tinta;
  final Color? botaoFundo;
  final Color? botaoTinta;

  /// Raio em px de desenho (padrão: `tokens.raio`).
  final double? raio;

  @override
  State<BarraSacola> createState() => _BarraSacolaState();
}

class _BarraSacolaState extends State<BarraSacola> with SingleTickerProviderStateMixin {
  late final AnimationController _bump;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _bump = AnimationController(vsync: this, duration: widget.mov.d(500));
    _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.04), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: .98), weight: 35),
    TweenSequenceItem(tween: Tween(begin: .98, end: 1), weight: 30),
    ]).animate(CurvedAnimation(parent: _bump, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant BarraSacola old) {
    super.didUpdateWidget(old);
    if (old.totalCentavos != widget.totalCentavos && widget.mov.anima) {
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final fundo = widget.fundo ?? t.accent;
    final tinta = widget.tinta ?? t.onAccent;
    final vazia = widget.itens == 0;
    final alto = context.dz(128);
    final raio = context.dz(widget.raio ?? t.raio);
    final rotulo = vazia
        ? 'Sua sacola está vazia'
        : 'Sua sacola · ${widget.itens} ${widget.itens == 1 ? 'item' : 'itens'}';
    return ScaleTransition(
      scale: _escala,
      child: Material(
        key: const ValueKey('barra-sacola'),
        color: fundo,
        borderRadius: BorderRadius.circular(raio),
        elevation: 6,
        shadowColor: const Color(0x66000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(raio),
          onTap: vazia ? null : widget.onVerSacola,
          child: SizedBox(
            height: alto,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.dz(28)),
              child: Row(children: [
                SizedBox(
                  key: widget.alvo,
                  width: context.dz(72),
                  height: context.dz(72),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Center(
                      child: Icon(Icons.shopping_bag_outlined, color: tinta, size: context.dz(52)),
                    ),
                    if (!vazia)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: context.dz(8)),
                          constraints: BoxConstraints(minWidth: context.dz(32)),
                          height: context.dz(32),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tinta,
                            borderRadius: BorderRadius.circular(context.dz(16)),
                          ),
                          child: Text('${widget.itens}',
                              key: const ValueKey('sacola-contador'),
                              style: t.texto(context.dz(19), peso: FontWeight.w800, cor: fundo)),
                        ),
                      ),
                  ]),
                ),
                SizedBox(width: context.dz(20)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rotulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.texto(context.dz(22), peso: FontWeight.w700, cor: tinta.withAlpha(210))),
                      Text(formatCentavos(widget.totalCentavos),
                          key: const ValueKey('sacola-total'),
                          maxLines: 1,
                          style: t.texto(context.dz(38), peso: FontWeight.w800, cor: tinta)),
                    ],
                  ),
                ),
                Container(
                  height: context.dz(80),
                  padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.botaoFundo ?? tinta,
                    borderRadius: BorderRadius.circular(context.dz(t.raioBotao)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ver sacola',
                        style: t.texto(context.dz(26),
                            peso: FontWeight.w800, cor: widget.botaoTinta ?? fundo)),
                    SizedBox(width: context.dz(10)),
                    Icon(Icons.arrow_forward_rounded,
                        size: context.dz(28), color: widget.botaoTinta ?? fundo),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ao adicionar, uma cópia da foto voa em curva até a sacola (820 ms, `easeInOutCubic`,
/// escala 1 → 0,12), pelo `Overlay` (docs/templates/00 §3.5). Sem [Movimento.anima], não voa.
class VooParaSacola {
  static void voar(
    BuildContext context, {
    required GlobalKey origem,
    required GlobalKey destino,
    required String? url,
    required TemplateTokens tokens,
    Movimento mov = Movimento.parado,
  }) {
    if (!mov.anima) return;
    final overlay = Overlay.maybeOf(context);
    final ro = origem.currentContext?.findRenderObject();
    final rd = destino.currentContext?.findRenderObject();
    final ov = overlay?.context.findRenderObject();
    if (overlay == null || ro is! RenderBox || rd is! RenderBox || ov is! RenderBox) return;
    if (!ro.hasSize || !rd.hasSize) return;
    final de = ro.localToGlobal(Offset.zero, ancestor: ov) & ro.size;
    final para = rd.localToGlobal(Offset.zero, ancestor: ov) & rd.size;
    late OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (_) => _Voo(
        de: de,
        para: para,
        url: url,
        tokens: tokens,
        duracao: mov.d(820),
        aoTerminar: () => entrada.remove(),
      ),
    );
    overlay.insert(entrada);
  }
}

class _Voo extends StatefulWidget {
  const _Voo({
    required this.de,
    required this.para,
    required this.url,
    required this.tokens,
    required this.duracao,
    required this.aoTerminar,
  });
  final Rect de;
  final Rect para;
  final String? url;
  final TemplateTokens tokens;
  final Duration duracao;
  final VoidCallback aoTerminar;

  @override
  State<_Voo> createState() => _VooState();
}

class _VooState extends State<_Voo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duracao)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.aoTerminar();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.de.center;
    final b = widget.para.center;
    // Ponto de controle acima do meio do caminho: a foto "sobe" e cai na sacola.
    final ctrl = Offset((a.dx + b.dx) / 2, (a.dy < b.dy ? a.dy : b.dy) - 160);
    final lado = widget.de.shortestSide;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final u = 1 - t;
          final p = a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
          final escala = 1 - .88 * t;
          final d = lado * escala;
          return Stack(children: [
            Positioned(
              left: p.dx - d / 2,
              top: p.dy - d / 2,
              width: d,
              height: d,
              child: ClipOval(
                child: ProdutoArte(url: widget.url, tokens: widget.tokens, sombra: false),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
