import 'package:flutter/material.dart';
import '../template_tokens.dart';

/// Pílula do `produto.selo` ("Mais pedido", "Novo"…, texto livre do lojista).
/// "Mais pedido"/"Mais vendido" usa o acento 2 com estrela; os outros, fundo `text`.
class Selo extends StatelessWidget {
  const Selo({
    super.key,
    required this.texto,
    required this.tokens,
    required this.altura,
    this.fundo,
    this.tinta,
    this.caixaAlta = false,
  });

  final String texto;
  final TemplateTokens tokens;

  /// Altura em px de TELA (já convertida com `context.dz`).
  final double altura;
  final Color? fundo;
  final Color? tinta;
  final bool caixaAlta;

  /// Selo de "mais pedido/vendido" (ganha a estrela e o acento 2).
  static bool ehMaisPedido(String s) {
    final t = s.toLowerCase();
    return t.contains('mais pedido') || t.contains('mais vendido') || t.contains('campe');
  }

  @override
  Widget build(BuildContext context) {
    final destaque = ehMaisPedido(texto);
    final bg = fundo ?? (destaque ? tokens.accent2 : tokens.text);
    final fg = tinta ?? (destaque ? tokens.onAccent2 : tokens.bg);
    final fs = altura * .42;
    return Container(
      height: altura,
      padding: EdgeInsets.symmetric(horizontal: altura * .38),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(altura / 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (destaque) ...[
          Icon(Icons.star_rounded, size: fs * 1.15, color: fg),
          SizedBox(width: altura * .12),
        ],
        Text(caixaAlta ? texto.toUpperCase() : texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.texto(fs, peso: FontWeight.w800, cor: fg)),
      ]),
    );
  }
}

/// Produto indisponível: cinza (saturação 0), selo "Esgotado" por cima e SEM toque.
class Indisponivel extends StatelessWidget {
  const Indisponivel({
    super.key,
    required this.ativo,
    required this.child,
    required this.tokens,
    required this.alturaSelo,
  });

  final bool ativo;
  final Widget child;
  final TemplateTokens tokens;
  final double alturaSelo;

  static const _cinza = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!ativo) return child;
    return IgnorePointer(
      child: Stack(children: [
        Opacity(opacity: .55, child: ColorFiltered(colorFilter: _cinza, child: child)),
        Positioned(
          top: alturaSelo * .3,
          left: alturaSelo * .3,
          child: Selo(
            key: const ValueKey('selo-esgotado'),
            texto: 'Esgotado',
            tokens: tokens,
            altura: alturaSelo,
            fundo: tokens.err,
            tinta: const Color(0xFFFFFFFF),
          ),
        ),
      ]),
    );
  }
}
