import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/fiscal/fiscal_loja.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart'
    show orderRepositoryProvider;
import 'fakes.dart';
import 'fixtures.dart';

/// CPF obrigatório acima do limite de identificação da UF.
///
/// No totem a NFC-e só é emitida DEPOIS de o pagamento aprovar. Se a compra passa do
/// limite (R$ 2.000,00 no RJ) e o cliente pula o CPF, o Regem recusa a nota com o
/// dinheiro já cobrado — e o caminho vira estorno. Por isso o CPF é exigido ANTES.
void main() {
  group('FiscalLoja.cpfObrigatorio', () {
    const rj = FiscalLoja(ativo: true, limiteIdentificacaoCentavos: 200000);

    test('acima do limite: obrigatório', () {
      expect(rj.cpfObrigatorio(200001), isTrue);
      expect(rj.cpfObrigatorio(250000), isTrue);
    });

    test('NO limite ou abaixo: opcional (a regra do Regem é ">", não ">=")', () {
      expect(rj.cpfObrigatorio(200000), isFalse);
      expect(rj.cpfObrigatorio(1999), isFalse);
    });

    test('loja sem fiscal, ou sem limite informado: nunca obriga', () {
      expect(const FiscalLoja(ativo: false, limiteIdentificacaoCentavos: 200000)
          .cpfObrigatorio(999999), isFalse);
      expect(const FiscalLoja(ativo: true).cpfObrigatorio(999999), isFalse);
      expect(FiscalLoja.semFiscal.cpfObrigatorio(999999), isFalse);
    });

    test('lê o bloco que o servidor manda; lixo vira "sem fiscal"', () {
      final f = FiscalLoja.fromJson(
          {'ativo': true, 'limiteIdentificacaoCentavos': 200000});
      expect(f.ativo, isTrue);
      expect(f.limiteIdentificacaoCentavos, 200000);
      expect(FiscalLoja.fromJson(null).ativo, isFalse);
      expect(FiscalLoja.fromJson('x').ativo, isFalse);
      expect(FiscalLoja.fromJson({'ativo': 'sim'}).ativo, isFalse);
    });
  });

  group('tela de identificação', () {
    Future<void> ateIdentificacao(WidgetTester tester, FiscalLoja fiscal) async {
      final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          menuProvider.overrideWith((ref) async => snap),
          orderRepositoryProvider.overrideWith((ref) => FakeOrderRepository()),
          fiscalProvider.overrideWith((ref) async => fiscal),
          // Nada sai para a rede no teste (o atualizador consulta a API no boot).
          gogemApiProvider.overrideWithValue(GogemApi(
              baseUrl: 'https://servidor.loja/api/v1',
              bearer: '',
              deviceToken: 'tok',
              client: MockClient((_) async => http.Response('{}', 200,
                  headers: {'content-type': 'application/json'})))),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      container.read(cartProvider.notifier).adicionar(
          ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/carrinho');
      await _bombear(tester);
      await tester.tap(find.byKey(const ValueKey('continuar')));
      await _bombear(tester);
      expect(find.byKey(const ValueKey('cpf-display')), findsOneWidget);
    }

    testWidgets('acima do limite: aviso na tela e PULAR não funciona',
        (tester) async {
      // Limite de 1 centavo: qualquer produto da fixture passa dele.
      await ateIdentificacao(
          tester, const FiscalLoja(ativo: true, limiteIdentificacaoCentavos: 1));
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      final pular =
          tester.widget<OutlinedButton>(find.byKey(const ValueKey('pular')));
      expect(pular.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('pular')));
      await _bombear(tester);
      // Continua na identificação — não foi para o pagamento.
      expect(find.byKey(const ValueKey('cpf-display')), findsOneWidget);
      expect(find.text('PAGAMENTO'), findsNothing);
    });

    testWidgets('abaixo do limite: CPF continua opcional', (tester) async {
      await ateIdentificacao(tester,
          const FiscalLoja(ativo: true, limiteIdentificacaoCentavos: 99999999));
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsNothing);
      final pular =
          tester.widget<OutlinedButton>(find.byKey(const ValueKey('pular')));
      expect(pular.onPressed, isNotNull);
    });

    testWidgets('loja sem fiscal (nuvem ou servidor antigo): nada muda',
        (tester) async {
      await ateIdentificacao(tester, FiscalLoja.semFiscal);
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsNothing);
      final pular =
          tester.widget<OutlinedButton>(find.byKey(const ValueKey('pular')));
      expect(pular.onPressed, isNotNull);
    });
  });
}

Future<void> _bombear(WidgetTester t, [int vezes = 8]) async {
  for (var i = 0; i < vezes; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
