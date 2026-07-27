import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:gogem_escpos/escpos.dart';

/// Transporte USB via platform channel Android (`gogem/usb_printer`).
/// O lado nativo (Kotlin) está em ANDROID-USB.md — colar após o
/// `flutter create`. Sem o plugin, open() falha e o health marca
/// "desconectada" (nunca derruba o app).
class UsbChannelTransport implements PrinterTransport {
  static const _ch = MethodChannel('gogem/usb_printer');
  static const _ev = EventChannel('gogem/usb_printer/asb');

  @override
  Future<void> open() async {
    try {
      final ok = await _ch.invokeMethod<bool>('open') ?? false;
      if (!ok) throw const PrinterDisconnected('USB não encontrada');
    } on PlatformException catch (e) {
      throw PrinterDisconnected('USB: ${e.message}');
    } on MissingPluginException {
      throw const PrinterDisconnected('plugin USB ausente');
    }
  }

  @override
  Future<void> close() => _ch.invokeMethod('close');

  @override
  Future<void> write(Uint8List bytes) async {
    try {
      await _ch.invokeMethod('write', bytes);
    } on PlatformException catch (e) {
      throw PrinterDisconnected('USB write: ${e.message}');
    }
  }

  @override
  Future<Uint8List> read(int max, {Duration timeout = const Duration(seconds: 2)}) async {
    final r = await _ch.invokeMethod<Uint8List>(
        'read', {'max': max, 'timeoutMs': timeout.inMilliseconds});
    if (r == null || r.isEmpty) throw const PrinterTimeout();
    return r;
  }

  @override
  Stream<Uint8List> get incoming =>
      _ev.receiveBroadcastStream().map((e) => e as Uint8List);
}
