import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/gogem_api.dart';
import '../catalog/catalog_sync.dart';

/// Auto-update do APK do totem.
///
/// Fluxo: consulta `GET /kiosk/latest`, compara com o versionCode instalado; se
/// houver versão nova, baixa o APK, confere o `sha256` e chama a instalação
/// nativa (canal `gogem/updater` → PackageInstaller). Em totem "device owner" a
/// instalação é silenciosa; senão, o Android mostra o prompt de instalação.
class Updater {
  Updater(this._api);
  final GogemApi _api;

  static const MethodChannel _canal = MethodChannel('gogem/updater');

  /// versionCode do APK instalado (buildNumber do pubspec: `x.y.z+CODE`).
  Future<int> versaoInstalada() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Devolve a release se houver uma MAIS NOVA que a instalada; senão null.
  Future<KioskRelease?> checar() async {
    final r = await _api.latestRelease();
    if (r == null) return null;
    return r.versionCode > await versaoInstalada() ? r : null;
  }

  /// Baixa o APK, confere o sha256 e dispara a instalação nativa (só Android).
  Future<void> baixarEInstalar(KioskRelease r) async {
    if (!Platform.isAndroid) return;
    final res = await http
        .get(Uri.parse(r.apkUrl))
        .timeout(const Duration(minutes: 5));
    if (res.statusCode != 200) {
      throw Exception('download da atualização falhou (${res.statusCode})');
    }
    final bytes = res.bodyBytes;
    final hash = sha256.convert(bytes).toString();
    if (r.sha256.isNotEmpty && hash.toLowerCase() != r.sha256.toLowerCase()) {
      throw Exception('sha256 não confere — atualização descartada');
    }
    final dir = await getTemporaryDirectory();
    final arquivo = File(p.join(dir.path, 'gogem-${r.versionCode}.apk'));
    await arquivo.writeAsBytes(bytes, flush: true);
    await _canal.invokeMethod<void>('installApk', {'path': arquivo.path});
  }

  /// Verifica e, se houver update, baixa e instala. Nunca lança (não pode
  /// derrubar o totem) — em erro, tenta de novo na próxima janela.
  Future<void> verificarEAtualizar() async {
    try {
      final r = await checar();
      if (r != null) await baixarEInstalar(r);
    } catch (e) {
      debugPrint('[updater] falhou: $e');
    }
  }
}

final updaterProvider = Provider<Updater>((ref) {
  return Updater(ref.watch(gogemApiProvider));
});
