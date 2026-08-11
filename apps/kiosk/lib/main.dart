import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

/// Trava de quiosque no Windows (bloqueia fechar a janela — Alt+F4). Produção =
/// true; para testar sem travar, buildar com --dart-define=GOGEM_KIOSK_LOCK=false.
/// A trava do SO (impedir troca de app) é o Assigned Access do Windows (config,
/// ver docs/totem-windows.md), não código.
const _kioskLock = bool.fromEnvironment('GOGEM_KIOSK_LOCK', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // Totem em PC (F13). sqflite não tem plugin desktop → banco pelo FFI
    // (sqlite3 empacotado por sqlite3_flutter_libs).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Tela cheia (quiosque nível-app).
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        fullScreen: true,
        title: 'GoGeM',
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.setFullScreen(true);
        if (_kioskLock) await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  } else if (Platform.isAndroid) {
    // Totem Android: tela cheia imersiva + retrato travado.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(const ProviderScope(child: GogemKioskApp()));
}
