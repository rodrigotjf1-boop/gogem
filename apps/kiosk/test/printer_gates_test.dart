import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'package:gogem_kiosk/features/pedido/pagamento_screen.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';
import 'package:gogem_kiosk/printing/printer_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'fakes.dart';
import 'fixtures.dart';

Future<void> bombear(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {

  testWidgets('PORTÃO 1 — descanso: sem papel => FORA DE OPERAÇÃO e toque bloqueado',
      (tester) async {
    final fake = FakeTransport()..semPapel = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [printerTransportProvider.overrideWithValue(fake)],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await bombear(tester);
    expect(find.byKey(const ValueKey('fora-operacao')), findsOneWidget);
    expect(find.textContaining('sem papel'), findsOneWidget);
    // toque não navega
    await tester.tap(find.text('TOTEM FORA DE OPERACAO'), warnIfMissed: false);
    await bombear(tester, 4);
    expect(find.text('MONTE SEU PEDIDO'), findsNothing);
  });

  testWidgets('descanso: near-end mostra aviso mas NÃO bloqueia', (tester) async {
    final fake = FakeTransport()..pertoDoFim = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [printerTransportProvider.overrideWithValue(fake)],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await bombear(tester);
    expect(find.byKey(const ValueKey('aviso-nearend')), findsOneWidget);
    expect(find.byKey(const ValueKey('fora-operacao')), findsNothing);
    await tester.tap(find.text('TOQUE PARA PEDIR'));
    await bombear(tester);
    expect(find.text('MONTE SEU PEDIDO'), findsOneWidget);
  });

  testWidgets('PORTÃO 2 — pagamento bloqueia com tampa aberta e libera no retry',
      (tester) async {
    final fake = FakeTransport()..tampaAberta = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [printerTransportProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: PagamentoScreen()),
    ));
    await bombear(tester, 4);
    expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
    expect(find.textContaining('tampa aberta'), findsOneWidget);
    // fecha a tampa e tenta de novo
    fake.tampaAberta = false;
    await tester.tap(find.byKey(const ValueKey('tentar-novamente')));
    await bombear(tester, 4);
    expect(find.text('PAGAMENTO'), findsOneWidget);
  });

  testWidgets(
      'JANELA RESIDUAL — papel acaba após aprovar: pedido salvo, senha na tela, '
      'aviso e cupom na fila de reimpressão', (tester) async {
    final repo = FakeOrderRepository();
    final fila = FakeFilaImpressao();
    final fake = FakeTransport();
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        printerTransportProvider.overrideWithValue(fake),
        menuProvider.overrideWith((ref) async => snap),
        // Repos em memória (sem sqflite) — ver test/fakes.dart.
        orderRepositoryProvider.overrideWith((ref) => repo),
        filaImpressaoProvider.overrideWith((ref) => fila),
        // API offline determinística: a drenagem F6 disparada no pagamento
        // falha rápido e o pedido permanece pendente (asserção abaixo).
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'http://t/api/v1',
            bearer: 'jwt',
            client: MockClient((_) async => throw Exception('offline')))),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await bombear(tester);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));

    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).go('/pagamento');
    await bombear(tester, 4);
    expect(find.text('PAGAMENTO'), findsOneWidget);

    // portões passam; o papel acaba DEPOIS do pré-check da impressão
    // 8 leituras nos dois portões (tela + pagar) + a consulta do imprimir
    // (4 leituras: printer/offline/error/paper). O papel precisa "acabar" ANTES
    // da última leitura (paper, a 12ª) para que o status consolidado do imprimir
    // já reporte SEM PAPEL — daí o cupom vai para a fila e aparece o aviso.
    var lidas = 0;
    fake.aposLeitura = () {
      lidas++;
      if (lidas >= 11) fake.semPapel = true;
    };
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await bombear(tester, 3); // spinner
    await tester.pump(const Duration(seconds: 1)); // processamento mock
    await bombear(tester);

    expect(find.text('PEDIDO CONFIRMADO!'), findsOneWidget);
    expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
    expect(await repo.pendentes(), 1); // venda NUNCA se perde
    expect(await fila.pendentes(), 1); // cupom aguardando reimpressão

    await tester.pump(const Duration(seconds: 9)); // consome auto-retorno
    await bombear(tester);
  });
}
