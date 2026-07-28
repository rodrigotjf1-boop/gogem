import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_escpos/escpos.dart';
import '../../core/config/app_config.dart';
import '../../core/kiosk/kiosk_service.dart';
import '../../core/theme/gogem_theme.dart';
import '../../data/catalog/catalog_sync.dart';
import '../../domain/order/venda_sync.dart';
import '../../printing/fila_impressao.dart';
import '../../printing/printer_providers.dart';

/// Painel administrativo (F5) — acessível só via PIN embaralhado.
/// Paridade+ com o baseline do mercado: diagnósticos, sync, teste de
/// impressora, DRENAGEM DA FILA DE REIMPRESSÃO, envio de vendas e saída
/// controlada do modo kiosk.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  String? _ocupado;
  int _filaImpressao = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refrescar());
  }

  Future<void> _refrescar() async {
    try {
      final fila = await ref.read(filaImpressaoProvider.future);
      final n = await fila.pendentes();
      await ref.read(vendaSyncProvider.notifier).atualizarContagem();
      if (mounted) setState(() => _filaImpressao = n);
    } catch (_) {
      // diagnóstico não deve derrubar o painel; segue com o último estado
    }
  }

  Future<void> _acao(String nome, Future<String> Function() fn) async {
    setState(() => _ocupado = nome);
    String msg;
    try {
      msg = await fn();
    } catch (e) {
      msg = 'falhou: $e';
    }
    if (!mounted) return;
    setState(() => _ocupado = null);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(
        content: Text('$nome: $msg'),
        duration: const Duration(seconds: 2)));
    await _refrescar();
  }

  Future<String> _testarImpressora() async {
    final d = ref.read(printerDriverProvider);
    final s = await d.imprimir((EscPosBuilder()
          ..texto('GOGEM — TESTE DE IMPRESSORA', negrito: true, centro: true)
          ..texto(DateTime.now().toString().substring(0, 19), centro: true)
          ..corte())
        .build());
    return s.prontaParaVenda ? 'impresso, status OK' : 'status: ${s.motivoBloqueio}';
  }

  Future<String> _reimprimirFila() async {
    final fila = await ref.read(filaImpressaoProvider.future);
    final d = ref.read(printerDriverProvider);
    var ok = 0;
    for (final row in await fila.listar()) {
      final cupom = row['cupom'];
      if (cupom is! List<int>) continue;
      final s = await d.imprimir(Uint8List.fromList(cupom));
      if (s.prontaParaVenda) {
        await fila.remover(row['uuid'] as String);
        ok++;
      } else {
        return '$ok reimpressos; parado: ${s.motivoBloqueio}';
      }
    }
    return '$ok cupom(ns) reimpressos';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final saude = ref.watch(printerHealthProvider);
    final cat = ref.watch(catalogSyncProvider);
    final vendas = ref.watch(vendaSyncProvider);
    final cfg = ref.watch(appConfigProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            Expanded(
              child: Text('PAINEL DO TOTEM',
                  style: t.headlineMedium, overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              key: const ValueKey('voltar-totem'),
              onPressed: () => context.go('/descanso'),
              child: const Text('VOLTAR AO TOTEM',
                  style: TextStyle(color: GogemColors.mint, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 16),
          _Info('Impressora',
              saude.desconectada ? 'DESCONECTADA' : saude.motivo.toUpperCase(),
              alerta: !saude.prontaParaVenda),
          _Info('Papel', saude.pertoDoFim ? 'ACABANDO (near-end)' : 'ok',
              alerta: saude.pertoDoFim),
          _Info('Cardápio', 'versão ${cat.versao ?? '-'} · ${cat.status.name}'),
          _Info('Vendas pendentes de envio', '${vendas.pendentes}',
              alerta: vendas.pendentes > 0),
          _Info('Fila de reimpressão', '$_filaImpressao',
              alerta: _filaImpressao > 0, key: const ValueKey('info-fila')),
          _Info('API', cfg.apiUrl),
          const SizedBox(height: 24),
          _Botao('SINCRONIZAR CARDÁPIO', _ocupado,
              key: const ValueKey('acao-sync'),
              onTap: () => _acao('Sincronizar', () async {
                    await ref.read(catalogSyncProvider.notifier).sincronizar();
                    final s = ref.read(catalogSyncProvider);
                    return 'v${s.versao ?? '-'} (${s.status.name})';
                  })),
          _Botao('TESTAR IMPRESSORA', _ocupado,
              key: const ValueKey('acao-teste-imp'),
              onTap: () => _acao('Teste de impressão', _testarImpressora)),
          _Botao('REIMPRIMIR FILA ($_filaImpressao)', _ocupado,
              key: const ValueKey('acao-reimprimir'),
              onTap: () => _acao('Reimpressão', _reimprimirFila)),
          _Botao('ENVIAR VENDAS AGORA (${vendas.pendentes})', _ocupado,
              key: const ValueKey('acao-enviar-vendas'),
              onTap: () => _acao('Envio de vendas', () async {
                    await ref.read(vendaSyncProvider.notifier).drenar();
                    return ref.read(vendaSyncProvider).msg ?? 'fila vazia';
                  })),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const ValueKey('sair-kiosk'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                side: const BorderSide(color: GogemColors.heat),
                foregroundColor: GogemColors.heat),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dctx) => AlertDialog(
                backgroundColor: GogemColors.panel,
                title: const Text('Sair do modo kiosk?'),
                content: const Text(
                    'O aplicativo será fechado para manutenção do sistema.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('CANCELAR')),
                  FilledButton(
                      key: const ValueKey('confirmar-sair'),
                      onPressed: () async {
                        // Libera o modo quiosque ANTES de fechar (manutenção).
                        await KioskService.sair();
                        await SystemNavigator.pop();
                      },
                      child: const Text('SAIR')),
                ],
              ),
            ),
            child: const Text('SAIR DO MODO KIOSK (manutenção)'),
          ),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.rotulo, this.valor, {this.alerta = false, super.key});
  final String rotulo;
  final String valor;
  final bool alerta;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GogemColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: alerta ? GogemColors.cheese : GogemColors.line),
        ),
        child: Row(children: [
          Expanded(
              child: Text(rotulo,
                  style: const TextStyle(color: GogemColors.inkDim, fontSize: 15))),
          Text(valor,
              style: TextStyle(
                  fontFamily: 'Tektur',
                  fontSize: 15,
                  color: alerta ? GogemColors.cheese : GogemColors.ink)),
        ]),
      );
}

class _Botao extends StatelessWidget {
  const _Botao(this.rotulo, this.ocupado, {required this.onTap, super.key});
  final String rotulo;
  final String? ocupado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: GogemColors.panel,
              foregroundColor: GogemColors.ink,
              side: const BorderSide(color: GogemColors.line)),
          onPressed: ocupado == null ? onTap : null,
          child: Text(rotulo, style: const TextStyle(fontSize: 18)),
        ),
      );
}
