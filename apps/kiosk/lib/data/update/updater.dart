import 'dart:io';
import 'dart:isolate';

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
import 'play_updater.dart';

/// Como este aparelho instala uma versão nova (canal `gogem/updater`).
enum ModoInstalacao {
  /// Device Owner: instala sem perguntar.
  silencioso,

  /// O Android mostra a confirmação na tela e alguém precisa tocar em Instalar.
  confirmacao,

  /// Falta liberar "instalar apps desconhecidos" para o GoGeM.
  semPermissao,

  /// Sem o canal nativo (teste, desktop, build antigo).
  indisponivel,
}

ModoInstalacao modoInstalacaoDe(String? valor) => switch (valor) {
      'silencioso' => ModoInstalacao.silencioso,
      'confirmacao' => ModoInstalacao.confirmacao,
      'sem_permissao' => ModoInstalacao.semPermissao,
      _ => ModoInstalacao.indisponivel,
    };

/// De onde veio o pedido de atualizar.
enum MomentoDaAtualizacao { abertura, descanso, painel }

/// Instala agora? A confirmação do Android cobre a tela, então ela não aparece
/// para o cliente na tela de descanso: sai ao ligar o totem (quem ligou está
/// ali) ou pelo painel. A versão marcada como obrigatória é a exceção.
@visibleForTesting
bool deveInstalarAgora({
  required bool obrigatoria,
  required ModoInstalacao modo,
  required MomentoDaAtualizacao momento,
}) =>
    switch (modo) {
      ModoInstalacao.semPermissao || ModoInstalacao.indisponivel => false,
      ModoInstalacao.silencioso =>
        momento != MomentoDaAtualizacao.abertura || obrigatoria,
      ModoInstalacao.confirmacao =>
        momento != MomentoDaAtualizacao.descanso || obrigatoria,
    };

/// Auto-update do APK do totem.
///
/// Fluxo: consulta `GET /kiosk/latest`, compara com o versionCode instalado; se
/// houver versão nova e for a hora (`deveInstalarAgora`), baixa o APK, confere o
/// `sha256` e chama a instalação nativa (canal `gogem/updater` →
/// PackageInstaller). O cliente nunca é interrompido: o `ocioso` é conferido
/// depois do download, que pode levar minutos.
class Updater {
  Updater(this._api);
  final GogemApi _api;

  static const MethodChannel _canal = MethodChannel('gogem/updater');

  /// Tentativas de consultar a versão ao ligar: a rede do totem pode subir
  /// depois do app.
  static const int _tentativasNaAbertura = 3;

  /// Auto-update PRÓPRIO (baixa o APK e instala). Ligado por padrão (builds de
  /// sideload). Nos builds distribuídos pela **Google Play** sai com
  /// `--dart-define=GOGEM_SELF_UPDATE=false` — quem atualiza é o Play, e o
  /// install próprio falharia por assinatura diferente (Play App Signing).
  static const bool _selfUpdate =
      bool.fromEnvironment('GOGEM_SELF_UPDATE', defaultValue: true);

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

  Future<ModoInstalacao> modoInstalacao() async {
    try {
      return modoInstalacaoDe(
          await _canal.invokeMethod<String>('modoInstalacao'));
    } on PlatformException {
      return ModoInstalacao.indisponivel;
    } on MissingPluginException {
      return ModoInstalacao.indisponivel;
    }
  }

  /// Baixa o APK, confere o sha256 e dispara a instalação nativa (só Android).
  /// Com `ocioso` falso depois do download, não instala: o arquivo fica guardado
  /// para a próxima vez.
  Future<void> baixarEInstalar(KioskRelease r, {bool Function()? ocioso}) async {
    if (!Platform.isAndroid) return;
    final arquivo = await _baixar(r);
    if (ocioso != null && !ocioso()) {
      debugPrint('[updater] há cliente no totem: instalação fica para depois');
      return;
    }
    await _canal.invokeMethod<void>('installApk', {'path': arquivo.path});
  }

