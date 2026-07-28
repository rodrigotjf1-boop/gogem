import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/catalog/catalog_sync.dart';
import '../../printing/fila_impressao.dart';
import '../../printing/printer_providers.dart';
import '../pareamento/device_token.dart';

/// Telemetria: envia um heartbeat periódico ao backend com o estado do totem
/// (papel, fila, versão do catálogo/app). Best-effort — falha nunca afeta a
/// operação. Só envia quando PAREADO (usa o X-Device-Token).
class HeartbeatNotifier extends Notifier<int> {
  Timer? _timer;
  static const _intervalo = Duration(seconds: 60);

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  /// Inicia o envio periódico (idempotente).
  void iniciar() {
    if (_timer != null) return;
    _enviar();
    _timer = Timer.periodic(_intervalo, (_) => _enviar());
  }

  Future<void> _enviar() async {
    final token = ref.read(deviceTokenProvider).token;
    if (token == null || token.isEmpty) return; // só pareado

    try {
      final saude = ref.read(printerHealthProvider);
      final cat = ref.read(catalogSyncProvider);
      var fila = 0;
      try {
        final f = await ref.read(filaImpressaoProvider.future);
        fila = await f.pendentes();
      } catch (_) {}

      final status = <String, dynamic>{
        'filaImpressao': fila,
        'impressoraOk': saude.prontaParaVenda,
        'papelAcabando': saude.pertoDoFim,
        'appVersao': '0.3.0',
      };
      if (cat.versao != null) status['versaoCatalogo'] = cat.versao;

      await ref.read(gogemApiProvider).heartbeat(status);
      state = state + 1;
    } catch (_) {
      // telemetria é best-effort; ignora falhas.
    }
  }
}

final heartbeatProvider =
    NotifierProvider<HeartbeatNotifier, int>(HeartbeatNotifier.new);
