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
package com.dms.gogem.gogem_kiosk

import android.content.Context
import android.hardware.usb.*
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
        val dev = mgr.deviceList.values.firstOrNull { it.vendorId == 0x04B8 } ?: return false
        if (!mgr.hasPermission(dev)) return false // concedida pelo USB_DEVICE_ATTACHED (device_filter)
        val ifc = (0 until dev.interfaceCount).map { dev.getInterface(it) }
            .firstOrNull { it.interfaceClass == UsbConstants.USB_CLASS_PRINTER } ?: dev.getInterface(0)
        val c = mgr.openDevice(dev) ?: return false
        if (!c.claimInterface(ifc, true)) return false
        for (i in 0 until ifc.endpointCount) {
            val ep = ifc.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (ep.direction == UsbConstants.USB_DIR_OUT) epOut = ep else epIn = ep
            }
        }
        conn = c; iface = ifc
        return epOut != null && epIn != null
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
        val buf = ByteArray(max)
        val n = synchronized(epInLock) { conn?.bulkTransfer(epIn, buf, max, timeoutMs) ?: -1 }
        if (n <= 0) return ByteArray(0)
        return buf.copyOf(n)
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
