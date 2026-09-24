import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/hardware/hardware_profile.dart';
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

  // ERR-018 — "Animações: reduzido" no painel não tinha efeito nenhum no totem.
  testWidgets('particulas=false: sem brasas, mesmo com animação ligada', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GogenStandby(chamada: 'Toque', anima: true, particulas: false),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint && '${w.painter.runtimeType}' == '_BrasasPainter'),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox()); // desmonta: para as animações
  });

  testWidgets('particulas=true (cheio): as brasas aparecem', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: GogenStandby(chamada: 'Toque', anima: true)),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint && '${w.painter.runtimeType}' == '_BrasasPainter'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
  });

  test('HardwareCaps.reduzidas: sem partículas e movimento a 60%', () {
    final r = HardwareCaps.high.reduzidas;
    expect(r.enableParticles, isFalse);
    expect(r.animationScale, 0.6);
    expect(HardwareCaps.low.reduzidas.animationScale, 0.6);
  });
}
