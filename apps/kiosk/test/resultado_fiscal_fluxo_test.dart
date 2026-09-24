import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/core/config/host_servidor.dart';
import 'package:gogem_kiosk/data/api/gogem_api.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/fiscal/bloqueio_fiscal.dart';
import 'package:gogem_kiosk/domain/fiscal/fiscal_loja.dart';
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

/// O resultado fiscal da venda no totem (contrato do Regem #574).
///
/// No totem a compra só termina com o cupom fiscal na mão do cliente. Estes testes
/// garantem, nos dois modos (nuvem e servidor da loja), que: a nota não emitida ESTORNA e
/// avisa sem imprimir cupom de um pedido que não existe; a venda recusada estorna e sai da
/// fila; o estorno sem rede fica pendente; o DANFE que não sai desfaz a venda no servidor
/// da loja (e não na nuvem); e a espera mostra "Emitindo o cupom fiscal…".
class _ComServidor extends HostServidorNotifier {
  @override
  DestinoServidor build() =>
      const DestinoServidor(apiBase: 'https://servidor.loja/api/v1');
}

const _danfe = 'DANFE NFC-e\nSerie 51 No 2\nTOTAL: R\$ 7,00\n'
    'Chave: 33260900000000000191650510000000021000000029\n'
    '@QR:https://www.nfce.fazenda.rj.gov.br/consulta?p=3326|2|1|1|ABC';

Map<String, dynamic> _naoEmitida({bool repete = true}) => {
      'status': 'nao_emitida',
      'danfe': null,
      'erro': {
        'etapa': 'rejeitada',
        'codigo': '778',
        'motivo': 'Informado NCM inexistente',
        'repete': repete,
      },
    };

http.Response _json(Object corpo, [int status = 201]) =>
    http.Response(jsonEncode(corpo), status,
        headers: {'content-type': 'application/json'});

class _Cena {
  final chamadas = <String>[];
  final corpos = <String, Map<String, dynamic>>{};
  final repo = FakeOrderRepository();
  final fila = FakeFilaImpressao();
  final papel = FakeTransport();
  late ProviderContainer container;

  String get impresso => String.fromCharCodes(papel.tudoEscrito);

  /// Monta o app e toca em CARTÃO com um item de R$ 7,00 no carrinho.
  Future<void> vender(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request req) servidor,
    bool modoServidor = false,
    bool fiscalAtivo = true,
    void Function(ProviderContainer c)? antesDePagar,
    bool bombearAteOFim = true,
  }) async {
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    final client = MockClient((req) async {
      final chave = '${req.method} ${req.url.path}';
      chamadas.add(chave);
      if (req.body.isNotEmpty) {
        try {
          corpos[chave] = jsonDecode(req.body) as Map<String, dynamic>;
        } catch (_) {}
      }
      return servidor(req);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) async => snap),
        orderRepositoryProvider.overrideWith((ref) => repo),
        printerTransportProvider.overrideWithValue(papel),
        filaImpressaoProvider.overrideWith((ref) => fila),
        fiscalProvider.overrideWith((ref) async =>
            FiscalLoja(ativo: fiscalAtivo, limiteIdentificacaoCentavos: 200000)),
        if (modoServidor) hostServidorProvider.overrideWith(_ComServidor.new),
        gogemApiProvider.overrideWithValue(GogemApi(
            baseUrl: modoServidor
                ? 'https://servidor.loja/api/v1'
                : 'https://nuvem/api',
            bearer: '',
            deviceToken: 'tok',
            client: client)),
        paymentProviderProvider.overrideWithValue(FakePaymentProvider(
            outcome: FakeOutcome.approved, delay: Duration.zero)),
      ],
      child: const GogemKioskApp(iniciarSync: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(cartProvider.notifier).adicionar(
        ItemCarrinho(produto: snap.produtos[1], selecoes: const {}));
    antesDePagar?.call(container);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/pagamento');
    await _bombear(tester);
    await tester.tap(find.byKey(const ValueKey('forma-cartao')));
    if (bombearAteOFim) await _bombear(tester, 30);
  }

  Future<void> sair(WidgetTester tester) async {
    // consome os timers de auto-retorno das telas de resultado
    await tester.pump(const Duration(seconds: 41));
    await _bombear(tester);
  }
}

