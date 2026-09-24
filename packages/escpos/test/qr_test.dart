import 'package:gogem_escpos/escpos.dart';
import 'package:test/test.dart';

/// K6 — o QR do DANFE NFC-e. Este QR é a única forma de o consumidor conferir a nota
/// na SEFAZ; se sair errado, o papel vira decoração. Os bytes são os MESMOS que o
/// servidor da loja já emite (`backend/edge/escpos.mjs`), de propósito: a mesma nota
/// tem de sair igual no totem e na impressora do caixa.
void main() {
  // Tamanho real de uma URL de consulta de NFC-e (base + chave de 44 + hash de 40).
  const url =
      'https://www.homologacao.nfce.fazenda.rj.gov.br/consulta?p=33260900000000000191650510000000021000000029|2|2|1|A1B2C3D4E5F60718293A4B5C6D7E8F9012345678';

  List<int> semPrefixo(List<int> b) => b.sublist(5); // tira ESC @ + ESC t 2

  test('emite modelo 2, modulo 6, correcao M, dados e impressao — nesta ordem', () {
    final b = semPrefixo(EscPosBuilder().qr(url).build());
    final txt = b.join(',');
    // modelo 2
    expect(txt, contains([0x1D, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0x00].join(',')));
    // tamanho do modulo = 6
    expect(txt, contains([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x43, 6].join(',')));
    // correcao M (0x31), exigida pelo Manual do DANFE NFC-e
    expect(txt, contains([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x45, 0x31].join(',')));
    // imprime por ultimo
    final imprime = [0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30].join(',');
    expect(txt.indexOf(imprime), greaterThan(txt.indexOf('49,80,48')));
  });

  test('o comprimento dos dados vai em pL/pH (k+3), senao a impressora corta a URL', () {
    final b = EscPosBuilder().qr(url).build();
    final i = _acharDados(b);
    expect(i, isNot(-1), reason: 'bloco de dados nao encontrado');
    final len = b[i - 5] + (b[i - 4] << 8); // pL + pH*256, logo antes de 49,80,48
    expect(len, url.length + 3);
    // A URL chega inteira: uma URL truncada leva a uma consulta que nao existe.
    expect(String.fromCharCodes(b.sublist(i, i + url.length)), url);
  });

  test('URL de NFC-e passa dos 255 bytes: pH tem de ser usado', () {
    final longa = 'https://x/consulta?p=${'A' * 300}';
    final b = EscPosBuilder().qr(longa).build();
    final i = _acharDados(b);
    expect(b[i - 4], greaterThan(0), reason: 'pH zerado trunca dados > 255 bytes');
    expect(b[i - 5] + (b[i - 4] << 8), longa.length + 3);
  });

  test('o QR sai CENTRALIZADO e o alinhamento volta para a esquerda depois', () {
    final b = EscPosBuilder().qr(url).texto('depois').build().join(',');
    final centro = [0x1B, 0x61, 0x01].join(',');
    final esq = [0x1B, 0x61, 0x00].join(',');
    expect(b.indexOf(centro), greaterThan(-1));
    expect(b.indexOf(esq, b.indexOf(centro)), greaterThan(b.indexOf(centro)));
  });

  test('dados vao em ASCII puro — nao passam pelo mapa CP850', () {
    // Se a URL passasse pelo mapa de acentos, um byte >= 0x80 viraria '?' (0x3F) e o
    // QR apontaria para um endereco inexistente.
    final b = EscPosBuilder().qr('https://a/b?p=1').build();
    final i = _acharDados(b);
    expect(String.fromCharCodes(b.sublist(i, i + 15)), 'https://a/b?p=1');
  });

  test('QR vazio nao emite comando nenhum (nota sem qrcode nao quebra a impressao)', () {
    final vazio = EscPosBuilder().qr('').build();
    final base = EscPosBuilder().build();
    expect(vazio, base);
  });
}

/// Índice do primeiro byte dos DADOS (logo após `49,80,48` da função 180).
int _acharDados(List<int> b) {
  for (var i = 0; i + 8 < b.length; i++) {
    if (b[i] == 0x1D &&
        b[i + 1] == 0x28 &&
        b[i + 2] == 0x6B &&
        b[i + 5] == 0x31 &&
        b[i + 6] == 0x50 &&
        b[i + 7] == 0x30) {
      return i + 8;
    }
  }
  return -1;
}
