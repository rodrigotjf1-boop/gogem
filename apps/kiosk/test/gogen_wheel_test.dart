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
}
