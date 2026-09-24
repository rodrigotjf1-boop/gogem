import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/core/config/host_servidor.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart'
    show orderRepositoryProvider;
import 'package:gogem_kiosk/domain/payment/payment_provider.dart';
import 'package:gogem_payment/payment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fakes.dart';
import 'fixtures.dart';

/// K4 — pedido RETIDO (loja com servidor local).
///
/// O pedido entra no servidor ANTES de cobrar, sem ir para a cozinha. O que estes
/// testes garantem: a senha que o cliente vê é a do SERVIDOR; o pagamento aprovado
/// LIBERA o que já está lá (não lança uma venda nova); e a recusa NÃO encerra o pedido —
/// ele fica esperando o cliente decidir, com o botão de cancelar aparecendo.

/// Notifier falso: força a loja em "modo servidor" sem tocar em banco.
class _ComServidor extends HostServidorNotifier {
  @override
  DestinoServidor build() =>
      const DestinoServidor(apiBase: 'https://servidor.loja/api/v1');
}

void main() {
  late List<String> chamadas;

  http.Client servidorFake({bool falhaAoAbrir = false}) =>
      MockClient((req) async {
        chamadas.add('${req.method} ${req.url.path}');
        if (req.url.path.endsWith('/vendas/retido')) {
          if (falhaAoAbrir) return http.Response('erro', 500);
          return http.Response(
              jsonEncode({'pedidoId': 'ped-1', 'senha': 42, 'total': 7}), 201,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/vendas/ped-1/liberar')) {
          return http.Response(
              jsonEncode({'comandaId': 'c1', 'senha': 42, 'total': 7}), 201,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/vendas/ped-1/cancelar')) {
          return http.Response(jsonEncode({'ok': true}), 201,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      });

  Future<void> ateOPagamento(
    WidgetTester tester, {
    required http.Client client,
    FakeOutcome outcome = FakeOutcome.approved,
  }) async {
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => FakeOrderRepository()),
        hostServidorProvider.overrideWith(_ComServidor.new),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'https://servidor.loja/api/v1',
            bearer: '',
            deviceToken: 'tok',
            client: client)),
        paymentProviderProvider.overrideWithValue(
            FakePaymentProvider(outcome: outcome, delay: Duration.zero)),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));
    _ir(tester, '/carrinho');
    await _bombear(tester);
    await tester.tap(find.byKey(const ValueKey('continuar')));
    await _bombear(tester);
    await tester.tap(find.byKey(const ValueKey('pular')));
    await _bombear(tester);
    expect(find.text('PAGAMENTO'), findsOneWidget);
  }

  setUp(() => chamadas = []);

  testWidgets('aprovado: abre o retido, mostra a senha do servidor e LIBERA',
      (tester) async {
    await ateOPagamento(tester, client: servidorFake());
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await _bombear(tester);

    // Retido primeiro, liberar depois — nunca a venda direta.
    expect(chamadas, contains('POST /api/v1/vendas/retido'));
    expect(chamadas, contains('POST /api/v1/vendas/ped-1/liberar'));
    expect(chamadas.any((c) => c.endsWith('POST /api/v1/vendas')), isFalse);

    expect(find.text('PEDIDO CONFIRMADO!'), findsOneWidget);
    // A senha na tela é a do SERVIDOR (42), não a sequencial local do totem.
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('recusado: o retido NAO e encerrado e aparece cancelar a compra',
      (tester) async {
    await ateOPagamento(tester,
        client: servidorFake(), outcome: FakeOutcome.denied);
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await _bombear(tester);

    expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
    expect(chamadas, contains('POST /api/v1/vendas/retido'));
    // Recusa não cancela: o cliente ainda pode tentar de novo com a MESMA senha.
    expect(chamadas.any((c) => c.contains('cancelar')), isFalse);
    expect(find.byKey(const ValueKey('cancelar-compra')), findsOneWidget);
  });

  testWidgets('cliente desiste: cancela no servidor e volta ao inicio',
      (tester) async {
    await ateOPagamento(tester,
        client: servidorFake(), outcome: FakeOutcome.denied);
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await _bombear(tester);

    await tester.tap(find.byKey(const ValueKey('cancelar-compra')));
    await _bombear(tester);
    expect(chamadas, contains('POST /api/v1/vendas/ped-1/cancelar'));
  });

  testWidgets('servidor fora: nao cobra — avisa e nao deixa pedido orfao',
      (tester) async {
    await ateOPagamento(tester, client: servidorFake(falhaAoAbrir: true));
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await _bombear(tester);

    // Cobrar sem conseguir registrar deixaria o cliente pago e a cozinha sem pedido.
    expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
    expect(chamadas.any((c) => c.contains('liberar')), isFalse);
  });
}

void _ir(WidgetTester t, String path) {
  final ctx = t.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).go(path);
}

/// Mesma cadência do teste de checkout (8 × 100ms): menos que isso e a tela de
/// identificação ainda não montou quando o teste procura o botão.
Future<void> _bombear(WidgetTester t, [int vezes = 8]) async {
  for (var i = 0; i < vezes; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
