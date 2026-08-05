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
 * MainActivity + canais nativos:
 *  - `gogem/updater` — auto-update do APK (PackageInstaller).
 *  - `gogem/tef` — TEF Elgin via IDH (Intent `com.elgin.e1.digitalhub.TEF` +
 *    startActivityForResult; a resposta volta no onActivityResult como `retorno`).
 */
class MainActivity : FlutterActivity() {
    private val canalUpdater = "gogem/updater"
    private val canalTef = "gogem/tef"
    private val tefRequest = 1234
    private val tefAction = "com.elgin.e1.digitalhub.TEF"

    /** Result pendente da transação TEF (completada no onActivityResult). */
    private var tefResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, canalUpdater).setMethodCallHandler { call, result ->
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

        MethodChannel(messenger, canalTef).setMethodCallHandler { call, result ->
            when (call.method) {
                "disponivel" -> result.success(idhDisponivel())
                "executar" -> executarTef(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    /** Dispara uma função do IDH ElginTef; a resposta volta no onActivityResult. */
    private fun executarTef(args: Any?, result: MethodChannel.Result) {
        if (tefResult != null) {
            result.error("BUSY", "Transação TEF em andamento", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val extras = (args as? Map<String, Any?>) ?: emptyMap()
        try {
            val i = Intent(tefAction)
            for ((k, v) in extras) i.putExtra(k, "$v")
            tefResult = result
            startActivityForResult(i, tefRequest)
        } catch (e: Exception) {
            tefResult = null
            result.error("TEF", e.message ?: "falha ao iniciar o TEF", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != tefRequest) return
        val pendente = tefResult
        tefResult = null
        val retorno = data?.getStringExtra("retorno")
        // Sem retorno (ex.: RESULT_CANCELED) → sinaliza cancelamento p/ o Dart.
        pendente?.success(
            if (!retorno.isNullOrEmpty()) retorno
            else "{\"mensagem\":\"Operação cancelada\"}",
        )
    }

    /** IDH ElginTef instalado e capaz de atender o Intent? */
    private fun idhDisponivel(): Boolean = try {
        Intent(tefAction).resolveActivity(packageManager) != null
    } catch (e: Exception) {
        false
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
