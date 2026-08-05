import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart'
    show orderRepositoryProvider;
import 'package:gogem_kiosk/domain/payment/payment_provider.dart';
import 'package:gogem_payment/payment.dart';
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'fakes.dart';
import 'fixtures.dart';

/// Ponta a ponta em widget: carrinho → pular CPF → pagar (mock) →
/// confirmação com senha → carrinho limpo → pedido na fila local.
void main() {

  testWidgets('checkout mock completo', (tester) async {
    final repo = FakeOrderRepository();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    final scope = ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        // Repos em memória (sem sqflite) — senão a query no widget congela o
        // teste sob o relógio-falso. Ver test/fakes.dart.
        orderRepositoryProvider.overrideWith((ref) => repo),
        // A drenagem F6 (unawaited) é disparada no pagamento; API mock offline
        // evita bater rede real.
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'http://t/api/v1',
            bearer: 'jwt',
            client: MockClient((_) async => throw Exception('offline')))),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    );
    await tester.pumpWidget(scope);
    await tester.pump(const Duration(milliseconds: 300));

    // semeia o carrinho direto (o fluxo de produto tem teste próprio)
    final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {})); // 700

    // navega para o carrinho (contexto de um widget DENTRO da rota atual,
    // abaixo do InheritedGoRouter)
    go(tester, '/carrinho');
    await bombear(tester);
    expect(find.text('R\$ 7,00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('continuar')));
    await bombear(tester);
    expect(find.text('SEUS DADOS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pular')));
    await bombear(tester);
    expect(find.text('PAGAMENTO'), findsOneWidget);

    // Crédito passa pelo provider fake (aprovado). PIX tem fluxo próprio (teste
    // dedicado abaixo).
    await tester.tap(find.byKey(const ValueKey('forma-credito')));
    await tester.pump(const Duration(milliseconds: 200)); // spinner
    await tester.pump(const Duration(seconds: 1)); // processamento mock
    await bombear(tester);

    expect(find.text('PEDIDO CONFIRMADO!'), findsOneWidget);
    expect(find.byKey(const ValueKey('senha')), findsOneWidget);
    expect(container.read(cartProvider).vazio, isTrue);
    expect(await repo.pendentes(), 1);

    // consome o timer de auto-retorno (evita "timer pending" no harness)
    await tester.pump(const Duration(seconds: 9));
    await bombear(tester);
    expect(find.text('TOQUE PARA PEDIR'), findsOneWidget);
  });

  testWidgets('peça também (F2): sugere upsell, adiciona e segue', (
    tester,
  ) async {
    final repo = FakeOrderRepository();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    // Carrinho com p1 (Mister Burguer), que sugere p2 (Refri) e p3 (esgotado).
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[0], selecoes: const {}));

    go(tester, '/carrinho');
    await bombear(tester);
    await tester.tap(find.byKey(const ValueKey('continuar')));
    await bombear(tester);

    // Mostra o passo com o Refri (disponível); o esgotado (p3) fica de fora.
    expect(find.text('PEÇA TAMBÉM'), findsOneWidget);
    expect(find.text('Refri Lata'), findsOneWidget);
    expect(find.text('Esgotado Burger'), findsNothing);

    // Adiciona o Refri → entra no carrinho e some da lista.
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('sugestao-p2')),
        matching: find.byIcon(Icons.add_circle)));
    await bombear(tester);
    expect(container.read(cartProvider).totalItens, 2);

    // Segue para a identificação.
    await tester.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
    await bombear(tester);
    expect(find.text('SEUS DADOS'), findsOneWidget);
  });

  testWidgets('F4: nome + vale-refeição vão no pedido', (tester) async {
    final repo = FakeOrderRepository();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => repo),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'http://t/api/v1',
            bearer: 'jwt',
            client: MockClient((_) async => throw Exception('offline')))),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {})); // Refri

    go(tester, '/identificacao');
    await bombear(tester);
    // Informa o nome (F4) e pula o CPF.
    await tester.enterText(find.byKey(const ValueKey('nome-cliente')), 'Ana');
    await tester.tap(find.byKey(const ValueKey('pular')));
    await bombear(tester);

    // Paga com vale-refeição (F4).
    await tester.tap(find.byKey(const ValueKey('forma-vr')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await bombear(tester);

    final corpo = jsonDecode(repo.pedidos.single['corpo_json'] as String)
        as Map<String, dynamic>;
    expect(corpo['cliente'], 'Ana');
    expect(corpo['pagamentos'][0]['forma'], 'vr');

    await tester.pump(const Duration(seconds: 9));
    await bombear(tester);
  });

  // F7: a tela consome o PaymentProvider. Desfecho != aprovado NÃO fecha o
  // pedido — mostra o erro, preserva o carrinho, deixa tentar outra forma.
  for (final caso in [
    (nome: 'negado', outcome: FakeOutcome.denied),
    (nome: 'erro de comunicação', outcome: FakeOutcome.communicationError),
  ]) {
    testWidgets('pagamento ${caso.nome}: erro na tela, sem confirmar',
        (tester) async {
      final repo = FakeOrderRepository();
      final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          menuProvider.overrideWith((ref) async => snap),
          orderRepositoryProvider.overrideWith((ref) => repo),
          gogemApiProvider.overrideWithValue(GogemApi(
              baseUrl: 'http://t/api/v1',
              bearer: 'jwt',
              client: MockClient((_) async => throw Exception('offline')))),
          paymentProviderProvider.overrideWithValue(
              FakePaymentProvider(outcome: caso.outcome, delay: Duration.zero)),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      container.read(cartProvider.notifier).adicionar(
          ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));

      go(tester, '/identificacao');
      await bombear(tester);
      await tester.tap(find.byKey(const ValueKey('pular')));
      await bombear(tester);
      expect(find.text('PAGAMENTO'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('forma-credito')));
      await bombear(tester);

      // Erro visível, sem confirmação, carrinho intacto, nada persistido.
      expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
      expect(find.text('PEDIDO CONFIRMADO!'), findsNothing);
      expect(container.read(cartProvider).vazio, isFalse);
      expect(await repo.pendentes(), 0);
    });
  }

  // F8: ao escolher PIX, a tela mostra o QR (copia-e-cola + copiar + cancelar).
  // A lógica de aprovação/expiração/cancelamento/timeout do polling é coberta
  // pelos testes unitários do PixProvider (packages/payment).
  testWidgets('PIX: a tela mostra o QR e o copia-e-cola', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // totem retrato
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeOrderRepository();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => repo),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'http://t/api/v1',
            bearer: 'jwt',
            client: MockClient((_) async => throw Exception('offline')))),
        // Fica pendente → a tela permanece no QR (cancelamos no fim).
        pixProviderProvider.overrideWithValue(PixProvider(
            _FakePixGateway(const ['pending', 'pending', 'pending', 'pending']),
            pollInterval: const Duration(milliseconds: 400))),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));

    go(tester, '/identificacao');
    await bombear(tester);
    await tester.tap(find.byKey(const ValueKey('pular')));
    await bombear(tester);
    expect(find.text('PAGAMENTO'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forma-pix')));
    await tester.pump(const Duration(milliseconds: 100)); // cria + emite o QR

    expect(find.text('PAGUE COM PIX'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(const ValueKey('pix-copia-cola')), findsOneWidget);
    expect(find.byKey(const ValueKey('pix-copiar')), findsOneWidget);
    expect(find.byKey(const ValueKey('pix-cancelar')), findsOneWidget);
    // Nada de pedido enquanto o PIX não aprova.
    expect(await repo.pendentes(), 0);

    // Encerra o polling para não deixar timer pendente no teardown.
    container.read(pixProviderProvider).cancelar();
    await tester.pump(const Duration(seconds: 1));
    await bombear(tester);
  });
}

/// Navega pelo GoRouter usando o contexto de um Scaffold da rota corrente
/// (garantidamente abaixo do InheritedGoRouter injetado pelo MaterialApp.router).
void go(WidgetTester t, String path) {
  final ctx = t.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).go(path);
}

Future<void> bombear(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Gateway PIX fake para os testes de widget: QR fixo; `status` percorre a
/// sequência de estados informada.
class _FakePixGateway implements PixGateway {
  _FakePixGateway(this._statuses);
  final List<String> _statuses;
  int _i = 0;

  @override
  Future<PixCharge> criar(PaymentRequest req) async => PixCharge(
        id: 'chg-test',
        status: 'pending',
        amountCents: req.amountCents,
        copiaECola: '00020126BR.GOV.BCB.PIX.TEST6304ABCD',
      );

  @override
  Future<PixCharge> status(String chargeId) async {
    final s = _i < _statuses.length ? _statuses[_i++] : 'pending';
    return PixCharge(id: chargeId, status: s, amountCents: 100);
  }
}
