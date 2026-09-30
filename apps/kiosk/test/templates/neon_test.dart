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
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import 'package:gogem_kiosk/features/templates/neon/bento.dart';
import 'package:gogem_kiosk/features/templates/neon/descanso.dart';
import 'package:gogem_kiosk/features/templates/neon/neon_comum.dart';
import 'package:gogem_kiosk/features/templates/neon/neon_template.dart';
import 'package:gogem_kiosk/features/templates/providers.dart';
import '../fixtures.dart';

/// Template Neon 2.0 (docs/templates/04-neon-2.md) — testes da seção 5 do 00: cada View
/// com `Movimento.parado` em 1080×1920 e um caso por tela em 800×600 (sem overflow).
/// Proibido `pumpAndSettle`: só `pump` em passos.

const _tpl = NeonTemplate();
const _grande = Size(1080, 1920);
const _pequena = Size(800, 600);

MenuSnapshot _menu() => MenuSnapshot.fromPublicadoJson(publicadoFixture);

Produto _mister() => _menu().porId('p1')!;

/// Produto com etapa OBRIGATÓRIA (escolha 1 de 2).
Produto _comObrigatorio() => Produto.fromJson({
      'id': 'px',
      'categoriaId': 'cat1',
      'nome': 'Combo Duplo',
      'descricao': 'Burger, batata e bebida',
      'precoCentavos': 4290,
      'grupos': [
        {
          'id': 'gb',
          'nome': 'Bebida',
          'min': 1,
          'max': 1,
          'obrigatorio': true,
          'opcoes': [
            {'id': 'ob1', 'nome': 'Refri', 'precoCentavosDelta': 0},
            {'id': 'ob2', 'nome': 'Suco', 'precoCentavosDelta': 200},
          ],
        },
      ],
    });

Future<void> _tela(WidgetTester t, Size s) async {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _passos(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Widget _app(Widget home) => MaterialApp(home: home);

/// Rola até o alvo e desenha o quadro (o toque usa a posição já rolada).
Future<void> _visivel(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
}

NeonBotao _botao(WidgetTester t, String chave) => t.widget<NeonBotao>(find.byKey(ValueKey(chave)));

DescansoProps _descanso(
        {required void Function(String) onIniciar, bool bloqueado = false, Movimento mov = Movimento.parado}) =>
    DescansoProps(
      chamada: 'Toque para começar',
      mov: mov,
      bloqueado: bloqueado,
      onIniciar: onIniciar,
      precoIsca: 'R\$ 52,90',
      destaques: [_mister()],
    );

List<Override> _overrides({MenuSnapshot? menu, bool semMenu = false}) => [
      menuProvider.overrideWith((ref) async => semMenu ? null : (menu ?? _menu())),
      aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'neon'})),
      movimentoProvider.overrideWithValue(Movimento.parado),
    ];

