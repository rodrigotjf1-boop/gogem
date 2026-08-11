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

/// Vigia da impressora: ASB sempre ligado + polling de segurança (30s) +
/// checagem síncrona sob demanda nos portões do fluxo.
class PrinterHealthNotifier extends Notifier<PrinterHealth> {
  Timer? _poll;
  StreamSubscription? _asbSub;
  static const intervalo = Duration(seconds: 30);

  @override
  PrinterHealth build() {
    ref.onDispose(() {
      _poll?.cancel();
      _asbSub?.cancel();
    });
    return const PrinterHealth();
  }

  Future<void> iniciar() async {
    if (_poll != null) return;
    final d = ref.read(printerDriverProvider);
    try {
      await d.conectar();
      await d.habilitarAsb();
      _asbSub = d.statusStream.listen((s) => state = PrinterHealth(
          status: s, desconectada: false, ultimaChecagem: DateTime.now()));
    } catch (_) {
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
      state = PrinterHealth(
          status: s, desconectada: false, ultimaChecagem: DateTime.now());
    } on Object {
      // tenta reconectar uma vez (cabo religado etc.)
      try {
        await d.conectar();
        final s = await d.consultarStatus();
        state = PrinterHealth(
            status: s, desconectada: false, ultimaChecagem: DateTime.now());
      } catch (_) {
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
