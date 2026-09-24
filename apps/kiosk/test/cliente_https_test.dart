import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/config/cliente_https.dart';

/// K2 — o totem confia na autoridade do servidor da loja, e um certificado ilegível NÃO
/// pode tirar o aparelho do ar.
void main() {
  final caReal = File('test/fixtures/ca_exemplo.pem').readAsStringSync();

  test('certificado válido vira contexto TLS confiando nele', () {
    expect(contextoComCa(caReal), isA<SecurityContext>());
  });

  test('sem certificado, nada de contexto próprio (é a nuvem)', () {
    expect(contextoComCa(null), isNull);
    expect(contextoComCa('   '), isNull);
  });

  test('certificado ilegível não derruba o app', () {
    const ruim =
        '-----BEGIN CERTIFICATE-----\nisto nao e base64 valido\n-----END CERTIFICATE-----';
    expect(() => contextoComCa(ruim), returnsNormally);
    expect(contextoComCa(ruim), isNull);
  });

  test('o cliente sai pronto em qualquer caso', () {
    for (final pem in [null, '', 'lixo', caReal]) {
      expect(() => clienteParaServidor(pem), returnsNormally);
    }
  });
}
