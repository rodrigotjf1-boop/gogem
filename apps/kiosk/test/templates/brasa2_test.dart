import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/core/router.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/features/pedido/confirmacao_screen.dart';
import 'package:gogem_kiosk/features/templates/brasa2/brasa2_template.dart';
import 'package:gogem_kiosk/features/templates/brasa2/catalogo.dart';
import 'package:gogem_kiosk/features/templates/brasa2/descanso.dart';
import 'package:gogem_kiosk/features/templates/brasa2/pagamento.dart';
import 'package:gogem_kiosk/features/templates/brasa2/peca_tambem.dart';
import 'package:gogem_kiosk/features/templates/brasa2/pintores/icones.dart';
import 'package:gogem_kiosk/features/templates/brasa2/sucesso.dart';
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import 'package:gogem_kiosk/features/templates/providers.dart';
import '../fixtures.dart';

/// Template Brasa 2.0 (docs/templates/01, testes da seção 5 do 00). Cada View é montada com
/// `Movimento.parado` em 1080×1920 e repetida em 800×600 (sem overflow). Sem `pumpAndSettle`.

const _tpl = Brasa2Template();
const _totem = Size(1080, 1920);
const _harness = Size(800, 600);

MenuSnapshot _menu() => MenuSnapshot.fromPublicadoJson(publicadoFixture);

Future<void> _passos(WidgetTester t, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void _tela(WidgetTester t, Size tamanho) {
  t.view.physicalSize = tamanho;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Monta uma View pura (sem providers). O descanso não tem `Scaffold` próprio.
Future<void> _view(WidgetTester t, Widget w, {Size tamanho = _totem}) async {
  _tela(t, tamanho);
  // Chave nova a cada montagem: a View nasce de novo (initState), como numa rota nova.
  await t.pumpWidget(MaterialApp(key: UniqueKey(), home: Scaffold(body: w)));
  await _passos(t);
}

/// Rotas de mentira para as telas inteiras (catálogo e sacola navegam com o go_router).
GoRouter _rotas(Widget inicial) => GoRouter(initialLocation: '/t', routes: [
      GoRoute(path: '/t', builder: (_, __) => inicial),
      GoRoute(path: '/produto/:id', builder: (_, s) => Text('ROTA produto ${s.pathParameters['id']}')),
      GoRoute(path: '/carrinho', builder: (_, __) => const Text('ROTA carrinho')),
      GoRoute(path: '/catalogo', builder: (_, __) => const Text('ROTA catalogo')),
      GoRoute(path: '/descanso', builder: (_, __) => const Text('ROTA descanso')),
      GoRoute(path: '/peca-tambem', builder: (_, __) => const Text('ROTA peca-tambem')),
    ]);

/// Monta uma tela inteira (catálogo/sacola) com os providers sobrescritos.
Future<ProviderContainer> _inteira(WidgetTester t, Widget w,
    {Size tamanho = _totem, MenuSnapshot? menu, bool semMenu = false}) async {
  _tela(t, tamanho);
  final c = ProviderContainer(overrides: [
    menuProvider.overrideWith((ref) async => semMenu ? null : (menu ?? _menu())),
    aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'brasa2'})),
    movimentoProvider.overrideWithValue(Movimento.parado),
  ]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: _rotas(w)),
  ));
  await _passos(t);
  return c;
}

DescansoProps _descanso({
  bool bloqueado = false,
  void Function(String)? onIniciar,
  String? nomeLoja,
  String? precoIsca,
  List<DescansoMidia> midias = const [],
  Movimento mov = Movimento.parado,
}) =>
    DescansoProps(
      chamada: 'Toque para começar',
      mov: mov,
      bloqueado: bloqueado,
      onIniciar: onIniciar ?? (_) {},
      nomeLoja: nomeLoja,
      precoIsca: precoIsca,
      midias: midias,
      destaques: [_menu().porId('p1')!],
    );

Produto _comObrigatorio() => Produto.fromJson({
      'id': 'px',
      'categoriaId': 'cat1',
      'nome': 'Duplo Bacon',
      'descricao': '2 blends de 120 g',
      'precoCentavos': 4290,
      'selo': 'Mais pedido',
      'grupos': [
        {
          'id': 'acomp',
          'nome': 'Acompanhamento',
          'min': 1,
          'max': 1,
          'obrigatorio': true,
          'opcoes': [
            {'id': 'batata', 'nome': 'Batata frita', 'precoCentavosDelta': 0},
            {'id': 'nachos', 'nome': 'Nachos com cheddar', 'precoCentavosDelta': 300},
          ],
        },
      ],
    });

