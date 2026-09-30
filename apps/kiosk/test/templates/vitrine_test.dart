import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/core/router.dart';
import 'package:gogem_kiosk/core/util/cpf.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/features/catalogo/catalogo_screen.dart';
import 'package:gogem_kiosk/features/pedido/carrinho_screen.dart';
import 'package:gogem_kiosk/features/pedido/confirmacao_screen.dart';
import 'package:gogem_kiosk/features/pedido/produto_screen.dart';
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import 'package:gogem_kiosk/features/templates/providers.dart';
import 'package:gogem_kiosk/features/templates/vitrine/carrinho.dart';
import 'package:gogem_kiosk/features/templates/vitrine/catalogo.dart';
import 'package:gogem_kiosk/features/templates/vitrine/descanso.dart';
import 'package:gogem_kiosk/features/templates/vitrine/identificacao.dart';
import 'package:gogem_kiosk/features/templates/vitrine/pagamento.dart';
import 'package:gogem_kiosk/features/templates/vitrine/peca_tambem.dart';
import 'package:gogem_kiosk/features/templates/vitrine/produto.dart';
import 'package:gogem_kiosk/features/templates/vitrine/sucesso.dart';
import 'package:gogem_kiosk/features/templates/vitrine/vitrine_template.dart';
import '../fixtures.dart';

/// Template Vitrine (docs/templates/02): cada tela em 1080×1920 (o totem) e em 800×600 (o
/// harness e o totem em paisagem — nada pode estourar). Sempre com `Movimento.parado` e
/// `pump` em passos: nada de `pumpAndSettle` (CLAUDE.md, regra 2).

const _totem = Size(1080, 1920);
const _baixa = Size(800, 600);

final _aparencia = Aparencia.fromJson({'temaPreset': 'vitrine'});

MenuSnapshot _menu() {
  final s = publicadoFixture['snapshot'] as Map<String, dynamic>;
  return MenuSnapshot(
    versao: 3,
    categorias: [for (final c in s['categorias'] as List) Categoria.fromJson(c as Map<String, dynamic>)],
    produtos: [for (final p in s['produtos'] as List) Produto.fromJson(p as Map<String, dynamic>)],
  );
}

Produto _prod(String id) => _menu().porId(id)!;

/// Produto com etapa OBRIGATÓRIA (escolha 1 de 2).
const _comEtapa = Produto(
  id: 'p9',
  categoriaId: 'cat1',
  nome: 'Duplo Bacon',
  descricao: '2 blends de 120 g, cheddar inglês, bacon crocante e maionese da casa',
  precoCentavos: 4290,
  disponivel: true,
  imagemUrl: null,
  externalRefs: [],
  selo: 'Mais pedido',
  grupos: [
    GrupoComplemento(id: 'g9', nome: 'Acompanhamento', min: 1, max: 1, obrigatorio: true, opcoes: [
      OpcaoComplemento(id: 'o91', nome: 'Batata frita', precoCentavosDelta: 0, imagemUrl: null, externalRefs: []),
      OpcaoComplemento(id: 'o92', nome: 'Nachos com cheddar', precoCentavosDelta: 300, imagemUrl: null, externalRefs: []),
    ]),
  ],
);

void _tela(WidgetTester t, Size s) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _passos(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

List<Override> _base({MenuSnapshot? menu, bool semMenu = false}) => [
      aparenciaProvider.overrideWith((ref) async => _aparencia),
      menuProvider.overrideWith((ref) async => semMenu ? null : (menu ?? _menu())),
      movimentoProvider.overrideWithValue(Movimento.parado),
    ];

/// Uma View do template dentro do app (o logo lê a aparência pelo provider).
Widget _view(Widget child, {List<Override> extra = const []}) =>
    ProviderScope(overrides: [..._base(), ...extra], child: MaterialApp(home: child));

/// Telas inteiras com rotas de verdade (o catálogo navega com `context.push`/`go`).
GoRouter _rotas(String inicial) => GoRouter(initialLocation: inicial, routes: [
      GoRoute(path: '/descanso', builder: (_, __) => const Scaffold(body: Text('DESCANSO'))),
      GoRoute(path: '/catalogo', builder: (_, __) => const CatalogoScreen()),
      GoRoute(path: '/produto/:id', builder: (_, s) => ProdutoScreen(produtoId: s.pathParameters['id']!)),
      GoRoute(path: '/carrinho', builder: (_, __) => const CarrinhoScreen()),
      GoRoute(path: '/peca-tambem', builder: (_, __) => const Scaffold(body: Text('PECA TAMBEM'))),
    ]);

Future<ProviderContainer> _app(WidgetTester t, String inicial,
    {MenuSnapshot? menu, bool semMenu = false, List<ItemCarrinho> itens = const []}) async {
  final c = ProviderContainer(overrides: _base(menu: menu, semMenu: semMenu));
  addTearDown(c.dispose);
  for (final i in itens) {
    c.read(cartProvider.notifier).adicionar(i);
  }
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: _rotas(inicial)),
  ));
  await _passos(t);
  return c;
}

