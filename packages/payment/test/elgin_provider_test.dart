import 'dart:convert';

import 'package:gogem_payment/payment.dart';
import 'package:test/test.dart';

/// Transporte fake: guarda os extras recebidos e devolve um `retorno` canned.
class _FakeElginTransport implements ElginTefTransport {
  _FakeElginTransport(this.retorno, {this.online = true, this.demora});
  final String retorno;
  final bool online;
  final Duration? demora;
  Map<String, String>? ultimoExtras;

  @override
  Future<String> executar(Map<String, String> extras) async {
    ultimoExtras = extras;
    if (demora != null) await Future<void>.delayed(demora!);
    return retorno;
  }

  @override
  Future<bool> disponivel() async => online;
}

String _retornoAprovado() => jsonEncode({
      'funcao': 'credito',
      'mensagem': 'Sucesso',
      'resultado': {
        'mensagem': 'APROVADO',
        'autorizacao': '123456',
        'nsu': '000144',
        'rede': 'REDE',
        'viaCliente': 'VIA CLIENTE\n...\n',
        'viaEstabelecimento': 'VIA ESTABELECIMENTO\n...\n',
        'valor': '83.60',
      },
    });

PaymentRequest _req({
  PaymentMethod metodo = PaymentMethod.credito,
  int parcelas = 1,
}) =>
    PaymentRequest(
      orderId: 'order-1',
      amountCents: 8360,
      method: metodo,
      installments: parcelas,
    );

void main() {
  group('ElginTefProvider', () {
    test('crédito à vista: extras corretos + aprovado com NSU e vias', () async {
      final tr = _FakeElginTransport(_retornoAprovado());
      final p = ElginTefProvider(tr);
      final r = await p.start(_req());

      expect(tr.ultimoExtras, {
        'funcao': 'credito',
        'valor': '8360', // crédito/débito vão em CENTAVOS
        'parcelas': '1',
        'financiamento': '1',
      });
      expect(r.status, PaymentStatus.approved);
      expect(r.nsu, '000144');
      expect(r.authCode, '123456');
      expect(r.customerReceipt, contains('VIA CLIENTE'));
      expect(r.merchantReceipt, contains('VIA ESTABELECIMENTO'));
      p.dispose();
    });

    test('crédito parcelado: financiamento 3 e parcelas N', () async {
      final tr = _FakeElginTransport(_retornoAprovado());
      final p = ElginTefProvider(tr);
      await p.start(_req(parcelas: 3));
      expect(tr.ultimoExtras?['parcelas'], '3');
      expect(tr.ultimoExtras?['financiamento'], '3');
      p.dispose();
    });

    test('débito: valor em centavos, sem parcelas', () async {
      final tr = _FakeElginTransport(_retornoAprovado());
      final p = ElginTefProvider(tr);
      await p.start(_req(metodo: PaymentMethod.debito));
      expect(tr.ultimoExtras, {'funcao': 'debito', 'valor': '8360'});
      p.dispose();
    });

    test('mensagem de erro => negado', () async {
      final tr = _FakeElginTransport(
          jsonEncode({'funcao': 'credito', 'mensagem': 'Cartão recusado'}));
      final p = ElginTefProvider(tr);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.denied);
      expect(r.message, 'Cartão recusado');
      p.dispose();
    });

    test('mensagem de cancelamento => cancelled', () async {
      final tr = _FakeElginTransport(jsonEncode(
          {'funcao': 'credito', 'mensagem': 'Operação cancelada pelo usuário'}));
      final p = ElginTefProvider(tr);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.cancelled);
      p.dispose();
    });

    test('cliente parado no pinpad => timeout', () async {
      final tr = _FakeElginTransport(_retornoAprovado(),
          demora: const Duration(milliseconds: 200));
      final p =
          ElginTefProvider(tr, timeout: const Duration(milliseconds: 20));
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.timeout);
      p.dispose();
    });

    test('retorno inválido (não-JSON) => error', () async {
      final tr = _FakeElginTransport('nao é json');
      final p = ElginTefProvider(tr);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.error);
      p.dispose();
    });

    test('healthCheck reflete a disponibilidade do IDH', () async {
      final onl = ElginTefProvider(_FakeElginTransport('{}', online: true));
      final off = ElginTefProvider(_FakeElginTransport('{}', online: false));
      expect(await onl.healthCheck(), isTrue);
      expect(await off.healthCheck(), isFalse);
      onl.dispose();
      off.dispose();
    });
  });
}
