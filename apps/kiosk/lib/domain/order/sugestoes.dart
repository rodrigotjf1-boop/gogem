import '../../data/catalog/catalog_models.dart';
import 'order_models.dart';

/// Upsell agregado dos itens da sacola ("Peça também" e o bloco "Combina com seu pedido"
/// dos templates): na ordem dos itens e do upsell de cada um, sem repetir, só produto
/// disponível e que ainda não está na sacola.
List<Produto> sugestoesUpsell(List<ItemCarrinho> itens, MenuSnapshot snap) {
  final noCarrinho = {for (final i in itens) i.produto.id};
  final vistos = <String>{};
  final out = <Produto>[];
  for (final item in itens) {
    for (final id in item.produto.upsell) {
      if (!vistos.add(id) || noCarrinho.contains(id)) continue;
      final p = snap.porId(id);
      if (p != null && p.disponivel) out.add(p);
    }
  }
  return out;
}

/// Produto com etapa obrigatória precisa passar pela tela do produto antes da sacola.
bool temEtapaObrigatoria(Produto p) => p.grupos.any((g) => minEfetivo(g) > 0);
