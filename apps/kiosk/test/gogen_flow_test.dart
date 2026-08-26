import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/features/gogen/gogen_pagamento.dart';
import 'package:gogem_kiosk/features/gogen/gogen_produto.dart';
import 'package:gogem_kiosk/features/gogen/gogen_sucesso.dart';
import 'fixtures.dart';

GogenPagamentoView _pagamento({
  bool bloqueado = false,
  bool processando = false,
  bool pointAtivo = false,
  String? pix,
  String? erro,
}) =>
    GogenPagamentoView(
      totalCentavos: 3690,
      bloqueado: bloqueado,
      motivo: 'sem papel',
      processando: processando,
      erro: erro,
      pointAtivo: pointAtivo,
      pixCopiaECola: pix,
      pixContador: '04:59',
      onVoltar: () {},
      onVoltarCarrinho: () {},
      onTentarNovamente: () {},
      onPagarPix: () {},
      onPagarCartao: () {},
      onPagarDinheiro: () {},
      onCancelarPix: () {},
      onCancelarPoint: () {},
    );

Produto _mister() =>
    Produto.fromJson((publicadoFixture['snapshot']['produtos'] as List).first as Map);

void main() {
  testWidgets('sucesso GoGen mostra a senha e o aviso quando não imprimiu', (t) async {
    await t.pumpWidget(MaterialApp(
      home: GogenSucessoView(
        senha: 'A12',
        impresso: false,
        entrada: 1,
        onNovoPedido: () {},
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('senha')), findsOneWidget);
    expect(find.text('A12'), findsOneWidget);
    expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
  });

  testWidgets('sucesso GoGen sem aviso quando imprimiu', (t) async {
    await t.pumpWidget(MaterialApp(
      home: GogenSucessoView(senha: 'B03', impresso: true, entrada: 1, onNovoPedido: () {}),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsNothing);
  });

  testWidgets('produto GoGen renderiza grupo/opção e o toque dispara onToggle', (t) async {
    final p = _mister();
    GrupoComplemento? gTocado;
    OpcaoComplemento? oTocada;
    await t.pumpWidget(MaterialApp(
      home: GogenProdutoView(
        produto: p,
        selecoes: const {},
        qtd: 1,
        valido: true,
        totalCentavos: p.precoCentavos,
        onToggle: (g, o) {
          gTocado = g;
          oTocada = o;
        },
        onMenos: () {},
        onMais: () {},
        onAdicionar: () {},
        onVoltar: () {},
      ),
    ));
    await t.pump();
    expect(find.text('Adicionais'), findsOneWidget);
    expect(find.text('Bacon'), findsOneWidget);
    expect(find.byKey(const ValueKey('adicionar')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('op-o1')));
    await t.pump();
    expect(gTocado?.id, 'g1');
    expect(oTocada?.id, 'o1');
  });

  testWidgets('pagamento GoGen idle: só PIX e Cartão', (t) async {
    await t.pumpWidget(MaterialApp(home: _pagamento()));
    await t.pump();
    expect(find.byKey(const ValueKey('forma-pix')), findsOneWidget);
    expect(find.byKey(const ValueKey('forma-cartao')), findsOneWidget);
    expect(find.text('PIX'), findsOneWidget);
    expect(find.text('Cartão'), findsOneWidget);
  });

  testWidgets('pagamento GoGen bloqueado (PORTÃO 2)', (t) async {
    await t.pumpWidget(MaterialApp(home: _pagamento(bloqueado: true)));
    await t.pump();
    expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
    expect(find.byKey(const ValueKey('tentar-novamente')), findsOneWidget);
  });

  testWidgets('pagamento GoGen PIX: QR + contador + cancelar', (t) async {
    await t.binding.setSurfaceSize(const Size(1080, 1920)); // totem real
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      home: _pagamento(processando: true, pix: '00020126BR.GOV.BCB.PIX'),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('pix-contador')), findsOneWidget);
    expect(find.byKey(const ValueKey('pix-cancelar')), findsOneWidget);
  });

  testWidgets('pagamento GoGen erro aparece no idle', (t) async {
    await t.pumpWidget(MaterialApp(home: _pagamento(erro: 'Pagamento não aprovado')));
    await t.pump();
    expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
  });
}
