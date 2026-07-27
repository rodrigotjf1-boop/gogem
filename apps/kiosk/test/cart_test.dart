import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'fixtures.dart';

void main() {
  final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
  test('adicionar/alterar/remover/limpar e totais', () {
    final c = ProviderContainer();
    final n = c.read(cartProvider.notifier);
    final item = ItemCarrinho(produto: menu.produtos[1], selecoes: const {});
    n.adicionar(item); // Refri 700
    expect(c.read(cartProvider).totalCentavos, 700);
    n.alterarQuantidade(item.linhaId, 3);
    expect(c.read(cartProvider).totalCentavos, 2100);
    expect(c.read(cartProvider).totalItens, 3);
    n.alterarQuantidade(item.linhaId, 0); // zera => remove
    expect(c.read(cartProvider).vazio, isTrue);
    n.adicionar(item);
    n.limpar();
    expect(c.read(cartProvider).vazio, isTrue);
  });
}
