import 'package:flutter/material.dart';
import '../../catalogo/produto_imagem.dart';
import '../template_tokens.dart';

/// Foto do produto nos templates (docs/templates/00 §3.5):
/// - URL terminada em `.png` → **recorte**: a imagem inteira (contain), com sombra projetada
///   no "chão", ocupando até [escalaRecorte] da área;
/// - qualquer outra → **foto**: cobre o recipiente (cover);
/// - sem URL → placeholder nas cores do template.
/// A imagem fica em memória no tamanho exibido (`memCacheWidth`).
class ProdutoArte extends StatelessWidget {
  const ProdutoArte({
    super.key,
    required this.url,
    required this.tokens,
    this.raio = 0,
    this.escalaRecorte = .86,
    this.sombra = true,
    this.fundo,
  });

  final String? url;
  final TemplateTokens tokens;
  final double raio;
  final double escalaRecorte;
  final bool sombra;

  /// Fundo atrás da arte (padrão: `tokens.art`). Transparente = sem fundo.
  final Color? fundo;

  /// `.png` (antes da query string) é tratado como recorte sem fundo.
  static bool ehRecorte(String? url) {
    if (url == null || url.isEmpty) return false;
    final caminho = url.split('?').first.split('#').first.toLowerCase();
    return caminho.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(raio);
    return LayoutBuilder(builder: (context, c) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final largura = c.maxWidth.isFinite ? c.maxWidth : 400.0;
      final cache = (largura * dpr).round().clamp(64, 1400);
      final corFundo = fundo ?? tokens.art;
      if (url == null || url!.isEmpty) {
        return _Vazio(tokens: tokens, raio: raio, fundo: corFundo);
      }
      if (!ehRecorte(url)) {
        return DecoratedBox(
          decoration: BoxDecoration(color: corFundo, borderRadius: br),
          child: ProdutoImagem(url: url, borderRadius: br, memCacheWidth: cache),
        );
      }
      return ClipRRect(
        borderRadius: br,
        child: ColoredBox(
          color: corFundo,
          child: Stack(alignment: Alignment.center, children: [
            if (sombra)
              Positioned(
                bottom: c.maxHeight.isFinite ? c.maxHeight * .07 : 12,
                child: Container(
                  width: largura * escalaRecorte * .62,
                  height: largura * .05,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x59000000), blurRadius: 18, spreadRadius: 2),
                    ],
                  ),
                ),
              ),
            FractionallySizedBox(
              widthFactor: escalaRecorte,
              heightFactor: escalaRecorte,
              child: ProdutoImagem(
                url: url,
                fit: BoxFit.contain,
                memCacheWidth: (cache * escalaRecorte).round(),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.tokens, required this.raio, required this.fundo});
  final TemplateTokens tokens;
  final double raio;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(raio)),
      child: LayoutBuilder(
        builder: (_, c) => Center(
          child: Icon(Icons.restaurant_menu,
              size: c.biggest.shortestSide.isFinite ? c.biggest.shortestSide * .34 : 48,
              color: tokens.muted.withAlpha(110)),
        ),
      ),
    );
  }
}