void main() {
  group('NUVEM', () {
    testWidgets(
        'nota NÃO emitida: a nuvem já estornou — o totem avisa, não imprime nada e não pede de novo',
        (tester) async {
      final cena = _Cena();
      await cena.vender(tester, servidor: (req) async {
        if (req.url.path.endsWith('/vendas')) {
          return _json({
            'comandaId': 'c1',
            'senha': 7,
            'nfce': _naoEmitida(),
            'cancelado': true,
            'estorno': {'feito': true, 'meio': 'debito', 'valorCentavos': 700},
          });
        }
        return _json({});
      });

      expect(find.byKey(const ValueKey('venda-nao-concluida')), findsOneWidget);
      expect(find.text('NÃO FOI POSSÍVEL EMITIR O CUPOM FISCAL'), findsOneWidget);
      expect(find.byKey(const ValueKey('estorno-feito')), findsOneWidget);
      // O motivo do Regem vai para o atendente (e para o relatório).
      expect(
          find.textContaining('NFC-e não emitida (rejeitada 778)'), findsOneWidget);
      // Nada de cupom de senha nem DANFE de uma compra que não existe.
      expect(cena.impresso, isNot(contains('SENHA')));
      expect(cena.impresso, isNot(contains('DANFE')));
      // A nuvem já estornou: pedir de novo seria só ruído.
      expect(cena.chamadas, isNot(contains('POST /api/pagamentos/estorno')));
      expect(cena.repo.pedidos.single['status'], 'nao_concluido');
      // O gestor é avisado.
      expect(cena.chamadas, contains('POST /api/telemetria/evento'));
      await cena.sair(tester);
    });

    testWidgets('venda RECUSADA pelo sistema da loja (422): estorna e explica',
        (tester) async {
      final cena = _Cena();
      await cena.vender(tester, servidor: (req) async {
        if (req.url.path.endsWith('/vendas')) {
          return _json({
            'message':
                'O sistema da loja recusou a venda: Código(s) PDV não encontrado(s)',
          }, 422);
        }
        if (req.url.path.endsWith('/pagamentos/estorno')) {
          return _json({
            'pedidoId': 'p1',
            'estorno': {'feito': true, 'meio': 'debito'}
          }, 200);
        }
        return _json({});
      });

      expect(find.text('NÃO FOI POSSÍVEL REGISTRAR O PEDIDO'), findsOneWidget);
      expect(find.byKey(const ValueKey('estorno-feito')), findsOneWidget);
      final corpo = cena.corpos['POST /api/pagamentos/estorno']!;
      expect(corpo['etapa'], 'recusada');
      expect(corpo['motivo'], contains('Código(s) PDV não encontrado(s)'));
      expect(cena.repo.pedidos.single['status'], 'nao_concluido');
      await cena.sair(tester);
    });

    testWidgets(
        'DANFE não impresso na NUVEM: a venda vale (não há como desfazê-la daqui) — reimpressão e aviso',
        (tester) async {
      final cena = _Cena();
      cena.papel.aposLeitura = () {
        if (cena.impresso.contains('DANFE NFC-e')) cena.papel.semPapel = true;
      };
      await cena.vender(tester, servidor: (req) async {
        if (req.url.path.endsWith('/vendas')) {
          return _json({
            'comandaId': 'c1',
            'senha': 7,
            'nfce': {'status': 'autorizada', 'danfe': _danfe},
          });
        }
        return _json({});
      });

      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(cena.chamadas, isNot(contains('POST /api/pagamentos/estorno')));
      expect(cena.repo.pedidos.single['status'], 'enviado');
      await cena.sair(tester);
    });
  });

  group('SERVIDOR DA LOJA', () {
    Future<http.Response> Function(http.Request) servidor({
      required Future<http.Response> Function() liberar,
      Future<http.Response> Function()? estorno,
      Future<http.Response> Function()? falhaImpressao,
    }) =>
        (req) async {
          final path = req.url.path;
          if (path.endsWith('/vendas/retido')) {
            return _json({'pedidoId': 'ped-1', 'senha': 42, 'total': 7});
          }
          if (path.endsWith('/vendas/ped-1/liberar')) return liberar();
          if (path.endsWith('/pagamentos/estorno')) {
            if (estorno != null) return estorno();
            return _json({
              'pedidoId': 'p1',
              'estorno': {'feito': true, 'meio': 'debito'}
            }, 200);
          }
          if (path.endsWith('/vendas/ped-1/falha-impressao')) {
            if (falhaImpressao != null) return falhaImpressao();
            return _json({
              'ok': true,
              'notaCancelada': true,
              'cancelamentoPendente': false
            });
          }
          return _json({});
        };

    testWidgets(
        'nota NÃO emitida: o totem pede o estorno à nuvem (pelo repasse) com o motivo do Regem',
        (tester) async {
      final cena = _Cena();
      await cena.vender(tester,
          modoServidor: true,
          servidor: servidor(
              liberar: () async => _json({
                    'comandaId': 'c1',
                    'senha': 42,
                    'nfce': _naoEmitida(),
                  })));

      final corpo = cena.corpos['POST /api/v1/pagamentos/estorno']!;
      expect(corpo['orderId'], cena.repo.pedidos.single['uuid']);
      expect(corpo['motivo'],
          'NFC-e não emitida (rejeitada 778): Informado NCM inexistente');
      expect(corpo['etapa'], 'rejeitada');
      expect(corpo['senha'], 42); // a senha do servidor, a que o cliente viu
      expect(corpo['itens'], isNotEmpty); // o registro do relatório
      expect(find.byKey(const ValueKey('estorno-feito')), findsOneWidget);
      expect(cena.impresso, isNot(contains('SENHA')));
      await cena.sair(tester);
    });

    testWidgets('estorno SEM REDE: fica pendente (a fila tenta de novo) e a tela diz isso',
        (tester) async {
      final cena = _Cena();
      await cena.vender(tester,
          modoServidor: true,
          servidor: servidor(
              liberar: () async =>
                  _json({'comandaId': 'c1', 'senha': 42, 'nfce': _naoEmitida()}),
              estorno: () async => http.Response('bad gateway', 502)));

      expect(find.byKey(const ValueKey('estorno-pendente')), findsOneWidget);
      expect(cena.repo.pedidos.single['status'], 'estorno_pendente');
      expect(await cena.repo.pendentes(), 1); // a fila não esquece o dinheiro
      await cena.sair(tester);
    });

    testWidgets(
        'DANFE não impresso: o Regem desfaz a venda (falha-impressao) e o totem estorna — sem cupom de senha',
        (tester) async {
      final cena = _Cena();
      cena.papel.aposLeitura = () {
        if (cena.impresso.contains('DANFE NFC-e')) cena.papel.semPapel = true;
      };
      await cena.vender(tester,
          modoServidor: true,
          servidor: servidor(
              liberar: () async => _json({
                    'comandaId': 'c1',
                    'senha': 42,
                    'nfce': {'status': 'autorizada', 'danfe': _danfe},
                  })));

      expect(cena.chamadas, contains('POST /api/v1/vendas/ped-1/falha-impressao'));
      expect(cena.corpos['POST /api/v1/vendas/ped-1/falha-impressao']!['motivo'],
          'sem papel');
      final estorno = cena.corpos['POST /api/v1/pagamentos/estorno']!;
      expect(estorno['etapa'], 'impressao');
      expect(estorno['motivo'], 'Cupom fiscal não impresso no totem: sem papel');
      expect(find.text('O CUPOM FISCAL NÃO PÔDE SER IMPRESSO'), findsOneWidget);
      // A nota foi cancelada: o DANFE NÃO pode ir para a reimpressão.
      expect(cena.fila.rows, isEmpty);
      expect(cena.impresso, isNot(contains('SENHA')));
      await cena.sair(tester);
    });

    testWidgets(
        'DANFE não impresso e o servidor NÃO confirma o desfazimento: a venda vale e NÃO se estorna',
        (tester) async {
      final cena = _Cena();
      cena.papel.aposLeitura = () {
        if (cena.impresso.contains('DANFE NFC-e')) cena.papel.semPapel = true;
      };
      await cena.vender(tester,
          modoServidor: true,
          servidor: servidor(
              liberar: () async => _json({
                    'comandaId': 'c1',
                    'senha': 42,
                    'nfce': {'status': 'autorizada', 'danfe': _danfe},
                  }),
              falhaImpressao: () async => http.Response('erro', 500)));

      // Estornar aqui devolveria o dinheiro de uma venda com nota VÁLIDA.
      expect(cena.chamadas, isNot(contains('POST /api/v1/pagamentos/estorno')));
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(cena.fila.rows.map((r) => r['uuid']),
          contains(endsWith('#danfe')));
      await cena.sair(tester);
    });

    testWidgets('espera a nota com "EMITINDO O CUPOM FISCAL…" na tela',
        (tester) async {
      final cena = _Cena();
      final resposta = Completer<http.Response>();
      await cena.vender(tester,
          modoServidor: true,
          bombearAteOFim: false,
          servidor: servidor(liberar: () => resposta.future));
      await _bombear(tester, 10);
      expect(find.text('EMITINDO O CUPOM FISCAL…'), findsOneWidget);

      resposta.complete(_json({
        'comandaId': 'c1',
        'senha': 42,
        'nfce': {'status': 'autorizada', 'danfe': _danfe},
      }));
      await _bombear(tester, 20);
      expect(find.text('PEDIDO CONFIRMADO!'), findsOneWidget);
      expect(cena.impresso, contains('DANFE NFC-e'));
      await cena.sair(tester);
    });

    testWidgets(
        'a 1ª liberação cai na rede: a REPETIÇÃO recupera a mesma nota e o DANFE sai',
        (tester) async {
      final cena = _Cena();
      var tentativas = 0;
      await cena.vender(tester,
          modoServidor: true,
          bombearAteOFim: false,
          servidor: servidor(liberar: () async {
            tentativas++;
            if (tentativas == 1) throw http.ClientException('conexão caiu');
            return _json({
              'comandaId': 'c1',
              'senha': 42,
              'idempotente': true,
              'nfce': {'status': 'autorizada', 'danfe': _danfe},
            });
          }));
      await _bombear(tester, 10);
      await tester.pump(const Duration(seconds: 3)); // pausa até a repetição
      await _bombear(tester, 20);

      expect(tentativas, 2);
      expect(cena.impresso, contains('DANFE NFC-e'));
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
      await cena.sair(tester);
    });

    testWidgets(
        'nota falhando EM SÉRIE (repete): cartão e PIX travados — sem cobrar, sem abrir pedido',
        (tester) async {
      final cena = _Cena();
      await cena.vender(tester,
          modoServidor: true,
          antesDePagar: (c) {
            final b = c.read(bloqueioFiscalProvider.notifier);
            b.registrarNaoEmitida(repete: true, motivo: 'certificado vencido');
            b.registrarNaoEmitida(repete: true, motivo: 'certificado vencido');
          },
          servidor: servidor(liberar: () async => _json({})));

      expect(find.textContaining('Cartão e PIX indisponíveis'), findsOneWidget);
      expect(cena.chamadas, isNot(contains('POST /api/v1/vendas/retido')));
      expect(cena.repo.pedidos, isEmpty);
      await _bombear(tester);
    });
  });
}

Future<void> _bombear(WidgetTester t, [int vezes = 8]) async {
  for (var i = 0; i < vezes; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
