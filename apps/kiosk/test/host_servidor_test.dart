import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/config/app_config.dart';
import 'package:gogem_kiosk/core/config/host_servidor.dart';
import 'package:gogem_kiosk/core/pareamento/device_token.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// K1 — o DESTINO do totem chega no pareamento e fica guardado.
///
/// Antes o endereço vivia no build (`--dart-define`), então apontar um aparelho para o
/// servidor da loja exigia um APK por loja. O que estes testes garantem: o destino é
/// persistido, sobrevive ao reinício, muda o cliente HTTP e some no despareamento.
/// Sem widgets de propósito — teste de widget com sqflite real congela sob o
/// relógio-falso (ver test/fakes.dart).
http.Client _pareamentoRespondendo(Map<String, Object?> corpo) =>
    MockClient((req) async {
      expect(req.url.path, endsWith('/publico/dispositivos/parear'));
      return http.Response(jsonEncode(corpo), 200,
          headers: {'content-type': 'application/json'});
    });

Future<(ProviderContainer, Database)> montar(http.Client client) async {
  final db = await novaDbMemoria();
  final c = ProviderContainer(overrides: [
    databaseProvider.overrideWith((ref) async => db),
    apiDePareamentoProvider.overrideWithValue(
        GogemApi(baseUrl: 'https://nuvem/api/v1', bearer: '', client: client)),
  ]);
  return (c, db);
}

void main() {
  test('sem pareamento, o totem fala com o host do build (nuvem)', () async {
    final (c, _) = await montar(_pareamentoRespondendo({'token': 't'}));
    await c.read(deviceTokenProvider.notifier).carregar();
    expect(c.read(hostServidorProvider).apiBase, isNull);
    expect(c.read(appConfigProvider).apiUrl, hostDoBuild);
  });

  test('pareou com destino → guarda e o cliente passa a usar o servidor', () async {
    final (c, db) = await montar(_pareamentoRespondendo(
        {'token': 'tok', 'apiBase': 'https://192.168.0.50:3002/api/v1'}));
    await c.read(deviceTokenProvider.notifier).parear('123456');

    expect(c.read(hostServidorProvider).apiBase, 'https://192.168.0.50:3002/api/v1');
    expect(c.read(appConfigProvider).apiUrl, 'https://192.168.0.50:3002/api/v1');
    // Persistido: é isso que faz o destino sobreviver ao reinício do aparelho.
    final r = await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveHost]);
    expect(r.single['valor'], 'https://192.168.0.50:3002/api/v1');
  });

  test('o destino guardado volta no boot seguinte', () async {
    final (c1, db) = await montar(_pareamentoRespondendo(
        {'token': 'tok', 'apiBase': 'https://10.0.0.7:3002/api/v1'}));
    await c1.read(deviceTokenProvider.notifier).parear('123456');
    c1.dispose();

    // Mesmo banco, container novo = o aparelho reiniciando.
    final c2 = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    await c2.read(deviceTokenProvider.notifier).carregar();
    expect(c2.read(appConfigProvider).apiUrl, 'https://10.0.0.7:3002/api/v1');
  });

  test('loja SEM servidor: pareamento sem destino mantém a nuvem', () async {
    final (c, db) = await montar(_pareamentoRespondendo({'token': 'tok'}));
    await c.read(deviceTokenProvider.notifier).parear('123456');
    expect(c.read(hostServidorProvider).apiBase, isNull);
    expect(c.read(appConfigProvider).apiUrl, hostDoBuild);
    expect(
        (await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveHost])).isEmpty,
        isTrue);
  });

  test('desparear limpa o destino (o próximo pareamento diz para onde ir)', () async {
    final (c, db) = await montar(_pareamentoRespondendo(
        {'token': 'tok', 'apiBase': 'https://192.168.1.9:3002/api/v1'}));
    await c.read(deviceTokenProvider.notifier).parear('123456');
    await c.read(deviceTokenProvider.notifier).desparear();

    expect(c.read(hostServidorProvider).apiBase, isNull);
    expect(c.read(appConfigProvider).apiUrl, hostDoBuild);
    expect(
        (await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveHost])).isEmpty,
        isTrue);
  });

  test('CA do servidor chega no pareamento, é guardada e volta no boot', () async {
    const ca = '''-----BEGIN CERTIFICATE-----
MIIBexemplo
-----END CERTIFICATE-----''';
    final (c1, db) = await montar(_pareamentoRespondendo({
      'token': 'tok',
      'apiBase': 'https://192.168.0.50:3002/api/v1',
      'caPem': ca,
    }));
    await c1.read(deviceTokenProvider.notifier).parear('123456');
    expect(c1.read(hostServidorProvider).caPem, ca);
    expect(
        (await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveCa])).single['valor'],
        ca);
    c1.dispose();

    final c2 = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)]);
    await c2.read(deviceTokenProvider.notifier).carregar();
    expect(c2.read(hostServidorProvider).caPem, ca);
  });

  test('sem servidor não sobra certificado guardado', () async {
    const ca = '''-----BEGIN CERTIFICATE-----
x
-----END CERTIFICATE-----''';
    final (c, db) = await montar(_pareamentoRespondendo(
        {'token': 'tok', 'apiBase': 'https://10.0.0.3:3002/api/v1', 'caPem': ca}));
    await c.read(deviceTokenProvider.notifier).parear('123456');
    // Repareamento devolvendo o aparelho para a nuvem: o certificado tem de sumir com
    // o endereço — credencial órfã no disco não serve para nada e confunde diagnóstico.
    await c.read(hostServidorProvider.notifier).definir(null);
    expect(c.read(hostServidorProvider).caPem, isNull);
    expect(
        (await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveCa])).isEmpty, isTrue);
  });

  test('o pareamento NÃO usa o destino guardado — vai sempre à nuvem', () async {
    // Se fosse ao servidor da loja, um endereço errado ou um servidor fora do ar
    // impediria o repareamento, que é justamente como se conserta isso.
    final urls = <String>[];
    final db = await novaDbMemoria();
    await db.insert('kv', {'chave': kvChaveHost, 'valor': 'https://servidor-antigo/api/v1'});
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      apiDePareamentoProvider.overrideWithValue(GogemApi(
        baseUrl: hostDoBuild,
        bearer: '',
        client: MockClient((req) async {
          urls.add(req.url.toString());
          return http.Response(jsonEncode({'token': 'novo'}), 200,
              headers: {'content-type': 'application/json'});
        }),
      )),
    ]);
    await c.read(deviceTokenProvider.notifier).carregar();
    expect(c.read(appConfigProvider).apiUrl, 'https://servidor-antigo/api/v1');

    await c.read(deviceTokenProvider.notifier).parear('123456');
    expect(urls.single, startsWith(hostDoBuild));
    // E o destino novo (ausente) devolveu o aparelho para a nuvem.
    expect(c.read(appConfigProvider).apiUrl, hostDoBuild);
  });
}
