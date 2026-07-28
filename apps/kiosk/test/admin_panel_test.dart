import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'db_helper.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/core/theme/gogem_theme.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart' show databaseProvider;
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'package:gogem_kiosk/features/admin/admin_panel_screen.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';
import 'package:gogem_kiosk/printing/printer_providers.dart';

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
    final db = await novaDbMemoria();
    final fila = FilaImpressao(db);
    await fila.enfileirar('u1', '001', [0x1B, 0x40, 0x41]);
    final fake = FakeTransport();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        printerTransportProvider.overrideWithValue(fake),
        databaseProvider.overrideWith((ref) async => db),
        filaImpressaoProvider.overrideWith((ref) async => fila),
        orderRepositoryProvider
            .overrideWith((ref) async => OrderRepository(db)),
      ],
      child: MaterialApp(theme: gogemTheme(), home: const AdminPanelScreen()),
    ));
    await bombear(tester);
    expect(find.text('PAINEL DO TOTEM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('acao-teste-imp')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(
        String.fromCharCodes(fake.tudoEscrito.where((c) => c >= 0x20)),
        contains('TESTE DE IMPRESSORA'));

    await tester.ensureVisible(find.byKey(const ValueKey('acao-reimprimir')));
    await tester.tap(find.byKey(const ValueKey('acao-reimprimir')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(await fila.pendentes(), 0); // fila drenada
  });

  testWidgets('reimprimir com SEM PAPEL não remove da fila', (tester) async {
    final db = await novaDbMemoria();
    final fila = FilaImpressao(db);
    await fila.enfileirar('u1', '001', [0x1B, 0x40]);
    final fake = FakeTransport()..semPapel = true;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        printerTransportProvider.overrideWithValue(fake),
        databaseProvider.overrideWith((ref) async => db),
        filaImpressaoProvider.overrideWith((ref) async => fila),
        orderRepositoryProvider
            .overrideWith((ref) async => OrderRepository(db)),
      ],
      child: MaterialApp(theme: gogemTheme(), home: const AdminPanelScreen()),
    ));
    await bombear(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('acao-reimprimir')));
    await tester.tap(find.byKey(const ValueKey('acao-reimprimir')));
    await bombear(tester);
    await consumirSnackbar(tester);
    expect(await fila.pendentes(), 1); // preservado até ter papel
  });
}
