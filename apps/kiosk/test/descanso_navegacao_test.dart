import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/app.dart';

void main() {
  testWidgets('descanso -> toque abre catálogo', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GogemKioskApp()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TOQUE PARA PEDIR'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900)); // toque no centro (fora do canto admin)
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('MONTE SEU PEDIDO'), findsOneWidget);
  });

  testWidgets('5 toques no canto abrem o portão admin com teclado embaralhado',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GogemKioskApp()));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('ACESSO RESTRITO'), findsOneWidget);
    // 10 teclas 0-9 presentes (ordem embaralhada)
    for (var n = 0; n < 10; n++) {
      expect(find.byKey(ValueKey('k$n')), findsOneWidget);
    }
  });
}
