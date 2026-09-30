import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/features/pedido/produto_screen.dart';
import 'package:gogem_kiosk/features/templates/diner/diner_template.dart';
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import 'package:gogem_kiosk/features/templates/providers.dart';
import '../fixtures.dart';

/// Template **Diner 58** (docs/templates/05 + 00 §5). Cada View é montada com
/// `Movimento.parado` em 1080×1920 e repetida em 800×600 (o harness) para provar que nada
/// transborda. Só passos fixos de 300 ms (nada de esperar a árvore "assentar").

const _tpl = DinerTemplate();
const _grande = Size(1080, 1920);
const _pequena = Size(800, 600);

MenuSnapshot _menu() => MenuSnapshot.fromPublicadoJson(publicadoFixture);

/// O cardápio da fixture + um lanche com etapa OBRIGATÓRIA (ponto da carne).
MenuSnapshot _menuComObrigatorio() {
  final base = _menu();
  final lanche = Produto.fromJson({
    'id': 'p9',
    'categoriaId': 'cat1',
    'nome': 'Smash do Diner',
    'descricao': 'Dois smash e cheddar',
    'precoCentavos': 3190,
    'grupos': [
      {
        'id': 'gPonto',
        'nome': 'Ponto da carne',
        'min': 1,
        'max': 1,
        'obrigatorio': true,
        'opcoes': [
          {'id': 'mal', 'nome': 'Mal passado', 'precoCentavosDelta': 0},
          {'id': 'bem', 'nome': 'Bem passado', 'precoCentavosDelta': 0},
        ],
      },
    ],
  });
  return MenuSnapshot(versao: base.versao, categorias: base.categorias, produtos: [...base.produtos, lanche]);
}

void _tela(WidgetTester t, Size tamanho) {
  t.view.physicalSize = tamanho;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Rola até o alvo (telas baixas) e toca.
Future<void> _tocar(WidgetTester t, Finder alvo) async {
  await t.ensureVisible(alvo);
  await t.pump();
  await t.tap(alvo);
}

Future<void> _passos(WidgetTester t, [int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

List<Override> _overrides({MenuSnapshot? menu, bool semMenu = false, Movimento mov = Movimento.parado}) => [
      aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'diner'})),
      movimentoProvider.overrideWithValue(mov),
      menuProvider.overrideWith((ref) async => semMenu ? null : (menu ?? _menu())),
    ];

/// View solta (sem rotas) dentro de um ProviderScope com a aparência do Diner.
Widget _app(Widget tela, {List<Override> extra = const []}) => ProviderScope(
      overrides: [..._overrides(), ...extra],
      child: MaterialApp(home: tela),
    );

/// Telas inteiras com rotas de verdade (o catálogo e a sacola navegam).
Widget _rotas(String inicio, Map<String, Widget Function(GoRouterState)> telas, List<Override> overrides) {
  final r = GoRouter(initialLocation: inicio, routes: [
    for (final e in telas.entries) GoRoute(path: e.key, builder: (_, s) => e.value(s)),
  ]);
  return ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: r));
}

Map<String, Widget Function(GoRouterState)> _destinos(Widget Function(GoRouterState) tela, String caminho) => {
      caminho: tela,
      '/catalogo': (_) => _tpl.catalogo(),
      '/produto/:id': (s) => Text('PRODUTO ${s.pathParameters['id']}'),
      '/carrinho': (_) => const Text('SACOLA'),
      '/descanso': (_) => const Text('DESCANSO'),
      '/peca-tambem': (_) => const Text('PECA TAMBEM'),
    };

ProviderContainer _container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(Navigator).first));

PagamentoProps _pag({
  bool bloqueado = false,
  bool processando = false,
  bool point = false,
  String? pix,
  String? erro,
  String? mensagem,
  String cliente = '',
  void Function(String)? chamou,
}) {
  void c(String s) => chamou?.call(s);
  return PagamentoProps(
    totalCentavos: 3690,
    bloqueado: bloqueado,
    motivo: 'sem papel',
    processando: processando,
    erro: erro,
    pointAtivo: point,
    pixCopiaECola: pix,
    pixContador: '04:59',
    mensagemProcessando: mensagem,
    cliente: cliente,
    onVoltar: () => c('voltar'),
    onVoltarCarrinho: () => c('voltar-carrinho'),
    onTentarNovamente: () => c('tentar'),
    onPagarPix: () => c('pix'),
    onPagarCartao: () => c('cartao'),
    onPagarDinheiro: () => c('dinheiro'),
    onCancelarPix: () => c('cancelar-pix'),
    onCancelarPoint: () => c('cancelar-point'),
  );
}

