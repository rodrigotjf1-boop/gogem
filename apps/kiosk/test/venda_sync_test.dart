import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'package:gogem_kiosk/domain/fiscal/bloqueio_fiscal.dart';
import 'package:gogem_kiosk/domain/order/venda_sync.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'db_helper.dart';
import 'fixtures.dart';

Future<(ProviderContainer, OrderRepository)> montar(http.Client client) async {
  final db = await novaDbMemoria();
  final repo = OrderRepository(db);
  final c = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWith((ref) async => repo),
    gogemApiProvider.overrideWithValue(
        GogemApi(baseUrl: 'http://t/api/v1', bearer: 'jwt', client: client)),
  ]);
  return (c, repo);
}

/// Como [montar], com a fila de reimpressão REAL no mesmo banco.
Future<(ProviderContainer, OrderRepository, FilaImpressao)> montarComFila(
    http.Client client) async {
  final db = await novaDbMemoria();
  final repo = OrderRepository(db);
  final fila = FilaImpressao(db);
  final c = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWith((ref) async => repo),
    filaImpressaoProvider.overrideWith((ref) async => fila),
    gogemApiProvider.overrideWithValue(
        GogemApi(baseUrl: 'http://t/api/v1', bearer: 'jwt', client: client)),
  ]);
  return (c, repo, fila);
}

