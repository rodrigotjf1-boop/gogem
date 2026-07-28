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
    // NÃO filtrar por faixa de bytes: parâmetros de comandos ESC/POS
    // (ESC @, ESC t, ESC a) são >= 0x20 e contaminariam a "linha".
    final b = EscPosBuilder().itemValor('X', 'Y').build();
    final linhaEsperada = 'X${' ' * 40}Y'; // 1 + 40 espaços + 1 = 42 colunas
    expect(String.fromCharCodes(b), contains('$linhaEsperada\n'));
    // nome+valor maiores que a largura: degrada para separador simples
    final b2 = EscPosBuilder().itemValor('A' * 30, 'B' * 20).build();
    expect(String.fromCharCodes(b2), contains('${'A' * 30} ${'B' * 20}'));
  });
}
