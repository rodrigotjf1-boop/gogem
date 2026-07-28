import 'package:flutter/services.dart';

/// Modo quiosque (lock task / fixação de tela do Android).
///
/// `entrar()` fixa o app na tela (o usuário não sai para o Android). Em um
/// device SEM Device Owner, o Android mostra o aviso nativo de "tela fixada"
/// (dá pra sair segurando Voltar+Visão geral) — já é uma barreira. Em um device
/// provisionado como **Device Owner**, a fixação é silenciosa e sem saída
/// (kiosk de verdade). O canal nativo está no MainActivity (Android).
///
/// Tudo é best-effort: em plataformas sem o canal (testes/desktop) as chamadas
/// falham silenciosamente e não quebram o app.
class KioskService {
  static const MethodChannel _canal = MethodChannel('gogem/kiosk');

  /// Entra no modo quiosque (fixa a tela).
  static Future<void> entrar() async {
    try {
      await _canal.invokeMethod<void>('entrar');
    } catch (_) {
      // sem canal nativo (ex.: teste) → ignora.
    }
  }

  /// Sai do modo quiosque (libera a tela) — usado na saída de manutenção.
  static Future<void> sair() async {
    try {
      await _canal.invokeMethod<void>('sair');
    } catch (_) {}
  }
}
