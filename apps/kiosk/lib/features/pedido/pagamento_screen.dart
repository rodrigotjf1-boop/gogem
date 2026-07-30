import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../domain/order/cart.dart';
import '../../domain/order/order_models.dart';
import '../../domain/order/order_repository.dart';
import '../../domain/order/venda_sync.dart';
import '../../printing/fila_impressao.dart';
import '../../printing/printer_providers.dart';
import '../../printing/recibo.dart';

/// Pagamento (mock na F3/F4; a F6 troca pelo POST real + TEF).
/// PORTÃO 2 (F4): checagem SÍNCRONA da impressora ao entrar E imediatamente
/// antes de cobrar — NUNCA cobrar sem poder concluir. Se o papel acabar na
/// janela residual pós-pagamento, o pedido não se perde: senha na tela +
/// fila de reimpressão.
class PagamentoScreen extends ConsumerStatefulWidget {
  const PagamentoScreen(
      {super.key, this.processamento = const Duration(milliseconds: 900)});
  final Duration processamento;
  @override
  ConsumerState<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends ConsumerState<PagamentoScreen> {
  bool _processando = false;
  bool _bloqueado = false;
  String _motivo = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _portao());
  }

  Future<void> _portao() async {
    final h = await ref.read(printerHealthProvider.notifier).checarAgora();
    if (!mounted) return;
    setState(() {
      _bloqueado = !h.prontaParaVenda;
      _motivo = h.motivo;
    });
  }

  Future<void> _pagar(FormaPagamento forma) async {
    final cart = ref.read(cartProvider);
    if (cart.vazio || _processando) return;
    // reconfere na hora de cobrar (o papel pode ter acabado AGORA)
    final h = await ref.read(printerHealthProvider.notifier).checarAgora();
    if (!h.prontaParaVenda) {
      if (!mounted) return;
      setState(() {
        _bloqueado = true;
        _motivo = h.motivo;
      });
      return;
    }
    setState(() => _processando = true);
    await Future<void>.delayed(widget.processamento); // simula a integradora

    final checkout = ref.read(checkoutProvider);
    final pedido = PedidoLocal(
      itens: cart.itens,
      forma: forma,
      cpf: checkout.cpf,
      cliente: checkout.cliente,
      consumo: checkout.consumo,
    );
    final repo = await ref.read(orderRepositoryProvider.future);
    final senha = await repo.salvarPedido(pedido);

    // impressão pós-pagamento (janela residual coberta)
    var impresso = true;
    final cupom = montarCupom(pedido, senha);
    try {
      final s = await ref.read(printerDriverProvider).imprimir(cupom);
      impresso = !s.semPapel && s.online && !s.tampaAberta;
    } catch (_) {
      impresso = false;
    }
    if (!impresso) {
      try {
        final fila = await ref.read(filaImpressaoProvider.future);
        await fila.enfileirar(pedido.uuid, senha, cupom);
      } catch (_) {}
    }

    // dispara o envio ao backend em segundo plano (F6) — não bloqueia a UX
    unawaited(ref.read(vendaSyncProvider.notifier).drenar());
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    if (mounted) {
      context.go('/confirmacao?senha=$senha&impresso=${impresso ? 1 : 0}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);

    if (_bloqueado) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
                key: const ValueKey('pagamento-bloqueado'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.print_disabled,
                      color: GogemColors.heat, size: 72),
                  const SizedBox(height: 20),
                  Text('NÃO É POSSÍVEL PAGAR AGORA', style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text('motivo: $_motivo', style: t.bodyLarge),
                  const SizedBox(height: 4),
                  Text('chame um atendente — seu carrinho está salvo',
                      style: t.bodyMedium),
                  const SizedBox(height: 28),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(180, 64),
                          side: const BorderSide(color: GogemColors.line),
                          foregroundColor: GogemColors.ink),
                      onPressed: () => context.go('/carrinho'),
                      child: const Text('VOLTAR'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      key: const ValueKey('tentar-novamente'),
                      onPressed: _portao,
                      child: const Text('TENTAR NOVAMENTE'),
                    ),
                  ]),
                ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _processando
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: GogemColors.cheese),
                const SizedBox(height: 24),
                Text('PROCESSANDO PAGAMENTO…', style: t.titleLarge),
              ]))
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => context.go('/identificacao'),
                      icon: const Icon(Icons.arrow_back,
                          color: GogemColors.ink, size: 32),
                    ),
                    const SizedBox(width: 8),
                    Text('PAGAMENTO', style: t.headlineMedium),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('Total ${formatCentavos(cart.totalCentavos)}',
                    style:
                        t.headlineMedium?.copyWith(color: GogemColors.cheese)),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    children: [
                      _FormaBtn(
                          key: const ValueKey('forma-credito'),
                          icone: Icons.credit_card,
                          rotulo: 'CRÉDITO',
                          onTap: () => _pagar(FormaPagamento.credito)),
                      _FormaBtn(
                          key: const ValueKey('forma-debito'),
                          icone: Icons.credit_card_outlined,
                          rotulo: 'DÉBITO',
                          onTap: () => _pagar(FormaPagamento.debito)),
                      _FormaBtn(
                          key: const ValueKey('forma-pix'),
                          icone: Icons.qr_code_2,
                          rotulo: 'PIX',
                          onTap: () => _pagar(FormaPagamento.pix)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('modo demonstração — pagamento simulado',
                      style: t.bodyMedium?.copyWith(fontSize: 13)),
                ),
              ]),
      ),
    );
  }
}

class _FormaBtn extends StatelessWidget {
  const _FormaBtn(
      {super.key, required this.icone, required this.rotulo, required this.onTap});
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(88),
            backgroundColor: GogemColors.panel,
            foregroundColor: GogemColors.ink,
            side: const BorderSide(color: GogemColors.line),
          ),
          onPressed: onTap,
          icon: Icon(icone, size: 32, color: GogemColors.mint),
          label: Text(rotulo,
              style: const TextStyle(fontFamily: 'Tektur', fontSize: 24)),
        ),
      );
}
