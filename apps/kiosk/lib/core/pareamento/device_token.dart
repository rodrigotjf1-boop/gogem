import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/catalog/catalog_sync.dart'
    show databaseProvider, gogemApiProvider;
import '../config/app_config.dart';

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
    final api = ref.read(gogemApiProvider);
    final token = await api.parear(codigo);
    final db = await ref.read(databaseProvider.future);
    await db.insert('kv', {'chave': _kvChaveToken, 'valor': token},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _aplicar(token);
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
