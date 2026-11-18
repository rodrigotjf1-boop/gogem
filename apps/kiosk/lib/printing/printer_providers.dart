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

  /// Checagem do portão. A LEITURA de status (DLE EOT) é flaky sobre USB, então
  /// o critério de "desconectada" é a AUSÊNCIA física do device (conectar/open
  /// falha), NÃO o status não ter voltado. Se o device está presente mas o
  /// status é ilegível, assume PRONTA (não trava a venda por um byte perdido) —
  /// a proteção de papel real vem quando o status É lido (ou de imprimir()).
  ///
  /// Leitura que ACUSA problema (tampa, papel, offline) só vale confirmada por uma
  /// segunda: pela USB o byte às vezes volta deslocado e acusa "tampa aberta" que não
  /// existe — o totem recusava o pagamento até o cliente tocar "Tentar novamente"
  /// (ERR-043). Problema de verdade persiste nas duas. A confirmação só LIBERA quando
  /// lê "pronta": se ela não ler, vale a primeira (bloqueia) — regra de ouro: nunca
  /// iniciar pagamento com a impressora acusando problema.
  Future<PrinterHealth> checarAgora() async {
    final d = ref.read(printerDriverProvider);
    Object? erroDaLeitura;
    try {
      var s = await d.consultarStatus();
      // ignore: avoid_print
      print('[printerHealth] status=$s');
      if (!s.prontaParaVenda) {
        await Future<void>.delayed(ref.read(confirmacaoDaImpressoraProvider));
        try {
          s = await d.consultarStatus();
          // ignore: avoid_print
          print('[printerHealth] confirmação=$s');
        } catch (e) {
          // ignore: avoid_print
          print('[printerHealth] confirmação ilegível ($e) — vale a primeira');
        }
      }
      state = PrinterHealth(
          status: s, desconectada: false, ultimaChecagem: DateTime.now());
      return state;
    } catch (e) {
      erroDaLeitura = e;
      // ignore: avoid_print
      print('[printerHealth] status ilegível: $e');
    }
    // Status não leu — o device ainda está conectado? (open sem erro = presente)
    try {
      await d.conectar();
    } catch (e2) {
      // ignore: avoid_print
      print('[printerHealth] desconectada: $e2');
      state = PrinterHealth(desconectada: true, ultimaChecagem: DateTime.now());
      return state;
    }
    // ERR-048: a leitura caiu porque a CONEXÃO morreu (a impressora reiniciou e voltou
    // com outro endereço USB). O `conectar` acabou de abrir uma conexão nova: lê por ela
    // antes de assumir "pronta" — a impressora que volta pode estar sem papel.
    if (erroDaLeitura is PrinterDisconnected) {
      try {
        final s = await d.consultarStatus();
        // ignore: avoid_print
        print('[printerHealth] reconectada, status=$s');
        state = PrinterHealth(
            status: s, desconectada: false, ultimaChecagem: DateTime.now());
        return state;
      } catch (e3) {
        // ignore: avoid_print
        print('[printerHealth] reconectada, status ainda ilegível ($e3)');
      }
    }
    // ignore: avoid_print
    print('[printerHealth] conectada, status desconhecido → assumindo pronta');
    state = PrinterHealth(desconectada: false, ultimaChecagem: DateTime.now());
    return state;
  }
}

/// Espera entre a leitura que acusou problema e a que confirma (ERR-043). Provider
/// para o teste trocar por zero.
final confirmacaoDaImpressoraProvider =
    Provider<Duration>((_) => const Duration(milliseconds: 400));

final printerHealthProvider =
    NotifierProvider<PrinterHealthNotifier, PrinterHealth>(
        PrinterHealthNotifier.new);
