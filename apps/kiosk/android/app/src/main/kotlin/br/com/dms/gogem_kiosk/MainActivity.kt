package br.com.dms.gogem_kiosk

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * MainActivity + canal nativo de auto-update (`gogem/updater`).
 *
 * `installApk(path)` instala o APK baixado pelo Dart via PackageInstaller. Em
 * totem provisionado como **device owner**, a instalação é SILENCIOSA (sem UI);
 * em aparelho comum, o Android mostra o prompt de confirmação. Nos dois casos o
 * app é substituído e o processo reinicia na nova versão.
 */
class MainActivity : FlutterActivity() {
    private val canal = "gogem/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("ARG", "path do APK ausente", null)
                        } else {
                            try {
                                instalarApk(path)
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("INSTALL", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun instalarApk(path: String) {
        val apk = File(path)
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("gogem.apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            // IntentSender de status. Em device owner o commit instala sozinho;
            // em aparelho comum o sistema mostra o prompt de instalação.
            val intent = Intent(this, MainActivity::class.java)
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            val pending = PendingIntent.getActivity(this, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
    }
}