void main() {
  group('Registro', () {
    test('templateDe(diner) devolve o DinerTemplate', () {
      expect(templateDe(Aparencia.fromJson({'temaPreset': 'diner'})), isA<DinerTemplate>());
      expect(templatesRegistrados, contains('diner'));
      expect(_tpl.tokens.claro, isTrue);
      expect(_tpl.tokens.fonteDisplay, 'Bungee');
      expect(_tpl.tokens.fonteTexto, 'Nunito');
    });
  });

  group('Descanso', () {
    DescansoProps props(List<String> chamadas, {bool bloqueado = false, Movimento mov = Movimento.parado}) =>
        DescansoProps(
          chamada: 'TOQUE PARA PEDIR',
          mov: mov,
          bloqueado: bloqueado,
          onIniciar: chamadas.add,
          destaques: _menu().produtos.where((p) => p.disponivel).toList(),
          precoIsca: 'Combo do dia R\$ 29,90',
        );

    for (final tamanho in [_grande, _pequena]) {
      testWidgets('"Para levar" chama onIniciar(viagem) e "Comer aqui" local — $tamanho', (t) async {
        _tela(t, tamanho);
        final chamadas = <String>[];
        await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(props(chamadas)))));
        await _passos(t);
        expect(find.byKey(const ValueKey('diner-lampadas')), findsOneWidget);
        expect(find.text('Toque para começar'), findsOneWidget);
        await t.tap(find.text('Para levar'));
        await t.tap(find.text('Comer aqui'));
        await _passos(t, 1);
        expect(chamadas, ['viagem', 'local']);
        expect(t.takeException(), isNull);
        // Parado: nenhuma lâmpada piscando, faixa correndo ou foto balançando.
        expect(t.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('bloqueado: nenhum botão começa o pedido', (t) async {
      _tela(t, _grande);
      final chamadas = <String>[];
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(props(chamadas, bloqueado: true)))));
      await _passos(t);
      await t.tap(find.text('Para levar'), warnIfMissed: false);
      await t.tap(find.text('Comer aqui'), warnIfMissed: false);
      await _passos(t, 1);
      expect(chamadas, isEmpty);
    });

    testWidgets('movimento cheio: lâmpadas e faixa animam; parado com a tela descartada', (t) async {
      _tela(t, _grande);
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(props([], mov: const Movimento())))));
      await _passos(t, 2);
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpWidget(const SizedBox());
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('Catálogo', () {
    for (final tamanho in [_grande, _pequena]) {
      testWidgets('mostra categoria e produto; indisponível não reage — $tamanho', (t) async {
        _tela(t, tamanho);
        await t.pumpWidget(_rotas('/catalogo', _destinos((_) => _tpl.catalogo(), '/catalogo'), _overrides()));
        await _passos(t);
        expect(find.text('Burgers'), findsWidgets);
        expect(find.text('Mister Burguer'), findsWidgets);
        expect(find.byKey(const ValueKey('jukebox-cat2')), findsOneWidget);
        expect(t.takeException(), isNull);

        // Esgotado: selo "Esgotado" e o toque não abre o produto.
        await t.scrollUntilVisible(find.text('Esgotado Burger'), 200,
            scrollable: find.byType(Scrollable).last);
        expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);
        await t.tap(find.text('Esgotado Burger'), warnIfMissed: false);
        await _passos(t, 1);
        expect(find.textContaining('PRODUTO'), findsNothing);
        expect(t.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('"+" sem etapa entra direto na sacola; toque na linha abre o produto', (t) async {
      _tela(t, _grande);
      await t.pumpWidget(_rotas('/catalogo', _destinos((_) => _tpl.catalogo(), '/catalogo'), _overrides()));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('jukebox-cat2')));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('mais-p2')));
      await _passos(t, 1);
      expect(_container(t).read(cartProvider).totalItens, 1);
      expect(find.text('Sua sacola · 1 item'), findsOneWidget);
      await t.tap(find.text('Refri Lata').last);
      await _passos(t);
      expect(find.text('PRODUTO p2'), findsOneWidget);
    });

    testWidgets('Cancelar limpa a sacola e volta ao descanso', (t) async {
      _tela(t, _grande);
      await t.pumpWidget(_rotas('/catalogo', _destinos((_) => _tpl.catalogo(), '/catalogo'), _overrides()));
      await _passos(t);
      final c = _container(t);
      c.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: _menu().porId('p2')!, selecoes: const {}));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('topo-cancelar')));
      await _passos(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.text('DESCANSO'), findsOneWidget);
    });

    testWidgets('sem retrato do cardápio: estado vazio com "Atualizar"', (t) async {
      _tela(t, _pequena);
      await t.pumpWidget(
          _rotas('/catalogo', _destinos((_) => _tpl.catalogo(), '/catalogo'), _overrides(semMenu: true)));
      await _passos(t);
      expect(find.text('Cardápio ainda não sincronizado'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalogo-atualizar')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Produto', () {
    for (final tamanho in [_grande, _pequena]) {
      testWidgets('grupo obrigatório: Adicionar desabilitado até escolher — $tamanho', (t) async {
        _tela(t, tamanho);
        await t.pumpWidget(_rotas(
          '/produto/p9',
          {
            '/produto/:id': (s) => ProdutoScreen(produtoId: s.pathParameters['id']!),
            '/carrinho': (_) => const Text('SACOLA'),
          },
          _overrides(menu: _menuComObrigatorio()),
        ));
        await _passos(t);
        expect(find.text('Smash do Diner'), findsOneWidget);
        expect(find.text('Obrigatório'), findsOneWidget);
        expect(t.takeException(), isNull);

        await t.tap(find.byKey(const ValueKey('adicionar')), warnIfMissed: false);
        await _passos(t, 1);
        expect(_container(t).read(cartProvider).vazio, isTrue);
        expect(find.text('SACOLA'), findsNothing);

        await _tocar(t, find.byKey(const ValueKey('op-bem')));
        await _passos(t, 1);
        await _tocar(t, find.byKey(const ValueKey('adicionar')));
        await _passos(t);
        expect(find.text('SACOLA'), findsOneWidget);
        final cart = _container(t).read(cartProvider);
        expect(cart.totalItens, 1);
        expect(cart.itens.single.todasOpcoes.single.id, 'bem');
      });
    }

    testWidgets('X fecha (onVoltar) e quantidade chama os callbacks', (t) async {
      _tela(t, _grande);
      final chamou = <String>[];
      final p = _menu().porId('p1')!;
      await t.pumpWidget(_app(_tpl.produto(ProdutoProps(
        produto: p,
        selecoes: const {},
        qtd: 2,
        valido: true,
        totalCentavos: 5980,
        onToggle: (_, o) => chamou.add('op-${o.id}'),
        onMenos: () => chamou.add('menos'),
        onMais: () => chamou.add('mais'),
        onAdicionar: () => chamou.add('adicionar'),
        onVoltar: () => chamou.add('voltar'),
      ))));
      await _passos(t);
      expect(find.text('Adicionar · R\$ 59,80'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('qtd-mais')));
      await t.tap(find.byKey(const ValueKey('qtd-menos')));
      await t.tap(find.byKey(const ValueKey('op-o1')));
      await t.tap(find.byKey(const ValueKey('adicionar')));
      await t.tap(find.byKey(const ValueKey('produto-fechar')));
      await _passos(t, 1);
      expect(chamou, ['mais', 'menos', 'op-o1', 'adicionar', 'voltar']);
    });
  });

  group('Sacola', () {
    Future<ProviderContainer> monta(WidgetTester t, Size tamanho) async {
      _tela(t, tamanho);
      await t.pumpWidget(_rotas('/sacola', _destinos((_) => _tpl.carrinho(), '/sacola'), _overrides()));
      await _passos(t, 1);
      final c = _container(t);
      c.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: _menu().porId('p1')!, selecoes: const {}));
      c.read(checkoutProvider.notifier).setConsumo('viagem');
      await _passos(t);
      return c;
    }

    for (final tamanho in [_grande, _pequena]) {
      testWidgets('mostra o total e "Combina com seu pedido" com o upsell — $tamanho', (t) async {
        final c = await monta(t, tamanho);
        expect(find.byKey(const ValueKey('total')), findsOneWidget);
        expect(find.text('R\$ 29,90'), findsWidgets);
        expect(find.text('Combina com seu pedido'), findsOneWidget);
        expect(find.byKey(const ValueKey('combina-p2')), findsOneWidget);
        expect(t.takeException(), isNull);

        await _tocar(t, find.byKey(const ValueKey('combina-mais-p2')));
        await _passos(t, 1);
        expect(c.read(cartProvider).totalItens, 2);
        // O único upsell entrou na sacola: o bloco some.
        expect(find.text('Combina com seu pedido'), findsNothing);
      });
    }

    testWidgets('consumo já vem do descanso e troca; lixeira remove; Finalizar segue', (t) async {
      final c = await monta(t, _grande);
      final viagem = t.widget<AnimatedContainer>(find.descendant(
          of: find.byKey(const ValueKey('consumo-viagem')), matching: find.byType(AnimatedContainer)));
      expect((viagem.decoration! as BoxDecoration).color, _tpl.tokens.accent2);
      await t.tap(find.byKey(const ValueKey('consumo-local')));
      await _passos(t, 1);
      expect(c.read(checkoutProvider).consumo, 'local');

      final linha = c.read(cartProvider).itens.single.linhaId;
      await t.tap(find.byKey(ValueKey('qtd-$linha-mais')));
      await _passos(t, 1);
      expect(c.read(cartProvider).totalItens, 2);
      await t.tap(find.byKey(const ValueKey('finalizar')));
      await _passos(t);
      expect(find.text('PECA TAMBEM'), findsOneWidget);
    });

    testWidgets('lixeira tira a linha (sem animação, na hora)', (t) async {
      final c = await monta(t, _grande);
      final linha = c.read(cartProvider).itens.single.linhaId;
      await t.tap(find.byKey(ValueKey('remover-$linha')));
      await _passos(t, 1);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.byKey(const ValueKey('sacola-vazia')), findsOneWidget);
    });
  });

  group('Peça também', () {
    for (final tamanho in [_grande, _pequena]) {
      testWidgets('adicionar chama onAdicionar e o botão vira "Continuar" — $tamanho', (t) async {
        _tela(t, tamanho);
        final adicionados = <String>[];
        var continuou = 0;
        var sugeridos = [_menu().porId('p2')!];
        await t.pumpWidget(_app(StatefulBuilder(
          builder: (context, setState) => _tpl.pecaTambem(PecaTambemProps(
            sugeridos: sugeridos,
            onAdicionar: (p) {
              adicionados.add(p.id);
              // Como na tela real: o que entrou na sacola sai da lista.
              setState(() => sugeridos = const []);
            },
            onVoltar: () {},
            onContinuar: () => continuou++,
          )),
        )));
        await _passos(t);
        expect(find.text('Que tal completar?'), findsOneWidget);
        expect(find.text('Seguir sem sugestão'), findsOneWidget);
        expect(t.takeException(), isNull);

        await t.tap(find.byKey(const ValueKey('sugestao-p2')));
        await _passos(t, 1);
        expect(adicionados, ['p2']);
        // Continua na tela com ✓ e o rótulo muda.
        expect(find.byKey(const ValueKey('sugestao-p2')), findsOneWidget);
        expect(find.text('Continuar'), findsOneWidget);
        expect(find.text('Seguir sem sugestão'), findsNothing);
        await t.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
        expect(continuou, 1);
      });
    }
  });

  group('Identificação', () {
    IdentificacaoProps props(
      TextEditingController nome, {
      String cpf = '',
      String? aviso,
      List<String>? chamou,
    }) =>
        IdentificacaoProps(
          nomeController: nome,
          cpf: cpf,
          completo: cpf.length == 11,
          valido: cpf == '52998224725',
          onDigito: (d) => chamou?.add('digito-$d'),
          onApagar: () => chamou?.add('apagar'),
          onPular: () => chamou?.add('pular'),
          onConfirmar: () => chamou?.add('confirmar'),
          onVoltar: () => chamou?.add('voltar'),
          avisoCpfObrigatorio: aviso,
        );

    for (final tamanho in [_grande, _pequena]) {
      testWidgets('CPF inválido desabilita Continuar — $tamanho', (t) async {
        _tela(t, tamanho);
        final nome = TextEditingController();
        addTearDown(nome.dispose);
        await t.pumpWidget(_app(_tpl.identificacao(props(nome, cpf: '12345678901'))));
        await _passos(t);
        expect(find.text('CPF inválido, confira os números'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('cpf-continuar')), warnIfMissed: false);
        await _passos(t, 1);
        expect(find.byKey(const ValueKey('identificacao-cpf')), findsOneWidget);
        expect(find.byKey(const ValueKey('identificacao-nome')), findsNothing);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('CPF incompleto também não passa', (t) async {
      _tela(t, _grande);
      final nome = TextEditingController();
      addTearDown(nome.dispose);
      await t.pumpWidget(_app(_tpl.identificacao(props(nome, cpf: '52998'))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')), warnIfMissed: false);
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('identificacao-nome')), findsNothing);
    });

    testWidgets('CPF obrigatório: aviso em destaque, Pular desabilitado e CPF vazio não passa', (t) async {
      _tela(t, _grande);
      final nome = TextEditingController();
      addTearDown(nome.dispose);
      final chamou = <String>[];
      await t.pumpWidget(_app(_tpl.identificacao(
          props(nome, aviso: 'Compras acima de R\$ 2.000,00 precisam do CPF na nota fiscal.', chamou: chamou))));
      await _passos(t);
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      expect(find.text('Opcional'), findsNothing);
      await t.tap(find.byKey(const ValueKey('pular')), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')), warnIfMissed: false);
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('identificacao-nome')), findsNothing);
      expect(chamou, isEmpty);
    });

    for (final tamanho in [_grande, _pequena]) {
      testWidgets('etapa 2 com CPF válido chama onConfirmar — $tamanho', (t) async {
        _tela(t, tamanho);
        final nome = TextEditingController();
        addTearDown(nome.dispose);
        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.identificacao(props(nome, cpf: '52998224725', chamou: chamou))));
        await _passos(t);
        await t.tap(find.byKey(const ValueKey('cpf-continuar')));
        await _passos(t, 1);
        expect(chamou, isEmpty, reason: 'sair da etapa 1 só guarda a escolha');
        expect(find.text('Como podemos te chamar?'), findsOneWidget);
        expect(t.takeException(), isNull);
        await _tocar(t, find.byKey(const ValueKey('nome-tecla-A')));
        await _tocar(t, find.byKey(const ValueKey('nome-tecla-N')));
        await _tocar(t, find.byKey(const ValueKey('nome-tecla-A')));
        await _passos(t, 1);
        expect(nome.text, 'ANA');
        expect(find.text('3/12'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('nome-continuar')));
        expect(chamou, ['confirmar']);
      });
    }

    testWidgets('Pular (sem CPF) e depois Continuar chama onPular; Voltar volta à etapa 1', (t) async {
      _tela(t, _grande);
      final nome = TextEditingController();
      addTearDown(nome.dispose);
      final chamou = <String>[];
      await t.pumpWidget(_app(_tpl.identificacao(props(nome, chamou: chamou))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('identificacao-nome')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('identificacao-cpf')), findsOneWidget);
      expect(chamou, isEmpty);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(chamou, ['voltar']);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(chamou, ['voltar', 'pular']);
    });

    testWidgets('teclado numérico: dígito, apagar e Limpar (apaga tudo)', (t) async {
      _tela(t, _grande);
      final nome = TextEditingController();
      addTearDown(nome.dispose);
      final chamou = <String>[];
      await t.pumpWidget(_app(_tpl.identificacao(props(nome, cpf: '529', chamou: chamou))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('cpf-tecla-7')));
      await t.tap(find.byKey(const ValueKey('cpf-apagar')));
      await t.tap(find.byKey(const ValueKey('cpf-limpar')));
      expect(chamou, ['digito-7', 'apagar', 'apagar', 'apagar', 'apagar']);
    });
  });

  group('Pagamento', () {
    for (final tamanho in [_grande, _pequena]) {
      testWidgets('escolha: Pix, Cartão e Dinheiro com as chaves da GoGen — $tamanho', (t) async {
        _tela(t, tamanho);
        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.pagamento(_pag(cliente: 'Ana', chamou: chamou.add))));
        await _passos(t);
        expect(find.text('ÚLTIMO PASSO, ANA'), findsOneWidget);
        expect(find.text('Crédito, débito ou vale: você escolhe na maquininha'), findsOneWidget);
        expect(t.takeException(), isNull);
        for (final k in ['forma-pix', 'forma-cartao', 'forma-dinheiro']) {
          await _tocar(t, find.byKey(ValueKey(k)));
        }
        await _tocar(t, find.byKey(const ValueKey('topo-voltar')));
        expect(chamou, ['pix', 'cartao', 'dinheiro', 'voltar']);
      });

      testWidgets('erro: mensagem e as formas continuam para tentar de novo — $tamanho', (t) async {
        _tela(t, tamanho);
        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.pagamento(_pag(erro: 'Pagamento recusado.', chamou: chamou.add))));
        await _passos(t);
        expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
        expect(find.text('Pagamento recusado.'), findsOneWidget);
        await _tocar(t, find.byKey(const ValueKey('forma-cartao')));
        expect(chamou, ['cartao']);
        expect(t.takeException(), isNull);
      });

      testWidgets('PIX: QR, contador e trocar forma — $tamanho', (t) async {
        _tela(t, tamanho);
        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.pagamento(_pag(processando: true, pix: '000201pix-diner', chamou: chamou.add))));
        await _passos(t);
        expect(find.byKey(const ValueKey('pix-qr')), findsOneWidget);
        expect(find.text('Expira em 04:59'), findsOneWidget);
        expect(find.byKey(const ValueKey('topo-voltar')), findsNothing);
        await _tocar(t, find.byKey(const ValueKey('pix-cancelar')));
        expect(chamou, ['cancelar-pix']);
        expect(t.takeException(), isNull);
      });

      testWidgets('maquininha: animação e Cancelar — $tamanho', (t) async {
        _tela(t, tamanho);
        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.pagamento(_pag(processando: true, point: true, chamou: chamou.add))));
        await _passos(t);
        expect(find.byKey(const ValueKey('maquininha')), findsOneWidget);
        expect(find.text('Use a maquininha abaixo'), findsOneWidget);
        await _tocar(t, find.byKey(const ValueKey('point-cancelar')));
        expect(chamou, ['cancelar-point']);
        expect(t.takeException(), isNull);
      });

      testWidgets('processando e bloqueado — $tamanho', (t) async {
        _tela(t, tamanho);
        await t.pumpWidget(_app(_tpl.pagamento(_pag(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…'))));
        await _passos(t);
        expect(find.text('Emitindo o cupom fiscal…'), findsOneWidget);
        await t.pumpWidget(_app(_tpl.pagamento(_pag(processando: true))));
        await _passos(t);
        expect(find.text('Processando…'), findsOneWidget);
        expect(find.byKey(const ValueKey('pagamento-espera')), findsOneWidget);

        final chamou = <String>[];
        await t.pumpWidget(_app(_tpl.pagamento(_pag(bloqueado: true, chamou: chamou.add))));
        await _passos(t);
        expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
        expect(find.text('Motivo: sem papel'), findsOneWidget);
        await _tocar(t, find.byKey(const ValueKey('tentar-novamente')));
        await _tocar(t, find.byKey(const ValueKey('voltar-carrinho')));
        expect(chamou, ['tentar', 'voltar-carrinho']);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('Confirmação', () {
    for (final tamanho in [_grande, _pequena]) {
      testWidgets('senha e avisos de segurança: sem comprovante, sem nota e pague no caixa — $tamanho',
          (t) async {
        _tela(t, tamanho);
        await t.pumpWidget(_app(_tpl.sucesso(SucessoProps(
          senha: '247',
          impresso: false,
          fiscal: false,
          dinheiro: true,
          entrada: 1,
          segundos: 12,
          onNovoPedido: () {},
        ))));
        await _passos(t);
        expect(find.byKey(const ValueKey('senha')), findsOneWidget);
        expect(find.text('247'), findsOneWidget);
        expect(find.text('Pedido enviado!'), findsOneWidget);
        // Mesmos textos e chaves da GoGen (ERR-022 / V20).
        expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
        expect(find.text('cupom não impresso — ANOTE A SENHA e informe o balcão'), findsOneWidget);
        expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
        expect(find.text('cupom fiscal não impresso — retire no balcão com a senha'), findsOneWidget);
        expect(find.byKey(const ValueKey('aviso-caixa')), findsOneWidget);
        expect(find.text('PAGUE NO CAIXA PARA RETIRAR'), findsOneWidget);
        expect(find.byKey(const ValueKey('recibo')), findsNothing);
        expect(find.text('Voltando ao início em 12 s'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('impresso, com nota e cartão: nenhum aviso, recibo e novo pedido', (t) async {
      _tela(t, _grande);
      var novo = 0;
      await t.pumpWidget(_app(_tpl.sucesso(SucessoProps(
        senha: '031',
        impresso: true,
        entrada: 1,
        onNovoPedido: () => novo++,
      ))));
      await _passos(t);
      expect(find.text('Pedido confirmado!'), findsOneWidget);
      expect(find.text('PAGAMENTO APROVADO'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsNothing);
      expect(find.byKey(const ValueKey('recibo')), findsOneWidget);
      expect(find.byKey(const ValueKey('confete')), findsNothing, reason: 'parado: sem confete');
      await t.tap(find.byKey(const ValueKey('novo-pedido')));
      expect(novo, 1);
    });
  });
}
