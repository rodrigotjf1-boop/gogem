import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../domain/order/cart.dart';
import '../../../domain/order/order_models.dart';
import '../../../domain/order/sugestoes.dart';

/// Uma categoria do cardápio com os produtos dela, na ordem publicada.
class SecaoCatalogo {
  const SecaoCatalogo(this.categoria, this.produtos);
  final Categoria categoria;
  final List<Produto> produtos;
}

/// O cardápio como os templates o mostram (docs/templates/00 §4.2). A disponibilidade já
/// vem aplicada pelo `menuProvider` (pausas do painel, opções que acabaram — ERR-017/024).
class CatalogoDados {
  const CatalogoDados({required this.secoes, required this.destaques});

  /// Categorias com ao menos um produto. Produto indisponível CONTINUA na seção — o card
  /// mostra "Esgotado" e não reage ao toque.
  final List<SecaoCatalogo> secoes;

  /// Até 4 produtos com selo, disponíveis; sem nenhum, os 3 primeiros disponíveis da
  /// primeira categoria.
  final List<Produto> destaques;

  factory CatalogoDados.de(MenuSnapshot snap) {
    final secoes = <SecaoCatalogo>[
      for (final c in snap.categorias)
        SecaoCatalogo(c, [
          for (final p in snap.produtos)
            if (p.categoriaId == c.id) p
        ]),
    ]..removeWhere((s) => s.produtos.isEmpty);
    var destaques = [
      for (final s in secoes)
        for (final p in s.produtos)
          if (p.disponivel && (p.selo ?? '').trim().isNotEmpty) p
    ].take(4).toList();
    if (destaques.isEmpty && secoes.isNotEmpty) {
      destaques = [
        for (final p in secoes.first.produtos)
          if (p.disponivel) p
      ].take(3).toList();
    }
    return CatalogoDados(secoes: secoes, destaques: destaques);
  }
}

/// As ações de pedido das telas INTEIRAS dos templates (catálogo e sacola). A regra é a
/// mesma das telas atuais, escrita uma vez só para os cinco templates.
class AcoesPedido {
  const AcoesPedido(this.ref);
  final WidgetRef ref;

  /// Toque no card: abre o produto (indisponível não reage).
  void abrirProduto(BuildContext context, Produto p) {
    if (!p.disponivel) return;
    context.push('/produto/${p.id}');
  }

  /// Botão "+" do card, da sugestão e da peça-também: sem etapa obrigatória, entra direto
  /// na sacola e devolve `true` (o template pode animar o voo); com etapa, abre o produto
  /// e devolve `false`.
  bool adicionarOuAbrir(BuildContext context, Produto p) {
    if (!p.disponivel) return false;
    if (temEtapaObrigatoria(p)) {
      context.push('/produto/${p.id}');
      return false;
    }
    ref.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: p, selecoes: const {}));
    return true;
  }

  /// "Cancelar" do topo: desiste do pedido — limpa sacola e checkout e volta ao descanso.
  void cancelarPedido(BuildContext context) {
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    context.go('/descanso');
  }

  void verSacola(BuildContext context) => context.push('/carrinho');
  void adicionarMais(BuildContext context) => context.go('/catalogo');
  void finalizar(BuildContext context) => context.go('/peca-tambem');

  void remover(String linhaId) => ref.read(cartProvider.notifier).remover(linhaId);
  void alterarQuantidade(String linhaId, int q) =>
      ref.read(cartProvider.notifier).alterarQuantidade(linhaId, q);
  void setConsumo(String consumo) => ref.read(checkoutProvider.notifier).setConsumo(consumo);
}

/// Complementos escolhidos numa linha da sacola, em texto curto ("+ Bacon, Sem cebola").
List<String> descricaoSelecoes(ItemCarrinho item) => [
      for (final o in item.todasOpcoes) o.nome,
    ];
