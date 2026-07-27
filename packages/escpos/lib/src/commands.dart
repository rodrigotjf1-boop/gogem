import 'dart:typed_data';

/// Comandos ESC/POS usados pelo GoGeM (referência: Epson TM-T88 series).
abstract final class Cmd {
  static final init = Uint8List.fromList([0x1B, 0x40]); // ESC @
  /// DLE EOT n — consulta de status em tempo real (funciona mesmo ocupada).
  static Uint8List dleEot(int n) => Uint8List.fromList([0x10, 0x04, n]);
  static const eotPrinter = 1; // status geral (offline)
  static const eotOffline = 2; // causa do offline (tampa, fim de papel)
  static const eotError = 3; // erros (guilhotina)
  static const eotPaper = 4; // sensores de papel (near-end / fim)

  /// GS a n — habilita ASB (Automatic Status Back): a impressora passa a
  /// enviar 4 bytes de status espontaneamente a cada mudança.
  static final asbOn = Uint8List.fromList([0x1D, 0x61, 0xFF]);
  static final asbOff = Uint8List.fromList([0x1D, 0x61, 0x00]);

  static final alignLeft = Uint8List.fromList([0x1B, 0x61, 0x00]);
  static final alignCenter = Uint8List.fromList([0x1B, 0x61, 0x01]);
  static final boldOn = Uint8List.fromList([0x1B, 0x45, 0x01]);
  static final boldOff = Uint8List.fromList([0x1B, 0x45, 0x00]);
  /// GS ! n — tamanho (largura<<4 | altura), 0 = normal.
  static Uint8List size(int wMul, int hMul) =>
      Uint8List.fromList([0x1D, 0x21, ((wMul - 1) << 4) | (hMul - 1)]);
  static final feed3 = Uint8List.fromList([0x1B, 0x64, 0x03]); // ESC d 3
  /// GS V 66 n — corte parcial com avanço.
  static final cut = Uint8List.fromList([0x1D, 0x56, 0x42, 0x10]);
  /// ESC t 2 — codepage PC850 (acentuação PT-BR na TM-T88).
  static final cp850 = Uint8List.fromList([0x1B, 0x74, 0x02]);
}
