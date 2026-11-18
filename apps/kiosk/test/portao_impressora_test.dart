import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:gogem_kiosk/printing/printer_providers.dart';

/// ERR-043 — pela USB a leitura de status às vezes volta com byte deslocado e acusa
/// "tampa aberta" que não existe: o totem recusava o pagamento ("Não é possível pagar
/// agora — tampa aberta") até o cliente tocar "Tentar novamente". O portão só bloqueia
/// com a acusação CONFIRMADA por uma segunda leitura.
class _DriverDeLeituras implements PrinterDriver {
  _DriverDeLeituras(this.leituras);

  /// Cada leitura: um [PrinterStatus] ou o erro que ela lança.
  final List<Object> leituras;
  int lidas = 0;

  @override
  Future<PrinterStatus> consultarStatus() async {
    final r = leituras[lidas++];
    if (r is PrinterStatus) return r;
    throw r;
  }

  @override
  Future<void> conectar() async {}
  @override
  Future<void> desconectar() async {}
  @override
  Future<void> habilitarAsb() async {}
  @override
  Stream<PrinterStatus> get statusStream => const Stream.empty();
  @override
  Future<PrinterStatus> imprimir(Uint8List cupom) async => const PrinterStatus();
}

ProviderContainer _container(_DriverDeLeituras d) => ProviderContainer(overrides: [
      printerDriverProvider.overrideWithValue(d),
      confirmacaoDaImpressoraProvider.overrideWithValue(Duration.zero),
    ]);

void main() {
  test('"tampa aberta" que a segunda leitura não confirma: libera o pagamento', () async {
    final d = _DriverDeLeituras([
      const PrinterStatus(tampaAberta: true),
      const PrinterStatus(),
    ]);
    final c = _container(d);
    addTearDown(c.dispose);

    final h = await c.read(printerHealthProvider.notifier).checarAgora();

    expect(h.prontaParaVenda, isTrue);
    expect(d.lidas, 2);
  });

  test('problema de verdade (sem papel nas duas leituras): bloqueia com o motivo', () async {
    final d = _DriverDeLeituras([
      const PrinterStatus(semPapel: true),
      const PrinterStatus(semPapel: true),
    ]);
    final c = _container(d);
    addTearDown(c.dispose);

    final h = await c.read(printerHealthProvider.notifier).checarAgora();

    expect(h.prontaParaVenda, isFalse);
    expect(h.motivo, 'sem papel');
  });

  test('a confirmação que não lê não libera: vale a primeira (regra de ouro)', () async {
    final d = _DriverDeLeituras([
      const PrinterStatus(tampaAberta: true),
      TimeoutException('timeout de leitura da impressora'),
    ]);
    final c = _container(d);
    addTearDown(c.dispose);

    final h = await c.read(printerHealthProvider.notifier).checarAgora();

    expect(h.prontaParaVenda, isFalse);
    expect(h.motivo, 'tampa aberta');
  });

  test('leitura boa de primeira: uma leitura só', () async {
    final d = _DriverDeLeituras([const PrinterStatus()]);
    final c = _container(d);
    addTearDown(c.dispose);

    final h = await c.read(printerHealthProvider.notifier).checarAgora();

    expect(h.prontaParaVenda, isTrue);
    expect(d.lidas, 1);
  });

  // ERR-048 — a impressora reiniciou (voltou com outro endereço USB): a leitura cai
  // com "desconectada", o conectar abre uma conexão nova, e o portão lê de novo por
  // ela em vez de assumir "pronta".
  group('conexão morta (a impressora reiniciou)', () {
    test('reconecta e lê de novo: voltou sem papel → bloqueia', () async {
      final d = _DriverDeLeituras([
        const PrinterDisconnected('USB write: bulkTransfer OUT falhou'),
        const PrinterStatus(semPapel: true),
      ]);
      final c = _container(d);
      addTearDown(c.dispose);

      final h = await c.read(printerHealthProvider.notifier).checarAgora();

      expect(h.prontaParaVenda, isFalse);
      expect(h.motivo, 'sem papel');
      expect(d.lidas, 2);
    });

    test('reconecta e lê de novo: voltou pronta → libera', () async {
      final d = _DriverDeLeituras([
        const PrinterDisconnected('USB write: bulkTransfer OUT falhou'),
        const PrinterStatus(),
      ]);
      final c = _container(d);
      addTearDown(c.dispose);

      final h = await c.read(printerHealthProvider.notifier).checarAgora();

      expect(h.prontaParaVenda, isTrue);
      expect(d.lidas, 2);
    });

    test('timeout comum (conexão viva) não relê: assume pronta como antes', () async {
      final d = _DriverDeLeituras([const PrinterTimeout()]);
      final c = _container(d);
      addTearDown(c.dispose);

      final h = await c.read(printerHealthProvider.notifier).checarAgora();

      expect(h.prontaParaVenda, isTrue);
      expect(d.lidas, 1);
    });
  });
}