ProdutoProps _produto({
  required bool valido,
  VoidCallback? onAdicionar,
  void Function(GrupoComplemento, OpcaoComplemento)? onToggle,
  VoidCallback? onVoltar,
}) {
  final p = _comObrigatorio();
  return ProdutoProps(
    produto: p,
    selecoes: valido
        ? {
            'acomp': [p.grupos.first.opcoes.first]
          }
        : const {},
    qtd: 1,
    valido: valido,
    totalCentavos: 4290,
    onToggle: onToggle ?? (_, __) {},
    onMenos: () {},
    onMais: () {},
    onAdicionar: onAdicionar ?? () {},
    onVoltar: onVoltar ?? () {},
  );
}

IdentificacaoProps _identificacao(
  TextEditingController nome, {
  String cpf = '',
  bool valido = false,
  String? aviso,
  void Function(String)? onDigito,
  VoidCallback? onApagar,
  VoidCallback? onPular,
  VoidCallback? onConfirmar,
  VoidCallback? onVoltar,
}) =>
    IdentificacaoProps(
      nomeController: nome,
      cpf: cpf,
      completo: cpf.length == 11,
      valido: valido,
      onDigito: onDigito ?? (_) {},
      onApagar: onApagar ?? () {},
      onPular: onPular ?? () {},
      onConfirmar: onConfirmar ?? () {},
      onVoltar: onVoltar ?? () {},
      avisoCpfObrigatorio: aviso,
    );

/// Registro das chamadas do pagamento.
class _Pag {
  final chamadas = <String>[];
  PagamentoProps props({
    bool bloqueado = false,
    bool processando = false,
    bool point = false,
    String? pix,
    String? erro,
    String? mensagem,
    String cliente = '',
  }) =>
      PagamentoProps(
        totalCentavos: 9880,
        bloqueado: bloqueado,
        motivo: 'sem papel',
        processando: processando,
        erro: erro,
        pointAtivo: point,
        pixCopiaECola: pix,
        pixContador: '04:59',
        mensagemProcessando: mensagem,
        cliente: cliente,
        onVoltar: () => chamadas.add('voltar'),
        onVoltarCarrinho: () => chamadas.add('voltarCarrinho'),
        onTentarNovamente: () => chamadas.add('tentarNovamente'),
        onPagarPix: () => chamadas.add('pix'),
        onPagarCartao: () => chamadas.add('cartao'),
        onPagarDinheiro: () => chamadas.add('dinheiro'),
        onCancelarPix: () => chamadas.add('cancelarPix'),
        onCancelarPoint: () => chamadas.add('cancelarPoint'),
      );
}

