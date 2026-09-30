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
import 'package:gogem_kiosk/features/templates/estudio/estudio_template.dart';
import 'package:gogem_kiosk/features/templates/estudio/estudio_tokens.dart';
import 'package:gogem_kiosk/features/templates/estudio/estudio_widgets.dart';
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import '../fixtures.dart';

/// Template Estúdio (docs/templates/03-estudio.md) — testes da seção 5 do 00: cada View
/// com `Movimento.parado` em 1080×1920 e um caso por tela em 800×600 (sem overflow).

const _tpl = EstudioTemplate();
const _retrato = Size(1080, 1920);
const _baixa = Size(800, 600);

MenuSnapshot _menu() => MenuSnapshot.fromPublicadoJson(publicadoFixture);
Produto _p(String id) => _menu().porId(id)!;

/// Produto com uma etapa OBRIGATÓRIA (escolha 1).
final _comEtapa = Produto.fromJson({
  'id': 'p9',
  'categoriaId': 'cat1',
  'nome': 'Burger do Chef',
  'descricao': 'Blend 180 g e cheddar',
  'precoCentavos': 3490,
  'disponivel': true,
  'selo': 'Novo',
  'grupos': [
    {
      'id': 'gp',
      'nome': 'Ponto da carne',
      'min': 1,
      'max': 1,
      'obrigatorio': true,
      'opcoes': [
        {'id': 'o-mal', 'nome': 'Mal passado', 'precoCentavosDelta': 0},
        {'id': 'o-ponto', 'nome': 'Ao ponto', 'precoCentavosDelta': 0},
      ],
    },
  ],
});

Future<void> _tela(WidgetTester t, Size tamanho) async {
  t.view.physicalSize = tamanho;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Sem `pumpAndSettle` (docs/templates/00 §5): passos fixos.
Future<void> _bombear(WidgetTester t, [int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

VoidCallback? _toque(WidgetTester t, String chave) =>
    t.widget<InkWell>(find.byKey(ValueKey(chave))).onTap;

DescansoProps _descanso({
  required void Function(String) onIniciar,
  bool bloqueado = false,
  List<DescansoMidia> midias = const [],
  String? precoIsca,
}) =>
    DescansoProps(
      chamada: 'Toque para começar',
      mov: Movimento.parado,
      bloqueado: bloqueado,
      onIniciar: onIniciar,
      nomeLoja: 'Casa do Burger',
      midias: midias,
      precoIsca: precoIsca,
      destaques: [_p('p1')],
    );

PagamentoProps _pagamento({
  bool bloqueado = false,
  bool processando = false,
  bool pointAtivo = false,
  String? pix,
  String? erro,
  String? mensagem,
  List<String>? log,
}) {
  void reg(String s) => log?.add(s);
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
    cliente: 'Ana',
    onVoltar: () => reg('voltar'),
    onVoltarCarrinho: () => reg('voltar-carrinho'),
    onTentarNovamente: () => reg('tentar'),
    onPagarPix: () => reg('pix'),
    onPagarCartao: () => reg('cartao'),
    onPagarDinheiro: () => reg('dinheiro'),
    onCancelarPix: () => reg('cancelar-pix'),
    onCancelarPoint: () => reg('cancelar-point'),
  );
}

/// Imita a `ProdutoScreen`: guarda as seleções e valida com a regra real.
class _Produto extends StatefulWidget {
  const _Produto({required this.produto, required this.onAdicionar});
  final Produto produto;
  final VoidCallback onAdicionar;
  @override
  State<_Produto> createState() => _ProdutoState();
}

class _ProdutoState extends State<_Produto> {
  final _sel = <String, List<OpcaoComplemento>>{};
  int _qtd = 1;
  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final valido = p.grupos.every((g) => selecaoValida(g, _sel[g.id] ?? const []));
    return _tpl.produto(ProdutoProps(
      produto: p,
      selecoes: _sel,
      qtd: _qtd,
      valido: valido,
      totalCentavos: p.precoCentavos * _qtd,
      onToggle: (g, o) => setState(() => _sel[g.id] = [o]),
      onMenos: () => setState(() => _qtd = _qtd > 1 ? _qtd - 1 : 1),
      onMais: () => setState(() => _qtd++),
      onAdicionar: widget.onAdicionar,
      onVoltar: () {},
    ));
  }
}

/// Imita a `IdentificacaoScreen`: CPF digitado e validado com a regra real.
class _Identificacao extends StatefulWidget {
  const _Identificacao({required this.log, this.aviso, this.cpfInicial = ''});
  final List<String> log;
  final String? aviso;
  final String cpfInicial;
  @override
  State<_Identificacao> createState() => _IdentificacaoState();
}

class _IdentificacaoState extends State<_Identificacao> {
  final _nome = TextEditingController();
  late String _cpf = widget.cpfInicial;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completo = _cpf.length == 11;
    final valido = cpfValido(_cpf);
    return _tpl.identificacao(IdentificacaoProps(
      nomeController: _nome,
      cpf: _cpf,
      completo: completo,
      valido: valido,
      onDigito: (d) => setState(() {
        if (_cpf.length < 11) _cpf += d;
      }),
      onApagar: () => setState(() {
        if (_cpf.isNotEmpty) _cpf = _cpf.substring(0, _cpf.length - 1);
      }),
      onPular: () => widget.log.add('pular:${_nome.text}'),
      onConfirmar: completo && valido ? () => widget.log.add('confirmar:$_cpf:${_nome.text}') : () {},
      onVoltar: () => widget.log.add('voltar'),
      avisoCpfObrigatorio: widget.aviso,
    ));
  }
}

