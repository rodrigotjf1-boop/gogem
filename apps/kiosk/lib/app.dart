import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/kiosk/inatividade_guard.dart';
import 'core/kiosk/kiosk_service.dart';
import 'core/pareamento/device_token.dart';
import 'core/tempo/relogio_servidor.dart';
import 'core/router.dart';
import 'core/telemetria/heartbeat.dart';
import 'core/telemetria/telemetria_reporter.dart';
import 'core/theme/gogem_theme.dart';
import 'data/catalog/aparencia.dart';
import 'data/catalog/catalog_sync.dart';
import 'data/update/updater.dart';
import 'domain/order/venda_sync.dart';

/// Modo quiosque (fixa a tela no Android). Ligado por padrão; nos builds de
/// TESTE (celular) sai com `--dart-define=GOGEM_KIOSK_LOCK=false`.
const _kioskLock = bool.fromEnvironment('GOGEM_KIOSK_LOCK', defaultValue: true);

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
        // K3 — o desvio de relógio guardado volta antes de tudo: um totem que reinicia
        // sem rede continua com a última hora boa, em vez do relógio torto do aparelho.
        ref.read(relogioServidorProvider.notifier).carregar();
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
        // Desligável p/ build de TESTE (celular): --dart-define=GOGEM_KIOSK_LOCK=false.
        if (_kioskLock) KioskService.entrar();
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
      // zero) — nunca durante uma venda. Desligado em testes de widget (evita
      // timer pendente).
      builder: widget.iniciarSync
          ? (context, child) => InatividadeGuard(
              aoExpirar: () => router.go('/descanso'),
              child: child ?? const SizedBox.shrink())
          : null,
    );
  }
}
