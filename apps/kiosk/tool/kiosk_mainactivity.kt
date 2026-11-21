// MainActivity do totem — a ÚNICA fonte (ERR-050).
//
// Este arquivo é COPIADO pelos workflows build-apk.yml e build-play-aab.yml para
// o projeto Android gerado por `flutter create`. Havia uma segunda MainActivity
// versionada em android/, com o atualizador e o TEF, que o build sobrescrevia:
// o APK saía sem esses canais. Canal novo entra AQUI; o teste
// `test/canais_nativos_test.dart` e o portão dos workflows reprovam o que faltar.
//
// Canais:
//  - `gogem/kiosk` — modo quiosque: entrar() = startLockTask, sair() = stopLockTask.
//    Sem Device Owner, o Android mostra o aviso de "tela fixada" (barreira leve);
//    como Device Owner, a fixação é silenciosa e sem saída (kiosk de verdade).
//  - `gogem/usb_printer` — impressora TM-T88 (registrado pelo UsbPrinterPlugin).
//  - `gogem/updater` — atualização do APK (PackageInstaller). Device Owner instala
//    sem perguntar; nos demais o Android pede a confirmação na tela.
//  - `gogem/tef` — TEF Elgin via IDH (Intent `com.elgin.e1.digitalhub.TEF` +
//    startActivityForResult; a resposta volta no onActivityResult como `retorno`).
package br.com.dms.gogem_kiosk

import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val canalKiosk = "gogem/kiosk"
    private val canalUpdater = "gogem/updater"
    private val canalTef = "gogem/tef"
    private val tefRequest = 1234
    private val instalacaoRequest = 1235
    private val tefAction = "com.elgin.e1.digitalhub.TEF"

    /** A confirmação do Android some sozinha: o totem nunca fica preso nela. */
    private val prazoDaConfirmacaoMs = 120_000L

    /** Depois do toque, o resultado chega pelo receptor; isto só solta a trava se não chegar. */
    private val prazoDoResultadoMs = 180_000L

    /** Result pendente da transação TEF (completada no onActivityResult). */
    private var tefResult: MethodChannel.Result? = null

    private val principal = Handler(Looper.getMainLooper())
    private var sessaoInstalacao: Int? = null
    private var receptorLigado = false

    private val venceConfirmacao = Runnable {
        Log.i("GoGeM", "atualização: ninguém confirmou, a tela volta para a venda")
        finishActivity(instalacaoRequest)
        encerrarInstalacao(abandonar = true)
    }
    private val venceResultado = Runnable { encerrarInstalacao(abandonar = false) }

    private val receptorInstalacao = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val sessao = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
            if (sessao != sessaoInstalacao) return
            val status = intent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE,
            )
            if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                @Suppress("DEPRECATION")
                val confirmar = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirmar == null) {
                    encerrarInstalacao(abandonar = true)
                } else {
                    abrirConfirmacao(confirmar)
                }
                return
            }
            val detalhe = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
            Log.i("GoGeM", "atualização: status=$status $detalhe")
            encerrarInstalacao(abandonar = false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Impressora USB (canal gogem/usb_printer + ASB).
        UsbPrinterPlugin(applicationContext).registrar(flutterEngine)

        MethodChannel(messenger, canalKiosk).setMethodCallHandler { call, result ->
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

        MethodChannel(messenger, canalUpdater).setMethodCallHandler { call, result ->
            when (call.method) {
                "modoInstalacao" -> result.success(modoInstalacao())
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("ARG", "path do APK ausente", null)
                    } else {
                        instalarApk(path, result)
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
        if (requestCode == instalacaoRequest) {
            // O instalador devolve "cancelado" mesmo quando a pessoa aceita, e a
            // instalação segue. Por isso NÃO se abandona a sessão aqui: quem diz o
            // que aconteceu é o receptor.
            principal.removeCallbacks(venceConfirmacao)
            if (sessaoInstalacao != null) {
                principal.postDelayed(venceResultado, prazoDoResultadoMs)
            }
            return
        }
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

    override fun onDestroy() {
        principal.removeCallbacks(venceConfirmacao)
        principal.removeCallbacks(venceResultado)
        soltarReceptor()
        super.onDestroy()
    }

    /** IDH ElginTef instalado e capaz de atender o Intent? */
    private fun idhDisponivel(): Boolean = try {
        Intent(tefAction).resolveActivity(packageManager) != null
    } catch (e: Exception) {
        false
    }

    /** Como este aparelho instala uma versão nova (o Dart decide quando). */
    private fun modoInstalacao(): String {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        if (dpm.isDeviceOwnerApp(packageName)) return "silencioso"
        val liberado = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
        return if (liberado) "confirmacao" else "sem_permissao"
    }

    private fun instalarApk(path: String, result: MethodChannel.Result) {
        if (sessaoInstalacao != null) {
            result.error("BUSY", "Instalação em andamento", null)
            return
        }
        val installer = packageManager.packageInstaller
        // Ação sorteada por instalação: em Android < 13 o receptor registrado em
        // código é visível a outros apps, e ele abre o Intent que recebe.
        val acao = "$packageName.INSTALACAO.${UUID.randomUUID()}"
        val sessao = try {
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            )
            params.setAppPackageName(packageName)
            installer.createSession(params)
        } catch (e: Exception) {
            result.error("INSTALL", e.message, null)
            return
        }
        sessaoInstalacao = sessao
        ligarReceptor(acao)

        // Copiar 44 MB na thread principal congelaria a tela do totem.
        Thread {
            try {
                val apk = File(path)
                installer.openSession(sessao).use { session ->
                    apk.inputStream().use { input ->
                        session.openWrite("gogem.apk", 0, apk.length()).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    val intent = Intent(acao).setPackage(packageName)
                    var flags = PendingIntent.FLAG_UPDATE_CURRENT
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        flags = flags or PendingIntent.FLAG_MUTABLE
                    }
                    val pendente = PendingIntent.getBroadcast(this, sessao, intent, flags)
                    session.commit(pendente.intentSender)
                }
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread {
                    encerrarInstalacao(abandonar = true)
                    result.error("INSTALL", e.message, null)
                }
            }
        }.start()
    }

    /**
     * Abre a confirmação na MESMA tarefa (sem NEW_TASK): com a tela fixada, abrir
     * outra tarefa seria recusado pelo Android.
     */
    private fun abrirConfirmacao(confirmar: Intent) {
        try {
            startActivityForResult(confirmar, instalacaoRequest)
            principal.postDelayed(venceConfirmacao, prazoDaConfirmacaoMs)
        } catch (e: Exception) {
            Log.w("GoGeM", "atualização: não abriu a confirmação: ${e.message}")
            encerrarInstalacao(abandonar = true)
        }
    }

    private fun encerrarInstalacao(abandonar: Boolean) {
        val sessao = sessaoInstalacao ?: return
        sessaoInstalacao = null
        principal.removeCallbacks(venceConfirmacao)
        principal.removeCallbacks(venceResultado)
        soltarReceptor()
        if (abandonar) {
            try {
                packageManager.packageInstaller.abandonSession(sessao)
            } catch (e: Exception) {
            }
        }
    }

    private fun ligarReceptor(acao: String) {
        soltarReceptor()
        val filtro = IntentFilter(acao)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receptorInstalacao, filtro, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receptorInstalacao, filtro)
        }
        receptorLigado = true
    }

    private fun soltarReceptor() {
        if (!receptorLigado) return
        receptorLigado = false
        try {
            unregisterReceiver(receptorInstalacao)
        } catch (e: Exception) {
        }
    }
}
