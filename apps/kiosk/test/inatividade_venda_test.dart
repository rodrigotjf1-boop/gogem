import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/core/kiosk/inatividade_guard.dart';
import 'package:gogem_kiosk/core/router.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart'
    show orderRepositoryProvider;
import 'package:gogem_kiosk/domain/payment/payment_provider.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart'
    show filaImpressaoProvider;
import 'package:gogem_kiosk/printing/printer_providers.dart';
import 'package:gogem_payment/payment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fakes.dart';
import 'fixtures.dart';

/// ERR-021 — o retorno por inatividade NÃO pode interromper uma venda.
///
/// Na venda o cliente não toca na tela: paga no celular (PIX), na maquininha, espera a
/// nota. O guarda de inatividade (90 s sem toque) levava o totem ao descanso no meio disso:
/// a tela de pagamento era descartada e a finalização morria no primeiro `ref.read` — o
/// pagamento aprovado não era enviado ao Regem nem impresso (só no próximo boot).
void main() {
  testWidgets(
      'pagamento aprovado DEPOIS do limite de inatividade: a venda é enviada e confirmada',
      (tester) async {
    final chamadas = <String>[];
    final repo = FakeOrderRepository();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    final client = MockClient((req) async {
      chamadas.add('${req.method} ${req.url.path}');
      if (req.url.path.endsWith('/vendas')) {
        return http.Response(
            jsonEncode({'comandaId': 'c1', 'senha': 7, 'total': 7}), 201,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => repo),
        printerTransportProvider.overrideWithValue(FakeTransport()),
        filaImpressaoProvider.overrideWith((ref) => FakeFilaImpressao()),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'https://nuvem/api',
            bearer: '',
            deviceToken: 'tok',
            client: client)),
        // A maquininha leva 10 s — o dobro do limite de inatividade deste teste.
        paymentProviderProvider.overrideWithValue(FakePaymentProvider(
            outcome: FakeOutcome.approved,
            delay: const Duration(seconds: 10))),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => InatividadeGuard(
          limite: const Duration(seconds: 5),
          aoExpirar: () => router.go('/descanso'),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/pagamento');
    await _bombear(tester);
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    // 12 s sem tocar na tela: a maquininha aprova aos 10 s.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _bombear(tester, 20);

    expect(chamadas, contains('POST /api/vendas'));
    expect(repo.pedidos.single['status'], 'enviado');
    // A senha na tela: o prazo que corria durante a venda NÃO pode vencer logo depois dela.
    expect(find.byKey(const ValueKey('senha')), findsOneWidget);
    // A venda acabou: o guarda volta a valer — e conta do zero a partir daqui.
    expect(container.read(vendaEmAndamentoDesdeProvider), isNull);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('senha')), findsNothing); // voltou ao descanso

    router.go('/descanso');
    await _bombear(tester, 3);
  });
}

Future<void> _bombear(WidgetTester t, [int vezes = 8]) async {
  for (var i = 0; i < vezes; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