class _SacolaCom extends CartNotifier {
  _SacolaCom(this.itens);
  final List<ItemCarrinho> itens;
  @override
  Carrinho build() => Carrinho(itens: itens);
}

/// Catálogo e sacola são telas inteiras: ProviderScope + um GoRouter mínimo.
Widget _telaInteira(String inicio, {List<Override> extra = const [], MenuSnapshot? menu}) {
  final rotas = GoRouter(initialLocation: inicio, routes: [
    GoRoute(path: '/catalogo', builder: (_, __) => _tpl.catalogo()),
    GoRoute(path: '/carrinho', builder: (_, __) => _tpl.carrinho()),
    GoRoute(path: '/produto/:id', builder: (_, s) => Scaffold(body: Text('PRODUTO ${s.pathParameters['id']}'))),
    GoRoute(path: '/descanso', builder: (_, __) => const Scaffold(body: Text('DESCANSO'))),
    GoRoute(path: '/peca-tambem', builder: (_, __) => const Scaffold(body: Text('PECA TAMBEM'))),
  ]);
  return ProviderScope(
    overrides: [
      aparenciaProvider.overrideWith(
          (ref) async => Aparencia.fromJson({'temaPreset': 'estudio', 'animacoes': 'off', 'nomeLoja': 'Casa'})),
      menuProvider.overrideWith((ref) async => menu ?? _menu()),
      ...extra,
    ],
    child: MaterialApp.router(routerConfig: rotas),
  );
}

