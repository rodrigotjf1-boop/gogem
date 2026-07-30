import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/util/cpf.dart';
import 'package:gogem_kiosk/data/catalog/catalog_models.dart';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'fixtures.dart';

void main() {
  final menu = MenuSnapshot.fromPublicadoJson(publicadoFixture);
  final burger = menu.produtos.first; // 2990, grupo Adicionais 0..3, Bacon +400

  test('preço unitário soma deltas e total multiplica quantidade', () {
    final bacon = burger.grupos.single.opcoes.single;
    final item = ItemCarrinho(
        produto: burger, selecoes: {'g1': [bacon]}, quantidade: 2);
    expect(item.precoUnitarioCentavos, 3390);
    expect(item.totalCentavos, 6780);
  });

  test('validação de grupos: min/max e obrigatorio', () {
    const g = GrupoComplemento(
        id: 'x', nome: 'Ponto', min: 0, max: 1, obrigatorio: true, opcoes: []);
    expect(minEfetivo(g), 1); // obrigatorio com min 0 exige 1
    expect(selecaoValida(g, const []), isFalse);
    final op = burger.grupos.single.opcoes.single;
    expect(selecaoValida(g, [op]), isTrue);
    final livre = burger.grupos.single; // min 0 max 3
    expect(selecaoValida(livre, const []), isTrue);
    expect(selecaoValida(livre, [op, op, op]), isTrue);
    expect(selecaoValida(livre, [op, op, op, op]), isFalse);
  });

  test('PedidoLocal.toJson emite o VendaTotemDto (codigo_pdv, pagamentos, '
      'consumo) e UUID v4', () {
    final bacon = burger.grupos.single.opcoes.single;
    final p = PedidoLocal(
        itens: [ItemCarrinho(produto: burger, selecoes: {'g1': [bacon]})],
        forma: FormaPagamento.pix,
        cpf: '52998224725',
        consumo: 'viagem');
    final j = p.toJson(senhaLocal: 7);
    // idempotência canônica + tipo de consumo.
    expect(j['idempotencyKey'], p.uuid);
    expect(j['consumo'], 'viagem');
    expect(j['senhaLocal'], 7);
    expect(j['cpf'], '52998224725');
    // produto vira 1ª linha; opção COM código PDV vira linha vendável separada.
    expect(j['itens'][0]['codigoPdv'], '101');
    expect(j['itens'][0]['quantidade'], 1);
    expect(j['itens'][1]['codigoPdv'], '201');
    // pagamento único no split, valor em CENTAVOS (produto 2990 + bacon 400).
    expect(j['pagamentos'][0]['forma'], 'pix');
    expect(j['pagamentos'][0]['valor'], 3390);
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(p.uuid),
        isTrue);
    expect(p.uuid[14], '4'); // versão 4
  });

  test('cpfValido: DV correto, repetidos e tamanho', () {
    expect(cpfValido('52998224725'), isTrue);
    expect(cpfValido('529.982.247-25'), isTrue);
    expect(cpfValido('11111111111'), isFalse);
    expect(cpfValido('52998224724'), isFalse);
    expect(cpfValido('123'), isFalse);
    expect(formatCpf('52998224725'), '529.982.247-25');
  });
}
