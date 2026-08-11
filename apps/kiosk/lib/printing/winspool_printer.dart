import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:gogem_escpos/escpos.dart';
import 'package:win32/win32.dart';

/// Driver de impressora no **Windows** (totem em PC — F13): manda os bytes
/// ESC/POS crus pela FILA de impressão do Windows (`winspool`, datatype RAW).
/// Reusa a MESMA Epson do ponto de teste, instalada como impressora do Windows
/// (driver Epson ou Genérico/Somente-texto).
///
/// ⚠️ winspool é **só escrita** — não há o back-channel do Epson (DLE EOT/ASB),
/// então o status fino (near-end) não existe aqui. O status vem GROSSO do
/// spooler (`GetPrinter` → PRINTER_INFO_2.Status): sem papel, offline, tampa,
/// erro. É o suficiente para o portão (não vende sem papel/offline).
class WinspoolPrinter implements PrinterDriver {
  WinspoolPrinter(this._nomeImpressora);

  /// Nome EXATO da impressora no Windows (Painel de Controle → Dispositivos e
  /// Impressoras). Vem de --dart-define=GOGEM_PRINTER_NAME.
  final String _nomeImpressora;

  @override
  Future<void> conectar() async {
    // Verifica que a fila existe (abre e fecha) — falha vira "desconectada".
    final h = _abrir();
    ClosePrinter(h);
  }

  @override
  Future<void> desconectar() async {}

  @override
  Future<void> habilitarAsb() async {
    // winspool não tem avisos espontâneos — no-op (o health faz polling).
  }

  @override
  Stream<PrinterStatus> get statusStream => const Stream.empty();

  @override
  Future<PrinterStatus> consultarStatus() async {
    final h = _abrir();
    try {
      return _statusDoSpooler(h);
    } finally {
      ClosePrinter(h);
    }
  }

  @override
  Future<PrinterStatus> imprimir(Uint8List cupom) async {
    final h = _abrir();
    try {
      final antes = _statusDoSpooler(h);
      if (!antes.prontaParaVenda) return antes; // portão: não grava nada
      _escreverRaw(h, cupom);
      return _statusDoSpooler(h);
    } finally {
      ClosePrinter(h);
    }
  }

  // ── win32 ──────────────────────────────────────────────────────────────────

  /// Abre a fila da impressora; retorna o HANDLE (int). Lança se indisponível.
  int _abrir() {
    final nome = _nomeImpressora.trim();
    if (nome.isEmpty) {
      throw const PrinterDisconnected('impressora do Windows não configurada');
    }
    final pNome = nome.toNativeUtf16(allocator: calloc);
    final phPrinter = calloc<IntPtr>();
    try {
      final ok = OpenPrinter(pNome, phPrinter, nullptr);
      if (ok == 0 || phPrinter.value == 0) {
        throw PrinterDisconnected('fila "$nome" indisponível');
      }
      return phPrinter.value;
    } finally {
      calloc.free(pNome);
      calloc.free(phPrinter);
    }
  }

  void _escreverRaw(int hPrinter, Uint8List bytes) {
    final docInfo = calloc<DOC_INFO_1>();
    final pDoc = 'GoGeM cupom'.toNativeUtf16(allocator: calloc);
    final pType = 'RAW'.toNativeUtf16(allocator: calloc);
    final buf = calloc<Uint8>(bytes.length);
    buf.asTypedList(bytes.length).setAll(0, bytes);
    final escrito = calloc<Uint32>();
    docInfo.ref.pDocName = pDoc;
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = pType;
    try {
      if (StartDocPrinter(hPrinter, 1, docInfo.cast()) == 0) {
        throw const PrinterDisconnected('StartDocPrinter falhou');
      }
      StartPagePrinter(hPrinter);
      WritePrinter(hPrinter, buf.cast(), bytes.length, escrito);
      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
    } finally {
      calloc.free(pDoc);
      calloc.free(pType);
      calloc.free(buf);
      calloc.free(escrito);
      calloc.free(docInfo);
    }
  }

  /// Lê o Status do spooler (2 passadas: tamanho, depois os dados).
  PrinterStatus _statusDoSpooler(int hPrinter) {
    final needed = calloc<Uint32>();
    try {
      GetPrinter(hPrinter, 2, nullptr, 0, needed);
      final cb = needed.value;
      // Sem info do spooler → assume ok (não trava a venda por falta de dado).
      if (cb == 0) return const PrinterStatus();
      final buf = calloc<Uint8>(cb);
      try {
        if (GetPrinter(hPrinter, 2, buf, cb, needed) == 0) {
          return const PrinterStatus();
        }
        return _mapStatus(buf.cast<PRINTER_INFO_2>().ref.Status);
      } finally {
        calloc.free(buf);
      }
    } finally {
      calloc.free(needed);
    }
  }

  // Flags PRINTER_STATUS_* do Win32 (winspool).
  static const _error = 0x00000002;
  static const _paperJam = 0x00000008;
  static const _paperOut = 0x00000010;
  static const _offline = 0x00000080;
  static const _notAvailable = 0x00001000;
  static const _userIntervention = 0x00100000;
  static const _doorOpen = 0x00400000;

  PrinterStatus _mapStatus(int status) => PrinterStatus(
        online: (status & (_offline | _notAvailable)) == 0,
        semPapel: (status & _paperOut) != 0,
        tampaAberta: (status & _doorOpen) != 0,
        erroGuilhotina:
            (status & (_error | _paperJam | _userIntervention)) != 0,
      );
}
