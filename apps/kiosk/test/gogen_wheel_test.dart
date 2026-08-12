import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/aparencia.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/features/gogen/gogen_category_wheel.dart';
import 'package:gogem_kiosk/features/gogen/gogen_tokens.dart';

const _cats = [
  Categoria(id: 'c1', nome: 'Promoções'),
  Categoria(id: 'c2', nome: 'Combos'),
  Categoria(id: 'c3', nome: 'Burgers'),
  Categoria(id: 'c4', nome: 'Bebidas'),
];

Future<void> _pump(WidgetTester t, {required ValueChanged<String> onSel, String sel = 'c1'}) {
  return t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: GogenCategoryWheel(
          categorias: _cats,
          selecionadaId: sel,
          onSelecionar: onSel,
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('roleta renderiza os rótulos das categorias visíveis', (t) async {
    await _pump(t, onSel: (_) {});
    await t.pump();
    // A categoria central e as vizinhas ficam visíveis.
    expect(find.text('Promoções'), findsOneWidget);
    expect(find.text('Combos'), findsOneWidget);
  });

  testWidgets('arrastar uma posição seleciona a próxima categoria ao assentar', (t) async {
    String? escolhido;
    await _pump(t, onSel: (id) => escolhido = id);
    await t.pump();
    // Arrasta pra esquerda um espaçamento (208px) → avança um item → c2.
    await t.drag(find.byType(GogenCategoryWheel), const Offset(-208, 0));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(escolhido, 'c2');
  });

  test('emoji por palavra-chave da categoria', () {
    expect(gogenEmojiCategoria('Promoções'), '🔥');
    expect(gogenEmojiCategoria('Combos'), '🍟');
    expect(gogenEmojiCategoria('Smash Burgers'), '🍔');
    expect(gogenEmojiCategoria('Bebidas geladas'), '🥤');
    expect(gogenEmojiCategoria('Algo qualquer'), '🍽️');
  });

  test('preset gogen só liga com temaPreset=gogen', () {
    expect(Aparencia.fromJson({'temaPreset': 'gogen'}).gogen, isTrue);
    expect(Aparencia.fromJson({'temaPreset': 'brasa'}).gogen, isFalse);
    expect(Aparencia.padrao.gogen, isFalse);
  });

  test('Categoria.fromJson parseia arte (imagem/emoji/cor)', () {
    final c = Categoria.fromJson({
      'id': 'c9',
      'nome': 'Tacos',
      'imagemUrl': 'https://x/y.png',
      'emoji': '🌮',
      'cor': '#E03A2F',
    });
    expect(c.imagemUrl, 'https://x/y.png');
    expect(c.emoji, '🌮');
    expect(c.cor, '#E03A2F');
    // Ausentes = null (cai no emoji por palavra-chave no render).
    final vazio = Categoria.fromJson({'id': 'c0', 'nome': 'X'});
    expect(vazio.imagemUrl, isNull);
    expect(vazio.emoji, isNull);
    expect(vazio.cor, isNull);
  });

  testWidgets('roleta usa o emoji próprio da categoria quando definido', (t) async {
    const cats = [
      Categoria(id: 'c1', nome: 'Tacos', emoji: '🌮'),
      Categoria(id: 'c2', nome: 'Bebidas'),
    ];
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: GogenCategoryWheel(
            categorias: cats,
            selecionadaId: 'c1',
            onSelecionar: _noop,
          ),
        ),
      ),
    ));
    await t.pump();
    expect(find.text('🌮'), findsOneWidget); // emoji da categoria, não o do nome
  });
}

void _noop(String _) {}
