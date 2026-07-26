import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/theme/gogem_theme.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/features/catalogo/catalogo_screen.dart';
import 'fixtures.dart';

void main() {
  testWidgets('lista categorias e produtos do snapshot local', (tester) async {
    final snap = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    await tester.pumpWidget(ProviderScope(
      overrides: [menuProvider.overrideWith((ref) async => snap)],
      child: MaterialApp(theme: gogemTheme(), home: const CatalogoScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('BURGERS'), findsOneWidget);
    expect(find.text('Mister Burguer'), findsOneWidget);
    expect(find.text('R\$ 29,90'), findsOneWidget);
    expect(find.text('Esgotado Burger'), findsNothing); // indisponível some
    // troca de categoria
    await tester.tap(find.text('BEBIDAS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Refri Lata'), findsOneWidget);
  });

  testWidgets('sem snapshot → estado vazio com ação de atualizar', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [menuProvider.overrideWith((ref) async => null)],
      child: MaterialApp(theme: gogemTheme(), home: const CatalogoScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cardápio ainda não sincronizado'), findsOneWidget);
    expect(find.text('ATUALIZAR'), findsOneWidget);
  });
}
