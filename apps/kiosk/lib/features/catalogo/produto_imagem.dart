import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/gogem_theme.dart';

/// Foto do produto na vitrine — com cache em disco (funciona offline após o
/// 1º carregamento online), placeholder enquanto baixa e fallback elegante
/// quando não há foto ou a rede falha. Nunca mostra um retângulo quebrado.
///
/// [url] nula/vazia → direto no placeholder (sem tocar a rede).
class ProdutoImagem extends StatelessWidget {
  const ProdutoImagem({
    super.key,
    required this.url,
    this.borderRadius,
    this.iconeVazio = 0.34,
  });

  final String? url;
  final BorderRadius? borderRadius;

  /// Tamanho do ícone de fallback como fração do menor lado (0..1).
  final double iconeVazio;

  @override
  Widget build(BuildContext context) {
    final raio = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: raio,
      child: (url == null || url!.isEmpty)
          ? _Placeholder(iconeVazio: iconeVazio)
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => const _Placeholder(carregando: true),
              errorWidget: (_, __, ___) => _Placeholder(iconeVazio: iconeVazio),
            ),
    );
  }
}

/// Fundo neutro da marca com um ícone de prato (ou spinner ao carregar).
class _Placeholder extends StatelessWidget {
  const _Placeholder({this.carregando = false, this.iconeVazio = 0.34});
  final bool carregando;
  final double iconeVazio;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GogemColors.panel, GogemColors.bg],
        ),
      ),
      child: Center(
        child: carregando
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: GogemColors.cheese,
                ),
              )
            : LayoutBuilder(
                builder: (_, c) => Icon(
                  Icons.restaurant_menu,
                  size: c.biggest.shortestSide * iconeVazio,
                  color: GogemColors.line,
                ),
              ),
      ),
    );
  }
}
