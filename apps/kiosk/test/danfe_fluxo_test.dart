import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/app.dart';
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

/// K6 — o caminho inteiro: venda aprovada → o Regem devolve a NFC-e → o totem
/// IMPRIME o DANFE.
///
/// Sem isto, o cliente paga no cartão, leva o cupom da cozinha e vai embora sem o
/// documento fiscal a que tem direito — e ninguém no balcão fica sabendo.
void main() {
  const qr = 'https://www.nfce.fazenda.rj.gov.br/consulta?p=3326|2|1|1|ABC';
  const danfe = 'DANFE NFC-e\nSerie 51 No 2\nTOTAL: R\$ 7,00\n'
      'Chave: 33260900000000000191650510000000021000000029\n@QR:$qr';

  late FakeTransport papel;

  http.Client servidor({Map<String, dynamic>? nfce}) => MockClient((req) async {
        if (req.url.path.endsWith('/vendas')) {
          return http.Response(
              jsonEncode({'comandaId': 'c1', 'senha': 7, 'total': 7, 'nfce': nfce}),
              201,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      });

  Future<void> venderNoCartao(WidgetTester tester, http.Client client) async {
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => FakeOrderRepository()),
        printerTransportProvider.overrideWithValue(papel),
        // Sem isto, o caminho de falha trava: a fila real abre um sqflite que nao
        // existe no ambiente de teste.
        filaImpressaoProvider.overrideWith((ref) => FakeFilaImpressao()),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: 'https://nuvem/api',
            bearer: '',
            deviceToken: 'tok',
            client: client)),
        paymentProviderProvider.overrideWithValue(FakePaymentProvider(
            outcome: FakeOutcome.approved, delay: Duration.zero)),
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
    await tester.tap(find.byKey(const ValueKey('pular')));
    await _bombear(tester);
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await _bombear(tester, 14);
  }

  setUp(() => papel = FakeTransport());

  /// Quantas vezes o comando "imprime o simbolo QR" apareceu no papel.
  int qrsImpressos() => _contar(papel.tudoEscrito.join(','),
      [0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30].join(','));

  testWidgets('nota autorizada: o DANFE sai no papel, com o QR desenhado',
      (tester) async {
    await venderNoCartao(
        tester,
        servidor(nfce: {
          'status': 'autorizada',
          'chave': '33260900000000000191650510000000021000000029',
          'contingencia': false,
          'danfe': danfe,
        }));
    final txt = String.fromCharCodes(papel.tudoEscrito);
    expect(txt, contains('DANFE NFC-e'));
    expect(txt, contains('Chave: 33260900000000000191650510000000021000000029'));
    expect(txt, isNot(contains('@QR:'))); // virou código, não texto
    expect(qrsImpressos(), 1);
    // A tela NÃO acusa nota faltando.
    expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
  });

  testWidgets('contingencia: sai UMA via — a segunda e opt-in (mig 287 do Regem)',
      (tester) async {
    await venderNoCartao(
        tester,
        servidor(nfce: {
          'status': 'contingencia',
          'contingencia': true,
          'danfe': '$danfe\n*** EMITIDA EM CONTINGENCIA ***\n'
              'Aguardando autorizacao da SEFAZ.',
        }));
    final txt = String.fromCharCodes(papel.tudoEscrito);
    // A mensagem obrigatória vem no texto do EMITENTE — o totem não a inventa.
    expect(txt, contains('EMITIDA EM CONTINGENCIA'));
    // Papel que ninguém arquiva não sai: a guarda é o XML (MOC 7.0, Anexo IV, §4).
    expect(txt, isNot(contains('VIA DO ESTABELECIMENTO')));
    expect(qrsImpressos(), 1);
  });

  testWidgets('contingencia com a 2a via LIGADA na loja: saem duas vias',
      (tester) async {
    await venderNoCartao(
        tester,
        servidor(nfce: {
          'status': 'contingencia',
          'contingencia': true,
          'viaEstabelecimento': true,
          'danfe': '$danfe\n*** EMITIDA EM CONTINGENCIA ***',
        }));
    final txt = String.fromCharCodes(papel.tudoEscrito);
    expect(txt, contains('VIA DO ESTABELECIMENTO'));
    expect(qrsImpressos(), 2);
  });

  testWidgets('loja sem fiscal: nada de DANFE, e sem aviso de nota faltando',
      (tester) async {
    await venderNoCartao(tester, servidor(nfce: null));
    expect(String.fromCharCodes(papel.tudoEscrito), isNot(contains('DANFE')));
    expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
  });

  testWidgets('nota emitida e impressora sem papel: o cliente e avisado',
      (tester) async {
    // O papel acaba DEPOIS do cupom (o totem nem deixa vender com a impressora
    // vazia — esse é o portão de venda). A nota, então, já está emitida: é o caso
    // que não pode passar calado.
    papel.aposLeitura = () {
      if (String.fromCharCodes(papel.tudoEscrito).contains('SENHA')) {
        papel.semPapel = true;
      }
    };
    await venderNoCartao(
        tester,
        servidor(nfce: {
          'status': 'autorizada',
          'contingencia': false,
          'danfe': danfe,
        }));
    // Documento fiscal que não saiu não pode virar silêncio: a tela manda o
    // cliente ao balcão com a senha (o cancelamento + estorno é o passo F4).
    expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
  });
}

int _contar(String texto, String agulha) {
  var n = 0, i = texto.indexOf(agulha);
  while (i != -1) {
    n++;
    i = texto.indexOf(agulha, i + 1);
  }
  return n;
}

Future<void> _bombear(WidgetTester t, [int vezes = 8]) async {
  for (var i = 0; i < vezes; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
