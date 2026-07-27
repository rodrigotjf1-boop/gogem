import 'package:gogem_escpos/escpos.dart';
import 'package:test/test.dart';

void main() {
  test('DLE EOT: máscaras de papel/tampa/offline', () {
    final ok = PrinterStatus.fromDleEot(printer: 0, offlineCause: 0, error: 0, paper: 0);
    expect(ok.prontaParaVenda, isTrue);
    expect(ok.motivoBloqueio, isNull);

    final semPapel = PrinterStatus.fromDleEot(printer: 0x08, offlineCause: 0x20, error: 0, paper: 0x60);
    expect(semPapel.semPapel, isTrue);
    expect(semPapel.online, isFalse);
    expect(semPapel.prontaParaVenda, isFalse);
    expect(semPapel.motivoBloqueio, 'sem papel');

    final tampa = PrinterStatus.fromDleEot(printer: 0, offlineCause: 0x04, error: 0, paper: 0);
    expect(tampa.tampaAberta, isTrue);
    expect(tampa.motivoBloqueio, 'tampa aberta');

    final nearEnd = PrinterStatus.fromDleEot(printer: 0, offlineCause: 0, error: 0, paper: 0x0C);
    expect(nearEnd.pertoDoFim, isTrue);
    expect(nearEnd.prontaParaVenda, isTrue); // near-end NÃO bloqueia venda
  });

  test('ASB: 4 bytes espontâneos', () {
    final s = PrinterStatus.fromAsb([0x20, 0, 0x0C, 0]);
    expect(s.tampaAberta, isTrue);
    expect(s.semPapel, isTrue);
    final n = PrinterStatus.fromAsb([0x00, 0, 0x01, 0]);
    expect(n.pertoDoFim, isTrue);
    expect(n.prontaParaVenda, isTrue);
  });
}
