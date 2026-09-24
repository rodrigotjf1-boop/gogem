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
    ..texto('consumo: ${pedido.consumo == 'viagem' ? 'para viagem' : 'comer aqui'}');
  // Dinheiro: pago no caixa — destaque na via do cliente. O texto diz a CONSEQUÊNCIA
  // ("para ser produzido"), não só a instrução: sem pagar, a cozinha não recebe o
  // pedido, e o cliente precisa entender isso olhando o cupom.
  if (pedido.forma == FormaPagamento.dinheiro) {
    b
      ..linha()
      ..texto('PAGUE NO CAIXA PARA SER PRODUZIDO',
          negrito: true, tamanho: 2, centro: true);
  }
  b
    ..linha()
    ..texto('SENHA', centro: true)
    ..texto(senha, negrito: true, tamanho: 3, centro: true)
    ..texto('*** NAO E DOCUMENTO FISCAL ***', centro: true)
    ..corte();
  return b.build();
}

/// K6 — DANFE NFC-e. O texto vem PRONTO do Regem (o emitente): ele tem os dados do
/// emitente, os tributos e a URL de consulta, e e onde as tarjas exigidas pela norma
/// sao decididas. O totem so desenha o que recebeu — um segundo montador de DANFE
/// aqui seria uma segunda versao do documento para corrigir a cada mudanca de norma.
///
/// Unico marcador: `@QR:<dados>` vira o QR Code DESENHADO (modelo 2, modulo 6,
/// correcao M — os >= 25 mm que o Manual do DANFE NFC-e exige). A mesma convencao que
/// o servidor da loja ja usa, para a nota sair igual no totem e na impressora do caixa.
///
/// A via do cliente sai SEM rotulo nenhum: e como o Regem a monta na impressora do
/// caixa, e a mesma nota nao pode sair com cara diferente em cada aparelho.
///
/// [viaEstabelecimento] monta a SEGUNDA via da contingencia off-line, do jeito exato do
/// Regem (`fiscal.service.ts`): o mesmo conteudo + separador + "VIA DO ESTABELECIMENTO"
/// no fim. Ela e OPCIONAL e desligada por padrao (mig 287): o MOC 7.0 Anexo IV §4 aceita
/// a guarda ELETRONICA do XML no lugar do papel, e restaurante nao arquiva cupom. Quem
/// imprime as duas vias sempre gasta papel que ninguem guarda e dobra a fila justamente
/// quando a loja esta sem internet.
Uint8List montarDanfe(String conteudo, {bool viaEstabelecimento = false}) {
  final b = EscPosBuilder();
  final texto = viaEstabelecimento
      ? '$conteudo\n--------------------------------\nVIA DO ESTABELECIMENTO'
      : conteudo;
  for (final linha in texto.split('\n')) {
    if (linha.startsWith('@QR:')) {
      b.qr(linha.substring(4));
    } else {
      b.texto(linha);
    }
  }
  b.corte();
  return b.build();
}
