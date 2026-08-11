import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogem_escpos/escpos.dart';
import 'usb_transport.dart';
import 'winspool_printer.dart';

/// Seleção do transporte USB/fake (Android/bancada):
/// --dart-define=GOGEM_PRINTER=usb|fake  (default: fake para dev/bancada).
final printerTransportProvider = Provider<PrinterTransport>((ref) {
  const modo = String.fromEnvironment('GOGEM_PRINTER', defaultValue: 'fake');
  return modo == 'usb' ? UsbChannelTransport() : FakeTransport();
});

/// Driver por provisionamento (--dart-define=GOGEM_PRINTER):
///  - `winspool` (Windows/F13): fila do Windows RAW; nome em GOGEM_PRINTER_NAME;
///  - `usb` (Android): Epson via USB (canal nativo);
///  - `fake` (default): Epson sobre transporte fake (dev/bancada/testes).
final printerDriverProvider = Provider<PrinterDriver>((ref) {
  const modo = String.fromEnvironment('GOGEM_PRINTER', defaultValue: 'fake');
  if (modo == 'winspool') {
    const nome = String.fromEnvironment('GOGEM_PRINTER_NAME', defaultValue: '');
    return WinspoolPrinter(nome);
  }
  return EpsonT88(ref.watch(printerTransportProvider));
});

class PrinterHealth {
  const PrinterHealth({
    this.status = const PrinterStatus(),
    this.desconectada = true,
    this.ultimaChecagem,
  });
  final PrinterStatus status;
  final bool desconectada;
  final DateTime? ultimaChecagem;

  /// Portão de operação do totem.
  bool get prontaParaVenda => !desconectada && status.prontaParaVenda;
  bool get pertoDoFim => !desconectada && status.pertoDoFim;
  String get motivo => desconectada
      ? 'impressora desconectada'
      : (status.motivoBloqueio ?? 'ok');
}

/// Vigia da impressora: polling síncrono (DLE EOT) a cada 30s + checagem sob
/// demanda nos portões do fluxo. ASB (avisos espontâneos) fica DESLIGADO: no
/// USB Android o pacote de 4 bytes do ASB compete com a resposta do DLE EOT no
/// mesmo endpoint IN e corrompe a leitura de status (impressora "conecta" mas o
/// status falha → totem trava). O polling cobre papel/tampa nos portões.
class PrinterHealthNotifier extends Notifier<PrinterHealth> {
  Timer? _poll;
  static const intervalo = Duration(seconds: 30);

  @override
  PrinterHealth build() {
    ref.onDispose(() => _poll?.cancel());
    return const PrinterHealth();
  }

  Future<void> iniciar() async {
    if (_poll != null) return;
    final d = ref.read(printerDriverProvider);
    try {
      await d.conectar();
    } catch (e) {
      // ignore: avoid_print
      print('[printerHealth] conectar falhou: $e');
      state = PrinterHealth(desconectada: true, ultimaChecagem: DateTime.now());
    }
    _poll = Timer.periodic(intervalo, (_) => checarAgora());
    await checarAgora();
  }

  /// Checagem SÍNCRONA (DLE EOT) — usada nos portões (antes do pagamento).
  Future<PrinterHealth> checarAgora() async {
    final d = ref.read(printerDriverProvider);
    try {
      final s = await d.consultarStatus();
      // ignore: avoid_print
      print('[printerHealth] status=$s');
      state = PrinterHealth(
          status: s, desconectada: false, ultimaChecagem: DateTime.now());
    } on Object catch (e) {
      // ignore: avoid_print
      print('[printerHealth] consultarStatus falhou: $e — reconectando');
      // tenta reconectar uma vez (cabo religado etc.)
      try {
        await d.conectar();
        final s = await d.consultarStatus();
        // ignore: avoid_print
        print('[printerHealth] status (retry)=$s');
        state = PrinterHealth(
            status: s, desconectada: false, ultimaChecagem: DateTime.now());
      } catch (e2) {
        // ignore: avoid_print
        print('[printerHealth] retry falhou: $e2');
        state =
            PrinterHealth(desconectada: true, ultimaChecagem: DateTime.now());
      }
    }
    return state;
  }
}

final printerHealthProvider =
    NotifierProvider<PrinterHealthNotifier, PrinterHealth>(
        PrinterHealthNotifier.new);