void main() {
  test('templateDe devolve o NeonTemplate para temaPreset "neon"', () {
    expect(templateDe(Aparencia.fromJson({'temaPreset': 'neon'})), isA<NeonTemplate>());
    expect(templatesRegistrados, contains('neon'));
  });

  group('Grade bento', () {
    String forma(int n) => montarBento(n).join(' ');
    test('1 item: largo (sem meia tela vazia)', () => expect(forma(1), 'largo[0]'));
    test('2 itens: grande + alto', () => expect(forma(2), 'dupla[0, 1]'));
    test('3 itens: grande + dois normais', () => expect(forma(3), 'abertura[0, 1, 2]'));
    test('4 itens (par): o último é largo', () => expect(forma(4), 'abertura[0, 1, 2] largo[3]'));
    test('5 itens: grande + dois + par', () => expect(forma(5), 'abertura[0, 1, 2] par[3, 4]'));
    test('7 itens: grande + dois + dois pares', () => expect(forma(7), 'abertura[0, 1, 2] par[3, 4] par[5, 6]'));
    test('toda posição aparece uma vez, na ordem', () {
      for (var n = 0; n <= 12; n++) {
        expect([for (final b in montarBento(n)) ...b.indices], List.generate(n, (i) => i), reason: 'n=$n');
      }
    });
    test('o 1º item é grande sempre que há par ao lado', () {
      for (var n = 2; n <= 9; n++) {
        expect(montarBento(n).first.tipo(0), TipoTile.grande, reason: 'n=$n');
      }
    });
  });

  group('Descanso', () {
    testWidgets('"Para levar" chama onIniciar("viagem"); "Comer aqui", "local"', (t) async {
      await _tela(t, _grande);
      final chamadas = <String>[];
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(_descanso(onIniciar: chamadas.add)))));
      await _passos(t);
      expect(find.text('PEDE AÍ.'), findsOneWidget);
      expect(find.text('TOQUE PARA COMEÇAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('neon-adesivo')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('neon-viagem')));
      await t.tap(find.byKey(const ValueKey('neon-local')));
      expect(chamadas, ['viagem', 'local']);
    });

    testWidgets('bloqueado: nenhum botão chama nada', (t) async {
      await _tela(t, _grande);
      final chamadas = <String>[];
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(_descanso(onIniciar: chamadas.add, bloqueado: true)))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('neon-viagem')), warnIfMissed: false);
      await t.tap(find.byKey(const ValueKey('neon-local')), warnIfMissed: false);
      await _passos(t, 1);
      expect(chamadas, isEmpty);
      expect(_botao(t, 'neon-viagem').onTap, isNull);
    });

    testWidgets('800×600: cabe inteiro, sem overflow, e o botão responde', (t) async {
      await _tela(t, _pequena);
      final chamadas = <String>[];
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(_descanso(onIniciar: chamadas.add)))));
      await _passos(t);
      await t.tap(find.byKey(const ValueKey('neon-viagem')));
      expect(chamadas, ['viagem']);
    });

    testWidgets('perfil low (sem partículas): nenhum loop fica rodando', (t) async {
      await _tela(t, _grande);
      const low = Movimento(anima: true, particulas: false, blur: false, escala: .6);
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(_descanso(onIniciar: (_) {}, mov: low)))));
      await _passos(t, 6);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('perfil forte: faixas, anéis e letreiro animam', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(_app(Scaffold(body: _tpl.descanso(_descanso(onIniciar: (_) {}, mov: const Movimento())))));
      await _passos(t, 2);
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pumpWidget(const SizedBox());
    });

    test('adesivo: preço-isca, rótulo antes do preço e selo do destaque', () {
      DescansoProps p({String? isca, List<Produto> destaques = const []}) => DescansoProps(
          chamada: '',
          mov: Movimento.parado,
          bloqueado: false,
          onIniciar: (_) {},
          precoIsca: isca,
          destaques: destaques);
      expect(textoAdesivo(p(isca: 'R\$ 52,90')), ('COMBO DA NOITE', 'R\$ 52,90'));
      expect(textoAdesivo(p(isca: 'Combo Duplo Bacon R\$ 52,90')), ('COMBO DUPLO BACON', 'R\$ 52,90'));
      expect(textoAdesivo(p(destaques: [_mister()])), ('MAIS VENDIDO', 'R\$ 29,90'));
      expect(textoAdesivo(p()), isNull);
    });

    test('faixas: kickers das mídias da loja ou os textos do template', () {
      expect(textosFaixas(const []).first, 'SMASH ✦ BACON ✦ CHEDDAR ✦');
      final t = textosFaixas(const [DescansoMidia(url: 'x', kicker: 'Promo do dia')]);
      expect(t, List.filled(6, 'PROMO DO DIA ✦'));
    });
  });

  group('Catálogo', () {
    Widget comRotas(List<Override> overrides) {
      final r = GoRouter(initialLocation: '/catalogo', routes: [
        GoRoute(path: '/catalogo', builder: (_, __) => _tpl.catalogo()),
        GoRoute(path: '/produto/:id', builder: (_, s) => Scaffold(body: Text('PRODUTO ${s.pathParameters['id']}'))),
        GoRoute(path: '/descanso', builder: (_, __) => const Scaffold(body: Text('DESCANSO'))),
      ]);
      return ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: r));
    }

    testWidgets('mostra categoria e produto; esgotado não reage ao toque', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(comRotas(_overrides()));
      await _passos(t);
      expect(find.text('BURGERS'), findsOneWidget);
      expect(find.text('BEBIDAS'), findsOneWidget);
      expect(find.byKey(const ValueKey('neon-prod-p1')), findsOneWidget);
      expect(find.text('MISTER BURGUER'), findsWidgets);
      expect(find.byKey(const ValueKey('neon-destaque')), findsOneWidget);
      expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('neon-prod-p3')), warnIfMissed: false);
      await _passos(t, 2);
      expect(find.text('PRODUTO p3'), findsNothing);

      await t.tap(find.byKey(const ValueKey('neon-prod-p1')));
      await _passos(t, 2);
      expect(find.text('PRODUTO p1'), findsOneWidget);
    });

    testWidgets('"+" de produto sem etapa entra direto na sacola', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(comRotas(_overrides()));
      await _passos(t);
      final c = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('neon-prod-p2'))));
      await _visivel(t, find.byKey(const ValueKey('neon-add-p2')));
      await t.tap(find.byKey(const ValueKey('neon-add-p2')));
      await _passos(t, 1);
      expect(c.read(cartProvider).totalItens, 1);
      expect(find.text('Sua sacola · 1 item'), findsOneWidget);
    });

    testWidgets('Cancelar limpa a sacola e volta ao descanso', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(comRotas(_overrides()));
      await _passos(t);
      final c = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('neon-prod-p2'))));
      c.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: _menu().porId('p2')!, selecoes: const {}));
      await t.tap(find.byKey(const ValueKey('topo-cancelar')));
      await _passos(t, 2);
      expect(find.text('DESCANSO'), findsOneWidget);
      expect(c.read(cartProvider).vazio, isTrue);
    });

    testWidgets('sem cardápio: estado vazio do Neon com Atualizar', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(comRotas(_overrides(semMenu: true)));
      await _passos(t);
      expect(find.text('CARDÁPIO AINDA NÃO SINCRONIZADO'), findsOneWidget);
      expect(find.byKey(const ValueKey('neon-atualizar')), findsOneWidget);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _tela(t, _pequena);
      await t.pumpWidget(comRotas(_overrides()));
      await _passos(t);
      expect(find.text('BURGERS'), findsOneWidget);
    });
  });

  group('Catálogo — rolagem', () {
    testWidgets('tocar na aba rola até a seção da categoria', (t) async {
      await _tela(t, _pequena);
      final r = GoRouter(initialLocation: '/catalogo', routes: [
        GoRoute(path: '/catalogo', builder: (_, __) => _tpl.catalogo()),
      ]);
      await t.pumpWidget(ProviderScope(overrides: _overrides(), child: MaterialApp.router(routerConfig: r)));
      await _passos(t);
      final antes = t.getTopLeft(find.byKey(const ValueKey('neon-prod-p2'))).dy;
      expect(antes, greaterThan(600)); // Bebidas começa fora da tela
      await t.tap(find.byKey(const ValueKey('aba-cat2')));
      await _passos(t, 2);
      final depois = t.getTopLeft(find.byKey(const ValueKey('neon-prod-p2'))).dy;
      expect(depois, lessThan(600));
    });
  });

  group('Descanso — mídias da loja', () {
    testWidgets('legenda da mídia (título/subtítulo) aparece sob o produto', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(_app(Scaffold(
        body: _tpl.descanso(DescansoProps(
          chamada: 'Toque para começar',
          mov: Movimento.parado,
          bloqueado: false,
          onIniciar: (_) {},
          midias: const [
            DescansoMidia(url: 'https://x/a.png', kicker: 'Promo', titulo: 'Smash duplo', subtitulo: 'Só hoje'),
            DescansoMidia(url: 'https://x/b.png'),
          ],
          intervaloSeg: 5,
        )),
      )));
      await _passos(t);
      expect(find.byKey(const ValueKey('descanso-legenda')), findsOneWidget);
      expect(find.text('SMASH DUPLO'), findsOneWidget);
      expect(find.text('Só hoje'), findsOneWidget);
      // Troca de mídia no intervalo (a 2ª não tem legenda).
      await t.pump(const Duration(seconds: 5));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('descanso-legenda')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Produto', () {
    Widget produto({Size tela = _grande, void Function()? aoAdicionar}) {
      final p = _comObrigatorio();
      final sel = <String, List<OpcaoComplemento>>{};
      return _app(StatefulBuilder(builder: (context, setState) {
        final valido = p.grupos.every((g) => selecaoValida(g, sel[g.id] ?? const []));
        return _tpl.produto(ProdutoProps(
          produto: p,
          selecoes: sel,
          qtd: 1,
          valido: valido,
          totalCentavos: p.precoCentavos,
          onToggle: (g, o) => setState(() => sel[g.id] = [o]),
          onMenos: () {},
          onMais: () {},
          onAdicionar: aoAdicionar ?? () {},
          onVoltar: () {},
        ));
      }));
    }

    testWidgets('grupo obrigatório: Adicionar desabilitado até escolher', (t) async {
      await _tela(t, _grande);
      var adicionou = 0;
      await t.pumpWidget(produto(aoAdicionar: () => adicionou++));
      await _passos(t, 2);
      expect(find.text('COMBO DUPLO'), findsOneWidget);
      expect(find.text('Obrigatório'), findsOneWidget);
      expect(_botao(t, 'adicionar').onTap, isNull);
      await t.tap(find.byKey(const ValueKey('adicionar')), warnIfMissed: false);
      expect(adicionou, 0);

      await t.tap(find.byKey(const ValueKey('op-ob2')));
      await _passos(t, 1);
      expect(_botao(t, 'adicionar').onTap, isNotNull);
      await t.tap(find.byKey(const ValueKey('adicionar')));
      expect(adicionou, 1);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _tela(t, _pequena);
      await t.pumpWidget(produto());
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('adicionar')), findsOneWidget);
    });
  });

  group('Sacola', () {
    Future<ProviderContainer> sacola(WidgetTester t, List<String> ids, {Size tela = _grande}) async {
      await _tela(t, tela);
      final c = ProviderContainer(overrides: _overrides());
      addTearDown(c.dispose);
      final snap = _menu();
      for (final id in ids) {
        c.read(cartProvider.notifier).adicionar(ItemCarrinho(produto: snap.porId(id)!, selecoes: const {}));
      }
      c.read(checkoutProvider.notifier).setConsumo('viagem');
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: _app(_tpl.carrinho())));
      await _passos(t);
      return c;
    }

    testWidgets('mostra o total e o bloco de sugestões quando há upsell', (t) async {
      final c = await sacola(t, ['p1']);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 29,90');
      expect(find.byKey(const ValueKey('sugestoes')), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('sugestao-p3')), findsNothing); // esgotado não é sugerido
      expect(find.text('01'), findsOneWidget);

      // Consumo já marcado com o do descanso; tocar troca.
      await t.tap(find.byKey(const ValueKey('consumo-local')));
      await _passos(t, 1);
      expect(c.read(checkoutProvider).consumo, 'local');

      // "+" da sugestão entra na sacola e o bloco some (nada mais a sugerir).
      await _visivel(t, find.byKey(const ValueKey('sugestao-add-p2')));
      await t.tap(find.byKey(const ValueKey('sugestao-add-p2')));
      await _passos(t, 1);
      expect(c.read(cartProvider).totalItens, 2);
      expect(find.byKey(const ValueKey('sugestoes')), findsNothing);
    });

    testWidgets('sem upsell: sem o bloco de sugestões', (t) async {
      await sacola(t, ['p2']);
      expect(find.byKey(const ValueKey('sugestoes')), findsNothing);
      expect(t.widget<Text>(find.byKey(const ValueKey('total'))).data, 'R\$ 7,00');
    });

    testWidgets('lixeira remove a linha; sacola vazia desabilita Finalizar', (t) async {
      final c = await sacola(t, ['p2']);
      final linha = c.read(cartProvider).itens.single.linhaId;
      await t.tap(find.byKey(ValueKey('remover-$linha')));
      await _passos(t, 1);
      expect(c.read(cartProvider).vazio, isTrue);
      expect(find.byKey(const ValueKey('sacola-vazia')), findsOneWidget);
      expect(_botao(t, 'continuar').onTap, isNull);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await sacola(t, ['p1', 'p2'], tela: _pequena);
      expect(find.byKey(const ValueKey('total')), findsOneWidget);
    });
  });

  group('Peça também', () {
    Widget peca({required void Function(Produto) onAdicionar, void Function()? onContinuar}) =>
        _app(_tpl.pecaTambem(PecaTambemProps(
          sugeridos: [_menu().porId('p2')!],
          onAdicionar: onAdicionar,
          onVoltar: () {},
          onContinuar: onContinuar ?? () {},
        )));

    testWidgets('adicionar chama onAdicionar, marca ✓ e troca o rótulo para Continuar', (t) async {
      await _tela(t, _grande);
      final adicionados = <String>[];
      var continuou = 0;
      await t.pumpWidget(peca(onAdicionar: (p) => adicionados.add(p.id), onContinuar: () => continuou++));
      await _passos(t, 1);
      expect(find.text('SEGUIR SEM SUGESTÃO'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('sugestao-add-p2')));
      await _passos(t, 1);
      expect(adicionados, ['p2']);
      expect(find.text('CONTINUAR'), findsOneWidget);
      expect(find.text('SEGUIR SEM SUGESTÃO'), findsNothing);
      // Tocar de novo não duplica.
      await t.tap(find.byKey(const ValueKey('sugestao-p2')));
      expect(adicionados, ['p2']);
      await t.tap(find.byKey(const ValueKey('peca-tambem-continuar')));
      expect(continuou, 1);
    });

    testWidgets('800×600 sem overflow', (t) async {
      await _tela(t, _pequena);
      await t.pumpWidget(peca(onAdicionar: (_) {}));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('peca-tambem-continuar')), findsOneWidget);
    });
  });

  group('Identificação', () {
    /// Harness com o estado do CPF como o `IdentificacaoScreen` guarda.
    Widget ident({
      String cpfInicial = '',
      String? aviso,
      required List<String> eventos,
      TextEditingController? nome,
    }) {
      var cpf = cpfInicial;
      final ctrl = nome ?? TextEditingController();
      return _app(StatefulBuilder(builder: (context, setState) {
        final completo = cpf.length == 11;
        final valido = cpfValido(cpf);
        return _tpl.identificacao(IdentificacaoProps(
          nomeController: ctrl,
          cpf: cpf,
          completo: completo,
          valido: valido,
          avisoCpfObrigatorio: aviso,
          onDigito: (d) => setState(() {
            if (cpf.length < 11) cpf += d;
          }),
          onApagar: () => setState(() {
            if (cpf.isNotEmpty) cpf = cpf.substring(0, cpf.length - 1);
          }),
          onPular: () => eventos.add('pular'),
          onConfirmar: () => eventos.add('confirmar:$cpf'),
          onVoltar: () => eventos.add('voltar'),
        ));
      }));
    }

    testWidgets('CPF inválido desabilita Continuar; válido habilita', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(ident(cpfInicial: '11111111111', eventos: []));
      await _passos(t, 1);
      expect(_botao(t, 'cpf-continuar').onTap, isNull);
      expect(find.text('CPF inválido, confira os números'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cpf-limpar')));
      await _passos(t, 1);
      // Vazio é opcional: Continuar volta a valer.
      expect(_botao(t, 'cpf-continuar').onTap, isNotNull);
      for (final d in '52998224725'.split('')) {
        await t.tap(find.byKey(ValueKey('cpf-tecla-$d')));
      }
      await _passos(t, 1);
      expect(find.text('CPF válido'), findsOneWidget);
      expect(_botao(t, 'cpf-continuar').onTap, isNotNull);
    });

    testWidgets('CPF obrigatório: sem "Opcional", aviso em destaque e Pular desabilitado', (t) async {
      await _tela(t, _grande);
      final eventos = <String>[];
      await t
          .pumpWidget(ident(aviso: 'Compras acima de R\$ 2.000,00 precisam do CPF na nota fiscal.', eventos: eventos));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('aviso-cpf-obrigatorio')), findsOneWidget);
      expect(find.byKey(const ValueKey('pilula-opcional')), findsNothing);
      expect(_botao(t, 'pular').onTap, isNull);
      // Vazio também não passa quando é obrigatório.
      expect(_botao(t, 'cpf-continuar').onTap, isNull);
      await t.tap(find.byKey(const ValueKey('pular')), warnIfMissed: false);
      expect(find.byKey(const ValueKey('etapa-cpf')), findsOneWidget);
      expect(eventos, isEmpty);
    });

    testWidgets('com CPF: a etapa 1 guarda a escolha e a 2 chama onConfirmar', (t) async {
      await _tela(t, _grande);
      final eventos = <String>[];
      final nome = TextEditingController();
      addTearDown(nome.dispose);
      await t.pumpWidget(ident(cpfInicial: '52998224725', eventos: eventos, nome: nome));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 1);
      expect(eventos, isEmpty); // sair da etapa 1 não confirma nada ainda
      expect(find.byKey(const ValueKey('etapa-nome')), findsOneWidget);
      for (final l in ['A', 'N', 'A']) {
        await t.tap(find.byKey(ValueKey('nome-tecla-$l')));
      }
      await _passos(t, 1);
      expect(nome.text, 'ANA');
      expect(find.text('3/12'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(eventos, ['confirmar:52998224725']);
    });

    testWidgets('Pular vai à etapa 2, que chama onPular; Voltar da 2 volta à 1', (t) async {
      await _tela(t, _grande);
      final eventos = <String>[];
      await t.pumpWidget(ident(eventos: eventos));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('etapa-nome')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('etapa-cpf')), findsOneWidget);
      expect(eventos, isEmpty);
      await t.tap(find.byKey(const ValueKey('topo-voltar')));
      expect(eventos, ['voltar']);
      await t.tap(find.byKey(const ValueKey('pular')));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('nome-continuar')));
      expect(eventos, ['voltar', 'pular']);
    });

    testWidgets('800×600 sem overflow nas duas etapas', (t) async {
      await _tela(t, _pequena);
      await t.pumpWidget(ident(eventos: []));
      await _passos(t, 1);
      await t.tap(find.byKey(const ValueKey('cpf-continuar')));
      await _passos(t, 1);
      expect(find.byKey(const ValueKey('etapa-nome')), findsOneWidget);
    });
  });

  group('Pagamento', () {
    final eventos = <String>[];
    setUp(eventos.clear);

    PagamentoProps pag({
      bool bloqueado = false,
      bool processando = false,
      bool point = false,
      String? pix,
      String? erro,
      String? mensagem,
      String cliente = '',
    }) =>
        PagamentoProps(
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
          onVoltar: () => eventos.add('voltar'),
          onVoltarCarrinho: () => eventos.add('carrinho'),
          onTentarNovamente: () => eventos.add('tentar'),
          onPagarPix: () => eventos.add('pix'),
          onPagarCartao: () => eventos.add('cartao'),
          onPagarDinheiro: () => eventos.add('dinheiro'),
          onCancelarPix: () => eventos.add('cancelar-pix'),
          onCancelarPoint: () => eventos.add('cancelar-point'),
        );

    for (final tela in [_grande, _pequena]) {
      final sufixo = tela == _grande ? '' : ' (800×600)';

      testWidgets('escolha: Pix, Cartão e Dinheiro com as chaves da GoGen$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(cliente: 'Ana'))));
        await _passos(t, 1);
        expect(find.text('ÚLTIMO PASSO, ANA'), findsOneWidget);
        expect(find.text('Crédito, débito ou vale: você escolhe na maquininha'), findsOneWidget);
        for (final f in ['forma-pix', 'forma-cartao', 'forma-dinheiro']) {
          await _visivel(t, find.byKey(ValueKey(f)));
          await t.tap(find.byKey(ValueKey(f)));
        }
        expect(eventos, ['pix', 'cartao', 'dinheiro']);
        expect(find.byKey(const ValueKey('pagamento-erro')), findsNothing);
      });

      testWidgets('PIX: QR, contador e Trocar forma de pagamento$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(processando: true, pix: '00020126pix'))));
        await _passos(t, 1);
        expect(find.byKey(const ValueKey('pix-qr')), findsOneWidget);
        expect(find.text('Expira em 04:59'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('pix-cancelar')));
        expect(eventos, ['cancelar-pix']);
      });

      testWidgets('Point: maquininha e Cancelar$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(processando: true, point: true))));
        await _passos(t, 1);
        expect(find.byKey(const ValueKey('maquininha')), findsOneWidget);
        expect(find.text('USE A MAQUININHA ABAIXO'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('point-cancelar')));
        expect(eventos, ['cancelar-point']);
      });

      testWidgets('processando: "Processando…" ou a mensagem da venda$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(processando: true))));
        await _passos(t, 1);
        expect(find.text('PROCESSANDO…'), findsOneWidget);
        await t.pumpWidget(_app(_tpl.pagamento(pag(processando: true, mensagem: 'Emitindo o cupom fiscal…'))));
        await _passos(t, 1);
        expect(t.widget<Text>(find.byKey(const ValueKey('pagamento-espera'))).data, 'EMITINDO O CUPOM FISCAL…');
      });

      testWidgets('erro: mensagem e as formas continuam para tentar de novo$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(erro: 'Pagamento recusado'))));
        await _passos(t, 1);
        expect(find.byKey(const ValueKey('pagamento-erro')), findsOneWidget);
        expect(find.text('Pagamento recusado'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('topo-voltar')));
        await _visivel(t, find.byKey(const ValueKey('forma-pix')));
        await t.tap(find.byKey(const ValueKey('forma-pix')));
        expect(eventos, ['voltar', 'pix']);
      });

      testWidgets('bloqueado: motivo, Voltar ao carrinho e Tentar novamente$sufixo', (t) async {
        await _tela(t, tela);
        await t.pumpWidget(_app(_tpl.pagamento(pag(bloqueado: true))));
        await _passos(t, 1);
        expect(find.byKey(const ValueKey('pagamento-bloqueado')), findsOneWidget);
        expect(find.text('sem papel'), findsOneWidget);
        await _visivel(t, find.byKey(const ValueKey('tentar-novamente')));
        await t.tap(find.byKey(const ValueKey('tentar-novamente')));
        await t.tap(find.byKey(const ValueKey('voltar-carrinho')));
        expect(eventos, ['tentar', 'carrinho']);
      });
    }
  });

  group('Sucesso', () {
    SucessoProps suc({bool impresso = true, bool fiscal = true, bool dinheiro = false, VoidCallback? novo}) =>
        SucessoProps(
          senha: '247',
          impresso: impresso,
          fiscal: fiscal,
          dinheiro: dinheiro,
          entrada: 1,
          segundos: 17,
          onNovoPedido: novo ?? () {},
        );

    testWidgets('senha, recibo e sem avisos quando tudo saiu', (t) async {
      await _tela(t, _grande);
      var novo = 0;
      await t.pumpWidget(_app(_tpl.sucesso(suc(novo: () => novo++))));
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('senha')), findsOneWidget);
      expect(find.text('247'), findsOneWidget);
      expect(find.text('PEDIDO CONFIRMADO!'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsOneWidget);
      expect(find.byKey(const ValueKey('contador-standby')), findsOneWidget);
      for (final k in ['aviso-caixa', 'aviso-sem-cupom', 'aviso-sem-nota']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      await t.tap(find.byKey(const ValueKey('novo-pedido')));
      expect(novo, 1);
    });

    // ERR-022 / V20: todo aviso de segurança existe em todos os modelos.
    testWidgets('avisos de impresso:false, fiscal:false e dinheiro:true (textos da GoGen)', (t) async {
      await _tela(t, _grande);
      await t.pumpWidget(_app(_tpl.sucesso(suc(impresso: false, fiscal: false, dinheiro: true))));
      await _passos(t, 2);
      expect(find.text('247'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-caixa')), findsOneWidget);
      expect(find.text('PAGUE NO CAIXA PARA RETIRAR'), findsOneWidget);
      expect(find.text('DIRIJA-SE AO CAIXA PARA PAGAR'), findsOneWidget);
      expect(find.text('PEDIDO ENVIADO!'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-cupom')), findsOneWidget);
      expect(find.text('cupom não impresso — ANOTE A SENHA e informe o balcão'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
      expect(find.text('cupom fiscal não impresso — retire no balcão com a senha'), findsOneWidget);
      expect(find.byKey(const ValueKey('recibo')), findsNothing);
    });

    testWidgets('800×600 sem overflow, com os três avisos', (t) async {
      await _tela(t, _pequena);
      await t.pumpWidget(_app(_tpl.sucesso(suc(impresso: false, fiscal: false, dinheiro: true))));
      await _passos(t, 2);
      expect(find.byKey(const ValueKey('aviso-sem-nota')), findsOneWidget);
    });
  });

  group('No app (registro real)', () {
    setUp(() => router.go('/descanso'));

    testWidgets('temaPreset "neon": descanso do Neon, "Para levar" grava viagem e abre o cardápio Neon', (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'neon', 'animacoes': 'off'})),
          menuProvider.overrideWith((ref) async => _menu()),
        ],
        child: const GogemKioskApp(iniciarSync: false),
      ));
      await _passos(t, 3);
      expect(find.byKey(const ValueKey('neon-descanso')), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('neon-descanso'))));
      await t.tap(find.byKey(const ValueKey('neon-viagem')));
      await _passos(t, 3);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      expect(find.byKey(const ValueKey('aba-cat1')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });
}
