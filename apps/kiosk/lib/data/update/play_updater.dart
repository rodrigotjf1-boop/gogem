import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Atualização pela **Google Play** (In-App Update). Só funciona em app
/// instalado pela Play (não em sideload/debug). Detecta versão nova e dispara o
/// fluxo IMEDIATO — o Google mostra a tela pedindo autorização e atualiza.
///
/// Usado nos builds do Play (`--dart-define=GOGEM_SELF_UPDATE=false`); os builds
/// de sideload seguem no updater próprio (`Updater`).
class PlayUpdater {
  const PlayUpdater._();

  /// Checa no Play e, se houver versão nova permitida, pede autorização e
  /// atualiza. Nunca lança (não pode derrubar o totem).
  static Future<void> verificarEPrompt() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('[play-update] falhou: $e');
    }
  }
}
