import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/kiosk/kiosk_service.dart';
import 'core/pareamento/device_token.dart';
import 'core/router.dart';
import 'core/telemetria/heartbeat.dart';
import 'core/telemetria/telemetria_reporter.dart';
import 'core/theme/gogem_theme.dart';
import 'data/catalog/aparencia.dart';
import 'data/catalog/catalog_sync.dart';
import 'data/update/updater.dart';
import 'domain/order/cart.dart';
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
        // Telemetria: heartbeat periódico (só envia quando pareado).
        ref.read(heartbeatProvider.notifier).iniciar();
        // Reporter de erros → Distribuição. Expõe a instância pros handlers
        // globais (main) que rodam fora do ProviderScope.
        TelemetriaReporter.instance = ref.read(telemetriaReporterProvider);
        // Update OBRIGATÓRIO: aplica no boot (não espera a janela de 3h).
        ref.read(updaterProvider).verificarObrigatorio();
        // Modo quiosque: fixa a tela (best-effort; silencioso sem Device Owner).
        KioskService.entrar();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tema DINÂMICO por loja (Fase 6): re-tematiza quando a aparência muda no
    // sync. Padrão GoGeM até carregar / offline sem dado salvo.
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    return MaterialApp.router(
      title: 'GoGeM',
      debugShowCheckedModeBanner: false,
      theme: temaDe(ap),
      routerConfig: router,
      // Idle inteligente (F4): sem toque por 90s no meio de um pedido → volta
      // ao descanso e limpa carrinho/checkout (o próximo cliente começa do
      // zero). Desligado em testes de widget (evita timer pendente).
      builder: widget.iniciarSync
          ? (context, child) =>
              _InatividadeGuard(child: child ?? const SizedBox.shrink())
          : null,
    );
  }
}

class _InatividadeGuard extends ConsumerStatefulWidget {
  const _InatividadeGuard({required this.child});
  final Widget child;
  @override
  ConsumerState<_InatividadeGuard> createState() => _InatividadeGuardState();
}

class _InatividadeGuardState extends ConsumerState<_InatividadeGuard> {
  Timer? _t;
  static const _limite = Duration(seconds: 90);

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _reset() {
    _t?.cancel();
    _t = Timer(_limite, _voltarAoDescanso);
  }

  void _voltarAoDescanso() {
    // Ir para /descanso é seguro em qualquer rota (o redirect trata /parear;
    // /descanso→/descanso é no-op). Limpa o pedido em andamento.
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    router.go('/descanso');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      child: widget.child,
    );
  }
}
