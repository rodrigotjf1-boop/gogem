import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_repository.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_helper.dart';
import 'fixtures.dart';

ProviderContainer containerCom(http.Client client) {
  sqfliteFfiInit();
  final repoFut = () async {
    final db = await novaDbMemoria();
    return CatalogRepository(db);
  }();
  return ProviderContainer(overrides: [
    catalogRepositoryProvider.overrideWith((ref) => repoFut),
    gogemApiProvider.overrideWithValue(
        GogemApi(baseUrl: 'http://t/api/v1', bearer: 'jwt', client: client)),
  ]);
}

void main() {
  test('200 com snapshot → salva e fica atualizado', () async {
    final c = containerCom(MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer jwt');
      return http.Response(jsonEncode(publicadoFixture), 200,
          headers: {'content-type': 'application/json'});
    }));
    await c.read(catalogSyncProvider.notifier).sincronizar();
    expect(c.read(catalogSyncProvider).status, SyncStatus.atualizado);
    expect(c.read(catalogSyncProvider).versao, 3);
    final menu = await c.read(menuProvider.future);
    expect(menu!.produtos, hasLength(3));
  });

  test('atualizado:false → mantém versão local (checagem barata)', () async {
    var chamadas = 0;
    final c = containerCom(MockClient((req) async {
      chamadas++;
      if (chamadas == 1) {
        // charset utf-8: o corpo tem acentos; sem isso o body vira latin1 e o
        // utf8.decode do cliente estoura (como faz um servidor real).
        return http.Response(jsonEncode(publicadoFixture), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      expect(req.url.queryParameters['desde'], '3'); // manda a versão local
      return http.Response(jsonEncode({'atualizado': false}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final n = c.read(catalogSyncProvider.notifier);
    await n.sincronizar();
    await n.sincronizar();
    expect(c.read(catalogSyncProvider).status, SyncStatus.atualizado);
    expect(c.read(catalogSyncProvider).versao, 3);
  });

  test('falha de rede → offline-first: snapshot local sobrevive', () async {
    var chamadas = 0;
    final c = containerCom(MockClient((req) async {
      chamadas++;
      if (chamadas == 1) {
        return http.Response(jsonEncode(publicadoFixture), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      throw Exception('sem rede');
    }));
    final n = c.read(catalogSyncProvider.notifier);
    await n.sincronizar(); // popula
    await n.sincronizar(); // cai
    expect(c.read(catalogSyncProvider).status, SyncStatus.offline);
    final menu = await c.read(menuProvider.future);
    expect(menu, isNotNull); // continua servindo o cardápio local
  });

  test('HTTP 401 → estado erro (sem apagar local)', () async {
    final c = containerCom(MockClient((_) async => http.Response('nope', 401)));
    await c.read(catalogSyncProvider.notifier).sincronizar();
    expect(c.read(catalogSyncProvider).status, SyncStatus.erro);
  });

  // ERR-017 — pausar no painel não chegava ao totem sem publicar.
  test('pausa ao vivo chega no sync sem versão nova; despausar volta; ausente limpa',
      () async {
    var resposta = <String, dynamic>{};
    final c = containerCom(MockClient((req) async => http.Response(
        jsonEncode(resposta), 200,
        headers: {'content-type': 'application/json; charset=utf-8'})));
    final n = c.read(catalogSyncProvider.notifier);
    const p0 = publicadoFixture;
    final produtos = (p0['snapshot'] as Map)['produtos'] as List;
    final primeiro = produtos.first as Map;
    final idProduto = '${primeiro['id']}';
    final idOutro = '${(produtos.last as Map)['id']}';
    final idCategoria = '${primeiro['categoriaId']}';

    resposta = {...p0, 'disponibilidade': {'produtosIndisponiveis': []}};
    await n.sincronizar();
    expect((await c.read(menuProvider.future))!.porId(idProduto)!.disponivel,
        isTrue);

    // Gerente pausou: resposta SEM catálogo novo, só a disponibilidade.
    resposta = {
      'versao': p0['versao'],
      'atualizado': false,
      'disponibilidade': {
        'produtosIndisponiveis': [idProduto, idOutro],
      },
    };
    await n.sincronizar();
    final pausado = (await c.read(menuProvider.future))!;
    expect(pausado.porId(idProduto)!.disponivel, isFalse);
    expect(pausado.produtosDa(idCategoria).map((p) => p.id),
        isNot(contains(idProduto)));

    // Mesmo conjunto em outra ordem: não recarrega à toa.
    final antes = c.read(catalogSyncProvider).disponibilidade;
    resposta = {
      'versao': p0['versao'],
      'atualizado': false,
      'disponibilidade': {
        'produtosIndisponiveis': [idOutro, idProduto],
      },
    };
    await n.sincronizar();
    expect(c.read(catalogSyncProvider).disponibilidade, antes);

    // Despausou.
    resposta = {
      'versao': p0['versao'],
      'atualizado': false,
      'disponibilidade': {'produtosIndisponiveis': []},
    };
    await n.sincronizar();
    expect((await c.read(menuProvider.future))!.porId(idProduto)!.disponivel,
        isTrue);

    // Servidor sem o campo: a disponibilidade guardada é apagada (vale o retrato).
    resposta = {'versao': p0['versao'], 'atualizado': false};
    await n.sincronizar();
    expect(c.read(catalogSyncProvider).disponibilidade, greaterThan(antes));
  });
}
