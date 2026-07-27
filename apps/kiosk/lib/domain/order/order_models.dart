import 'dart:math';
import '../../data/catalog/catalog_models.dart';

/// Mínimo efetivo do grupo: `obrigatorio` com `min = 0` conta como 1.
int minEfetivo(GrupoComplemento g) =>
    g.obrigatorio && g.min == 0 ? 1 : g.min;

/// Seleção válida? (respeita min/max/obrigatorio do snapshot)
bool selecaoValida(GrupoComplemento g, List<OpcaoComplemento> sel) =>
    sel.length >= minEfetivo(g) && sel.length <= max(g.max, minEfetivo(g));

/// UUID v4 sem dependência externa (Random.secure).
String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40;
  b[8] = (b[8] & 0x3F) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class ItemCarrinho {
  ItemCarrinho({
    String? linhaId,
    required this.produto,
    required this.selecoes,
    this.quantidade = 1,
    this.observacao = '',
  }) : linhaId = linhaId ?? uuidV4();

  final String linhaId;
  final Produto produto;
  /// grupoId -> opções escolhidas
  final Map<String, List<OpcaoComplemento>> selecoes;
  final int quantidade;
  final String observacao;

  List<OpcaoComplemento> get todasOpcoes =>
      [for (final l in selecoes.values) ...l];

  int get precoUnitarioCentavos =>
      produto.precoCentavos +
      todasOpcoes.fold<int>(0, (s, o) => s + o.precoCentavosDelta);

  int get totalCentavos => precoUnitarioCentavos * quantidade;

  ItemCarrinho comQuantidade(int q) => ItemCarrinho(
      linhaId: linhaId,
      produto: produto,
      selecoes: selecoes,
      quantidade: q,
      observacao: observacao);
}

enum FormaPagamento { credito, debito, pix }

/// Pedido finalizado no totem — nasce com UUID (idempotência, CLAUDE.md) e
/// vai para a fila local `pedidos_locais` (a F6 drena para o backend).
class PedidoLocal {
  PedidoLocal({
    String? uuid,
    required this.itens,
    required this.forma,
    this.cpf,
    DateTime? criadoEm,
  })  : uuid = uuid ?? uuidV4(),
        criadoEm = criadoEm ?? DateTime.now();

  final String uuid;
  final List<ItemCarrinho> itens;
  final FormaPagamento forma;
  final String? cpf;
  final DateTime criadoEm;

  int get totalCentavos => itens.fold<int>(0, (s, i) => s + i.totalCentavos);

  /// Corpo F6-ready: de-para SEMPRE por codigo_pdv, nunca id interno.
  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'criadoEm': criadoEm.toIso8601String(),
        'forma': forma.name,
        if (cpf != null && cpf!.isNotEmpty) 'cpf': cpf,
        'totalCentavos': totalCentavos,
        'itens': [
          for (final i in itens)
            {
              'codigoPdv': i.produto.codigoPdvRegem,
              'nome': i.produto.nome,
              'quantidade': i.quantidade,
              'precoUnitarioCentavos': i.precoUnitarioCentavos,
              if (i.observacao.isNotEmpty) 'observacao': i.observacao,
              'opcoes': [
                for (final o in i.todasOpcoes)
                  {
                    'codigoPdv': ExternalRef.codigoRegem(o.externalRefs),
                    'nome': o.nome,
                    'deltaCentavos': o.precoCentavosDelta,
                  }
              ],
            }
        ],
      };
}