DescansoProps _descanso({
  required void Function(String) onIniciar,
  bool bloqueado = false,
  List<Produto>? destaques,
  List<DescansoMidia> midias = const [],
  Movimento mov = Movimento.parado,
  String? precoIsca,
}) =>
    DescansoProps(
      chamada: 'Toque para começar',
      mov: mov,
      bloqueado: bloqueado,
      onIniciar: onIniciar,
      destaques: destaques ?? [_prod('p1')],
      midias: midias,
      intervaloSeg: 3,
      precoIsca: precoIsca,
    );

PagamentoProps _pagamento({
  bool bloqueado = false,
  bool processando = false,
  bool pointAtivo = false,
  String? pix,
  String? erro,
  String? mensagem,
  String cliente = '',
  List<String>? eventos,
}) {
  void ev(String e) => eventos?.add(e);
  return PagamentoProps(
    totalCentavos: 9880,
    bloqueado: bloqueado,
    motivo: 'sem papel',
    processando: processando,
    erro: erro,
    pointAtivo: pointAtivo,
    pixCopiaECola: pix,
    pixContador: '04:59',
    mensagemProcessando: mensagem,
    cliente: cliente,
    onVoltar: () => ev('voltar'),
    onVoltarCarrinho: () => ev('carrinho'),
    onTentarNovamente: () => ev('tentar'),
    onPagarPix: () => ev('pix'),
    onPagarCartao: () => ev('cartao'),
    onPagarDinheiro: () => ev('dinheiro'),
    onCancelarPix: () => ev('cancelar-pix'),
    onCancelarPoint: () => ev('cancelar-point'),
  );
}

/// Simula a `IdentificacaoScreen`: guarda o CPF e repassa como a tela repassa.
class _IdHarness extends StatefulWidget {
  const _IdHarness({super.key, required this.eventos, this.aviso});
  final List<String> eventos;
  final String? aviso;
  @override
  State<_IdHarness> createState() => _IdHarnessState();
}

class _IdHarnessState extends State<_IdHarness> {
  String cpf = '';
  final nome = TextEditingController();

  @override
  void dispose() {
    nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completo = cpf.length == 11;
    final valido = cpfValido(cpf);
    return VitrineIdentificacaoView(
      p: IdentificacaoProps(
        nomeController: nome,
        cpf: cpf,
        completo: completo,
        valido: valido,
        onDigito: (d) => setState(() {
          if (cpf.length < 11) cpf += d;
        }),
        onApagar: () => setState(() {
          if (cpf.isNotEmpty) cpf = cpf.substring(0, cpf.length - 1);
        }),
        onPular: () => widget.eventos.add('pular:${nome.text}'),
        onConfirmar: completo && valido ? () => widget.eventos.add('confirmar:$cpf:${nome.text}') : () {},
        onVoltar: () => widget.eventos.add('voltar'),
        avisoCpfObrigatorio: widget.aviso,
      ),
    );
  }
}

Future<void> _digitarCpf(WidgetTester t, String cpf) async {
  for (final d in cpf.split('')) {
    await t.tap(find.byKey(ValueKey('cpf-tecla-$d')));
    await t.pump();
  }
}

