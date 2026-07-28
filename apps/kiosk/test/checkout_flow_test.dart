import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'db_helper.dart';
import 'fixtures.dart';

/// Ponta a ponta em widget: carrinho → pular CPF → pagar (mock) →
/// confirmação com senha → carrinho limpo → pedido na fila local.
void main() {

  testWidgets('checkout mock completo', (tester) async {
    final db = await novaDbMemoria();
    final repo = OrderRepository(db);
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    final scope = ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) async => repo),
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
    expect(find.text('CPF NA NOTA?'), findsOneWidget);

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
