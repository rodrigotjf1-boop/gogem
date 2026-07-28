import 'package:gogem_escpos/escpos.dart';
import 'package:test/test.dart';

void main() {
  test('consultarStatus dispara os 4 DLE EOT e consolida', () async {
    final t = FakeTransport()..pertoDoFim = true;
    final d = EpsonT88(t);
    await d.conectar();
    final s = await d.consultarStatus();
    expect(s.pertoDoFim, isTrue);
    expect(s.prontaParaVenda, isTrue);
    // 4 consultas escritas
    final eots = t.escritos.where((b) => b.length == 3 && b[0] == 0x10).toList();
    expect(eots.map((b) => b[2]), [1, 2, 3, 4]);
  });

  test('PORTÃO: sem papel, imprimir() NÃO grava o cupom', () async {
    final t = FakeTransport()..semPapel = true;
    final d = EpsonT88(t);
    await d.conectar();
    final cupom = EscPosBuilder().texto('pedido').corte().build();
    final s = await d.imprimir(cupom);
    expect(s.semPapel, isTrue);
    // nada além dos DLE EOT foi escrito
    expect(t.escritos.every((b) => b.length == 3 && b[0] == 0x10), isTrue);
  });

  test('papel acaba DURANTE a impressão: cupom sai, status pós reporta', () async {
    final t = FakeTransport();
    final d = EpsonT88(t);
    await d.conectar();
    // pré-check (4 leituras) passa; na 4ª leitura o papel acaba —
    // exatamente o cenário que derruba o concorrente.
    var lidas = 0;
    t.aposLeitura = () {
      if (++lidas == 4) t.semPapel = true;
    };
    final cupom = EscPosBuilder().texto('pedido').corte().build();
    final depois = await d.imprimir(cupom);
    expect(depois.semPapel, isTrue); // detectado no pós-check
    expect(t.tudoEscrito, contains(0x56)); // o cupom FOI gravado (GS V do corte)
  });

  test('ASB stream converte pacotes espontâneos', () async {
    final t = FakeTransport();
    final d = EpsonT88(t);
    await d.conectar();
    await d.habilitarAsb();
    final futuro = d.statusStream.first;
    t
      ..semPapel = true
      ..emitirAsb();
    final s = await futuro;
    expect(s.semPapel, isTrue);
  });

  test('desconectada: exceção limpa', () async {
    final t = FakeTransport()..desconectada = true;
    final d = EpsonT88(t);
    expect(d.conectar(), throwsA(isA<PrinterDisconnected>()));
  });
}
