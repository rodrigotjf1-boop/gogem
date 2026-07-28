// MainActivity com suporte a MODO QUIOSQUE (lock task).
//
// Este arquivo é COPIADO pelo workflow build-apk.yml para o projeto Android
// gerado por `flutter create --org com.dms.gogem` (a pasta android/ não é
// versionada). O canal 'gogem/kiosk' liga o KioskService (Dart) ao lock task
// nativo: entrar() = startLockTask, sair() = stopLockTask.
//
// Sem Device Owner, o Android mostra o aviso de "tela fixada" (barreira leve);
// como Device Owner, a fixação é silenciosa e sem saída (kiosk de verdade).
package com.dms.gogem.gogem_kiosk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val canal = "gogem/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "entrar" -> {
                        try {
                            startLockTask()
                        } catch (e: Exception) {
                        }
                        result.success(null)
                    }
                    "sair" -> {
                        try {
                            stopLockTask()
                        } catch (e: Exception) {
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
