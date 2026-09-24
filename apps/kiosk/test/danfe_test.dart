import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/printing/recibo.dart';

/// K6 — o DANFE NFC-e impresso pelo totem.
///
/// O texto vem PRONTO do Regem: o que se testa aqui é o desenho no papel. Duas coisas
/// não podem sair erradas: o QR tem de virar CÓDIGO (não endereço em texto — sem ele o
/// consumidor não consegue consultar a nota) e a contingência tem de gerar a segunda via
/// identificada, porque em contingência o papel é a prova de que a nota foi emitida.
void main() {
  const qr =
      'https://www.nfce.fazenda.rj.gov.br/consulta?p=33260900000000000191650510000000021000000029|2|1|1|ABCDEF';
  const danfe = 'DANFE NFC-e\n'
      'Serie 51 No 2\n'
      '--------------------------------\n'
      '2x X-BURGER\n'
      '   R\$ 20,00\n'
      '--------------------------------\n'
      'TOTAL: R\$ 20,00\n'
      'CONSUMIDOR NAO IDENTIFICADO\n'
      'Chave: 33260900000000000191650510000000021000000029\n'
      'Protocolo: 333260002547395\n'
      'Consulte pela chave ou pelo QR Code:\n'
      '@QR:$qr';

  test('imprime o texto do emitente linha a linha, sem reescrever nada', () {
    final txt = String.fromCharCodes(montarDanfe(danfe));
    expect(txt, contains('DANFE NFC-e\n'));
    expect(txt, contains('Serie 51 No 2\n'));
    expect(txt, contains('Chave: 33260900000000000191650510000000021000000029\n'));
    expect(txt, contains('Protocolo: 333260002547395\n'));
  });

  test('a linha @QR vira CODIGO — o marcador nao pode sair impresso', () {
    final b = montarDanfe(danfe);
    final txt = String.fromCharCodes(b);
    expect(txt, isNot(contains('@QR:')));
    // comando GS ( k de impressao do simbolo
    expect(b.join(','), contains([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30].join(',')));
    // e a URL foi para dentro do simbolo, inteira
    expect(txt, contains(qr));
  });

  test('a via do cliente NAO leva rotulo — sai igual a do caixa; e corta o papel', () {
    final b = montarDanfe(danfe);
    // O Regem imprime a via do cliente sem cabecalho nenhum (`fiscal.service.ts`). Rotular
    // aqui faria a MESMA nota sair diferente no totem e na impressora do balcao.
    expect(String.fromCharCodes(b), isNot(contains('VIA DO')));
    expect(String.fromCharCodes(b), isNot(contains('Via do')));
    expect(b.sublist(b.length - 4), [0x1D, 0x56, 0x42, 0x10]);
  });

  test('segunda via: mesmo conteudo + "VIA DO ESTABELECIMENTO" no fim, como o Regem monta',
      () {
    final loja = String.fromCharCodes(montarDanfe(danfe, viaEstabelecimento: true));
    expect(loja, contains('VIA DO ESTABELECIMENTO'));
    // Carrega o MESMO documento — a segunda via só marca quem fica com o papel.
    expect(loja, contains('Chave: 33260900000000000191650510000000021000000029'));
    // O rotulo vai no FIM, depois do separador (formato do `fiscal.service.ts`), nunca
    // como cabecalho: e assim que a nota reimpressa pela tela do Regem sai.
    expect(loja.indexOf('VIA DO ESTABELECIMENTO'),
        greaterThan(loja.indexOf('Chave: ')));
  });

  test('DANFE sem QR (nota que nao autorizou) nao quebra a impressao', () {
    final b = montarDanfe('DANFE NFC-e\nSerie 51 No 2');
    expect(String.fromCharCodes(b), contains('Serie 51 No 2\n'));
    expect(b.sublist(b.length - 4), [0x1D, 0x56, 0x42, 0x10]);
  });
}
