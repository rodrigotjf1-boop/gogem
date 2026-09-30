import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/app.dart';
import 'package:gogem_kiosk/core/hardware/hardware_profile.dart';
import 'package:gogem_kiosk/core/router.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/domain/order/cart.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/sugestoes.dart';
import 'package:gogem_kiosk/features/templates/comum/catalogo_dados.dart';
import 'package:gogem_kiosk/features/templates/comum/etapas.dart';
import 'package:gogem_kiosk/features/templates/comum/produto_arte.dart';
import 'package:gogem_kiosk/features/templates/comum/sacola.dart';
import 'package:gogem_kiosk/features/templates/comum/selo.dart';
import 'package:gogem_kiosk/features/templates/comum/sucesso_comum.dart';
import 'package:gogem_kiosk/features/templates/comum/teclados.dart';
import 'package:gogem_kiosk/features/templates/kiosk_template.dart';
import 'package:gogem_kiosk/features/templates/movimento.dart';
import 'package:gogem_kiosk/features/templates/template_tokens.dart';
import 'package:gogem_kiosk/printing/printer_providers.dart';
import '../fixtures.dart';

/// Base comum dos templates (docs/templates/00, Fase 0). Nenhum template concreto ainda:
/// a delegação das telas é provada com um template FALSO registrado só no teste.

const _tk = TemplateTokens(
  bg: Color(0xFF111111),
  surface: Color(0xFF222222),
  surface2: Color(0xFF333333),
  text: Color(0xFFFFFFFF),
  muted: Color(0xFFAAAAAA),
  accent: Color(0xFFEC7433),
  onAccent: Color(0xFF000000),
  accent2: Color(0xFFF4B63F),
  onAccent2: Color(0xFF000000),
  line: Color(0xFF444444),
  line2: Color(0xFF555555),
  price: Color(0xFFF4B63F),
  hi: Color(0x21EC7433),
  art: Color(0xFF241C18),
  ok: Color(0xFF6FCF97),
  err: Color(0xFFFF7A6B),
  raio: 30,
  raioBotao: 22,
  raioTecla: 24,
  fonteDisplay: 'Tektur',
  fonteTexto: 'Tektur',
);

MenuSnapshot _menu() {
  final s = publicadoFixture['snapshot'] as Map<String, dynamic>;
  return MenuSnapshot(
    versao: 3,
    categorias: [for (final c in s['categorias'] as List) Categoria.fromJson(c as Map<String, dynamic>)],
    produtos: [for (final p in s['produtos'] as List) Produto.fromJson(p as Map<String, dynamic>)],
  );
}

Widget _app(Widget child, {Size tela = const Size(1080, 1920)}) => MediaQuery(
      data: MediaQueryData(size: tela),
      child: MaterialApp(home: Scaffold(body: child)),
    );

