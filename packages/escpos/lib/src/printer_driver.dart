import 'dart:typed_data';
import 'status.dart';

/// Contrato do driver de impressora do totem — a camada de UI/health fala SÓ
/// com isto, sem saber o transporte. Duas implementações:
///  - [EpsonT88] (Android): USB bidirecional, status fino via DLE EOT/ASB;
///  - `WinspoolPrinter` (Windows, no app kiosk): fila do Windows (RAW, só
///    escrita), status grosso via spooler (sem papel/offline/erro).
abstract interface class PrinterDriver {
  /// Abre o canal (verifica a impressora). Lança se indisponível.
  Future<void> conectar();

  /// Fecha o canal.
  Future<void> desconectar();

  /// Status atual (portão antes do pagamento). Síncrono.
  Future<PrinterStatus> consultarStatus();

  /// Liga os avisos espontâneos (ASB no Epson; no-op onde não houver).
  Future<void> habilitarAsb();

  /// Eventos espontâneos de status (vazio onde não houver back-channel; o health
  /// faz polling de [consultarStatus] nesses casos).
  Stream<PrinterStatus> get statusStream;

  /// Consulta (portão), imprime e reconsulta. Não grava se o portão bloquear.
  Future<PrinterStatus> imprimir(Uint8List cupom);
}
