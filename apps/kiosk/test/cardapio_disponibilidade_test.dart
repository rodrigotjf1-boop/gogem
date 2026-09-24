import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';

/// O cardápio que o cliente VÊ: retrato publicado + disponibilidade (ERR-017, 024, 025).
Map<String, dynamic> _corpo({
  bool produtoDisponivel = true,
  bool baconDisponivel = true,
  Object? max = 3,
  bool obrigatorio = false,
}) =>
    {
      'versao': 5,
      'snapshot': {
        'categorias': [
          {'id': 'c1', 'nome': 'Lanches'},
          {'id': 'c2', 'nome': 'Bebidas'},
        ],
        'produtos': [
          {
            'id': 'p1',
            'categoriaId': 'c1',
            'nome': 'X-Burger',
            'precoCentavos': 2990,
            'disponivel': produtoDisponivel,
            'externalRefs': [
              {'sistema': 'regem', 'codigo_pdv': 'P1'}
            ],
            'grupos': [
              {
                'id': 'g1',
                'nome': 'Adicionais',
                'min': 0,
                'max': max,
                'obrigatorio': obrigatorio,
                'opcoes': [
                  {
                    'id': 'bacon',
                    'nome': 'Bacon',
                    'precoCentavosDelta': 400,
                    'disponivel': baconDisponivel,
                    'externalRefs': [],
                  },
                  {
                    'id': 'cheddar',
                    'nome': 'Cheddar',
                    'precoCentavosDelta': 300,
                    'disponivel': true,
                    'externalRefs': [],
                  },
                  {
                    'id': 'ovo',
                    'nome': 'Ovo',
                    'precoCentavosDelta': 200,
                    'disponivel': true,
                    'externalRefs': [],
                  },
                ],
              }
            ],
          },
          {
            'id': 'p2',
            'categoriaId': 'c2',
            'nome': 'Refri',
            'precoCentavos': 700,
            'disponivel': true,
            'externalRefs': [
              {'sistema': 'regem', 'codigo_pdv': 'P2'}
            ],
            'grupos': [],
          },
        ],
      },
    };

MenuSnapshot _menu(Map<String, dynamic> corpo, [Disponibilidade? d]) =>
    MenuSnapshot.fromPublicadoJson(corpo).aplicarDisponibilidade(d);

List<String> _opcoes(MenuSnapshot m) =>
    [for (final o in m.porId('p1')!.grupos.single.opcoes) o.id];

void main() {
  group('ERR-024 — opção indisponível', () {
    test('opção pausada no painel NÃO é oferecida', () {
      final m = _menu(_corpo(baconDisponivel: false));
      expect(_opcoes(m), ['cheddar', 'ovo']);
    });

    test('etapa obrigatória sem opções suficientes tira o produto da venda', () {
      final corpo = _corpo(obrigatorio: true);
      const d =
          Disponibilidade(opcoesIndisponiveis: {'bacon', 'cheddar', 'ovo'});
      final m = _menu(corpo, d);
      expect(m.porId('p1')!.disponivel, isFalse);
      expect(m.produtosDa('c1'), isEmpty);
    });
  });

  group('ERR-025 — grupo sem limite', () {
    test('max nulo vira o número de opções (não 1)', () {
      final g = _menu(_corpo(max: null)).porId('p1')!.grupos.single;
      expect(g.max, 3);
      expect(selecaoValida(g, g.opcoes.take(2).toList()), isTrue);
    });

    test('max numérico continua valendo', () {
      final g = _menu(_corpo(max: 1)).porId('p1')!.grupos.single;
      expect(g.max, 1);
    });
  });

  group('ERR-017 — disponibilidade ao vivo por cima do retrato', () {
    test('pausado AGORA (depois de publicar) sai da venda', () {
      final m = _menu(_corpo(),
          const Disponibilidade(produtosIndisponiveis: {'p1'}));
      expect(m.porId('p1')!.disponivel, isFalse);
      expect(m.produtosDa('c1'), isEmpty);
    });

    test('despausado AGORA volta à venda sem publicar', () {
      final m = _menu(_corpo(produtoDisponivel: false), const Disponibilidade());
      expect(m.porId('p1')!.disponivel, isTrue);
    });

    test('categoria pausada agora some com os produtos dela', () {
      final m = _menu(
          _corpo(), const Disponibilidade(categoriasPausadas: {'c2'}));
      expect(m.categorias.map((c) => c.id), ['c1']);
      expect(m.porId('p2'), isNull);
    });

    test('opção pausada agora sai; despausada volta', () {
      final pausada = _menu(
          _corpo(), const Disponibilidade(opcoesIndisponiveis: {'cheddar'}));
      expect(_opcoes(pausada), ['bacon', 'ovo']);
      final volta =
          _menu(_corpo(baconDisponivel: false), const Disponibilidade());
      expect(_opcoes(volta), ['bacon', 'cheddar', 'ovo']);
    });

    test('sem disponibilidade (servidor da loja): vale o retrato', () {
      final m = _menu(_corpo(produtoDisponivel: false));
      expect(m.porId('p1')!.disponivel, isFalse);
    });

    test('Disponibilidade.fromJson: ausente ou inválida = null', () {
      expect(Disponibilidade.fromJson(null), isNull);
      expect(Disponibilidade.fromJson('x'), isNull);
      final d = Disponibilidade.fromJson({
        'produtosIndisponiveis': ['p1'],
        'categoriasPausadas': [],
        'opcoesIndisponiveis': ['o1'],
      })!;
      expect(d.produtosIndisponiveis, {'p1'});
      expect(d.opcoesIndisponiveis, {'o1'});
    });
  });
}
