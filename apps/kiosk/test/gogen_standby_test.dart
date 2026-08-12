import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/features/gogen/gogen_standby.dart';

Future<void> _pump(WidgetTester t, {bool anima = false, String? nome, String? isca}) {
  return t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: GogenStandby(
        nomeLoja: nome,
        chamada: 'Toque para pedir',
        precoIsca: isca,
        anima: anima,
      ),
    ),
  ));
}

void main() {
  testWidgets('standby GoGen mostra nome da loja, chamada e CTA', (t) async {
    await _pump(t, nome: 'Brasa Burger', isca: 'a partir de R\$ 19,90');
    await t.pump();
    expect(find.text('Brasa Burger'), findsOneWidget);
    expect(find.text('TOQUE PARA PEDIR'), findsOneWidget); // ShaderMask usa upper
    expect(find.text('Toque para começar'), findsOneWidget);
    expect(find.text('a partir de R\$ 19,90'), findsOneWidget);
  });

  testWidgets('com anima=false não deixa timers pendentes (brasas off)', (t) async {
    await _pump(t, anima: false, nome: 'Sem Anim');
    await t.pump(const Duration(seconds: 1));
    // Se houvesse AnimationController em repeat, o teste falharia por timer vivo.
    expect(find.text('Sem Anim'), findsOneWidget);
  });
}
