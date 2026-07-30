import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'fixtures.dart';

void main() {
  test('parse do snapshot publicado', () {
    final m = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    expect(m.versao, 3);
    expect(m.categorias, hasLength(2));
    expect(m.produtos, hasLength(3));
    final p = m.produtos.first;
    expect(p.nome, 'Mister Burguer');
    expect(p.precoCentavos, 2990);
    expect(p.codigoPdvRegem, '101'); // de-para SEMPRE por codigo_pdv
    expect(p.grupos.single.opcoes.single.precoCentavosDelta, 400);
  });

  test('produtosDa filtra por categoria e disponibilidade', () {
    final m = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    final burgers = m.produtosDa('cat1');
    expect(burgers.map((p) => p.id), ['p1']); // p3 indisponível fica fora
  });

  test('upsell (F2): parse dos ids sugeridos e porId', () {
    final m = MenuSnapshot.fromPublicadoJson(publicadoFixture);
    expect(m.produtos.first.upsell, ['p2', 'p3']);
    expect(m.produtos[1].upsell, isEmpty); // sem upsell → lista vazia
    expect(m.porId('p2')?.nome, 'Refri Lata');
    expect(m.porId('inexistente'), isNull);
  });

  test('parsing defensivo: campos ausentes não explodem', () {
    final m = MenuSnapshot.fromPublicadoJson(const {
      'versao': 1,
      'snapshot': {
        'categorias': [
          {'id': 7, 'nome': 'X'}
        ],
        'produtos': [
          {'id': 9, 'nome': 'Solto'}
        ]
      }
    });
    expect(m.categorias.single.id, '7');
    expect(m.produtos.single.precoCentavos, 0);
    expect(m.produtos.single.disponivel, isTrue);
  });
}
