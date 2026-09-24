import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/api/gogem_api.dart';
import '../../data/catalog/catalog_sync.dart' show databaseProvider;
import '../config/app_config.dart';
import '../config/host_servidor.dart';

/// Pareamento do totem: o dispositivo troca um código de 6 dígitos por um
/// token próprio (NÃO expira), guardado localmente. Substitui a dependência do
/// JWT de gestor (12h). O backend aceita `X-Device-Token` (ver GogemApi).

enum PairStatus { carregando, pareado, naoPareado }

/// Ponte para o GoRouter (que vive fora do ProviderScope) reagir ao pareamento.
/// Começa em `carregando` para NÃO redirecionar antes do boot resolver.
final pairingStatus = ValueNotifier<PairStatus>(PairStatus.carregando);

const _kvChaveToken = 'device_token';

class DeviceTokenState {
  const DeviceTokenState({this.carregando = true, this.token});
  final bool carregando;
  final String? token;
  bool get pareado => token != null && token!.isNotEmpty;
}

class DeviceTokenNotifier extends Notifier<DeviceTokenState> {
  @override
  DeviceTokenState build() => const DeviceTokenState();

  /// Carrega o token salvo (chamado no boot). Atualiza o `pairingStatus`.
  /// Se NÃO houver token mas houver um JWT de dev (AppConfig), dispensa o
  /// pareamento (build de dev). Só força a tela de pareamento quando não há
  /// nem token nem JWT (build de produção).
  Future<void> carregar() async {
    // O DESTINO deste totem (servidor da loja ou nuvem) vem antes: o cliente HTTP é
    // montado a partir dele, e carregá-lo depois faria a primeira chamada sair pelo
    // endereço errado.
    await ref.read(hostServidorProvider.notifier).carregar();
    final db = await ref.read(databaseProvider.future);
    final r =
        await db.query('kv', where: 'chave = ?', whereArgs: [_kvChaveToken]);
    final token = r.isNotEmpty ? r.first['valor'] as String? : null;
    state = DeviceTokenState(carregando: false, token: token);
    final temJwtDev = ref.read(appConfigProvider).devJwt.isNotEmpty;
    pairingStatus.value = (state.pareado || temJwtDev)
        ? PairStatus.pareado
        : PairStatus.naoPareado;
  }

  /// Troca o código pelo token de dispositivo e persiste. Lança em falha
  /// (código inválido/expirado → GogemApiException).
  Future<void> parear(String codigo) async {
    // O pareamento vai SEMPRE ao host do build (a nuvem): é ela que valida o código e
    // que sabe a qual servidor este aparelho pertence. Perguntar ao servidor da loja
    // qual é o servidor da loja seria circular — e impediria repareamento quando o
    // endereço guardado estiver errado ou o servidor estiver fora.
    final api = ref.read(apiDePareamentoProvider);
    final r = await api.parear(codigo);
    final db = await ref.read(databaseProvider.future);
    await db.insert('kv', {'chave': _kvChaveToken, 'valor': r.token},
        conflictAlgorithm: ConflictAlgorithm.replace);
    // O destino vem do pareamento; ausente = nuvem.
    await ref.read(hostServidorProvider.notifier).definir(r.apiBase, caPem: r.caPem);
    _aplicar(r.token);
  }

  /// O servidor revogou/invalidou o dispositivo (a chamada volta 401): apaga o
  /// token local e volta à tela de pareamento (o router reage ao pairingStatus).
  /// Sem isso, um totem revogado ficava preso no catálogo em cache, sem pedir
  /// código de novo.
  Future<void> desparear() async {
    final db = await ref.read(databaseProvider.future);
    await db.delete('kv', where: 'chave = ?', whereArgs: [_kvChaveToken]);
    // Some também com o destino: sem credencial o aparelho não é de ninguém, e o
    // próximo pareamento é quem diz para onde ele volta a apontar.
    await ref.read(hostServidorProvider.notifier).definir(null);
    _aplicar(null);
  }

  void _aplicar(String? token) {
    state = DeviceTokenState(carregando: false, token: token);
    pairingStatus.value =
        state.pareado ? PairStatus.pareado : PairStatus.naoPareado;
  }
}

final deviceTokenProvider =
    NotifierProvider<DeviceTokenNotifier, DeviceTokenState>(
        DeviceTokenNotifier.new);

/// Cliente usado APENAS no pareamento: fixo no host do build (a nuvem), independente do
/// destino guardado. Separado do `gogemApiProvider` de propósito — e overridável em teste.
final apiDePareamentoProvider = Provider<GogemApi>((ref) {
  final cfg = ref.read(appConfigProvider);
  return GogemApi(baseUrl: hostDoBuild, bearer: cfg.devJwt);
});