Future<void> _bombear(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Template falso: só marca de onde veio cada tela e expõe os botões do descanso.
class _TemplateTeste extends KioskTemplate {
  const _TemplateTeste();
  @override
  TemplateTokens get tokens => _tk;
  @override
  Widget descanso(DescansoProps p) => Stack(children: [
        const Positioned(top: 200, left: 100, child: Text('TPL DESCANSO')),
        Positioned(
          bottom: 40,
          left: 40,
          child: ElevatedButton(
            key: const ValueKey('tpl-local'),
            onPressed: () => p.onIniciar('local'),
            child: const Text('Comer aqui'),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 40,
          child: ElevatedButton(
            key: const ValueKey('tpl-viagem'),
            onPressed: () => p.onIniciar('viagem'),
            child: const Text('Para levar'),
          ),
        ),
      ]);
  @override
  Widget catalogo() => const Scaffold(body: Center(child: Text('TPL CATALOGO')));
  @override
  Widget carrinho() => const Scaffold(body: Center(child: Text('TPL CARRINHO')));
  @override
  Widget produto(ProdutoProps p) => Scaffold(body: Text('TPL PRODUTO ${p.produto.nome}'));
  @override
  Widget pecaTambem(PecaTambemProps p) => const Scaffold(body: Text('TPL PECA'));
  @override
  Widget identificacao(IdentificacaoProps p) => const Scaffold(body: Text('TPL ID'));
  @override
  Widget pagamento(PagamentoProps p) => const Scaffold(body: Text('TPL PAG'));
  @override
  Widget sucesso(SucessoProps p) => Scaffold(body: Text('TPL SUCESSO ${p.senha}'));
}

void main() {
  group('Aparencia — chaves dos templates', () {
    for (final chave in ['brasa2', 'vitrine', 'estudio', 'neon', 'diner']) {
      test('fromJson reconhece "$chave"', () {
        final ap = Aparencia.fromJson({'temaPreset': chave});
        expect(ap.temaPreset, chave);
        final flags = {
          'brasa2': ap.brasa2,
          'vitrine': ap.vitrine,
          'estudio': ap.estudio,
          'neon': ap.neon,
          'diner': ap.diner,
        };
        expect(flags.entries.where((e) => e.value).map((e) => e.key), [chave]);
        expect(ap.gogen || ap.brasa || ap.editorial, isFalse);
      });
    }

    test('brasa (antigo), gogen, padrao e burger seguem o caminho atual das telas', () {
      for (final chave in ['brasa', 'gogen', 'padrao', 'burger']) {
        expect(templateDe(Aparencia.fromJson({'temaPreset': chave})), isNull, reason: chave);
      }
    });
  });

  group('Movimento', () {
    test('high + cheio: tudo ligado', () {
      final m = Movimento.de(Aparencia.fromJson({'animacoes': 'cheio'}), HardwareCaps.high);
      expect([m.anima, m.particulas, m.blur, m.escala], [true, true, true, 1.0]);
    });
    test('animacoes off: nada anima e nada de partícula', () {
      final m = Movimento.de(Aparencia.fromJson({'animacoes': 'off'}), HardwareCaps.high);
      expect(m.anima, isFalse);
      expect(m.particulas, isFalse);
    });
    test('reduzido: sem partícula e movimento a 60%', () {
      final m = Movimento.de(Aparencia.fromJson({'animacoes': 'reduzido'}), HardwareCaps.high);
      expect(m.anima, isTrue);
      expect(m.particulas, isFalse);
      expect(m.escala, 0.6);
      expect(m.d(600), const Duration(milliseconds: 1000));
    });
    test('perfil low (Tinker Board): sem blur, sem partícula, 60%', () {
      final m = Movimento.de(Aparencia.fromJson({'animacoes': 'cheio'}), HardwareCaps.low);
      expect([m.anima, m.particulas, m.blur, m.escala], [true, false, false, 0.6]);
    });
  });

  group('Dados do pedido', () {
    test('sugestoesUpsell: na ordem, sem repetir, disponível e fora da sacola', () {
      final snap = _menu();
      final burger = snap.porId('p1')!;
      final item = ItemCarrinho(produto: burger, selecoes: const {});
      // p1 sugere p2 (disponível) e p3 (esgotado).
      expect(sugestoesUpsell([item], snap).map((p) => p.id), ['p2']);
      final comRefri = ItemCarrinho(produto: snap.porId('p2')!, selecoes: const {});
      expect(sugestoesUpsell([item, item, comRefri], snap), isEmpty);
    });

    test('CatalogoDados: esgotado continua na seção; destaque = produto com selo', () {
      final d = CatalogoDados.de(_menu());
      expect(d.secoes.map((s) => s.categoria.nome), ['Burgers', 'Bebidas']);
      expect(d.secoes.first.produtos.map((p) => p.id), ['p1', 'p3']);
      expect(d.destaques.map((p) => p.id), ['p1']);
    });

    test('CatalogoDados sem selo nenhum: os 3 primeiros disponíveis da 1ª categoria', () {
      final snap = _menu();
      final semSelo = MenuSnapshot(versao: 1, categorias: snap.categorias, produtos: [
        for (final p in snap.produtos)
          Produto(
            id: p.id,
            categoriaId: p.categoriaId,
            nome: p.nome,
            descricao: p.descricao,
            precoCentavos: p.precoCentavos,
            disponivel: p.disponivel,
            imagemUrl: p.imagemUrl,
            externalRefs: p.externalRefs,
            grupos: p.grupos,
          ),
      ]);
      expect(CatalogoDados.de(semSelo).destaques.map((p) => p.id), ['p1']);
    });
  });

  group('Teclados', () {
    test('máscara do CPF: o que foi digitado e o que falta', () {
      expect(mascaraCpf(''), ('', '___.___.___-__'));
      expect(mascaraCpf('123'), ('123', '.___.___-__'));
      expect(mascaraCpf('1234'), ('123.4', '__.___-__'));
      expect(mascaraCpf('52998224725'), ('529.982.247-25', ''));
    });

    test('nome: no máximo 12, sem espaço no começo nem dois seguidos', () {
      expect(aplicarTeclaNome('', 'espaco'), '');
      expect(aplicarTeclaNome('ANA', 'espaco'), 'ANA ');
      expect(aplicarTeclaNome('ANA ', 'espaco'), 'ANA ');
      expect(aplicarTeclaNome('ANA', 'apagar'), 'AN');
      expect(aplicarTeclaNome('', 'apagar'), '');
      expect(aplicarTeclaNome('ABCDEFGHIJKL', 'M'), 'ABCDEFGHIJKL');
      expect(aplicarTeclaNome('ABCDEFGHIJK', 'espaco'), 'ABCDEFGHIJK ');
      expect(aplicarTeclaNome('ABCDEFGHIJKL', 'espaco'), 'ABCDEFGHIJKL');
    });

    testWidgets('TecladoCpf: dígito, apagar e limpar chamam os callbacks', (t) async {
      final digitos = <String>[];
      var apagou = 0;
      var limpou = 0;
      await t.pumpWidget(_app(SingleChildScrollView(
        child: TecladoCpf(
          onDigito: digitos.add,
          onApagar: () => apagou++,
          onLimpar: () => limpou++,
          tokens: _tk,
        ),
      )));
      await t.tap(find.byKey(const ValueKey('cpf-tecla-5')));
      await t.tap(find.byKey(const ValueKey('cpf-tecla-0')));
      await t.tap(find.byKey(const ValueKey('cpf-apagar')));
      await t.tap(find.byKey(const ValueKey('cpf-limpar')));
      expect(digitos, ['5', '0']);
      expect([apagou, limpou], [1, 1]);
    });

    testWidgets('TecladoNome escreve no controller do fluxo, até 12 letras', (t) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await t.pumpWidget(_app(SingleChildScrollView(child: TecladoNome(controller: ctrl, tokens: _tk))));
      for (final l in ['A', 'N', 'A']) {
        await t.tap(find.byKey(ValueKey('nome-tecla-$l')).first);
      }
      await t.tap(find.byKey(const ValueKey('nome-espaco')));
      await t.tap(find.byKey(const ValueKey('nome-tecla-Ç')));
      expect(ctrl.text, 'ANA Ç');
      await t.tap(find.byKey(const ValueKey('nome-apagar')));
      expect(ctrl.text, 'ANA ');
      for (var i = 0; i < 20; i++) {
        await t.tap(find.byKey(const ValueKey('nome-tecla-Q')));
      }
      expect(ctrl.text.length, 12);
    });

    testWidgets('CampoCpf mostra a máscara e fica vermelho com CPF inválido', (t) async {
      await t.pumpWidget(_app(const CampoCpf(cpf: '11111111111', completo: true, valido: false, tokens: _tk)));
      final campo = t.widget<Container>(find.byKey(const ValueKey('cpf-campo')));
      final borda = (campo.decoration! as BoxDecoration).border! as Border;
      expect(borda.top.color, _tk.err);
      expect(find.byKey(const ValueKey('cpf-display')), findsOneWidget);
    });
  });

  group('Componentes', () {
    test('ProdutoArte: .png é recorte, o resto é foto', () {
      expect(ProdutoArte.ehRecorte('https://x/burger.PNG?v=2'), isTrue);
      expect(ProdutoArte.ehRecorte('https://x/burger.webp'), isFalse);
      expect(ProdutoArte.ehRecorte(null), isFalse);
    });

    test('Selo: "mais pedido/vendido" ganha o destaque', () {
      expect(Selo.ehMaisPedido('Mais pedido'), isTrue);
      expect(Selo.ehMaisPedido('MAIS VENDIDO'), isTrue);
      expect(Selo.ehMaisPedido('Novo'), isFalse);
    });

    testWidgets('Indisponivel: selo "Esgotado" e o toque não passa', (t) async {
      var tocou = false;
      await t.pumpWidget(_app(Indisponivel(
        ativo: true,
        tokens: _tk,
        alturaSelo: 40,
        child: GestureDetector(
          onTap: () => tocou = true,
          child: const SizedBox(width: 300, height: 300, child: Text('card')),
        ),
      )));
      expect(find.byKey(const ValueKey('selo-esgotado')), findsOneWidget);
      await t.tap(find.text('card'), warnIfMissed: false);
      expect(tocou, isFalse);
    });

    // ERR-029: o "✓" era o caractere U+2713, que as fontes dos templates não têm (virava
    // uma caixinha). Agora é ícone desenhado, e nenhum texto das etapas leva o caractere.
    testWidgets('Etapas: concluídos com ✓ desenhado, o atual numerado', (t) async {
      await t.pumpWidget(_app(const Etapas(atual: 2, tokens: _tk)));
      expect(find.text('Cardápio'), findsOneWidget);
      expect(find.text('Sacola'), findsOneWidget);
      expect(find.byKey(const ValueKey('etapa-feita-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('etapa-feita-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('etapa-feita-2')), findsNothing);
      expect(find.text('3. Identificação'), findsOneWidget);
      expect(find.text('4. Pagamento'), findsOneWidget);
      final textos = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '');
      expect(textos.where((s) => s.contains('✓')), isEmpty);
    });

    testWidgets('ReciboImpresso sem nome da loja não deixa linha vazia', (t) async {
      await t.pumpWidget(_app(const ReciboImpresso(senha: '247', tokens: _tk)));
      final textos = t.widgetList<Text>(find.descendant(
          of: find.byKey(const ValueKey('recibo')), matching: find.byType(Text)));
      expect(textos.map((w) => w.data), ['SENHA 247']);
    });

    testWidgets('BarraSacola: contagem, total e "Ver sacola"; vazia não abre', (t) async {
      var abriu = 0;
      await t.pumpWidget(_app(BarraSacola(itens: 2, totalCentavos: 9880, onVerSacola: () => abriu++, tokens: _tk)));
      expect(find.text('Sua sacola · 2 itens'), findsOneWidget);
      expect(find.text('R\$ 98,80'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('barra-sacola')));
      expect(abriu, 1);
      await t.pumpWidget(_app(BarraSacola(itens: 0, totalCentavos: 0, onVerSacola: () => abriu++, tokens: _tk)));
      expect(find.text('Sua sacola está vazia'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('barra-sacola')));
      expect(abriu, 1);
    });

    testWidgets('ContagemSenha sem animação mostra a senha direto', (t) async {
      await t.pumpWidget(_app(const ContagemSenha(senha: '247', estilo: TextStyle(fontSize: 40))));
      expect(find.text('247'), findsOneWidget);
    });

    testWidgets('ContagemSenha anima até a senha certa', (t) async {
      await t.pumpWidget(_app(const ContagemSenha(
        senha: '047',
        estilo: TextStyle(fontSize: 40),
        mov: Movimento(),
      )));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 900));
      expect(find.text('047'), findsOneWidget);
    });

    testWidgets('Confete não existe sem partículas', (t) async {
      await t.pumpWidget(_app(const Confete(cores: [Colors.red])));
      expect(find.byKey(const ValueKey('confete')), findsNothing);
    });
  });

  group('Delegação das telas (template falso registrado)', () {
    setUp(() {
      registroDeTeste = {'teste': const _TemplateTeste()};
      router.go('/descanso');
    });
    tearDown(() => registroDeTeste = null);

    Widget app(List<Override> extra) => ProviderScope(
          overrides: [
            aparenciaProvider.overrideWith((ref) async => Aparencia.fromJson({'temaPreset': 'teste'})),
            menuProvider.overrideWith((ref) async => _menu()),
            ...extra,
          ],
          child: const GogemKioskApp(iniciarSync: false),
        );

    testWidgets('descanso: "Para levar" grava viagem e abre o catálogo do template', (t) async {
      late ProviderContainer c;
      await t.pumpWidget(app([]));
      await _bombear(t, 3);
      c = ProviderScope.containerOf(t.element(find.text('TPL DESCANSO')));
      expect(find.text('TPL DESCANSO'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tpl-viagem')));
      await _bombear(t);
      expect(c.read(checkoutProvider).consumo, 'viagem');
      expect(find.text('TPL CATALOGO'), findsOneWidget);
    });

    testWidgets('descanso: toque no fundo começa "Comer aqui"', (t) async {
      await t.pumpWidget(app([]));
      await _bombear(t, 3);
      final c = ProviderScope.containerOf(t.element(find.text('TPL DESCANSO')));
      c.read(checkoutProvider.notifier).setConsumo('viagem');
      await t.tapAt(const Offset(400, 300));
      await _bombear(t);
      expect(c.read(checkoutProvider).consumo, 'local');
      expect(find.text('TPL CATALOGO'), findsOneWidget);
    });

    testWidgets('descanso bloqueado (sem papel): nenhum botão começa o pedido', (t) async {
      final fake = FakeTransport()..semPapel = true;
      await t.pumpWidget(app([printerTransportProvider.overrideWithValue(fake)]));
      await _bombear(t);
      expect(find.byKey(const ValueKey('fora-operacao')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tpl-viagem')), warnIfMissed: false);
      await t.tapAt(const Offset(400, 300));
      await _bombear(t);
      expect(find.text('TPL CATALOGO'), findsNothing);
    });

    testWidgets('5 toques no canto continuam abrindo o admin com template', (t) async {
      await t.pumpWidget(app([]));
      await _bombear(t, 3);
      for (var i = 0; i < 5; i++) {
        await t.tapAt(const Offset(40, 40));
        await t.pump(const Duration(milliseconds: 80));
      }
      await _bombear(t);
      expect(find.text('ACESSO RESTRITO'), findsOneWidget);
      expect(find.text('TPL CATALOGO'), findsNothing);
    });

    testWidgets('produto, sacola e confirmação delegam ao template', (t) async {
      await t.pumpWidget(app([]));
      await _bombear(t, 3);
      router.go('/produto/p1');
      await _bombear(t);
      expect(find.text('TPL PRODUTO Mister Burguer'), findsOneWidget);
      router.go('/carrinho');
      await _bombear(t);
      expect(find.text('TPL CARRINHO'), findsOneWidget);
      router.go('/confirmacao?senha=247&impresso=1');
      await _bombear(t);
      expect(find.text('TPL SUCESSO 247'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });
}
