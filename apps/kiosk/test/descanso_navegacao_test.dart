import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/app.dart';

/// NOTA DE HARNESS: a tela de descanso tem animações em loop
/// (AnimationController.repeat) — NUNCA usar pumpAndSettle com ela na árvore;
/// usar pumps de duração fixa. Viewport do teste é 800x600: todo tap deve
/// mirar um finder ou coordenada dentro desses limites.
void main() {
  testWidgets('descanso -> toque abre catálogo', (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: GogemKioskApp(iniciarSync: false)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TOQUE PARA PEDIR'), findsOneWidget);

    await tester.tap(find.text('TOQUE PARA PEDIR')); // dentro do viewport
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // transição do router
    }
    expect(find.text('MONTE SEU PEDIDO'), findsOneWidget);
  });

  testWidgets('5 toques no canto abrem o portão admin com teclado embaralhado',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: GogemKioskApp(iniciarSync: false)));
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(40, 40)); // canto sup. esq. (in-bounds)
      await tester.pump(const Duration(milliseconds: 80));
    }
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('ACESSO RESTRITO'), findsOneWidget);
    for (var n = 0; n < 10; n++) {
      expect(find.byKey(ValueKey('k' + n.toString())), findsOneWidget);
    }
  });
}