void main() {
  group('Registro e textos', () {
    test('templateDe devolve o Brasa 2.0 para "brasa2"; o "brasa" antigo segue o caminho atual', () {
      expect(templateDe(Aparencia.fromJson({'temaPreset': 'brasa2'})), isA<Brasa2Template>());
      expect(templateDe(Aparencia.fromJson({'temaPreset': 'brasa'})), isNull);
      expect(templatesRegistrados, contains('brasa2'));
    });

    test('tokens do template: fontes empacotadas e cores da especificação', () {
      final t = _tpl.tokens;
      expect(t.fonteDisplay, 'DMSerifDisplay');
      expect(t.fonteTexto, 'Manrope');
      expect(t.accent, const Color(0xFFEC7433));
      expect(t.price, const Color(0xFFF4B63F));
    });

    test('peça-também: sobremesa quando todas vêm de uma categoria de doces; senão "Que tal completar?"', () {
      final doces = Categoria.fromJson({'id': 'd', 'nome': 'Sobremesas'});
      final bebidas = Categoria.fromJson({'id': 'b', 'nome': 'Bebidas'});
      Produto p(String id, String cat) =>
          Produto.fromJson({'id': id, 'categoriaId': cat, 'nome': id, 'precoCentavos': 100});
      expect(textosPecaTambem([p('a', 'd'), p('b', 'd')], [doces, bebidas]).titulo, 'Uma sobremesa pra fechar?');
      expect(textosPecaTambem([p('a', 'd')], [doces]).pular, 'Seguir sem sobremesa');
      final misto = textosPecaTambem([p('a', 'd'), p('b', 'b')], [doces, bebidas]);
      expect(misto.titulo, 'Que tal completar?');
      expect(misto.pular, 'Seguir sem sugestão');
      expect(textosPecaTambem([p('a', 'b')], [bebidas]).titulo, 'Que tal completar?');
    });

    test('texto de espera: caixa de frase, e "Processando…" sem mensagem', () {
      expect(textoEsperaBrasa(null), 'Processando…');
      expect(textoEsperaBrasa('EMITINDO O CUPOM FISCAL…'), 'Emitindo o cupom fiscal…');
    });

    test('ícones do protótipo: todo desenho vira um Path dentro do viewBox 24×24', () {
      for (final i in BrasaIcone.values) {
        final b = caminhoDoIcone(i).getBounds();
        expect(b.width + b.height, greaterThan(0), reason: i.name); // "menos" é uma linha: altura 0
        expect(b.left >= -.5 && b.top >= -.5 && b.right <= 24.5 && b.bottom <= 24.5, isTrue, reason: '${i.name} $b');
      }
    });
  });

  group('Descanso', () {
    testWidgets('"Para levar" chama onIniciar(viagem) e "Comer aqui" chama onIniciar(local)', (t) async {
      final consumos = <String>[];
      await _view(t, _tpl.descanso(_descanso(onIniciar: consumos.add)));
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await t.tap(find.byKey(const ValueKey('descanso-local')));
      expect(consumos, ['viagem', 'local']);
      expect(find.text('Toque para começar'), findsOneWidget);
      expect(find.text('BRASA'), findsOneWidget); // logo padrão sem nome/logo da loja
    });

    testWidgets('bloqueado: nenhum botão começa o pedido', (t) async {
      final consumos = <String>[];
      await _view(t, _tpl.descanso(_descanso(bloqueado: true, onIniciar: consumos.add)));
      await t.tap(find.byKey(const ValueKey('descanso-viagem')), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('descanso-local')), warnIfMissed: false);
      await t.pump();
      expect(consumos, isEmpty);
    });

    testWidgets('usa o nome da loja, o preço-isca e a legenda da mídia', (t) async {
      await _view(
        t,
        _tpl.descanso(_descanso(
          nomeLoja: 'Zé Burger',
          precoIsca: 'Combo Zé R\$ 39,90',
          midias: const [DescansoMidia(url: '', kicker: 'Promo da noite', titulo: 'Dobro de bacon')],
        )),
      );
      expect(find.text('ZÉ BURGER'), findsOneWidget);
      expect(find.text('BRASA'), findsNothing);
      expect(find.text('PROMO DA NOITE'), findsOneWidget);
      expect(find.textContaining('Dobro de bacon'), findsOneWidget);
      expect(find.textContaining('Combo Zé R\$ 39,90'), findsOneWidget); // 1ª frase do letreiro
    });

    testWidgets('brasas só com partículas (parado: nada de brasa)', (t) async {
      await _view(t, _tpl.descanso(_descanso()));
      expect(find.byKey(const ValueKey('brasas')), findsNothing);
      await _view(t, _tpl.descanso(_descanso(mov: const Movimento())));
      expect(find.byKey(const ValueKey('brasas')), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // desmonta: para o Ticker e o Ken Burns
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _view(t, _tpl.descanso(_descanso(precoIsca: 'Combo R\$ 29,90')), tamanho: _harness);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('descanso-local')), findsOneWidget);
    });
  });

  group('Catálogo', () {
    testWidgets('mostra categoria e produto da fixture; tocar no card abre o produto', (t) async {
      await _inteira(t, _tpl.catalogo());
      expect(find.text('Burgers'), findsWidgets); // trilho + título da seção
      expect(find.text('Mister Burguer'), findsWidgets); // destaque + card
      expect(find.byKey(const ValueKey('produto-p1')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('produto-p1')));
      await _passos(t);
      expect(find.text('ROTA produto p1'), findsOneWidget);
    });

    testWidgets('produto indisponível mostra "Esgotado" e não reage ao toque', (t) async {
      await _inteira(t, _tpl.catalogo());
      expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('produto-p3')), warnIfMissed: false);
      await _passos(t);
      expect(find.textContaining('ROTA produto'), findsNothing);
    });

    testWidgets('"+" sem etapa obrigatória entra direto na sacola', (t) async {
      final c = await _inteira(t, _tpl.catalogo());
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar-p1')));
      await _passos(t);
      expect(c.read(cartProvider).totalItens, 1);
      expect(find.text('Sua sacola · 1 item'), findsOneWidget);
      expect(find.text('R\$ 29,90'), findsWidgets);
    });

    testWidgets('Cancelar limpa a sacola e volta ao descanso', (t) async {
      final c = await _inteira(t, _tpl.catalogo());
      c.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: _menu().porId('p2')!, selecoes: const {}));
      c.read(checkoutProvider.notifier).setConsumo('viagem');
      await t.tap(find.byKey(const ValueKey('topo-cancelar')));
      await _passos(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(c.read(checkoutProvider).consumo, 'local');
      expect(find.text('ROTA descanso'), findsOneWidget);
    });

    testWidgets('sem cardápio: estado vazio com "Atualizar"', (t) async {
      await _inteira(t, _tpl.catalogo(), semMenu: true);
      expect(find.text('Cardápio ainda não sincronizado'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalogo-atualizar')), findsOneWidget);
    });

    testWidgets('categoria no trilho rola até a seção', (t) async {
      await _inteira(t, _tpl.catalogo());
      final lista = t.widget<SingleChildScrollView>(find.byKey(const ValueKey('catalogo-lista')));
      expect(lista.controller!.offset, 0);
      await t.tap(find.byKey(const ValueKey('categoria-cat2')));
      await _passos(t);
      expect(lista.controller!.offset, greaterThan(0));
      expect(find.text('Refri Lata'), findsOneWidget);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _inteira(t, _tpl.catalogo(), tamanho: _harness);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('barra-sacola')), findsOneWidget);
    });
  });

  group('Produto', () {
    testWidgets('grupo obrigatório: "Adicionar" desabilitado até escolher', (t) async {
      var adicionou = 0;
      await _view(t, _tpl.produto(_produto(valido: false, onAdicionar: () => adicionou++)));
      expect(find.text('Obrigatório'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      expect(adicionou, 0);
      await _view(t, _tpl.produto(_produto(valido: true, onAdicionar: () => adicionou++)));
      expect(find.text('Adicionar · R\$ 42,90'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      expect(adicionou, 1);
      expect(find.byKey(const ValueKey('opcao-marcada')), findsOneWidget);
    });

    testWidgets('tocar numa opção chama onToggle; o X chama onVoltar', (t) async {
      String? tocada;
      var voltou = 0;
      await _view(
        t,
        _tpl.produto(_produto(valido: false, onToggle: (g, o) => tocada = '${g.id}/${o.id}', onVoltar: () => voltou++)),
      );
      expect(find.text('+ R\$ 3,00'), findsOneWidget);
      expect(find.text('incluso'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('op-nachos')));
      expect(tocada, 'acomp/nachos');
      await t.tap(find.byKey(const ValueKey('produto-fechar')));
      expect(voltou, 1);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _view(t, _tpl.produto(_produto(valido: true)), tamanho: _harness);
      expect(t.takeException(), isNull);
    });
  });

  group('Sacola', () {
    Future<ProviderContainer> comItens(WidgetTester t, List<ItemCarrinho> itens, {Size tamanho = _totem}) async {
      final c = await _inteira(t, _tpl.carrinho(), tamanho: tamanho);
      for (final i in itens) {
        c.read(cartProvider.notifier).adicionar(i);
      }
      await _passos(t);
      return c;
    }

    ItemCarrinho mister() {
      final p1 = _menu().porId('p1')!;
      return ItemCarrinho(produto: p1, selecoes: {'g1': p1.grupos.first.opcoes});
    }

    testWidgets('mostra o total e o bloco "Combina com seu pedido" quando há upsell', (t) async {
      await comItens(t, [mister()]);
      expect(find.text('Sua sacola'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('+ Bacon'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 33,90');
      expect(find.byKey(const ValueKey('combina')), findsOneWidget);
      expect(find.text('Combina com seu pedido'), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p2')), findsOneWidget); // p3 esgotado não entra
      expect(find.byKey(const ValueKey('sugestao-p3')), findsNothing);
    });

    testWidgets('sem upsell, sem o bloco de sugestões', (t) async {
      await comItens(t, [ItemCarrinho(produto: _menu().porId('p2')!, selecoes: const {})]);
      expect(find.byKey(const ValueKey('combina')), findsNothing);
    });

    testWidgets('consumo vem marcado e troca; "+" da sugestão entra na sacola; Finalizar segue', (t) async {
      final c = await comItens(t, [mister()]);
      c.read(checkoutProvider.notifier).setConsumo('viagem');
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('consumo-local')));
      expect(c.read(checkoutProvider).consumo, 'local');
      await t.tap(find.byKey(const ValueKey('sugestao-add-p2')));
      await _passos(t, 1);
      expect(c.read(cartProvider).itens.map((i) => i.produto.id), ['p1', 'p2']);
      await t.ensureVisible(find.byKey(const ValueKey('continuar')));
      await t.tap(find.byKey(const ValueKey('continuar')));
      await _passos(t);
      expect(find.text('ROTA peca-tambem'), findsOneWidget);
    });

    testWidgets('lixeira remove a linha', (t) async {
      final item = mister();
      final c = await comItens(t, [item]);
      await t.tap(find.byKey(ValueKey('remover-${item.linhaId}')));
      await _passos(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await comItens(t, [mister(), ItemCarrinho(produto: _menu().porId('p2')!, selecoes: const {})], tamanho: _harness);
      expect(t.takeException(), isNull);
    });
  });

  group('Peça também', () {
    testWidgets('chama onAdicionar e troca o rótulo para "Continuar"', (t) async {
      final adicionados = <String>[];
      var continuou = 0;
      final p2 = _menu().porId('p2')!;
      await _view(
        t,
        _tpl.pecaTambem(PecaTambemProps(
          sugeridos: [p2],
          onAdicionar: (p) => adicionados.add(p.id),
          onVoltar: () {},
          onContinuar: () => continuou++,
        )),
      );
      expect(find.text('Que tal completar?'), findsOneWidget);
      expect(find.text('Seguir sem sugestão'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sugestao-p2')));
      await t.pump();
      expect(adicionados, ['p2']);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Seguir sem sugestão'), findsNothing);
      await t.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
      expect(continuou, 1);
    });

    testWidgets('800×600 sem overflow', (t) async {
      final m = _menu();
      await _view(
        t,
        _tpl.pecaTambem(PecaTambemProps(
          sugeridos: [m.porId('p1')!, m.porId('p2')!],
          onAdicionar: (_) {},
          onVoltar: () {},
          onContinuar: () {},
        )),
        tamanho: _harness,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('Identificação', () {
    late TextEditingController nome;
    setUp(() => nome = TextEditingController());
    tearDown(() => nome.dispose());

    testWidgets('CPF inválido (ou incompleto) deixa "Continuar" desabilitado', (t) async {
      await _view(t, _tpl.identificacao(_identificacao(nome, cpf: '11111111111')));
      expect(find.text('CPF inválido, confira os números'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await t.pump();
      expect(find.text('CPF na nota?'), findsOneWidget);
      await _view(t, _tpl.identificacao(_identificacao(nome, cpf: '5299822')));
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await t.pump();
      expect(find.text('CPF na nota?'), findsOneWidget);
    });

    testWidgets('aviso de CPF obrigatório: sem "Opcional" e "Pular" desabilitado', (t) async {
      await _view(
        t,
        _tpl.identificacao(_identificacao(nome, aviso: 'Compras acima de R\$ 2.000,00 precisam do CPF na nota fiscal.')),
      );
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      expect(find.byKey(const ValueKey('cpf-opcional')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pular')));
      await t.tap(find.byKey(const ValueKey('cpf-continuar'))); // vazio não serve quando obrigatório
      await t.pump();
      expect(find.text('CPF na nota?'), findsOneWidget);
    });

    testWidgets('com CPF válido, a etapa 2 chama onConfirmar (não onPular)', (t) async {
      final chamadas = <String>[];
      await _view(
        t,
        _tpl.identificacao(_identificacao(nome,
            cpf: '52998224725',
            valido: true,
            onConfirmar: () => chamadas.add('confirmar'),
            onPular: () => chamadas.add('pular'))),
      );
      expect(find.text('CPF válido'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 1);
      expect(find.text('Como podemos\nte chamar?'), findsOneWidget);
      expect(chamadas, isEmpty); // sair da etapa 1 só guarda a escolha
      for (final l in ['A', 'N', 'A']) {
        await t.tap(find.byKey(ValueKey('nome-tecla-$l')));
      }
      await t.pump();
      expect(nome.text, 'ANA');
      expect(find.text('3/12'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(chamadas, ['confirmar']);
    });

    testWidgets('Pular: a etapa 2 chama onPular; Voltar da etapa 2 volta ao CPF', (t) async {
      final chamadas = <String>[];
      await _view(
        t,
        _tpl.identificacao(_identificacao(nome,
            onConfirmar: () => chamadas.add('confirmar'),
            onPular: () => chamadas.add('pular'),
            onVoltar: () => chamadas.add('voltar'))),
      );
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      await _passos(t, 1);
      expect(find.text('CPF na nota?'), findsOneWidget);
      expect(chamadas, isEmpty);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(chamadas, ['voltar']);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(chamadas, ['voltar', 'pular']);
    });

    testWidgets('teclado do CPF: dígito chama onDigito e Limpar apaga tudo', (t) async {
      final digitos = <String>[];
      var apagou = 0;
      await _view(
        t,
        _tpl.identificacao(
            _identificacao(nome, cpf: '529', onDigito: digitos.add, onApagar: () => apagou++)),
      );
      await t.tap(find.byKey(const ValueKey('cpf-tecla-7')));
      await t.tap(find.byKey(const ValueKey('cpf-limpar')));
      expect(digitos, ['7']);
      expect(apagou, 3);
    });

    testWidgets('800×600 sem overflow nas duas etapas', (t) async {
      await _view(t, _tpl.identificacao(_identificacao(nome)), tamanho: _harness);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const ValueKey('pular')));
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('nome-continuar')), findsOneWidget);
    });
  });

  group('Pagamento', () {
    testWidgets('escolha: Pix, Cartão e Dinheiro (chaves da GoGen) e o kicker com o nome', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(cliente: 'Rodrigo')));
      expect(find.text('ÚLTIMO PASSO, RODRIGO'), findsOneWidget);
      expect(find.text('Como você quer pagar?'), findsOneWidget);
      expect(find.text('Crédito, débito ou vale: você escolhe na maquininha'), findsOneWidget);
      expect(find.text('R\$ 98,80'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('forma-pix')));
      await t.tap(find.byKey(const ValueKey('forma-cartao')));
      await t.tap(find.byKey(const ValueKey('forma-dinheiro')));
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(r.chamadas, ['pix', 'cartao', 'dinheiro', 'voltar']);
    });

    testWidgets('PIX: QR, contador e "Trocar forma de pagamento"', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(processando: true, pix: '00020126BR.GOV.BCB.PIX')));
      expect(find.byKey(const ValueKey('pix-qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('pix-contador')), findsOneWidget);
      expect(find.text('Expira em 04:59'), findsOneWidget);
      expect(find.byKey(const ValueKey('topo-voltar')), findsNothing); // cobrando: sai pelo rodapé
      await t.tap(find.byKey(const ValueKey('pix-cancelar')));
      expect(r.chamadas, ['cancelarPix']);
    });

    testWidgets('Point: maquininha e cancelar', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(processando: true, point: true)));
      expect(find.byKey(const ValueKey('maquininha')), findsOneWidget);
      expect(find.text('Use a maquininha abaixo'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('point-cancelar')));
      expect(r.chamadas, ['cancelarPoint']);
    });

    testWidgets('processando: a mensagem do fluxo em caixa de frase, ou "Processando…"', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…')));
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'Emitindo o cupom fiscal…');
      await _view(t, _tpl.pagamento(r.props(processando: true)));
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'Processando…');
    });

    testWidgets('erro: mensagem, "Tentar novamente" volta às formas e "Voltar" chama onVoltar', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(erro: 'Pagamento não aprovado')));
      expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
      expect(find.text('Pagamento não aprovado'), findsOneWidget);
      expect(find.byKey(const ValueKey('forma-pix')), findsNothing);
      await t.tap(find.byKey(const ValueKey('erro-voltar')));
      expect(r.chamadas, ['voltar']);
      await t.tap(find.byKey(const ValueKey('erro-tentar-novamente')));
      await t.pump();
      expect(find.byKey(const ValueKey('forma-pix')), findsOneWidget);
    });

    testWidgets('bloqueado (PORTÃO 2): motivo, Voltar ao carrinho e Tentar novamente', (t) async {
      final r = _Pag();
      await _view(t, _tpl.pagamento(r.props(bloqueado: true)));
      expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
      expect(find.text('Não é possível pagar agora'), findsOneWidget);
      expect(find.text('sem papel'), findsOneWidget);
      expect(find.text('Chame um atendente, seu carrinho está salvo'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('voltar-carrinho')));
      await t.tap(find.byKey(const ValueKey('tentar-novamente')));
      expect(r.chamadas, ['voltarCarrinho', 'tentarNovamente']);
    });

    testWidgets('800×600 sem overflow em todos os estados', (t) async {
      final r = _Pag();
      for (final p in [
        r.props(cliente: 'Rodrigo'),
        r.props(processando: true, pix: '00020126BR.GOV.BCB.PIX'),
        r.props(processando: true, point: true),
        r.props(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…'),
        r.props(erro: 'Pagamento não aprovado'),
        r.props(bloqueado: true),
      ]) {
        await _view(t, _tpl.pagamento(p), tamanho: _harness);
        expect(t.takeException(), isNull);
      }
    });
  });

  group('No app (registro real)', () {
    setUp(() => router.go('/descanso'));

    testWidgets('descanso Brasa 2.0: "Para levar" grava viagem e abre o catálogo Brasa 2.0', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider.overrideWith(
              (ref) async => Aparencia.fromJson({'temaPreset': 'brasa2', 'animacoes': 'off'})),
          menuProvider.overrideWith((ref) async => _menu()),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await _passos(t);
      expect(find.byType(Brasa2Descanso), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byType(Brasa2Descanso)));
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await _passos(t, 3);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      expect(find.byType(Brasa2Catalogo), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Confirmação', () {
    testWidgets('mostra a senha e, impresso e com nota, sem avisos', (t) async {
      var novo = 0;
      await _view(
          t, _tpl.sucesso(SucessoProps(senha: '247', impresso: true, entrada: 1, segundos: 17, onNovoPedido: () => novo++)));
      expect(find.text('Pedido confirmado!'), findsOneWidget);
      expect(find.text('PAGAMENTO APROVADO'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('senha'))).data, '247');
      expect(find.byKey(const ValueKey('recibo')), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsNothing);
      expect(find.byKey(const ValueKey('confete')), findsNothing); // parado: sem confete
      expect(find.text('Voltando ao início em 17 s'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('novo-pedido')));
      expect(novo, 1);
    });

    // ERR-022/V20: os avisos de segurança existem em TODOS os modelos, com os textos da GoGen.
    testWidgets('avisos de impresso=false, fiscal=false e dinheiro=true', (t) async {
      await _view(
        t,
        _tpl.sucesso(SucessoProps(
            senha: '248', impresso: false, fiscal: false, dinheiro: true, entrada: 1, onNovoPedido: () {})),
      );
      expect(find.text('Pedido enviado!'), findsOneWidget);
      expect(find.text('DIRIJA-SE AO CAIXA PARA PAGAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsOneWidget);
      expect(find.text('PAGUE NO CAIXA PARA RETIRAR'), findsOneWidget);
      expect(find.text('dirija-se ao caixa, informe a senha e efetue o pagamento'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
      expect(find.text('cupom não impresso — ANOTE A SENHA e informe o balcão'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(find.text('cupom fiscal não impresso — retire no balcão com a senha'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsNothing);
      expect(t.widget<Text>(find.byKey(const ValueKey('senha'))).data, '248');
    });

    testWidgets('a confirmação no tema brasa2 repassa o aviso fiscal da rota', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'brasa2'})),
          movimentoProvider.overrideWithValue(Movimento.parado),
        ],
        child: const MaterialApp(home: ConfirmacaoScreen(senha: 'A12', fiscal: false)),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(Brasa2Sucesso), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // desmonta: cancela o auto-retorno
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _view(
        t,
        _tpl.sucesso(SucessoProps(
            senha: '248', impresso: false, fiscal: false, dinheiro: true, entrada: 1, segundos: 9, onNovoPedido: () {})),
        tamanho: _harness,
      );
      expect(t.takeException(), isNull);
    });
  });
}
