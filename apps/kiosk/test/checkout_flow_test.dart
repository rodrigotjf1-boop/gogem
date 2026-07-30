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
import 'package:http/testing.dart';
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

    await tester.tap(find.byKey(const ValueKey('forma-pix')));
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
