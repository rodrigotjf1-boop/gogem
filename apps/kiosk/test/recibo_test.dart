import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/printing/recibo.dart';
import 'fixtures.dart';

void main() {
  test('cupom contém itens, total, senha e corte', () {
    final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    final bacon = menu.produtos.first.grupos.single.opcoes.single;
    final p = PedidoLocal(itens: [
      ItemCarrinho(
          produto: menu.produtos.first, selecoes: {'g1': [bacon]}, quantidade: 2)
    ], forma: FormaPagamento.credito);
    final bytes = montarCupom(p, '042');
    final txt = String.fromCharCodes(bytes); // sem filtro: contains() ignora bytes de comando
    expect(txt, contains('2x Mister Burguer'));
    expect(txt, contains('+ Bacon'));
    expect(txt, contains('67,80')); // 2 x 33,90
    expect(txt, contains('042'));
    expect(txt, contains('NAO E DOCUMENTO FISCAL'));
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x10]);
  });
}
