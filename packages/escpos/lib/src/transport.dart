import 'dart:typed_data';

/// Canal físico com a impressora (USB Android, USB/driver Windows, fake).
abstract interface class PrinterTransport {
  Future<void> open();
  Future<void> close();
  Future<void> write(Uint8List bytes);
  /// Lê até [max] bytes; lança [PrinterTimeout] se nada chegar em [timeout].
  Future<Uint8List> read(int max, {Duration timeout});
  /// Stream de bytes espontâneos (ASB). Pode ser vazio em transportes
  /// que não suportam leitura assíncrona.
  Stream<Uint8List> get incoming;

  /// Byte do GET_PORT_STATUS da classe de impressora USB, pedido pelo canal de
  /// CONTROLE (ver [StatusDaPorta]). Não passa pela via de dados, então não se
  /// desloca como a resposta do DLE EOT (ERR-043). `null` quando o transporte não
  /// tem esse canal: impressora em Vendor Class, Windows, transporte falso sem a
  /// simulação ligada.
  Future<int?> statusDaPorta();
}

class PrinterTimeout implements Exception {
  const PrinterTimeout([this.msg = 'timeout de leitura da impressora']);
  final String msg;
  @override
  String toString() => 'PrinterTimeout: $msg';
}

class PrinterDisconnected implements Exception {
  const PrinterDisconnected([this.msg = 'impressora desconectada']);
  final String msg;
  @override
  String toString() => 'PrinterDisconnected: $msg';
}
