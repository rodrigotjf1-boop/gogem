import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/theme/gogem_theme.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart';
import 'package:gogem_kiosk/features/pedido/produto_screen.dart';
import 'fixtures.dart';

/// Fixture com grupo OBRIGATÓRIO para exercitar o bloqueio do botão.
Map<String, dynamic> comGrupoObrigatorio() {
  final f = Map<String, dynamic>.from(publicadoFixture);
  final snap = Map<String, dynamic>.from(f['snapshot'] as Map);
  final produtos = List<Map<String, dynamic>>.from(
      (snap['produtos'] as List).cast<Map<String, dynamic>>());
  produtos[0] = {
    ...produtos[0],
    'grupos': [
      {
        'id': 'gPonto',
        'nome': 'Ponto da carne',
        'min': 1,
        'max': 1,
        'obrigatorio': true,
        'opcoes': [
          {'id': 'mal', 'nome': 'Mal passado', 'precoCentavosDelta': 0, 'externalRefs': []},
          {'id': 'bem', 'nome': 'Bem passado', 'precoCentavosDelta': 0, 'externalRefs': []},
        ]
      },
      ...(produtos[0]['grupos'] as List),
    ]
  };
  snap['produtos'] = produtos;
  f['snapshot'] = snap;
  return f;
}

void main() {
  testWidgets('bloqueia ADICIONAR até o grupo obrigatório e soma delta ao vivo',
      (tester) async {
    final snap = MenuSnapshot.fromPublicadoJson(comGrupoObrigatorio());
    await tester.pumpWidget(ProviderScope(
      overrides: [menuProvider.overrideWith((ref) async => snap)],
      child: MaterialApp(
          theme: gogemTheme(), home: const ProdutoScreen(produtoId: 'p1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    FilledButton btn() =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('adicionar')));
    expect(btn().onPressed, isNull); // obrigatório pendente
    expect(find.text('ADICIONAR · R\$ 29,90'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('op-mal')));
    await tester.pump();
    expect(btn().onPressed, isNotNull); // liberado

    await tester.tap(find.byKey(const ValueKey('op-o1'))); // Bacon +4,00
    await tester.pump();
    expect(find.text('ADICIONAR · R\$ 33,90'), findsOneWidget);

    // max=1 age como rádio: trocar o ponto não desabilita
    await tester.tap(find.byKey(const ValueKey('op-bem')));
    await tester.pump();
    expect(btn().onPressed, isNotNull);
  });
}
