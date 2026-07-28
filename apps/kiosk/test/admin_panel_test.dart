import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/core/theme/gogem_theme.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart'
    show orderRepositoryProvider;
import 'package:gogem_kiosk/features/admin/admin_panel_screen.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart'
    show filaImpressaoProvider;
import 'package:gogem_kiosk/printing/printer_providers.dart';
import 'fakes.dart';

Future<void> bombear(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Consome o timer de auto-dismiss do SnackBar (2s) para não deixar timer
/// pendente ao fim do teste.
Future<void> consumirSnackbar(WidgetTester t) async {
  await t.pump(const Duration(seconds: 2));
  await t.pump();
}

void main() {
  testWidgets('painel: teste de impressora escreve no transporte e '
      'reimprimir drena a fila', (tester) async {
    final fila = FakeFilaImpressao();
    await fila.enfileirar('u1', '001', [0x1B, 0x40, 0x41]);
    final fake = FakeTransport();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        printerTransportProvider.overrideWithValue(fake),
        filaImpressaoProvider.overrideWith((ref) => fila),
        orderRepositoryProvider.overrideWith((ref) => FakeOrderRepository()),
      ],
      child: MaterialApp(theme: gogemTheme(), home: const AdminPanelScreen()),
    ));
    await bombear(tester);
    expect(find.text('PAINEL DO TOTEM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('acao-teste-imp')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(String.fromCharCodes(fake.tudoEscrito.where((c) => c >= 0x20)),
        contains('TESTE DE IMPRESSORA'));

    // A ListView é lazy: o botão fica abaixo da dobra em 800x600 e não é
    // construído até rolarmos até ele (ensureVisible exige o elemento já na
    // árvore; scrollUntilVisible constrói+rola).
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('acao-reimprimir')), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('acao-reimprimir')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(await fila.pendentes(), 0); // fila drenada
  });

  testWidgets('reimprimir com SEM PAPEL não remove da fila', (tester) async {
    final fila = FakeFilaImpressao();
    await fila.enfileirar('u1', '001', [0x1B, 0x40]);
    final fake = FakeTransport()..semPapel = true;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        printerTransportProvider.overrideWithValue(fake),
        filaImpressaoProvider.overrideWith((ref) => fila),
        orderRepositoryProvider.overrideWith((ref) => FakeOrderRepository()),
      ],
      child: MaterialApp(theme: gogemTheme(), home: const AdminPanelScreen()),
    ));
    await bombear(tester);
    // A ListView é lazy: o botão fica abaixo da dobra em 800x600 e não é
    // construído até rolarmos até ele (ensureVisible exige o elemento já na
    // árvore; scrollUntilVisible constrói+rola).
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('acao-reimprimir')), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('acao-reimprimir')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(await fila.pendentes(), 1); // preservado até ter papel
  });
}
