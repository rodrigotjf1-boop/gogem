import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/catalog/catalog_sync.dart' show gogemApiProvider;

/// Sobe erros do totem pra a Distribuição (best-effort, via /telemetria/evento).
/// Guarda uma instância ESTÁTICA porque os handlers globais de erro
/// (FlutterError.onError e o runZonedGuarded) rodam FORA do ProviderScope e
/// precisam de um ponto de acesso ao reporter. Nunca propaga exceção.
class TelemetriaReporter {
  TelemetriaReporter(this._ref);
  final Ref _ref;

  /// Setada no boot do app (app.dart). Nula antes disso → erros muito iniciais
  /// não sobem (aceitável; o app ainda nem pareou/subiu a árvore).
  static TelemetriaReporter? instance;

  Future<void> reportar(
    String mensagem, {
    String? detalhe,
    String nivel = 'erro',
  }) async {
    try {
      await _ref.read(gogemApiProvider).reportarErro(
            mensagem: mensagem,
            detalhe: detalhe,
            nivel: nivel,
          );
    } catch (_) {
      // best-effort
    }
  }
}

final telemetriaReporterProvider =
    Provider<TelemetriaReporter>((ref) => TelemetriaReporter(ref));
