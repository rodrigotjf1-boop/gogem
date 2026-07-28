import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/config/app_config.dart';
import '../../core/pareamento/device_token.dart';
import '../api/gogem_api.dart';
import '../db/kiosk_database.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

enum SyncStatus { ocioso, sincronizando, atualizado, offline, erro }

class SyncState {
  const SyncState({
    this.status = SyncStatus.ocioso,
    this.versao,
    this.ultimaSync,
    this.mensagem,
  });
  final SyncStatus status;
  final int? versao;
  final DateTime? ultimaSync;
  final String? mensagem;

  SyncState copyWith({SyncStatus? status, int? versao, DateTime? ultimaSync, String? mensagem}) =>
      SyncState(
        status: status ?? this.status,
        versao: versao ?? this.versao,
        ultimaSync: ultimaSync ?? this.ultimaSync,
        mensagem: mensagem,
      );
}

// ---------- providers de infraestrutura (overridáveis em teste) ----------
final databaseProvider = FutureProvider<Database>((ref) => KioskDatabase.open());

final catalogRepositoryProvider = FutureProvider<CatalogRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CatalogRepository(db);
});

final gogemApiProvider = Provider<GogemApi>((ref) {
  final cfg = ref.watch(appConfigProvider);
  // Prefere o token de dispositivo (pareado) sobre o JWT de dev.
  final deviceToken = ref.watch(deviceTokenProvider).token;
  return GogemApi(
      baseUrl: cfg.apiUrl, bearer: cfg.devJwt, deviceToken: deviceToken);
});

/// Cardápio corrente (recarrega quando a versão do sync muda).
final menuProvider = FutureProvider<MenuSnapshot?>((ref) async {
  ref.watch(catalogSyncProvider.select((s) => s.versao)); // dependência de recarga
  final repo = await ref.watch(catalogRepositoryProvider.future);
  return repo.carregarCorrente();
});

/// Orquestra o sync: checagem barata por `desde=<versao>`, offline-first
/// (falha de rede NUNCA apaga o snapshot local) e agendador com backoff.
class CatalogSyncNotifier extends Notifier<SyncState> {
  Timer? _timer;
  int _falhasSeguidas = 0;
  static const _intervaloBase = Duration(seconds: 60);

  @override
  SyncState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SyncState();
  }

  /// Chamar uma vez no boot do app (idempotente).
  void iniciarAgendador() {
    if (_timer != null) return;
    _agendar(Duration.zero);
  }

  void _agendar(Duration atraso) {
    _timer?.cancel();
    _timer = Timer(atraso, () async {
      await sincronizar();
      // backoff exponencial em falha (60s, 2min, 4min... teto 10min)
      final mult = 1 << _falhasSeguidas.clamp(0, 4);
      final prox = _falhasSeguidas == 0
          ? _intervaloBase
          : Duration(seconds: (_intervaloBase.inSeconds * mult).clamp(60, 600));
      _agendar(prox);
    });
  }

  Future<void> sincronizar() async {
    state = state.copyWith(status: SyncStatus.sincronizando);
    try {
      final repo = await ref.read(catalogRepositoryProvider.future);
      final atual = await repo.versaoCorrente();
      final api = ref.read(gogemApiProvider);
      final res = await api.getCatalogoPublicado(desde: atual);
      switch (res) {
        case MenuJaAtualizado():
          _falhasSeguidas = 0;
          state = state.copyWith(
              status: SyncStatus.atualizado, versao: atual, ultimaSync: DateTime.now());
        case MenuAtualizado(:final body, :final snapshot):
          await repo.salvarSnapshot(body);
          _falhasSeguidas = 0;
          state = state.copyWith(
              status: SyncStatus.atualizado,
              versao: snapshot.versao,
              ultimaSync: DateTime.now());
      }
    } on GogemApiException catch (e) {
      _falhasSeguidas++;
      state = state.copyWith(status: SyncStatus.erro, mensagem: 'API ${e.status}');
    } catch (_) {
      // Sem rede: segue com o snapshot local (offline-first).
      _falhasSeguidas++;
      state = state.copyWith(status: SyncStatus.offline, mensagem: 'sem conexão');
    }
  }
}

final catalogSyncProvider =
    NotifierProvider<CatalogSyncNotifier, SyncState>(CatalogSyncNotifier.new);