  /// Baixa direto para o disco (o APK tem 44 MB e o totem tem pouca memória) e
  /// reaproveita o que já foi baixado e conferido.
  Future<File> _baixar(KioskRelease r) async {
    final dir = await getTemporaryDirectory();
    final destino = File(p.join(dir.path, 'gogem-${r.versionCode}.apk'));
    await _apagarBaixados(dir, manter: p.basename(destino.path));
    final esperado = r.sha256.toLowerCase();
    if (esperado.isNotEmpty &&
        await destino.exists() &&
        await _resumoDe(destino.path) == esperado) {
      return destino;
    }
    final parcial = File('${destino.path}.parcial');
    final cliente = http.Client();
    try {
      final res = await cliente
          .send(http.Request('GET', Uri.parse(r.apkUrl)))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('download da atualização falhou (${res.statusCode})');
      }
      await res.stream
          .timeout(const Duration(seconds: 60))
          .pipe(parcial.openWrite());
    } finally {
      cliente.close();
    }
    if (esperado.isNotEmpty && await _resumoDe(parcial.path) != esperado) {
      await parcial.delete();
      throw Exception('sha256 não confere — atualização descartada');
    }
    return parcial.rename(destino.path);
  }

  /// Fora da thread da tela: 44 MB travariam a animação do totem.
  static Future<String> _resumoDe(String caminho) => Isolate.run(() async {
        final d = await sha256.bind(File(caminho).openRead()).first;
        return d.toString();
      });

  Future<void> _apagarBaixados(Directory dir, {String? manter}) async {
    await for (final e in dir.list()) {
      final nome = p.basename(e.path);
      if (e is File &&
          nome != manter &&
          RegExp(r'^gogem-\d+\.apk(\.parcial)?$').hasMatch(nome)) {
        await e.delete();
      }
    }
  }

  /// Tela de descanso (a cada 3h). Nunca lança (não pode derrubar o totem) — em
  /// erro, tenta de novo na próxima janela.
  Future<void> verificarEAtualizar({bool Function()? ocioso}) async {
    if (!_selfUpdate) return PlayUpdater.verificarEPrompt(); // canal Play
    try {
      final r = await checar();
      if (r == null) return;
      await _aplicar(r, MomentoDaAtualizacao.descanso, ocioso);
    } catch (e) {
      debugPrint('[updater] falhou: $e');
    }
  }

  /// Ao ligar o totem. Device Owner aplica já só a obrigatória (a outra segue no
  /// ciclo do descanso); nos demais é o momento de pedir a confirmação de
  /// qualquer versão nova. Nunca lança.
  Future<void> verificarObrigatorio({bool Function()? ocioso}) async {
    if (!_selfUpdate) return PlayUpdater.verificarEPrompt(); // canal Play
    try {
      final r = await _checarNaAbertura();
      if (r == null) {
        if (Platform.isAndroid) {
          await _apagarBaixados(await getTemporaryDirectory());
        }
        return;
      }
      await _aplicar(r, MomentoDaAtualizacao.abertura, ocioso);
    } catch (e) {
      debugPrint('[updater] na abertura falhou: $e');
    }
  }

  Future<KioskRelease?> _checarNaAbertura() async {
    for (var tentativa = 1;; tentativa++) {
      try {
        return await checar();
      } catch (e) {
        if (tentativa >= _tentativasNaAbertura) rethrow;
        debugPrint('[updater] sem resposta ($tentativa): $e');
        await Future<void>.delayed(const Duration(minutes: 1));
      }
    }
  }

  Future<void> _aplicar(KioskRelease r, MomentoDaAtualizacao momento,
      bool Function()? ocioso) async {
    final modo = await modoInstalacao();
    if (deveInstalarAgora(
        obrigatoria: r.obrigatorio, modo: modo, momento: momento)) {
      await baixarEInstalar(r, ocioso: ocioso);
    } else {
      debugPrint('[updater] ${r.versionName} disponível, sem instalar agora '
          '(${modo.name}, ${momento.name})');
    }
  }

  /// Botão do painel do totem. Devolve a frase para o operador.
  Future<String> atualizarAgora() async {
    if (!_selfUpdate) {
      await PlayUpdater.verificarEPrompt();
      return 'conferido na Google Play';
    }
    final r = await checar();
    if (r == null) return 'já está na versão mais nova';
    final modo = await modoInstalacao();
    if (modo == ModoInstalacao.semPermissao) {
      return 'libere "instalar apps desconhecidos" para o GoGeM';
    }
    if (!deveInstalarAgora(
        obrigatoria: r.obrigatorio,
        modo: modo,
        momento: MomentoDaAtualizacao.painel)) {
      return 'este aparelho não instala pelo app';
    }
    await baixarEInstalar(r);
    return modo == ModoInstalacao.silencioso
        ? 'instalando a ${r.versionName}'
        : 'toque em Instalar na tela (${r.versionName})';
  }
}

final updaterProvider = Provider<Updater>((ref) {
  return Updater(ref.watch(gogemApiProvider));
});
