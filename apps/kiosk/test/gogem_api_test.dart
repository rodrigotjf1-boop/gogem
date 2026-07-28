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

  test('parear troca o código de 6 dígitos por um token', () async {
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: '',
      client: MockClient((req) async {
        expect(req.url.path, endsWith('/publico/dispositivos/parear'));
        expect(jsonDecode(req.body)['codigo'], '123456');
        return _json({'token': 'abc123def', 'nome': 'Totem entrada'});
      }),
    );
    expect(await api.parear('123456'), 'abc123def');
  });

  test('parear com código inválido lança GogemApiException', () async {
    final api = GogemApi(
      baseUrl: 'http://t/api/v1',
      bearer: '',
      client: MockClient((_) async => _json({'message': 'inválido'}, 400)),
    );
    expect(() => api.parear('000000'), throwsA(isA<GogemApiException>()));
  });
}