void main() {
  test('templateDe devolve o Estúdio para "estudio" (tema claro)', () {
    final tpl = templateDe(Aparencia.fromJson({'temaPreset': 'estudio'}));
    expect(tpl, isA<EstudioTemplate>());
    expect(tpl!.tokens.claro, isTrue);
    expect(tpl.tokens.fonteDisplay, 'Sora');
    expect(tpl.tokens.fonteTexto, 'Figtree');
    expect(templatesRegistrados, contains('estudio'));
  });

  test('cor do disco: a da categoria (#RRGGBB) ou a rotação; tinta legível sobre ela', () {
    expect(corDisco(0), estudioDiscos[0]);
    expect(corDisco(5), estudioDiscos[1]);
    expect(corDisco(0, '#123456'), const Color(0xFF123456));
    expect(corDisco(2, 'azul'), estudioDiscos[2]);
    expect(tintaSobre(estudioDiscos[0]), EstudioCores.branco);
    for (final c in estudioDiscos.skip(1)) {
      expect(tintaSobre(c), estudioTokens.text);
    }
  });

  test('movimento cheio só no high + cheio', () {
    expect(movimentoCheio(const Movimento()), isTrue);
    expect(movimentoCheio(const Movimento(escala: .6)), isFalse);
    expect(movimentoCheio(Movimento.parado), isFalse);
  });

  group('Descanso', () {
    testWidgets('"Para levar" chama onIniciar(viagem) e "Comer aqui", local', (t) async {
      await _tela(t, _retrato);
      final chamadas = <String>[];
      await t.pumpWidget(_app(_tpl.descanso(_descanso(onIniciar: chamadas.add))));
      await _bombear(t);
      expect(find.text('Toque para começar'), findsOneWidget);
      expect(find.text('Mister Burguer'), findsOneWidget); // legenda do palco
      expect(find.text('Casa do Burger'), findsOneWidget); // logo com o nome da loja
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await t.tap(find.byKey(const ValueKey('descanso-local')));
      expect(chamadas, ['viagem', 'local']);
    });

    testWidgets('bloqueado: nenhum botão chama nada', (t) async {
      await _tela(t, _retrato);
      final chamadas = <String>[];
      await t.pumpWidget(_app(_tpl.descanso(_descanso(onIniciar: chamadas.add, bloqueado: true))));
      await _bombear(t);
      await t.tap(find.byKey(const ValueKey('descanso-viagem')), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('descanso-local')), warnIfMissed: false);
      await _bombear(t, 1);
      expect(chamadas, isEmpty);
      expect(_toque(t, 'descanso-viagem'), isNull);
    });

    testWidgets('mídia da loja substitui o título; preço-isca num selo', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(_tpl.descanso(_descanso(
        onIniciar: (_) {},
        precoIsca: 'Combo a R\$ 29,90',
        midias: const [DescansoMidia(url: 'https://x/foto.jpg', titulo: 'Novo smash', subtitulo: 'Só hoje')],
      ))));
      await _bombear(t);
      expect(find.text('Novo smash'), findsOneWidget);
      expect(find.text('Só hoje'), findsOneWidget);
      expect(find.text('Combo a R\$ 29,90'), findsOneWidget);
    });

    testWidgets('com animação, o carrossel troca de item a cada 3 s (e para no dispose)', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(_tpl.descanso(DescansoProps(
        chamada: 'Toque para começar',
        mov: const Movimento(),
        bloqueado: false,
        onIniciar: (_) {},
        destaques: [_p('p1'), _p('p2')],
      ))));
      await _bombear(t, 2);
      expect(find.text('Mister Burguer'), findsOneWidget);
      expect(find.text('Refri Lata'), findsNothing);
      await t.pump(const Duration(seconds: 3));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Refri Lata'), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // cancela o timer e as repetições
    });

    testWidgets('800×600: sem overflow e os botões respondem', (t) async {
      await _tela(t, _baixa);
      final chamadas = <String>[];
      await t.pumpWidget(_app(_tpl.descanso(_descanso(onIniciar: chamadas.add))));
      await _bombear(t);
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      expect(chamadas, ['viagem']);
    });
  });

  group('Catálogo', () {
    testWidgets('categoria e produto da fixture; indisponível não reage; o card abre o produto', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/catalogo'));
      await _bombear(t);
      expect(find.byKey(const ValueKey('categoria-cat1')), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget); // nome da loja no logo (aparência)
      expect(find.text('Burgers'), findsWidgets);
      expect(find.byKey(const ValueKey('estudio-prod-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('destaque-p1')), findsOneWidget); // selo "Mais vendido"
      expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('estudio-prod-p3')), warnIfMissed: false);
      await _bombear(t);
      expect(find.text('PRODUTO p3'), findsNothing);
      await t.tap(find.byKey(const ValueKey('estudio-prod-p1')));
      await _bombear(t);
      expect(find.text('PRODUTO p1'), findsOneWidget);
    });

    testWidgets('"+" sem etapa obrigatória põe na sacola e a barra mostra o total', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/catalogo'));
      await _bombear(t);
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('estudio-mais-p1')));
      await _bombear(t);
      expect(find.text('Sua sacola · 1 item'), findsOneWidget);
      expect(find.text('R\$ 29,90'), findsWidgets);
    });

    testWidgets('pílula rola até a seção da categoria; Cancelar volta ao descanso', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/catalogo'));
      await _bombear(t);
      await t.tap(find.byKey(const ValueKey('categoria-cat2')));
      await _bombear(t);
      expect(find.byKey(const ValueKey('estudio-prod-p2')).hitTestable(), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-cancelar')));
      await _bombear(t);
      expect(find.text('DESCANSO'), findsOneWidget);
    });

    testWidgets('movimento cheio: destaques rolam sozinhos e nada quebra', (t) async {
      await _tela(t, _retrato);
      final rotas = GoRouter(initialLocation: '/catalogo', routes: [
        GoRoute(path: '/catalogo', builder: (_, __) => _tpl.catalogo()),
      ]);
      final comDoisDestaques = MenuSnapshot(versao: 1, categorias: _menu().categorias, produtos: [
        for (final p in _menu().produtos)
          p.id == 'p2' ? Produto.fromJson({'id': 'p2', 'categoriaId': 'cat2', 'nome': 'Refri Lata', 'precoCentavos': 700, 'selo': 'Gelado'}) : p,
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'estudio', 'animacoes': 'cheio'})),
          menuProvider.overrideWith((ref) async => comDoisDestaques),
        ],
        child: MaterialApp.router(routerConfig: rotas),
      ));
      await _bombear(t, 3);
      final faixa = t.widget<PageView>(find.byKey(const ValueKey('faixa-destaques')));
      expect(faixa.controller!.page, 0);
      await t.pump(const Duration(milliseconds: 3600));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      // Passou para o 2º destaque (com 2 cartões, o último para antes da borda).
      expect(faixa.controller!.page, greaterThan(.5));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sem snapshot: estado vazio com "Atualizar"', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/catalogo', extra: [menuProvider.overrideWith((ref) async => null)]));
      await _bombear(t);
      expect(find.text('Cardápio ainda não sincronizado'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalogo-atualizar')), findsOneWidget);
    });

    testWidgets('800×600: sem overflow', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(_telaInteira('/catalogo'));
      await _bombear(t);
      expect(find.byKey(const ValueKey('catalogo-rolagem')), findsOneWidget);
      await t.drag(find.byKey(const ValueKey('catalogo-rolagem')), const Offset(0, -500));
      await _bombear(t);
    });
  });

  group('Inclinação 3D', () {
    /// Sem rotação: só a perspectiva do card (0,0011).
    bool reto(WidgetTester t) =>
        t
            .widget<Transform>(
                find.descendant(of: find.byType(CartaoInclinavel), matching: find.byType(Transform)).first)
            .transform ==
        (Matrix4.identity()..setEntry(3, 2, 0.0011));

    Widget cartao(bool inclina) => _app(Center(
          child: CartaoInclinavel(
            inclina: inclina,
            builder: (_, premido) => SizedBox(width: 300, height: 300, child: Text(premido ? 'premido' : 'solto')),
          ),
        ));

    testWidgets('com o dedo fora do centro o card inclina; ao soltar, volta', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(cartao(true));
      final centro = t.getCenter(find.byType(CartaoInclinavel));
      final g = await t.startGesture(centro + const Offset(120, -120));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('premido'), findsOneWidget);
      expect(reto(t), isFalse);
      await g.up();
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('solto'), findsOneWidget);
      expect(reto(t), isTrue);
    });

    testWidgets('sem movimento cheio: só o "press", sem inclinar', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(cartao(false));
      final centro = t.getCenter(find.byType(CartaoInclinavel));
      final g = await t.startGesture(centro + const Offset(120, -120));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('premido'), findsOneWidget);
      expect(reto(t), isTrue);
      await g.up();
      await t.pump();
    });
  });

  group('Produto', () {
    testWidgets('etapa obrigatória: Adicionar desabilitado até escolher', (t) async {
      await _tela(t, _retrato);
      var adicionou = 0;
      await t.pumpWidget(_app(_Produto(produto: _comEtapa, onAdicionar: () => adicionou++)));
      await _bombear(t);
      expect(find.text('Burger do Chef'), findsOneWidget);
      expect(find.text('Obrigatório'), findsOneWidget);
      expect(_toque(t, 'adicionar'), isNull);
      await t.tap(find.byKey(const ValueKey('adicionar')), warnIfMissed: false);
      expect(adicionou, 0);
      await t.tap(find.byKey(const ValueKey('op-o-ponto')));
      await _bombear(t, 1);
      expect(_toque(t, 'adicionar'), isNotNull);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      expect(adicionou, 1);
    });

    testWidgets('quantidade e X de fechar', (t) async {
      await _tela(t, _retrato);
      var voltou = false;
      await t.pumpWidget(_app(_tpl.produto(ProdutoProps(
        produto: _p('p1'),
        selecoes: const {},
        qtd: 2,
        valido: true,
        totalCentavos: 5980,
        onToggle: (_, __) {},
        onMenos: () {},
        onMais: () {},
        onAdicionar: () {},
        onVoltar: () => voltou = true,
      ))));
      await _bombear(t);
      expect(find.text('Adicionar · R\$ 59,80'), findsOneWidget);
      expect(find.text('Até 3'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('produto-fechar')));
      expect(voltou, isTrue);
    });

    testWidgets('800×600: sem overflow', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(_app(_Produto(produto: _comEtapa, onAdicionar: () {})));
      await _bombear(t);
      expect(find.byKey(const ValueKey('produto-cartao')), findsOneWidget);
    });
  });

  group('Sacola', () {
    List<Override> sacola(List<ItemCarrinho> itens) => [cartProvider.overrideWith(() => _SacolaCom(itens))];
    ItemCarrinho comBacon() {
      final p1 = _p('p1');
      return ItemCarrinho(linhaId: 'l1', produto: p1, selecoes: {'g1': [p1.grupos.first.opcoes.first]});
    }

    testWidgets('total, "Combina com seu pedido" com o upsell e Finalizar', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/carrinho', extra: sacola([comBacon()])));
      await _bombear(t);
      expect(find.text('Sua sacola'), findsOneWidget);
      expect(find.text('Cardápio'), findsOneWidget); // passo feito: ícone ✓, não o glifo
      expect(find.textContaining('✓'), findsNothing);
      expect(find.text('2. Sacola'), findsOneWidget);
      expect(find.text('Bacon'), findsOneWidget);
      expect(find.text('R\$ 33,90'), findsWidgets);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 33,90');
      expect(find.byKey(const ValueKey('combina')), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p2')), findsOneWidget); // p3 está esgotado
      expect(find.byKey(const ValueKey('sugestao-p3')), findsNothing);
      await t.tap(find.byKey(const ValueKey('finalizar-pedido')));
      await _bombear(t);
      expect(find.text('PECA TAMBEM'), findsOneWidget);
    });

    testWidgets('consumo marcado muda no checkout; lixeira esvazia a sacola', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_telaInteira('/carrinho', extra: sacola([comBacon()])));
      await _bombear(t);
      final c = ProviderScope.containerOf(t.element(find.text('Sua sacola')));
      expect(c.read(checkoutProvider).consumo, 'local');
      await t.tap(find.byKey(const ValueKey('consumo-viagem')));
      await _bombear(t, 1);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      await t.tap(find.byKey(const ValueKey('remover-l1')));
      await _bombear(t);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
    });

    testWidgets('sem sugestões, o bloco some', (t) async {
      await _tela(t, _retrato);
      final refri = ItemCarrinho(linhaId: 'l2', produto: _p('p2'), selecoes: const {});
      await t.pumpWidget(_telaInteira('/carrinho', extra: sacola([refri])));
      await _bombear(t);
      expect(find.byKey(const ValueKey('combina')), findsNothing);
    });

    testWidgets('800×600: sem overflow', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(_telaInteira('/carrinho', extra: sacola([comBacon()])));
      await _bombear(t);
      expect(find.byKey(const ValueKey('total')), findsOneWidget);
    });
  });

  group('Peça também', () {
    testWidgets('adicionar chama onAdicionar e o rótulo vira "Continuar"', (t) async {
      await _tela(t, _retrato);
      final adicionados = <String>[];
      var continuou = 0;
      Widget view(List<Produto> sugeridos) => _app(_tpl.pecaTambem(PecaTambemProps(
            sugeridos: sugeridos,
            onAdicionar: (p) => adicionados.add(p.id),
            onVoltar: () {},
            onContinuar: () => continuou++,
          )));
      await t.pumpWidget(view([_p('p2'), _p('p1')]));
      await _bombear(t);
      expect(find.text('Seguir sem sugestão'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sugestao-p2')));
      await _bombear(t, 1);
      expect(adicionados, ['p2']);
      // A tela recalcula a lista e o item adicionado sai dela: aqui ele fica, com ✓.
      await t.pumpWidget(view([_p('p1')]));
      await _bombear(t, 1);
      expect(find.byKey(const ValueKey('sugestao-ok-p2')), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
      expect(continuou, 1);
    });

    testWidgets('800×600: sem overflow', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(_app(_tpl.pecaTambem(PecaTambemProps(
        sugeridos: [_p('p2'), _p('p1'), _comEtapa],
        onAdicionar: (_) {},
        onVoltar: () {},
        onContinuar: () {},
      ))));
      await _bombear(t);
      expect(find.byKey(const ValueKey('peca-tambem-cartao')), findsOneWidget);
    });
  });

  group('Identificação', () {
    testWidgets('CPF inválido desabilita Continuar', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(const _Identificacao(log: [], cpfInicial: '11111111111')));
      await _bombear(t, 1);
      expect(find.text('CPF inválido, confira os números'), findsOneWidget);
      expect(_toque(t, 'continuar-cpf'), isNull);
      expect(_toque(t, 'pular'), isNotNull);
    });

    testWidgets('aviso de CPF obrigatório: sem "Opcional" e Pular desabilitado', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(const _Identificacao(log: [], aviso: 'Compras acima de R\$ 200,00 precisam do CPF na nota fiscal.')));
      await _bombear(t, 1);
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      expect(find.byKey(const ValueKey('cpf-opcional')), findsNothing);
      expect(_toque(t, 'pular'), isNull);
      expect(_toque(t, 'continuar-cpf'), isNull); // obrigatório: vazio não segue
    });

    testWidgets('com CPF válido, a etapa 2 chama onConfirmar com o nome digitado', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_Identificacao(log: log)));
      await _bombear(t, 1);
      for (final d in '52998224725'.split('')) {
        await t.tap(find.byKey(ValueKey('cpf-tecla-$d')));
      }
      await t.pump();
      expect(find.text('CPF válido'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('continuar-cpf')));
      await _bombear(t);
      expect(find.text('Como podemos te chamar?'), findsOneWidget);
      expect(log, isEmpty); // sair da etapa 1 não chama nada
      for (final l in ['A', 'N', 'A']) {
        await t.tap(find.byKey(ValueKey('nome-tecla-$l')));
      }
      await t.pump();
      expect(find.text('ANA'), findsOneWidget);
      expect(find.text('3/12'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('continuar-pagamento')));
      expect(log, ['confirmar:52998224725:ANA']);
    });

    testWidgets('Pular leva à etapa 2, que chama onPular; Voltar na etapa 2 volta à 1', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_Identificacao(log: log)));
      await _bombear(t, 1);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _bombear(t);
      expect(find.text('Como podemos te chamar?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      await _bombear(t);
      expect(find.text('CPF na nota?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(log, ['voltar']);
      await t.tap(find.byKey(const ValueKey('continuar-cpf'))); // CPF vazio segue sem CPF
      await _bombear(t);
      await t.tap(find.byKey(const ValueKey('continuar-pagamento')));
      expect(log, ['voltar', 'pular:']);
    });

    testWidgets('Limpar apaga o CPF inteiro', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(const _Identificacao(log: [], cpfInicial: '529982')));
      await _bombear(t, 1);
      await t.tap(find.byKey(const ValueKey('cpf-limpar')));
      await t.pump();
      expect(find.text('Ex.: 529.982.247-25'), findsOneWidget);
      expect(_toque(t, 'continuar-cpf'), isNotNull);
    });

    testWidgets('800×600: sem overflow nas duas etapas', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(_app(const _Identificacao(log: [])));
      await _bombear(t, 1);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _bombear(t);
      expect(find.byKey(const ValueKey('nome-campo')), findsOneWidget);
    });
  });

  group('Pagamento', () {
    testWidgets('escolha: Pix, Cartão e Dinheiro com as chaves da GoGen', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(log: log))));
      await _bombear(t);
      expect(find.text('ÚLTIMO PASSO, ANA'), findsOneWidget);
      expect(find.text('Crédito, débito ou vale: você escolhe na maquininha'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-total'))).data, 'R\$ 98,80');
      await t.tap(find.byKey(const ValueKey('forma-pix')));
      await t.tap(find.byKey(const ValueKey('forma-cartao')));
      await t.tap(find.byKey(const ValueKey('forma-dinheiro')));
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(log, ['pix', 'cartao', 'dinheiro', 'voltar']);
    });

    testWidgets('PIX: QR, contador e "Trocar forma de pagamento"', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(processando: true, pix: '00020126PIX', log: log))));
      await _bombear(t);
      expect(find.byKey(const ValueKey('pix-qr')), findsOneWidget);
      expect(find.text('Expira em 04:59'), findsOneWidget);
      expect(find.text('Aguardando pagamento'), findsOneWidget);
      expect(find.byKey(const ValueKey('topo-voltar')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pix-cancelar')));
      expect(log, ['cancelar-pix']);
    });

    testWidgets('Point: maquininha, instrução e Cancelar', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(processando: true, pointAtivo: true, log: log))));
      await _bombear(t);
      expect(find.byKey(const ValueKey('maquininha')), findsOneWidget);
      expect(find.text('Use a maquininha abaixo'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('point-cancelar')));
      expect(log, ['cancelar-point']);
    });

    testWidgets('processando: a mensagem da tela (ou "Processando…")', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(processando: true, mensagem: 'EMITINDO O CUPOM FISCAL…'))));
      await _bombear(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'Emitindo o cupom fiscal…');
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(processando: true))));
      await _bombear(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'Processando…');
    });

    testWidgets('erro: mensagem, Voltar e Tentar novamente (volta à escolha)', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(erro: 'Pagamento recusado', log: log))));
      await _bombear(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-erro'))).data, 'Pagamento recusado');
      await t.tap(find.byKey(const ValueKey('erro-voltar')));
      expect(log, ['voltar']);
      await t.tap(find.byKey(const ValueKey('erro-tentar-novamente')));
      await _bombear(t);
      expect(find.byKey(const ValueKey('forma-pix')), findsOneWidget);
    });

    testWidgets('bloqueado: motivo, Voltar ao carrinho e Tentar novamente', (t) async {
      await _tela(t, _retrato);
      final log = <String>[];
      await t.pumpWidget(_app(_tpl.pagamento(_pagamento(bloqueado: true, log: log))));
      await _bombear(t);
      expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
      expect(find.text('Motivo: sem papel'), findsOneWidget);
      expect(find.byKey(const ValueKey('forma-pix')), findsNothing);
      await t.tap(find.byKey(const ValueKey('voltar-carrinho')));
      await t.tap(find.byKey(const ValueKey('tentar-novamente')));
      expect(log, ['voltar-carrinho', 'tentar']);
    });

    testWidgets('800×600: sem overflow em todos os estados', (t) async {
      await _tela(t, _baixa);
      for (final props in [
        _pagamento(),
        _pagamento(processando: true, pix: '00020126PIX'),
        _pagamento(processando: true, pointAtivo: true),
        _pagamento(processando: true),
        _pagamento(erro: 'Pagamento recusado'),
        _pagamento(bloqueado: true),
      ]) {
        await t.pumpWidget(_app(_tpl.pagamento(props)));
        await _bombear(t, 2);
      }
      expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
    });
  });

  group('Sucesso', () {
    Widget sucesso({bool impresso = true, bool fiscal = true, bool dinheiro = false, VoidCallback? novo}) =>
        _app(_tpl.sucesso(SucessoProps(
          senha: '247',
          impresso: impresso,
          fiscal: fiscal,
          dinheiro: dinheiro,
          entrada: 1,
          segundos: 17,
          onNovoPedido: novo ?? () {},
        )));

    testWidgets('senha, recibo e "Fazer novo pedido"', (t) async {
      await _tela(t, _retrato);
      var novo = 0;
      await t.pumpWidget(sucesso(novo: () => novo++));
      await _bombear(t);
      expect(find.byKey(const ValueKey('senha')), findsOneWidget);
      expect(find.text('247'), findsOneWidget);
      expect(find.text('Pedido confirmado!'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsOneWidget);
      expect(find.text('Voltando ao início em 17 s'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsNothing);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsNothing);
      await t.tap(find.byKey(const ValueKey('novo-pedido')));
      expect(novo, 1);
    });

    testWidgets('avisos de segurança: sem comprovante, sem nota e pague no caixa (ERR-022)', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(sucesso(impresso: false, fiscal: false, dinheiro: true));
      await _bombear(t);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
      expect(find.text('cupom não impresso — ANOTE A SENHA e informe o balcão'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(find.text('cupom fiscal não impresso — retire no balcão com a senha'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsOneWidget);
      expect(find.text('PAGUE NO CAIXA PARA RETIRAR'), findsOneWidget);
      expect(find.text('Pedido enviado!'), findsOneWidget);
      expect(find.text('DIRIJA-SE AO CAIXA PARA PAGAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsNothing);
    });

    testWidgets('800×600: sem overflow com todos os avisos', (t) async {
      await _tela(t, _baixa);
      await t.pumpWidget(sucesso(impresso: false, fiscal: false, dinheiro: true));
      await _bombear(t);
      expect(find.byKey(const ValueKey('senha')), findsOneWidget);
    });
  });

  group('No app (delegação real)', () {
    setUp(() => router.go('/descanso'));

    testWidgets('descanso do Estúdio: "Para levar" grava viagem e abre o catálogo do Estúdio', (t) async {
      await _tela(t, _retrato);
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'estudio', 'animacoes': 'off'})),
          menuProvider.overrideWith((ref) async => _menu()),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await _bombear(t);
      expect(find.byKey(const ValueKey('descanso-titulo')), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('descanso-titulo'))));
      await t.tap(find.byKey(const ValueKey('descanso-viagem')));
      await _bombear(t);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      expect(find.byKey(const ValueKey('catalogo-rolagem')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });
}
