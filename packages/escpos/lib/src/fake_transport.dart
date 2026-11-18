import 'dart:async';
import 'dart:typed_data';
import 'commands.dart';
import 'transport.dart';

/// Transporte de bancada/testes: registra tudo que foi escrito e responde
/// DLE EOT conforme o estado simulado. Também emite ASB sintético.
class FakeTransport implements PrinterTransport {
  bool aberta = false;
  bool desconectada = false;
  final List<Uint8List> escritos = [];
  final _asb = StreamController<Uint8List>.broadcast();

  // estado simulado
  bool offline = false;
  bool tampaAberta = false;
  bool semPapel = false;
  bool pertoDoFim = false;

  /// Hook de teste: chamado após cada resposta de leitura (permite simular
  /// o papel acabando NO MEIO de uma sequência real de consultas/impressão).
  void Function()? aposLeitura;

  /// Impressora em Printer Class: responde o GET_PORT_STATUS coerente com o
  /// estado simulado. Desligado = transporte sem o canal (como em Vendor Class).
  bool temStatusDaPorta = false;

  /// Byte da porta forçado (ex.: leitura errada com bit reservado ligado).
  int? portaForcada;

  /// Respostas do DLE EOT forçadas, em ordem — simulam a via de dados deslocada
  /// do totem (ERR-043): a resposta de uma pergunta lida como a da seguinte.
  /// Vazia = responde pelo estado simulado.
  final List<int> filaDleEot = [];

  /// Quantas vezes o GET_PORT_STATUS foi pedido.
  int pedidosDaPorta = 0;

  /// DLE EOT sem resposta (timeout), como na maior parte das leituras do totem.
  bool dleEotMudo = false;

  @override
  Future<int?> statusDaPorta() async {
    if (desconectada) throw const PrinterDisconnected();
    if (!temStatusDaPorta) return null;
    pedidosDaPorta++;
    if (portaForcada != null) return portaForcada;
    final problema = offline || tampaAberta || semPapel;
    return (problema ? 0x00 : 0x18) | (semPapel ? 0x20 : 0x00);
  }

  int? _ultimoEot;

  @override
  Future<void> open() async {
    if (desconectada) throw const PrinterDisconnected();
    aberta = true;
  }

  @override
  Future<void> close() async => aberta = false;

  @override
  Future<void> write(Uint8List bytes) async {
    if (desconectada) throw const PrinterDisconnected();
    escritos.add(bytes);
    if (bytes.length == 3 && bytes[0] == 0x10 && bytes[1] == 0x04) {
      _ultimoEot = bytes[2];
    }
  }

  @override
  Future<Uint8List> read(int max, {Duration timeout = const Duration(seconds: 2)}) async {
    if (desconectada) throw const PrinterDisconnected();
    final n = _ultimoEot;
    _ultimoEot = null;
    if (n == null || dleEotMudo) throw const PrinterTimeout();
    final resp = Uint8List.fromList(
        [filaDleEot.isNotEmpty ? filaDleEot.removeAt(0) : _statusByte(n)]);
    aposLeitura?.call();
    return resp;
  }

  int _statusByte(int n) => switch (n) {
        Cmd.eotPrinter => offline ? 0x08 : 0x00,
        Cmd.eotOffline =>
          (tampaAberta ? 0x04 : 0x00) | (semPapel ? 0x20 : 0x00),
        Cmd.eotError => 0x00,
        Cmd.eotPaper =>
          (pertoDoFim ? 0x0C : 0x00) | (semPapel ? 0x60 : 0x00),
        _ => 0x00,
      };

  /// Emite um pacote ASB coerente com o estado atual (simula o evento real).
  void emitirAsb() => _asb.add(Uint8List.fromList([
        (offline ? 0x08 : 0x00) | (tampaAberta ? 0x20 : 0x00),
        0x00,
        (pertoDoFim ? 0x01 : 0x00) | (semPapel ? 0x0C : 0x00),
        0x00,
      ]));

  @override
  Stream<Uint8List> get incoming => _asb.stream;

  /// Bytes acumulados (para asserts de conteúdo do cupom).
  Uint8List get tudoEscrito =>
      Uint8List.fromList([for (final b in escritos) ...b]);
}
