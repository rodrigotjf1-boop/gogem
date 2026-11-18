import 'package:gogem_escpos/escpos.dart';
import 'package:test/test.dart';

/// ERR-043: no totem (TM-T88VII em Printer Class) o DLE EOT se desloca pela via de
/// dados — a resposta do "estado da impressora" (0x16: bit 2 = pino da gaveta) é
/// lida como a "causa de offline" e vira "tampa aberta", duas vezes seguidas. O
/// status da PORTA (GET_PORT_STATUS, canal de controle) não se desloca e decide.
List<int> eotsEscritos(FakeTransport t) => t.escritos
    .where((b) => b.length == 3 && b[0] == 0x10 && b[1] == 0x04)
    .map((b) => b[2])
    .toList();

void main() {
  group('StatusDaPorta', () {
    test('0x18 = online e sem erro, com papel → pronta', () {
      const p = StatusDaPorta(0x18);
      expect(p.valido, isTrue);
      expect(p.pronta, isTrue);
    });
    // ERR-049: o totem .19 lia 0x38 com papel no rolo (o app da Epson: "Papel:
    // Definir"; o teste de impressão saiu) — o PE com a impressora online é o
    // sensor de QUASE-FIM. Fim de papel de verdade deixa a impressora offline.
    test('0x38 = online, sem erro e PE → pronta, papel acabando (não bloqueia)', () {
      const p = StatusDaPorta(0x38);
      expect(p.semPapel, isTrue);
      expect(p.pronta, isTrue);
      expect(p.papelAcabando, isTrue);
    });
    test('0x20 = PE com a impressora offline e com erro → fim de papel, não pronta', () {
      const p = StatusDaPorta(0x20);
      expect(p.pronta, isFalse);
      expect(p.papelAcabando, isFalse);
    });
    test('0x10 = online com erro (tampa) → não pronta', () {
      expect(const StatusDaPorta(0x10).pronta, isFalse);
    });
    test('bit reservado ligado → leitura errada, não vale', () {
      expect(const StatusDaPorta(0xFF).valido, isFalse);
      expect(const StatusDaPorta(0x1C).valido, isFalse);
    });
  });

  group('consultarStatus com a porta (Printer Class)', () {
    test('SEM a porta, o DLE EOT deslocado inventa "tampa aberta" (o defeito do campo)',
        () async {
      final t = FakeTransport()..filaDleEot.addAll([0x12, 0x16, 0x12, 0x12]);
      final s = await EpsonT88(t).consultarStatus();
      expect(s.tampaAberta, isTrue);
      expect(s.prontaParaVenda, isFalse);
    });

    test('porta pronta + DLE EOT deslocado → PRONTA (a tampa falsa não bloqueia)', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..filaDleEot.addAll([0x16, 0x16, 0x16, 0x16]);
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isTrue);
      expect(s.tampaAberta, isFalse);
      // Com a porta pronta, do DLE EOT só sai a pergunta do papel (aviso).
      expect(eotsEscritos(t), [4]);
    });

    test('tampa aberta DE VERDADE: a porta acusa e o DLE EOT dá o motivo', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..tampaAberta = true;
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isFalse);
      expect(s.motivoBloqueio, 'tampa aberta');
    });

    test('porta sem papel e DLE EOT dizendo "pronta" → vale a porta (bloqueia)', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0x30; // online, com erro, sem papel
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isFalse);
      expect(s.motivoBloqueio, 'sem papel');
    });

    test('ERR-049: porta 0x38 (quase-fim) e DLE EOT sem fim de papel → VENDE com o aviso',
        () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0x38
        ..pertoDoFim = true; // DLE EOT 4 = 0x0C (quase no fim), sem os bits de fim
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isTrue);
      expect(s.pertoDoFim, isTrue);
    });

    test('ERR-049: porta 0x38 e DLE EOT mudo → vende com o aviso (a porta diz online)',
        () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0x38
        ..dleEotMudo = true;
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isTrue);
      expect(s.pertoDoFim, isTrue);
    });

    test('ERR-049: porta 0x38 mas o DLE EOT 4 diz FIM de papel → bloqueia', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0x38
        ..semPapel = true; // DLE EOT 4 = 0x60
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isFalse);
      expect(s.motivoBloqueio, 'sem papel');
    });

    test('fim de papel de verdade (porta 0x20: PE, offline, erro) → bloqueia sem papel',
        () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..semPapel = true; // o fake responde 0x20 na porta
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isFalse);
      expect(s.motivoBloqueio, 'sem papel');
    });

    test('porta offline e DLE EOT mudo → bloqueia como offline', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0x00
        ..dleEotMudo = true;
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isFalse);
      expect(s.motivoBloqueio, 'impressora offline');
    });

    test('porta pronta e DLE EOT mudo → pronta (não trava por byte que não voltou)', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..dleEotMudo = true;
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isTrue);
      expect(s.pertoDoFim, isFalse);
    });

    test('papel acabando: aviso pelo DLE EOT 4 com duas leituras seguidas, sem bloquear',
        () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..pertoDoFim = true;
      final d = EpsonT88(t);
      final primeira = await d.consultarStatus();
      expect(primeira.pertoDoFim, isFalse);
      final segunda = await d.consultarStatus();
      expect(segunda.pertoDoFim, isTrue);
      expect(segunda.prontaParaVenda, isTrue);
    });

    test('byte deslocado UMA vez no DLE EOT 4 não acende "papel acabando"', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..filaDleEot.add(0x16);
      final d = EpsonT88(t);
      expect((await d.consultarStatus()).pertoDoFim, isFalse);
      expect((await d.consultarStatus()).pertoDoFim, isFalse); // a 2ª lê 0x00 (estado real)
    });

    test('byte da porta inválido → volta ao DLE EOT inteiro', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..portaForcada = 0xFF;
      final s = await EpsonT88(t).consultarStatus();
      expect(s.prontaParaVenda, isTrue);
      expect(eotsEscritos(t), [1, 2, 3, 4]);
    });

    test('imprimir(): porta pronta + DLE EOT deslocado → o cupom SAI', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..filaDleEot.addAll([0x16, 0x16, 0x16, 0x16, 0x16, 0x16, 0x16, 0x16]);
      final cupom = EscPosBuilder().texto('pedido').corte().build();
      final depois = await EpsonT88(t).imprimir(cupom);
      expect(t.tudoEscrito, contains(0x56)); // GS V do corte: o cupom foi gravado
      expect(depois.prontaParaVenda, isTrue);
    });

    test('desconectada: a porta não mascara (exceção limpa)', () async {
      final t = FakeTransport()
        ..temStatusDaPorta = true
        ..desconectada = true;
      expect(EpsonT88(t).consultarStatus(), throwsA(isA<PrinterDisconnected>()));
    });
  });
}