void main() {
  group('Registro', () {
    test('templateDe devolve o VitrineTemplate para "vitrine"', () {
      final tpl = templateDe(Aparencia.fromJson({'temaPreset': 'vitrine'}));
      expect(tpl, isA<VitrineTemplate>());
      expect(tpl!.tokens.fonteDisplay, 'Syne');
      expect(tpl.tokens.fonteTexto, 'Onest');
      expect(templatesRegistrados, contains('vitrine'));
    });
  });

  group('Descanso (stories)', () {
    testWidgets('"Para levar" chama onIniciar(viagem); "Comer aqui", local', (t) async {
      _tela(t, _totem);
      final chamadas = <String>[];
      await t.pumpWidget(_view(Scaffold(body: VitrineDescanso(p: _descanso(onIniciar: chamadas.add)))));
      await _passos(t);
      expect(find.text('Mister Burguer'), findsOneWidget); // produto com selo = story padrão
      expect(find.text('MAIS VENDIDO'), findsOneWidget);
      expect(find.text('Toque para começar'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await t.tap(find.byKey(const ValueKey('descanso-local')));
      expect(chamadas, ['viagem', 'local']);
    });

    testWidgets('bloqueado: nenhum botão começa o pedido', (t) async {
      _tela(t, _totem);
      final chamadas = <String>[];
      await t.pumpWidget(
          _view(Scaffold(body: VitrineDescanso(p: _descanso(onIniciar: chamadas.add, bloqueado: true)))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('descanso-viagem')), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('descanso-local')), warnIfMissed: false);
      await t.pump();
      expect(chamadas, isEmpty);
    });

    testWidgets('stories: barras no topo, troca a cada intervalo (off = Timer) e preço-isca', (t) async {
      _tela(t, _totem);
      Produto destaque(String id, String nome) => Produto(
            id: id,
            categoriaId: 'cat1',
            nome: nome,
            descricao: '',
            precoCentavos: 1990,
            disponivel: true,
            imagemUrl: null,
            externalRefs: const [],
            grupos: const [],
            selo: 'Novo',
          );
      await t.pumpWidget(_view(Scaffold(
        body: VitrineDescanso(
          p: _descanso(
            onIniciar: (_) {},
            destaques: [destaque('a', 'Smash Onion'), destaque('b', 'Crispy Chicken')],
            precoIsca: 'Combo R\$ 52,90',
          ),
        ),
      )));
      await t.pump();
      expect(find.byKey(const ValueKey('stories-barras')), findsOneWidget);
      expect(find.byKey(const ValueKey('preco-isca')), findsOneWidget);
      expect(find.text('Smash Onion'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pump();
      expect(find.text('Crispy Chicken'), findsOneWidget);
      expect(find.text('Smash Onion'), findsNothing); // troca seca, sem crossfade
      // Sem animação nada pede quadro (o relógio é um Timer).
      expect(t.binding.hasScheduledFrame, isFalse);
      await t.pumpWidget(const SizedBox()); // desmonta: cancela o Timer
    });

    testWidgets('mídias da loja viram os stories (kicker, título e preço)', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(_view(Scaffold(
        body: VitrineDescanso(
          p: _descanso(onIniciar: (_) {}, midias: const [
            DescansoMidia(url: '', kicker: 'Lançamento', titulo: 'Costela Defumada', subtitulo: 'R\$ 46,90'),
          ]),
        ),
      )));
      await t.pump();
      expect(find.text('LANÇAMENTO'), findsOneWidget);
      expect(find.text('Costela Defumada'), findsOneWidget);
      expect(find.text('R\$ 46,90'), findsOneWidget);
      expect(find.text('Mister Burguer'), findsNothing); // mídia vence o destaque
    });

    testWidgets('vidro só com blur: sem blur, nenhum BackdropFilter', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(_view(Scaffold(body: VitrineDescanso(p: _descanso(onIniciar: (_) {})))));
      await t.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      await t.pumpWidget(_view(Scaffold(
        body: VitrineDescanso(
          p: _descanso(onIniciar: (_) {}, mov: const Movimento(anima: false, particulas: false, blur: true)),
        ),
      )));
      await t.pump();
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('800×600 sem overflow', (t) async {
      _tela(t, _baixa);
      await t.pumpWidget(_view(Scaffold(body: VitrineDescanso(p: _descanso(onIniciar: (_) {})))));
      await _passos(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('descanso-viagem')), findsOneWidget);
    });

    testWidgets('app real: "Para levar" no descanso grava viagem e abre o feed do Vitrine', (t) async {
      router.go('/descanso');
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider
              .overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'vitrine', 'animacoes': 'off'})),
          menuProvider.overrideWith((ref) async => _menu()),
          movimentoProvider.overrideWithValue(Movimento.parado),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await _passos(t, 3);
      expect(find.byType(VitrineDescanso), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byType(VitrineDescanso)));
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await _passos(t, 3);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      expect(find.byType(VitrineCatalogoScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Catálogo (feed vertical)', () {
    testWidgets('mostra categoria e produto; Personalizar abre o produto', (t) async {
      _tela(t, _totem);
      await _app(t, '/catalogo');
      expect(find.byType(VitrineCatalogoScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-cat1')), findsOneWidget);
      expect(find.text('Burgers'), findsOneWidget);
      expect(find.text('Mister Burguer'), findsOneWidget);
      expect(find.text('R\$ 29,90'), findsOneWidget);
      expect(find.text('Mais vendido'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing); // Movimento.parado = sem blur
      await t.tap(find.byKey(const ValueKey('personalizar-p1')));
      await _passos(t);
      expect(find.byType(VitrineProdutoView), findsOneWidget);
    });

    testWidgets('+ Adicionar sem etapa obrigatória entra direto na sacola', (t) async {
      _tela(t, _totem);
      final c = await _app(t, '/catalogo');
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar-p1')));
      await _passos(t);
      expect(c.read(cartProvider).totalItens, 1);
      expect(find.text('Sua sacola · 1 item'), findsOneWidget);
      expect(find.byKey(const ValueKey('sacola-contador')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('barra-sacola')));
      await _passos(t);
      expect(find.byType(VitrineCarrinhoScreen), findsOneWidget);
    });

    testWidgets('+ Adicionar com etapa obrigatória abre o produto', (t) async {
      _tela(t, _totem);
      final m = _menu();
      final c = await _app(t, '/catalogo',
          menu: MenuSnapshot(versao: 1, categorias: m.categorias, produtos: [_comEtapa, ...m.produtos]));
      await t.tap(find.byKey(const ValueKey('adicionar-p9')));
      await _passos(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.byType(VitrineProdutoView), findsOneWidget);
    });

    testWidgets('chip leva ao 1º produto da categoria e a página marca o chip', (t) async {
      _tela(t, _totem);
      await _app(t, '/catalogo');
      await t.tap(find.byKey(const ValueKey('chip-cat2')));
      await _passos(t);
      expect(find.text('Refri Lata'), findsOneWidget);
      expect(find.text('Mister Burguer'), findsNothing);
      await t.tap(find.byKey(const ValueKey('chip-cat1')));
      await _passos(t);
      expect(find.text('Mister Burguer'), findsOneWidget);
    });

    testWidgets('produto esgotado fica no feed, cinza e sem toque', (t) async {
      _tela(t, _totem);
      final c = await _app(t, '/catalogo');
      await t.drag(find.byKey(const ValueKey('vitrine-feed')), const Offset(0, -1300));
      await _passos(t);
      expect(find.text('Esgotado Burger'), findsOneWidget);
      expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);
      expect(find.byKey(const ValueKey('personalizar-p3')), findsNothing);
      expect(find.byKey(const ValueKey('adicionar-p3')), findsNothing);
      await t.tap(find.text('Esgotado Burger'), warnIfMissed: false);
      await t.tapAt(const Offset(540, 700));
      await _passos(t);
      expect(find.byType(VitrineCatalogoScreen), findsOneWidget);
      expect(find.byType(VitrineProdutoView), findsNothing);
      expect(c.read(cartProvider).vazio, isTrue);
    });

    testWidgets('sem cardápio: estado vazio do template com "Atualizar"', (t) async {
      _tela(t, _totem);
      await _app(t, '/catalogo', semMenu: true);
      expect(find.text('Cardápio ainda não sincronizado'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalogo-atualizar')), findsOneWidget);
    });

    testWidgets('Cancelar limpa a sacola e volta ao descanso', (t) async {
      _tela(t, _totem);
      final c = await _app(t, '/catalogo', itens: [ItemCarrinho(produto: _prod('p1'), selecoes: const {})]);
      await t.tap(find.byKey(const ValueKey('topo-cancelar')));
      await _passos(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.text('DESCANSO'), findsOneWidget);
    });

    testWidgets('800×600 sem overflow', (t) async {
      _tela(t, _baixa);
      await _app(t, '/catalogo', itens: [ItemCarrinho(produto: _prod('p1'), selecoes: const {})]);
      expect(t.takeException(), isNull);
      expect(find.text('Mister Burguer'), findsOneWidget);
    });
  });

  group('Produto (folha)', () {
    MenuSnapshot comEtapa() {
      final m = _menu();
      return MenuSnapshot(versao: 1, categorias: m.categorias, produtos: [_comEtapa, ...m.produtos]);
    }

    testWidgets('etapa obrigatória: Adicionar desabilitado até escolher', (t) async {
      _tela(t, _totem);
      final c = await _app(t, '/produto/p9', menu: comEtapa());
      expect(find.byType(VitrineProdutoView), findsOneWidget);
      expect(find.text('ACOMPANHAMENTO'), findsOneWidget);
      expect(find.text('Obrigatório'), findsOneWidget);
      expect(find.text('+ R\$ 3,00'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      await _passos(t, 2);
      expect(c.read(cartProvider).vazio, isTrue); // desabilitado: não adiciona
      await t.tap(find.byKey(const ValueKey('op-o92')));
      await t.pump();
      expect(find.byKey(const ValueKey('op-marcada-o92')), findsOneWidget);
      expect(find.text('Adicionar · R\$ 45,90'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      await _passos(t);
      expect(c.read(cartProvider).totalItens, 1);
      expect(c.read(cartProvider).totalCentavos, 4590);
    });

    testWidgets('quantidade e X de fechar', (t) async {
      _tela(t, _totem);
      await _app(t, '/catalogo', menu: comEtapa());
      await t.tap(find.byKey(const ValueKey('personalizar-p9')));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('qtd-mais')));
      await t.pump();
      expect(find.text('2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('produto-fechar')));
      await _passos(t);
      expect(find.byType(VitrineCatalogoScreen), findsOneWidget);
    });

    testWidgets('800×600 sem overflow', (t) async {
      _tela(t, _baixa);
      await _app(t, '/produto/p9', menu: comEtapa());
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('adicionar')), findsOneWidget);
    });
  });

  group('Sacola', () {
    testWidgets('total, consumo e "Combina com seu pedido" com o upsell', (t) async {
      _tela(t, _totem);
      final c = await _app(t, '/carrinho', itens: [ItemCarrinho(produto: _prod('p1'), selecoes: const {})]);
      expect(find.byType(VitrineCarrinhoScreen), findsOneWidget);
      expect(find.text('Sua sacola'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 29,90');
      // p1 sugere p2 (disponível) e p3 (esgotado): só o Refri aparece.
      expect(find.byKey(const ValueKey('vitrine-sugestoes')), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p3')), findsNothing);
      await t.tap(find.byKey(const ValueKey('consumo-viagem')));
      await t.pump();
      expect(c.read(checkoutProvider).consumo, 'viagem');
      await t.tap(find.byKey(const ValueKey('sugestao-mais-p2')));
      await _passos(t, 2);
      expect(c.read(cartProvider).totalItens, 2);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 36,90');
      expect(find.byKey(const ValueKey('vitrine-sugestoes')), findsNothing); // tudo já na sacola
    });

    testWidgets('lixeira tira a linha; "Finalizar pedido" vai à peça-também', (t) async {
      _tela(t, _totem);
      final item = ItemCarrinho(produto: _prod('p2'), selecoes: const {});
      final c = await _app(t, '/carrinho',
          itens: [ItemCarrinho(produto: _prod('p1'), selecoes: const {}), item]);
      await t.tap(find.byKey(ValueKey('remover-${item.linhaId}')));
      await t.pump();
      expect(c.read(cartProvider).itens.map((i) => i.produto.id), ['p1']);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await _passos(t);
      expect(find.text('PECA TAMBEM'), findsOneWidget);
    });

    testWidgets('sacola vazia: estado vazio e Finalizar desabilitado', (t) async {
      _tela(t, _totem);
      await _app(t, '/carrinho');
      expect(find.byKey(const ValueKey('sacola-vazia')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await _passos(t);
      expect(find.text('PECA TAMBEM'), findsNothing);
    });

    testWidgets('800×600 sem overflow', (t) async {
      _tela(t, _baixa);
      await _app(t, '/carrinho', itens: [ItemCarrinho(produto: _prod('p1'), selecoes: const {})]);
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('total')), findsOneWidget);
    });
  });

  group('Peça também', () {
    testWidgets('adicionar chama onAdicionar e troca o rótulo para Continuar', (t) async {
      _tela(t, _totem);
      final adicionados = <String>[];
      var continuou = 0;
      var sugeridos = [_prod('p2')];
      late StateSetter atualizar;
      await t.pumpWidget(_view(StatefulBuilder(builder: (context, setState) {
        atualizar = setState;
        return VitrinePecaTambemView(
          p: PecaTambemProps(
            sugeridos: sugeridos,
            onAdicionar: (p) => adicionados.add(p.id),
            onVoltar: () {},
            onContinuar: () => continuou++,
          ),
        );
      })));
      await _passos(t);
      expect(find.text('Seguir sem sugestão'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sugestao-p2')));
      await t.pump();
      expect(adicionados, ['p2']);
      // A tela tira da lista o que entrou na sacola — o cartão continua, com ✓.
      atualizar(() => sugeridos = []);
      await t.pump();
      expect(find.byKey(const ValueKey('sugestao-ok-p2')), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
      expect(continuou, 1);
    });

    testWidgets('800×600 sem overflow', (t) async {
      _tela(t, _baixa);
      await t.pumpWidget(_view(VitrinePecaTambemView(
        p: PecaTambemProps(
          sugeridos: [_prod('p2'), _prod('p1'), _comEtapa],
          onAdicionar: (_) {},
          onVoltar: () {},
          onContinuar: () {},
        ),
      )));
      await _passos(t);
      expect(t.takeException(), isNull);
    });
  });

  group('Identificação (CPF e nome)', () {
    testWidgets('CPF inválido deixa Continuar desabilitado', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(_IdHarness(eventos: ev)));
      await _passos(t);
      expect(find.byKey(const ValueKey('cpf-opcional')), findsOneWidget);
      await _digitarCpf(t, '11111111111');
      expect(find.text('CPF inválido, confira os números'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('nome-cliente')), findsNothing); // não saiu da etapa 1
      expect(ev, isEmpty);
    });

    testWidgets('CPF válido → etapa 2 → Continuar chama onConfirmar com o nome', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(_IdHarness(eventos: ev)));
      await _passos(t);
      await _digitarCpf(t, '52998224725');
      expect(find.text('CPF válido'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 2);
      expect(ev, isEmpty); // sair da etapa 1 não chama nada
      expect(find.text('Como podemos te chamar?'), findsOneWidget);
      expect(find.text('Digite seu nome'), findsOneWidget);
      for (final l in ['A', 'N', 'A']) {
        await t.tap(find.byKey(ValueKey('nome-tecla-$l')));
        await t.pump();
      }
      expect(find.text('ANA'), findsOneWidget);
      expect(find.text('3/12'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(ev, ['confirmar:52998224725:ANA']);
    });

    testWidgets('Pular → etapa 2 → Continuar chama onPular; Voltar volta à etapa 1', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(_IdHarness(eventos: ev)));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('nome-cliente')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      await _passos(t, 2);
      expect(find.text('CPF na nota?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(ev, ['voltar']);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 2);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(ev, ['voltar', 'pular:']);
    });

    testWidgets('CPF obrigatório: aviso no lugar do "Opcional" e Pular desabilitado', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(_IdHarness(
          eventos: ev, aviso: 'Compras acima de R\$ 2.000,00 precisam do CPF na nota fiscal.')));
      await _passos(t);
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      expect(find.byKey(const ValueKey('cpf-opcional')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pular')));
      await t.tap(find.byKey(const ValueKey('cpf-continuar'))); // vazio também não passa
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('nome-cliente')), findsNothing);
      await _digitarCpf(t, '52998224725');
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 2);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(ev, ['confirmar:52998224725:']);
    });

    testWidgets('800×600 sem overflow (as duas etapas); o teclado rola até aparecer', (t) async {
      _tela(t, _baixa);
      await t.pumpWidget(_view(const _IdHarness(
          eventos: [], aviso: 'Compras acima de R\$ 2.000,00 precisam do CPF na nota fiscal.')));
      await _passos(t);
      expect(t.takeException(), isNull);
      final ev = <String>[];
      await t.pumpWidget(_view(_IdHarness(key: const ValueKey('sem-aviso'), eventos: ev)));
      await _passos(t);
      await t.ensureVisible(find.byKey(const ValueKey('cpf-tecla-5')));
      await t.tap(find.byKey(const ValueKey('cpf-tecla-5')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pular'))); // o rodapé fica sempre à vista
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('nome-cliente')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.byKey(const ValueKey('nome-tecla-Q')));
      await t.tap(find.byKey(const ValueKey('nome-tecla-Q')));
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(ev, ['pular:Q']);
    });
  });

  group('Pagamento', () {
    testWidgets('escolha: Pix em destaque, Cartão e Dinheiro com as chaves da GoGen', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(VitrinePagamentoView(p: _pagamento(cliente: 'Rodrigo', eventos: ev))));
      await _passos(t);
      expect(find.text('ÚLTIMO PASSO, RODRIGO'), findsOneWidget);
      expect(find.text('Como você quer pagar?'), findsOneWidget);
      expect(find.text('MAIS RÁPIDO'), findsOneWidget);
      expect(find.text('Crédito, débito ou vale: você escolhe na maquininha'), findsOneWidget);
      expect(find.text('Seu pedido vai para o caixa e você paga lá'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-total'))).data, 'R\$ 98,80');
      await t.tap(find.byKey(const ValueKey('forma-pix')));
      await t.tap(find.byKey(const ValueKey('forma-cartao')));
      await t.tap(find.byKey(const ValueKey('forma-dinheiro')));
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(ev, ['pix', 'cartao', 'dinheiro', 'voltar']);
    });

    testWidgets('erro: mensagem, Tentar novamente e Voltar (as formas continuam)', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(
          _view(VitrinePagamentoView(p: _pagamento(erro: 'Pagamento não aprovado', eventos: ev))));
      await _passos(t);
      expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
      expect(find.text('Pagamento não aprovado'), findsOneWidget);
      expect(find.byKey(const ValueKey('forma-pix')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tentar-novamente')));
      await t.tap(find.byKey(const ValueKey('erro-voltar')));
      expect(ev, ['tentar', 'voltar']);
    });

    testWidgets('PIX: QR, total, contador e "Trocar forma de pagamento"', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(VitrinePagamentoView(
          p: _pagamento(processando: true, pix: '00020126BR.GOV.BCB.PIX', eventos: ev))));
      await _passos(t);
      expect(find.byKey(const ValueKey('pix-qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('pix-contador')), findsOneWidget);
      expect(find.text('04:59'), findsOneWidget);
      expect(find.text('Aguardando pagamento'), findsOneWidget);
      expect(find.text('Simular aprovação'), findsNothing); // só existe no protótipo
      expect(find.byKey(const ValueKey('topo-voltar')), findsNothing); // cobrando: sem voltar
      expect(t.binding.hasScheduledFrame, isFalse); // sem animação: varredura e pontos parados
      await t.tap(find.byKey(const ValueKey('pix-cancelar')));
      expect(ev, ['cancelar-pix']);
    });

    testWidgets('maquininha: ilustração e Cancelar', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(
          _view(VitrinePagamentoView(p: _pagamento(processando: true, pointAtivo: true, eventos: ev))));
      await _passos(t);
      expect(find.byKey(const ValueKey('maquininha')), findsOneWidget);
      expect(find.text('Use a maquininha abaixo'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('point-cancelar')));
      expect(ev, ['cancelar-point']);
    });

    testWidgets('processando: a mensagem da espera em caixa de frase', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(_view(VitrinePagamentoView(p: _pagamento(processando: true))));
      await t.pump();
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'Processando…');
      await t.pumpWidget(_view(VitrinePagamentoView(
          p: _pagamento(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…'))));
      await t.pump();
      expect(find.text('Emitindo o cupom fiscal…'), findsOneWidget);
    });

    testWidgets('bloqueado: motivo, Voltar ao carrinho e Tentar novamente', (t) async {
      _tela(t, _totem);
      final ev = <String>[];
      await t.pumpWidget(_view(VitrinePagamentoView(p: _pagamento(bloqueado: true, eventos: ev))));
      await _passos(t);
      expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
      expect(find.text('Motivo: sem papel'), findsOneWidget);
      expect(find.text('Chame um atendente, seu carrinho está salvo'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('voltar-carrinho')));
      await t.tap(find.byKey(const ValueKey('tentar-novamente')));
      expect(ev, ['carrinho', 'tentar']);
    });

    testWidgets('800×600 sem overflow em todos os estados', (t) async {
      _tela(t, _baixa);
      for (final p in [
        _pagamento(),
        _pagamento(erro: 'Pagamento não aprovado'),
        _pagamento(processando: true, pix: '00020126BR.GOV.BCB.PIX'),
        _pagamento(processando: true, pointAtivo: true),
        _pagamento(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…'),
        _pagamento(bloqueado: true),
      ]) {
        await t.pumpWidget(_view(VitrinePagamentoView(p: p)));
        await _passos(t, 2);
        expect(t.takeException(), isNull);
      }
    });
  });

  group('Confirmação', () {
    SucessoProps sucesso({bool impresso = true, bool fiscal = true, bool dinheiro = false, VoidCallback? novo}) =>
        SucessoProps(
          senha: '247',
          impresso: impresso,
          entrada: 1,
          onNovoPedido: novo ?? () {},
          dinheiro: dinheiro,
          segundos: 17,
          fiscal: fiscal,
        );

    testWidgets('senha, recibo e "Fazer novo pedido"; sem avisos quando tudo saiu', (t) async {
      _tela(t, _totem);
      var novo = 0;
      await t.pumpWidget(_view(VitrineSucessoView(p: sucesso(novo: () => novo++))));
      await _passos(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('senha'))).data, '247');
      expect(find.text('Pedido confirmado!'), findsOneWidget);
      expect(find.text('PAGAMENTO APROVADO'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsOneWidget);
      expect(find.text('Voltando ao início em 17 s'), findsOneWidget);
      for (final k in ['aviso-sem-cupom', 'aviso-sem-nota', 'aviso-caixa']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      await t.tap(find.byKey(const ValueKey('novo-pedido')));
      expect(novo, 1);
    });

    // ERR-022/V20: todo aviso de segurança existe em TODOS os modelos, com o texto da GoGen.
    testWidgets('avisos de impresso:false, fiscal:false e dinheiro:true', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(_view(VitrineSucessoView(p: sucesso(impresso: false, fiscal: false, dinheiro: true))));
      await _passos(t);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
      expect(find.text('cupom não impresso — ANOTE A SENHA e informe o balcão'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(find.text('cupom fiscal não impresso — retire no balcão com a senha'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsOneWidget);
      expect(find.text('PAGUE NO CAIXA PARA RETIRAR'), findsOneWidget);
      expect(find.text('Pedido enviado!'), findsOneWidget);
      expect(find.text('DIRIJA-SE AO CAIXA PARA PAGAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsNothing); // não imprimiu
      expect(find.byKey(const ValueKey('confete')), findsNothing); // sem partículas
    });

    testWidgets('a ConfirmacaoScreen repassa o aviso fiscal da rota ao Vitrine', (t) async {
      _tela(t, _totem);
      await t.pumpWidget(_view(const ConfirmacaoScreen(senha: 'A12', fiscal: false)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(VitrineSucessoView), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // desmonta: cancela o auto-retorno
    });

    testWidgets('800×600 sem overflow (com todos os avisos)', (t) async {
      _tela(t, _baixa);
      await t.pumpWidget(_view(VitrineSucessoView(p: sucesso(impresso: false, fiscal: false, dinheiro: true))));
      await _passos(t);
      expect(t.takeException(), isNull);
      await t.pumpWidget(_view(VitrineSucessoView(p: sucesso())));
      await _passos(t);
      expect(t.takeException(), isNull);
    });
  });
}
