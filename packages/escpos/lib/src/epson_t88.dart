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

  /// Status para os portões. Com a porta USB legível (Printer Class), ELA decide
  /// se a impressora está pronta (ERR-043): o DLE EOT se desloca pela via de dados
  /// e inventava "tampa aberta". Porta pronta → pronta; do DLE EOT sai só o
  /// "papel acabando" (aviso, nunca bloqueia). Porta com problema → o DLE EOT só
  /// DETALHA o motivo (tampa × papel); se ele não ler ou disser "pronta", vale a
  /// porta (bloqueia). Sem a porta (Vendor Class, Windows), o DLE EOT de sempre.
  @override
  Future<PrinterStatus> consultarStatus() async {
    final porta = await _porta();
    if (porta == null) return _consultarDleEot();
    if (porta.pronta) {
      return PrinterStatus(pertoDoFim: await _pertoDoFim());
    }
    try {
      final detalhe = await _consultarDleEot();
      if (!detalhe.prontaParaVenda) return detalhe;
    } catch (_) {
      // DLE EOT ilegível: o motivo sai da porta.
    }
    return PrinterStatus(
      online: porta.online && porta.semErro,
      semPapel: porta.semPapel,
    );
  }

  Future<StatusDaPorta?> _porta() async {
    try {
      final b = await _t.statusDaPorta();
      if (b == null) return null;
      final p = StatusDaPorta(b);
      return p.valido ? p : null;
    } on PrinterDisconnected {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// "Papel acabando" pelo DLE EOT 4 — só aviso, nunca bloqueia. Vale com DUAS
  /// leituras seguidas: o byte deslocado (0x16) também acende o bit de "acabando"
  /// (ERR-043), e papel acabando de verdade continua acabando na leitura seguinte.
  /// Leitura ilegível = não avisa e não apaga a anterior.
  bool _acabandoNaAnterior = false;

  Future<bool> _pertoDoFim() async {
    final int b;
    try {
      b = await _eot(Cmd.eotPaper);
    } catch (_) {
      return false;
    }
    final agora = (b & 0x0C) != 0;
    final confirmado = agora && _acabandoNaAnterior;
    _acabandoNaAnterior = agora;
    return confirmado;
  }

  Future<PrinterStatus> _consultarDleEot() async {
    final printer = await _eot(Cmd.eotPrinter);
    final offlineCause = await _eot(Cmd.eotOffline);
    final error = await _eot(Cmd.eotError);
    final paper = await _eot(Cmd.eotPaper);
    return PrinterStatus.fromDleEot(
      printer: printer,
      offlineCause: offlineCause,
      error: error,
      paper: paper,
    );
  }

  @override
  Future<void> habilitarAsb() => _t.write(Cmd.asbOn);

  @override
  Stream<PrinterStatus> get statusStream =>
      _t.incoming.where((b) => b.length >= 4).map(PrinterStatus.fromAsb);

  /// Resultado da impressão. A ESCRITA USB é confiável; a LEITURA de status
  /// (DLE EOT) é flaky sobre USB. Então só BLOQUEIA se conseguiu LER o status e
  /// ele diz "não pronta" (sem papel/tampa). Status ilegível → imprime mesmo
  /// assim (não travar a venda por causa de um byte que não voltou).
  @override
  Future<PrinterStatus> imprimir(Uint8List cupom) async {
    PrinterStatus? antes;
    try {
      antes = await consultarStatus();
    } catch (_) {
      antes = null; // status ilegível — segue e imprime
    }
    if (antes != null && !antes.prontaParaVenda) return antes; // portão real
    await _t.write(cupom);
    try {
      return await consultarStatus();
    } catch (_) {
      return const PrinterStatus(); // imprimiu; status pós ilegível = assume ok
    }
  }
}
