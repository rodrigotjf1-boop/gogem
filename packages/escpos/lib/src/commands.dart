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

  // ---- QR Code (GS ( k, cn=49) ----
  // Bytes IDENTICOS aos que o servidor da loja ja usa (`backend/edge/escpos.mjs`): a mesma
  // NFC-e tem de sair igual no totem e na impressora do caixa. Referencia: Epson ESC/POS
  // Functions 165 (modelo), 167 (tamanho do modulo), 169 (correcao), 180 (dados), 181 (imprime).
  /// GS ( k 4 0 49 65 50 0 - modelo 2 (o usado pela NFC-e).
  static final qrModelo =
      Uint8List.fromList([0x1D, 0x28, 0x6B, 4, 0, 0x31, 0x41, 0x32, 0x00]);

  /// GS ( k 3 0 49 67 n - tamanho do modulo, em pontos (1..16).
  ///
  /// O padrao 6 nao e estetico: o Manual do DANFE NFC-e exige o QR com ao menos
  /// **25 mm x 25 mm**. A 203 dpi (8 pontos/mm), a URL da NFC-e cabe em um QR de ~57
  /// modulos -> 57 x 6 = 342 pontos = ~43 mm. Com modulo 3 sairia ~21 mm: menor que a
  /// norma, e ilegivel por parte dos leitores de celular.
  static Uint8List qrTamanho(int n) =>
      Uint8List.fromList([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x43, n.clamp(1, 16)]);

  /// GS ( k 3 0 49 69 n - nivel de correcao (48=L, 49=M, 50=Q, 51=H). A norma pede **M**.
  static final qrCorrecaoM =
      Uint8List.fromList([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x45, 0x31]);

  /// GS ( k pL pH 49 80 48 d1..dk - guarda os dados. (pL + pH*256) = k + 3.
  static Uint8List qrDados(List<int> d) {
    final len = d.length + 3;
    return Uint8List.fromList(
        [0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x31, 0x50, 0x30, ...d]);
  }

  /// GS ( k 3 0 49 81 48 - imprime o simbolo guardado.
  static final qrImprimir =
      Uint8List.fromList([0x1D, 0x28, 0x6B, 3, 0, 0x31, 0x51, 0x30]);
}
