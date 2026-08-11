import 'dart:async';
import 'dart:typed_data';
import 'commands.dart';
import 'printer_driver.dart';
import 'status.dart';
import 'transport.dart';

/// Driver Epson TM-T88 (e compatíveis ESC/POS).
/// Toda a lógica dos PORTÕES do fluxo mora aqui:
///  - [consultarStatus]: DLE EOT 1/2/3/4 síncrono — usado ANTES do pagamento;
///  - [habilitarAsb] + [statusStream]: eventos espontâneos (papel/tampa);
///  - [imprimir]: consulta antes, grava, e reconsulta depois (fim de papel
///    DURANTE a impressão é detectado e reportado).
class EpsonT88 implements PrinterDriver {
  EpsonT88(this._t);
  final PrinterTransport _t;

  @override
  Future<void> conectar() => _t.open();
  @override
  Future<void> desconectar() => _t.close();

  Future<int> _eot(int n) async {
    await _t.write(Cmd.dleEot(n));
    final r = await _t.read(1, timeout: const Duration(seconds: 2));
    if (r.isEmpty) throw const PrinterTimeout();
    return r[0];
  }

  @override
  Future<PrinterStatus> consultarStatus() async => PrinterStatus.fromDleEot(
        printer: await _eot(Cmd.eotPrinter),
        offlineCause: await _eot(Cmd.eotOffline),
        error: await _eot(Cmd.eotError),
        paper: await _eot(Cmd.eotPaper),
      );

  @override
  Future<void> habilitarAsb() => _t.write(Cmd.asbOn);

  @override
  Stream<PrinterStatus> get statusStream =>
      _t.incoming.where((b) => b.length >= 4).map(PrinterStatus.fromAsb);

  /// Resultado da impressão com o status pós-escrita.
  @override
  Future<PrinterStatus> imprimir(Uint8List cupom) async {
    final antes = await consultarStatus();
    if (!antes.prontaParaVenda) return antes; // portão: não grava nada
    await _t.write(cupom);
    return consultarStatus(); // near-end/fim durante a impressão aparece aqui
  }
}
