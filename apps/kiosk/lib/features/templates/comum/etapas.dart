import 'package:flutter/material.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// Barra de 4 passos do pedido: Cardápio, Sacola, Identificação, Pagamento
/// (docs/templates/00 §3.5). Concluídos com ✓ e barra cheia; o atual enche em 800 ms.
class Etapas extends StatelessWidget {
  const Etapas({
    super.key,
    required this.atual,
    required this.tokens,
    this.mov = Movimento.parado,
    this.corBarra,
    this.corTrilho,
  });

  static const nomes = ['Cardápio', 'Sacola', 'Identificação', 'Pagamento'];

  /// 0..3.
  final int atual;
  final TemplateTokens tokens;
  final Movimento mov;
  final Color? corBarra;
  final Color? corTrilho;

  @override
  Widget build(BuildContext context) {
    final barra = corBarra ?? tokens.accent;
    final trilho = corTrilho ?? tokens.line;
    final alto = context.dz(8);
    return Row(
      key: ValueKey('etapas-$atual'),
      children: [
        for (var i = 0; i < nomes.length; i++) ...[
          if (i > 0) SizedBox(width: context.dz(14)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(alto),
                child: SizedBox(
                  height: alto,
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: trilho),
                    if (i < atual)
                      ColoredBox(color: barra)
                    else if (i == atual)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: mov.anima ? 0 : 1, end: 1),
                        duration: mov.anima ? mov.d(800) : Duration.zero,
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: ColoredBox(color: barra),
                        ),
                      ),
                  ]),
                ),
              ),
              SizedBox(height: context.dz(10)),
              Text(
                i < atual ? '✓ ${nomes[i]}' : '${i + 1}. ${nomes[i]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.texto(context.dz(19),
                    peso: FontWeight.w800,
                    cor: i < atual ? barra : (i == atual ? tokens.text : tokens.muted)),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}
