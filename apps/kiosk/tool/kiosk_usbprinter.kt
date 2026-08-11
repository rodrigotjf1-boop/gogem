// Plugin USB da impressora (TM-T88VII) — canal `gogem/usb_printer`
// (open/close/write/read) + EventChannel `gogem/usb_printer/asb`.
//
// COPIADO pelo build-apk.yml para o projeto Android gerado por
// `flutter create --org com.dms.gogem` (a pasta android/ não é versionada).
// Registrado no MainActivity.configureFlutterEngine.
//
// O endpoint IN é COMPARTILHADO entre a leitura síncrona (DLE EOT, dentro de
// `read`) e a thread de ASB (pacotes espontâneos de 4 bytes). Duas bulkTransfer
// concorrentes no mesmo endpoint se atrapalham → serializamos por `epInLock`.
//
// Permissão USB: o auto-grant pelo device_filter é frágil (só quando o SO roteia
// o attach pro app). Então, se `hasPermission` for false, PEDIMOS o diálogo do
// sistema (requestPermission). Logs em `adb logcat -s UsbPrinter` mostram cada
// passo (VID/PID, sem permissão, sem endpoint).
package br.com.dms.gogem_kiosk

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class UsbPrinterPlugin(private val ctx: Context) {
    private var conn: UsbDeviceConnection? = null
    private var epOut: UsbEndpoint? = null
    private var epIn: UsbEndpoint? = null
    private var iface: UsbInterface? = null
    private var asbSink: EventChannel.EventSink? = null
    @Volatile private var lendo = false

    // Serializa o acesso ao endpoint IN (read síncrono x thread ASB).
    private val epInLock = Any()

    private var permReceiver: BroadcastReceiver? = null
    @Volatile private var pedindoPermissao = false

    companion object {
        private const val TAG = "UsbPrinter"
        private const val EPSON_VID = 0x04B8
        private const val ACAO_PERMISSAO = "br.com.dms.gogem_kiosk.USB_PERMISSION"
    }

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "gogem/usb_printer")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "open" -> result.success(abrir())
                        "close" -> { fechar(); result.success(null) }
                        "write" -> { escrever(call.arguments as ByteArray); result.success(null) }
                        "read" -> {
                            val args = call.arguments as Map<*, *>
                            result.success(ler(args["max"] as Int, args["timeoutMs"] as Int))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("USB", e.message, null)
                }
            }
        EventChannel(engine.dartExecutor.binaryMessenger, "gogem/usb_printer/asb")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(a: Any?, sink: EventChannel.EventSink) {
                    asbSink = sink; iniciarLeituraAsb()
                }
                override fun onCancel(a: Any?) {
                    asbSink = null; lendo = false
                }
            })
    }

    private fun abrir(): Boolean {
        val mgr = ctx.getSystemService(Context.USB_SERVICE) as UsbManager
        val todos = mgr.deviceList.values
        Log.i(TAG, "USB conectados: " + (todos.joinToString {
            "vid=0x%04X pid=0x%04X cls=%d".format(it.vendorId, it.productId, it.deviceClass)
        }.ifEmpty { "(nenhum)" }))
        // Epson por VID; se não achar, tenta um dispositivo com interface de
        // impressora (classe 7) — clones/genéricos usam outro VID.
        val dev = todos.firstOrNull { it.vendorId == EPSON_VID }
            ?: todos.firstOrNull { d ->
                (0 until d.interfaceCount).any {
                    d.getInterface(it).interfaceClass == UsbConstants.USB_CLASS_PRINTER
                }
            }
        if (dev == null) {
            Log.w(TAG, "nenhuma impressora encontrada (nem Epson 0x04B8 nem classe 7)")
            return false
        }
        if (!mgr.hasPermission(dev)) {
            Log.w(TAG, "sem permissão para vid=0x%04X — abrindo diálogo".format(dev.vendorId))
            solicitarPermissao(mgr, dev)
            return false
        }
        val ifc = (0 until dev.interfaceCount).map { dev.getInterface(it) }
            .firstOrNull { it.interfaceClass == UsbConstants.USB_CLASS_PRINTER }
            ?: dev.getInterface(0)
        val c = mgr.openDevice(dev)
        if (c == null) { Log.w(TAG, "openDevice falhou"); return false }
        if (!c.claimInterface(ifc, true)) {
            Log.w(TAG, "claimInterface falhou"); c.close(); return false
        }
        epOut = null; epIn = null
        for (i in 0 until ifc.endpointCount) {
            val ep = ifc.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (ep.direction == UsbConstants.USB_DIR_OUT) epOut = ep else epIn = ep
            }
        }
        conn = c; iface = ifc
        val ok = epOut != null && epIn != null
        Log.i(TAG, "conectada=$ok (epOut=${epOut != null} epIn=${epIn != null})")
        return ok
    }

    /** Diálogo do sistema pedindo acesso à impressora. */
    private fun solicitarPermissao(mgr: UsbManager, dev: UsbDevice) {
        if (pedindoPermissao) return
        pedindoPermissao = true
        if (permReceiver == null) {
            permReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context, i: Intent) {
                    pedindoPermissao = false
                    val ok = i.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    Log.i(TAG, "permissão USB concedida=$ok")
                }
            }
            val filtro = IntentFilter(ACAO_PERMISSAO)
            if (Build.VERSION.SDK_INT >= 33) {
                ctx.registerReceiver(permReceiver, filtro, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                ctx.registerReceiver(permReceiver, filtro)
            }
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getBroadcast(
            ctx, 0, Intent(ACAO_PERMISSAO).setPackage(ctx.packageName), flags
        )
        mgr.requestPermission(dev, pi)
    }

    private fun fechar() {
        lendo = false
        iface?.let { conn?.releaseInterface(it) }
        conn?.close()
        conn = null
    }

    private fun escrever(b: ByteArray) {
        val n = conn?.bulkTransfer(epOut, b, b.size, 4000) ?: -1
        if (n < 0) throw RuntimeException("bulkTransfer OUT falhou")
    }

    private fun ler(max: Int, timeoutMs: Int): ByteArray {
        val ep = epIn ?: return ByteArray(0)
        // Bulk IN precisa de um buffer >= tamanho do pacote do endpoint (ex.: 64B).
        // Pedir só `max` (1 byte no DLE EOT) faz o controlador rejeitar (-1).
        val cap = maxOf(max, ep.maxPacketSize)
        val buf = ByteArray(cap)
        val n = synchronized(epInLock) { conn?.bulkTransfer(ep, buf, cap, timeoutMs) ?: -1 }
        if (n <= 0) return ByteArray(0)
        return buf.copyOf(minOf(n, max))
    }

    /** Thread de leitura contínua para ASB (pacotes de 4 bytes espontâneos). */
    private fun iniciarLeituraAsb() {
        if (lendo) return
        lendo = true
        Thread {
            val buf = ByteArray(4)
            while (lendo && conn != null) {
                val n = synchronized(epInLock) { conn?.bulkTransfer(epIn, buf, 4, 300) ?: -1 }
                if (n == 4) {
                    val copia = buf.copyOf()
                    android.os.Handler(ctx.mainLooper).post { asbSink?.success(copia) }
                }
            }
        }.start()
    }
}
