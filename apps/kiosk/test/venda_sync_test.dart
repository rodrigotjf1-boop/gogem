import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/data/db/kiosk_database.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'package:gogem_kiosk/domain/order/venda_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures.dart';

Future<(ProviderContainer, OrderRepository)> montar(http.Client client) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await KioskDatabase.ensureSchema(db);
  final repo = OrderRepository(db);
  final c = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWith((ref) async => repo),
    gogemApiProvider.overrideWithValue(
        GogemApi(baseUrl: 'http://t/api/v1', bearer: 'jwt', client: client)),
  ]);
  return (c, repo);
}

PedidoLocal pedido() {
  final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
  return PedidoLocal(
      itens: [ItemCarrinho(produto: menu.produtos[1], selecoes: const {})],
      forma: FormaPagamento.pix);
}

void main() {
  test('201 → marcado enviado, com Idempotency-Key = uuid', () async {
    String? keyVista;
    final (c, repo) = await montar(MockClient((req) async {
      keyVista = req.headers['Idempotency-Key'];
      expect(req.url.path, endsWith('/vendas'));
      return http.Response(jsonEncode({'id': 'L1'}), 201);
    }));
    final p = pedido();
    await repo.salvarPedido(p);
    await c.read(vendaSyncProvider.notifier).drenar();
    expect(keyVista, p.uuid);
    expect(await repo.pendentes(), 0);
    final row = (await repo.listarPendentes()); // vazio
    expect(row, isEmpty);
    expect(c.read(vendaSyncProvider).msg, contains('enviados'));
  });

  test('409 (já processado) → tratado como sucesso idempotente', () async {
    final (c, repo) = await montar(
        MockClient((_) async => http.Response('duplicado', 409)));
    await repo.salvarPedido(pedido());
    await c.read(vendaSyncProvider.notifier).drenar();
    expect(await repo.pendentes(), 0);
  });

  test('sem rede → fila INTACTA e tentativa registrada no próximo erro de API',
      () async {
    final (c, repo) = await montar(MockClient((_) async {
      throw Exception('sem rede');
    }));
    await repo.salvarPedido(pedido());
    await c.read(vendaSyncProvider.notifier).drenar();
    expect(await repo.pendentes(), 1); // offline-first
    expect(c.read(vendaSyncProvider).msg, contains('offline'));
  });

  test('erro 500 → mantém na fila, incrementa tentativas e para a drenagem',
      () async {
    final (c, repo) = await montar(
        MockClient((_) async => http.Response('boom', 500)));
    await repo.salvarPedido(pedido());
    await repo.salvarPedido(pedido());
    await c.read(vendaSyncProvider.notifier).drenar();
    expect(await repo.pendentes(), 2);
    final rows = await repo.listarPendentes();
    expect(rows.first['tentativas'], 1);
    expect(rows.last['tentativas'], 0); // parou no primeiro erro
  });
}
