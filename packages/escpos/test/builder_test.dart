import 'package:gogem_escpos/escpos.dart';
import 'package:test/test.dart';

void main() {
  test('builder: init, cp850, acentos, corte', () {
    final b = EscPosBuilder()
        .texto('PÃO COM AÇÚCAR', negrito: true, tamanho: 2, centro: true)
        .itemValor('1x Refri', 'R\$ 7,00')
        .corte()
        .build();
    // começa com ESC @ e ESC t 2
    expect(b.sublist(0, 2), [0x1B, 0x40]);
    expect(b.sublist(2, 5), [0x1B, 0x74, 0x02]);
    // Ã (0xC7) e Ç (0x80) mapeados em CP850, nada de '?' para eles
    expect(b, contains(0xC7));
    expect(b, contains(0x80));
    // termina com feed + corte GS V
    expect(b.sublist(b.length - 4), [0x1D, 0x56, 0x42, 0x10]);
  });

  test('itemValor alinha à direita em 42 colunas', () {
    final b = EscPosBuilder().itemValor('X', 'Y').build();
    final linha = String.fromCharCodes(
        b.where((c) => c >= 0x20 || c == 0x0A)).split('\n').first;
    expect(linha.length, 42);
    expect(linha.startsWith('X'), isTrue);
    expect(linha.endsWith('Y'), isTrue);
  });
}