http.Response _json(Object corpo, [int status = 201]) =>
    http.Response(jsonEncode(corpo), status,
        headers: {'content-type': 'application/json'});

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

  group('F10 — recuperação no boot (write-ahead)', () {
    // Responde ao GET /pagamentos/status/:orderId com um status fixo.
    MockClient statusFixo(String tipo, String status) => MockClient((req) async {
          expect(req.url.path, contains('/pagamentos/status/'));
          return http.Response(
              jsonEncode({'tipo': tipo, 'status': status}), 200);
        });

    test('aprovado → libera pro envio (pendente_envio)', () async {
      final (c, repo) = await montar(statusFixo('point', 'approved'));
      final p = pedido();
      await repo.salvarPreCobranca(p); // preso em aguardando_pagamento
      await c.read(vendaSyncProvider.notifier).resolverPendencias();
      expect((await repo.listarAguardandoPagamento()), isEmpty);
      expect(await repo.pendentes(), 1); // virou pendente_envio
    });

    test('recusado → descarta (cancelado, não vai pro Regem)', () async {
      final (c, repo) = await montar(statusFixo('point', 'rejected'));
      final p = pedido();
      await repo.salvarPreCobranca(p);
      await c.read(vendaSyncProvider.notifier).resolverPendencias();
      expect((await repo.listarAguardandoPagamento()), isEmpty);
      expect(await repo.pendentes(), 0); // NÃO virou pendente
    });

    test('sem cobrança no backend (nenhum) → descarta', () async {
      final (c, repo) = await montar(statusFixo('nenhum', 'nenhum'));
      await repo.salvarPreCobranca(pedido());
      await c.read(vendaSyncProvider.notifier).resolverPendencias();
      expect((await repo.listarAguardandoPagamento()), isEmpty);
      expect(await repo.pendentes(), 0);
    });

    test('ainda pendente → deixa preso (tenta no próximo boot)', () async {
      final (c, repo) = await montar(statusFixo('pix', 'pending'));
      await repo.salvarPreCobranca(pedido());
      await c.read(vendaSyncProvider.notifier).resolverPendencias();
      expect((await repo.listarAguardandoPagamento()).length, 1);
      expect(await repo.pendentes(), 0);
    });

    test('offline → deixa preso (não perde, não envia)', () async {
      final (c, repo) =
          await montar(MockClient((_) async => throw Exception('sem rede')));
      await repo.salvarPreCobranca(pedido());
      await c.read(vendaSyncProvider.notifier).resolverPendencias();
      expect((await repo.listarAguardandoPagamento()).length, 1);
      expect(await repo.pendentes(), 0);
    });
  });

  // ERR-008 — uma venda recusada de forma DEFINITIVA ficava na frente da fila para sempre
  // e nenhuma outra saía. Agora ela sai (com estorno) e as de trás seguem.
  group('recusa definitiva não trava a fila', () {
    test('422 na 1ª venda: ela sai estornada e a 2ª é enviada', () async {
      final estornos = <Map<String, dynamic>>[];
      var vendas = 0;
      final (c, repo) = await montar(MockClient((req) async {
        if (req.url.path.endsWith('/pagamentos/estorno')) {
          estornos.add(jsonDecode(req.body) as Map<String, dynamic>);
          return _json({
            'estorno': {'feito': true}
          }, 200);
        }
        if (req.url.path.endsWith('/vendas')) {
          vendas++;
          return vendas == 1
              ? _json({'message': 'O sistema da loja recusou a venda: X9'}, 422)
              : _json({'comandaId': 'c2', 'senha': 2});
        }
        return _json({}, 200);
      }));
      final p1 = pedido();
      final p2 = pedido();
      await repo.salvarPedido(p1);
      await repo.salvarPedido(p2);

      await c.read(vendaSyncProvider.notifier).drenar();

      expect(await repo.pendentes(), 0);
      expect(estornos.single['orderId'], p1.uuid);
      expect(estornos.single['etapa'], 'recusada');
      expect(estornos.single['motivo'], contains('X9'));
      expect(c.read(vendaSyncProvider).msg, contains('recusado'));
    });

    test('dinheiro recusado: sai da fila SEM pedir estorno (nada foi cobrado)',
        () async {
      final chamadas = <String>[];
      final (c, repo) = await montar(MockClient((req) async {
        chamadas.add(req.url.path);
        return _json({'message': 'recusado'}, 400);
      }));
      final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
      await repo.salvarPedido(PedidoLocal(
          itens: [ItemCarrinho(produto: menu.produtos[1], selecoes: const {})],
          forma: FormaPagamento.dinheiro));

      await c.read(vendaSyncProvider.notifier).drenar();

      expect(await repo.pendentes(), 0);
      expect(chamadas.where((p) => p.endsWith('/pagamentos/estorno')), isEmpty);
    });
  });

  group('servidor da loja', () {
    test('pedido RETIDO reenvia pela LIBERAÇÃO (mesma senha, mesma nota)',
        () async {
      final caminhos = <String>[];
      final (c, repo) = await montar(MockClient((req) async {
        caminhos.add(req.url.path);
        return _json({'comandaId': 'c1', 'senha': 42});
      }));
      final p = pedido();
      await repo.salvarPedido(p);
      await repo.marcarRetido(p.uuid, 'ped-9');

      await c.read(vendaSyncProvider.notifier).drenar();

      expect(caminhos, ['/api/v1/vendas/ped-9/liberar']);
      expect(await repo.pendentes(), 0);
    });
  });

  group('resultado fiscal em segundo plano (o cliente já saiu)', () {
    test('nota NÃO emitida → estorna com o motivo do Regem e sai da fila',
        () async {
      Map<String, dynamic>? estorno;
      final (c, repo) = await montar(MockClient((req) async {
        if (req.url.path.endsWith('/pagamentos/estorno')) {
          estorno = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'estorno': {'feito': true}
          }, 200);
        }
        if (req.url.path.endsWith('/vendas')) {
          return _json({
            'comandaId': 'c1',
            'nfce': {
              'status': 'nao_emitida',
              'danfe': null,
              'erro': {
                'etapa': 'sem_contingencia',
                'codigo': null,
                'motivo': 'SEFAZ sem resposta',
                'repete': true
              }
            }
          });
        }
        return _json({}, 200);
      }));
      final p = pedido();
      await repo.salvarPedido(p);

      await c.read(vendaSyncProvider.notifier).drenar();

      expect(estorno!['orderId'], p.uuid);
      expect(estorno!['motivo'],
          'NFC-e não emitida (sem_contingencia): SEFAZ sem resposta');
      expect(await repo.pendentes(), 0);
      expect(c.read(bloqueioFiscalProvider).falhasSeguidas, 1);
    });

    test('nota emitida → o DANFE vai para a REIMPRESSÃO (nunca sai sozinho)',
        () async {
      final (c, repo, fila) = await montarComFila(MockClient((req) async =>
          _json({
            'comandaId': 'c1',
            'senha': 42,
            'nfce': {
              'status': 'contingencia',
              'contingencia': true,
              'viaEstabelecimento': true,
              'danfe': 'DANFE NFC-e\nTOTAL: R\$ 7,00'
            }
          })));
      final p = pedido();
      await repo.salvarPedido(p);

      await c.read(vendaSyncProvider.notifier).drenar();

      final chaves = (await fila.listar()).map((r) => r['uuid']).toList();
      expect(chaves, [chaveDanfe(p.uuid), chaveDanfe(p.uuid, viaEstabelecimento: true)]);
      expect(await repo.pendentes(), 0);
    });

    test('estorno sem rede fica PENDENTE e sai no ciclo seguinte', () async {
      var estornoFunciona = false;
      final (c, repo) = await montar(MockClient((req) async {
        if (req.url.path.endsWith('/pagamentos/estorno')) {
          if (!estornoFunciona) return http.Response('bad gateway', 502);
          return _json({
            'estorno': {'feito': true}
          }, 200);
        }
        return _json({'message': 'recusado'}, 422);
      }));
      final p = pedido();
      await repo.salvarPedido(p);

      await c.read(vendaSyncProvider.notifier).drenar();
      expect((await repo.listarEstornosPendentes()).single['uuid'], p.uuid);
      expect(await repo.pendentes(), 1); // o dinheiro do cliente não é esquecido

      estornoFunciona = true;
      await c.read(vendaSyncProvider.notifier).drenar();
      expect(await repo.listarEstornosPendentes(), isEmpty);
      expect(await repo.pendentes(), 0);
    });

    test('cancelado pelo painel enquanto na fila → sai sem pedir estorno',
        () async {
      final chamadas = <String>[];
      final (c, repo) = await montar(MockClient((req) async {
        chamadas.add(req.url.path);
        return _json({'comandaId': 'c1', 'cancelado': true, 'idempotente': true});
      }));
      await repo.salvarPedido(pedido());

      await c.read(vendaSyncProvider.notifier).drenar();

      expect(await repo.pendentes(), 0);
      expect(chamadas.where((p) => p.endsWith('/pagamentos/estorno')), isEmpty);
    });
  });
}
