import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/pareamento/device_token.dart';
import 'core/router.dart';
import 'core/theme/gogem_theme.dart';
import 'data/catalog/catalog_sync.dart';
import 'domain/order/venda_sync.dart';

class GogemKioskApp extends ConsumerStatefulWidget {
  const GogemKioskApp({super.key, this.iniciarSync = true});
  /// Desligável em testes de widget (evita rede/banco reais).
  final bool iniciarSync;
  @override
  ConsumerState<GogemKioskApp> createState() => _GogemKioskAppState();
}

class _GogemKioskAppState extends ConsumerState<GogemKioskApp> {
  @override
  void initState() {
    super.initState();
    if (widget.iniciarSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Resolve o pareamento (token salvo ou JWT de dev) → destrava o portão
        // do router; sem isso o app fica no descanso (carregando) até parear.
        ref.read(deviceTokenProvider.notifier).carregar();
        ref.read(catalogSyncProvider.notifier).iniciarAgendador();
        ref.read(vendaSyncProvider.notifier).iniciarAgendador();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'GoGeM',
        debugShowCheckedModeBanner: false,
        theme: gogemTheme(),
        routerConfig: router,
      );
}
