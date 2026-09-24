import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Cabeçalho case-insensitive (o http normaliza a caixa ao enviar).
String? _h(Map<String, String> headers, String nome) {
  for (final e in headers.entries) {
    if (e.key.toLowerCase() == nome.toLowerCase()) return e.value;
  }
  return null;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('pareado: envia X-Device-Token e NÃO o Bearer', () async {
    Map<String, String>? headers;
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: 'jwt-dev',
      deviceToken: 'devtok',
      client: MockClient((req) async {
        headers = req.headers;
        return _json({'atualizado': false});
      }),
    );
    await api.getCatalogoPublicado(desde: 1);
    expect(_h(headers!, 'X-Device-Token'), 'devtok');
    expect(_h(headers!, 'Authorization'), isNull);
  });

  test('sem pareamento: cai no Bearer JWT de dev', () async {
    Map<String, String>? headers;
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: 'jwt-dev',
      client: MockClient((req) async {
        headers = req.headers;
        return _json({'atualizado': false});
      }),
    );
    await api.getCatalogoPublicado(desde: 1);
    expect(_h(headers!, 'Authorization'), 'Bearer jwt-dev');
    expect(_h(headers!, 'X-Device-Token'), isNull);
  });

  test('parear troca o código de 6 dígitos por token + destino', () async {
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: '',
      client: MockClient((req) async {
        expect(req.url.path, endsWith('/publico/dispositivos/parear'));
        expect(jsonDecode(req.body)['codigo'], '123456');
        return _json({
          'token': 'abc123def',
          'nome': 'Totem entrada',
          'apiBase': 'https://192.168.0.50:3002/api/v1',
        });
      }),
    );
    final r = await api.parear('123456');
    expect(r.token, 'abc123def');
    expect(r.apiBase, 'https://192.168.0.50:3002/api/v1');
  });

  // Loja SEM servidor local: a nuvem não manda destino e o totem segue no host do
  // build. É o comportamento de hoje, e ele não pode quebrar com o campo novo.
  test('parear sem apiBase mantém o totem na nuvem', () async {
    for (final corpo in [
      {'token': 'tok', 'nome': 'Totem'},
      {'token': 'tok', 'nome': 'Totem', 'apiBase': null},
      {'token': 'tok', 'nome': 'Totem', 'apiBase': '   '},
    ]) {
      final api = GogemApi(
        baseUrl: 'http://t/api/v1',
        bearer: '',
        client: MockClient((_) async => _json(corpo)),
      );
      final r = await api.parear('123456');
      expect(r.token, 'tok');
      expect(r.apiBase, isNull);
    }
  });

  test('parear com código inválido lança GogemApiException', () async {
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: '',
      client: MockClient((_) async => _json({'message': 'inválido'}, 400)),
    );
    expect(() => api.parear('000000'), throwsA(isA<GogemApiException>()));
  });

  group('resultado fiscal (Regem #574)', () {
    test('estornarPagamento: POST /pagamentos/estorno e devolve o `estorno`',
        () async {
      http.Request? pedido;
      final api = GogemApi(
        baseUrl: 'http://t/api/v1',
        bearer: '',
        deviceToken: 'tok',
        client: MockClient((req) async {
          pedido = req;
          return _json({
            'pedidoId': 'p1',
            'estorno': {'feito': true, 'meio': 'pix', 'valorCentavos': 700}
          });
        }),
      );
      final e = await api.estornarPagamento(
          orderId: 'u1', motivo: 'NFC-e não emitida', etapa: 'rejeitada', senha: 42);
      expect(pedido!.url.path, '/api/v1/pagamentos/estorno');
      expect(jsonDecode(pedido!.body),
          {'orderId': 'u1', 'motivo': 'NFC-e não emitida', 'etapa': 'rejeitada', 'senha': 42});
      expect(e['feito'], isTrue);
    });

    test('estornarPagamento: erro do servidor LANÇA (quem chama decide se fica pendente)',
        () async {
      final api = GogemApi(
        baseUrl: 'http://t/api/v1',
        bearer: '',
        deviceToken: 'tok',
        client: MockClient((_) async => http.Response('bad gateway', 502)),
      );
      expect(api.estornarPagamento(orderId: 'u1', motivo: 'x'),
          throwsA(isA<GogemApiException>().having((e) => e.status, 'status', 502)));
    });

    test('falhaImpressao: POST /vendas/:id/falha-impressao com o motivo', () async {
      http.Request? pedido;
      final api = GogemApi(
        baseUrl: 'http://t/api/v1',
        bearer: '',
        deviceToken: 'tok',
        client: MockClient((req) async {
          pedido = req;
          return _json({'ok': true, 'notaCancelada': true, 'cancelamentoPendente': false}, 201);
        }),
      );
      final r = await api.falhaImpressao('ped-1', 'sem papel');
      expect(pedido!.url.path, '/api/v1/vendas/ped-1/falha-impressao');
      expect(jsonDecode(pedido!.body), {'motivo': 'sem papel'});
      expect(r['ok'], isTrue);
    });

    test('GogemApiException.motivo limpa a mensagem do Nest', () {
      expect(
          GogemApiException(422, jsonEncode({'message': 'O sistema da loja recusou a venda: X9'}))
              .motivo,
          'O sistema da loja recusou a venda: X9');
      expect(GogemApiException(400, jsonEncode({'message': ['a', 'b']})).motivo, 'a; b');
      expect(GogemApiException(502, 'bad gateway').motivo, 'bad gateway');
    });

    test('recusa definitiva = 400/422; o resto se reenvia', () {
      expect(recusaDefinitiva(400), isTrue);
      expect(recusaDefinitiva(422), isTrue);
      for (final s in [401, 403, 404, 408, 409, 429, 500, 502, 503]) {
        expect(recusaDefinitiva(s), isFalse, reason: '$s');
      }
    });
  });
}
