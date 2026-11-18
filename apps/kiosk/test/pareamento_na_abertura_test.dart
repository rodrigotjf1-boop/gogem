import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/pareamento/device_token.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// ERR-048 — o totem perdia o pareamento a cada reinício.
///
/// Na abertura do app, `deviceTokenProvider.carregar()` (lê o token do banco) e a
/// primeira sync do cardápio disparam juntos. A sync podia sair SEM o token; a nuvem
/// responde 401 "Token de dispositivo ausente"; quando a resposta voltava o token já
/// tinha carregado, e o `catch` via "pareado + 401" e APAGAVA o token. Visto na loja
/// em 18/11/2026: os 3 totens voltaram à tela de pareamento depois da atualização.
/// Sem widgets de propósito (ver host_servidor_test.dart).
Future<(ProviderContainer, Database)> montar(
    Future<http.Response> Function(http.Request req, ProviderContainer c) responder,
    {String? tokenGuardado}) async {
  final db = await novaDbMemoria();
  if (tokenGuardado != null) {
    await db.insert('kv', {'chave': 'device_token', 'valor': tokenGuardado});
  }
  late final ProviderContainer c;
  final cliente = MockClient((req) => responder(req, c));
  c = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) async => db),
    // Como o de produção: o cliente sai com o token que estiver carregado.
    gogemApiProvider.overrideWith((ref) => GogemApi(
          baseUrl: 'http://t/api/v1',
          bearer: '',
          deviceToken: ref.watch(deviceTokenProvider).token,
          client: cliente,
        )),
  ]);
  return (c, db);
}

http.Response nao401(String msg) => http.Response(
    jsonEncode({'message': msg, 'error': 'Unauthorized', 'statusCode': 401}), 401,
    headers: {'content-type': 'application/json; charset=utf-8'});

Future<String?> tokenNoBanco(Database db) async {
  final r = await db.query('kv', where: 'chave = ?', whereArgs: ['device_token']);
  return r.isEmpty ? null : r.first['valor'] as String?;
}

void main() {
  test('a sync que saiu SEM token antes de ele carregar NÃO apaga o pareamento', () async {
    String? cabecalhoVisto = 'nao-chamado';
    final (c, db) = await montar((req, c) async {
      cabecalhoVisto = req.headers['X-Device-Token'];
      // Enquanto a chamada está no ar, o token termina de carregar do banco.
      await c.read(deviceTokenProvider.notifier).carregar();
      return nao401('Token de dispositivo ausente.');
    }, tokenGuardado: 'tok-guardado');

    await c.read(catalogSyncProvider.notifier).sincronizar();

    expect(cabecalhoVisto, isNull, reason: 'a chamada saiu sem o token (a corrida)');
    expect(c.read(catalogSyncProvider).status, SyncStatus.erro);
    expect(c.read(deviceTokenProvider).pareado, isTrue);
    expect(await tokenNoBanco(db), 'tok-guardado');
  });

  test('401 para a chamada COM o token de agora = revogado: desfaz o pareamento', () async {
    final (c, db) = await montar((req, c) async {
      expect(req.headers['X-Device-Token'], 'tok-revogado');
      return nao401('Token de dispositivo inválido.');
    }, tokenGuardado: 'tok-revogado');
    await c.read(deviceTokenProvider.notifier).carregar();

    await c.read(catalogSyncProvider.notifier).sincronizar();

    expect(c.read(deviceTokenProvider).pareado, isFalse);
    expect(await tokenNoBanco(db), isNull);
    expect(c.read(catalogSyncProvider).mensagem, contains('refazer pareamento'));
  });

  test('token trocado no meio da chamada: o 401 do antigo não apaga o novo', () async {
    final (c, db) = await montar((req, c) async {
      // Pareado de novo enquanto a chamada antiga estava no ar.
      final banco = await c.read(databaseProvider.future);
      await banco.insert('kv', {'chave': 'device_token', 'valor': 'tok-novo'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await c.read(deviceTokenProvider.notifier).carregar();
      return nao401('Token de dispositivo inválido.');
    }, tokenGuardado: 'tok-velho');
    await c.read(deviceTokenProvider.notifier).carregar();

    await c.read(catalogSyncProvider.notifier).sincronizar();

    expect(c.read(deviceTokenProvider).token, 'tok-novo');
    expect(await tokenNoBanco(db), 'tok-novo');
  });
}
