import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'db_helper.dart';
import 'fixtures.dart';

void main() {

  test('senha sequencial 3 dígitos com reset diário', () async {
    final db = await novaDbMemoria();
    var dia = DateTime(2026, 7, 25);
    final repo = OrderRepository(db, clock: () => dia);
    expect(await repo.proximaSenha(), '001');
    expect(await repo.proximaSenha(), '002');
    dia = DateTime(2026, 7, 26); // virou o dia
    expect(await repo.proximaSenha(), '001');
  });

  test('salvarPedido entra na fila pendente_envio com o mesmo UUID', () async {
    final db = await novaDbMemoria();
    final repo = OrderRepository(db);
    final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    final pedido = PedidoLocal(
        itens: [ItemCarrinho(produto: menu.produtos[1], selecoes: const {})],
        forma: FormaPagamento.debito);
    final senha = await repo.salvarPedido(pedido);
    expect(senha, '001');
    expect(await repo.pendentes(), 1);
    final row = (await db.query('pedidos_locais')).single;
    expect(row['uuid'], pedido.uuid);
    expect(row['status'], 'pendente_envio');
  });
}
