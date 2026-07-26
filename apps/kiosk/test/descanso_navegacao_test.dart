import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/app.dart';

void main() {
  // A tela de descanso tem uma animação idle PERPÉTUA (`..repeat()`), então
  // NÃO se pode usar `pumpAndSettle` (ela nunca "assenta" → timeout). Usar
  // `pump(Duration)` explícito. E o totem é retrato grande: dimensionar a
  // superfície (o padrão de teste é 800x600, que deixaria toques fora da tela).
  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: GogemKioskApp()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('descanso -> toque abre catálogo', (tester) async {
    await montar(tester);
    expect(find.text('TOQUE PARA PEDIR'), findsOneWidget);
    await tester.tapAt(const Offset(540, 1200)); // centro (fora do canto admin)
    await tester.pump(); // processa o toque
    await tester.pump(const Duration(milliseconds: 500)); // transição do go_router
    expect(find.text('MONTE SEU PEDIDO'), findsOneWidget);
  });

  testWidgets('5 toques no canto abrem o portão admin com teclado embaralhado',
      (tester) async {
    await montar(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 500)); // transição p/ /admin
    expect(find.text('ACESSO RESTRITO'), findsOneWidget);
    // 10 teclas 0-9 presentes (ordem embaralhada)
    for (var n = 0; n < 10; n++) {
      expect(find.byKey(ValueKey('k$n')), findsOneWidget);
    }
  });
}
