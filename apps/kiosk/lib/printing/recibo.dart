import 'dart:typed_data';
import 'package:gogem_escpos/escpos.dart';
import '../core/util/moeda.dart';
import '../domain/order/order_models.dart';

/// Cupom NÃO-FISCAL do pedido (via do cliente + senha de retirada).
Uint8List montarCupom(PedidoLocal pedido, String senha, {String loja = 'GoGeM'}) {
  final b = EscPosBuilder()
    ..texto(loja, negrito: true, tamanho: 2, centro: true)
    ..texto('PEDIDO ${pedido.uuid.substring(0, 8).toUpperCase()}', centro: true)
    ..texto(pedido.criadoEm.toString().substring(0, 16), centro: true)
    ..linha();
  for (final i in pedido.itens) {
    b.itemValor('${i.quantidade}x ${i.produto.nome}',
        formatCentavos(i.totalCentavos));
    for (final o in i.todasOpcoes) {
      b.texto('   + ${o.nome}'
          '${o.precoCentavosDelta != 0 ? ' (${formatCentavos(o.precoCentavosDelta)})' : ''}');
    }
    if (i.observacao.isNotEmpty) b.texto('   obs: ${i.observacao}');
  }
  b
    ..linha()
    ..itemValor('TOTAL', formatCentavos(pedido.totalCentavos))
    ..texto('pagamento: ${pedido.forma.name}')
    ..linha()
    ..texto('SENHA', centro: true)
    ..texto(senha, negrito: true, tamanho: 3, centro: true)
    ..texto('*** NAO E DOCUMENTO FISCAL ***', centro: true)
    ..corte();
  return b.build();
}
