import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/api/repete_na_conexao.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// ERR-044 — no totem, a PRIMEIRA chamada à nuvem depois de abrir o app às vezes falha
/// com "No route to host" (errno 113) e a seguinte passa: o primeiro PIX mostrava erro
/// e o atualizador falhava sempre ao abrir. Repete UMA vez só o erro de conexão.
void main() {
  SocketException semRota() => const SocketException('No route to host',
      osError: OSError('No route to host', 113));

  test('erro de conexão (errno 113): repete uma vez com o MESMO pedido e passa', () async {
    final vistos = <http.Request>[];
    final interno = MockClient((req) async {
      vistos.add(req);
      if (vistos.length == 1) throw semRota();
      return http.Response('{"ok":true}', 201);
    });
    final cliente = ClienteQueRepeteNaConexao(interno, espera: Duration.zero);

    final r = await cliente.post(Uri.parse('https://api.exemplo/api/v1/pagamentos/pix'),
        headers: {'X-Device-Token': 'tok', 'Content-Type': 'application/json'},
        body: '{"orderId":"o-1","amountCents":3250}');

    expect(r.statusCode, 201);
    expect(vistos, hasLength(2));
    expect(vistos[1].method, 'POST');
    expect(vistos[1].url, vistos[0].url);
    expect(vistos[1].body, '{"orderId":"o-1","amountCents":3250}');
    expect(vistos[1].headers['X-Device-Token'], 'tok');
  });

  test('erro depois de conectar (conexão derrubada): NÃO repete', () async {
    var chamadas = 0;
    final interno = MockClient((req) async {
      chamadas++;
      throw http.ClientException('Connection reset by peer');
    });
    final cliente = ClienteQueRepeteNaConexao(interno, espera: Duration.zero);

    await expectLater(cliente.get(Uri.parse('https://api.exemplo/x')),
        throwsA(isA<http.ClientException>()));
    expect(chamadas, 1);
  });

  test('a repetição também falha: sobe o erro, sem laço', () async {
    var chamadas = 0;
    final interno = MockClient((req) async {
      chamadas++;
      throw semRota();
    });
    final cliente = ClienteQueRepeteNaConexao(interno, espera: Duration.zero);

    await expectLater(cliente.get(Uri.parse('https://api.exemplo/x')),
        throwsA(isA<SocketException>()));
    expect(chamadas, 2);
  });

  test('o erro chega embrulhado num ClientException: reconhece pela mensagem', () {
    expect(
        falhaAoConectar(http.ClientException(
            'SocketException: No route to host (OS Error: No route to host, errno = 113)')),
        isTrue);
    expect(falhaAoConectar(http.ClientException('Connection closed while receiving data')),
        isFalse);
  });

  test('a GogemApi usa o cliente que repete (o atualizador ao abrir passa)', () async {
    var chamadas = 0;
    final interno = MockClient((req) async {
      chamadas++;
      if (chamadas == 1) throw semRota();
      return http.Response('null', 200); // sem versão nova
    });
    final api = GogemApi(baseUrl: 'https://api.exemplo/api/v1', bearer: '', client: interno);

    expect(await api.latestRelease(), isNull);
    expect(chamadas, 2);
  });
}
