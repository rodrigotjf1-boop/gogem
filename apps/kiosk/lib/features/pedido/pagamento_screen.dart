import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../domain/order/cart.dart';
import '../../domain/order/order_models.dart';
import '../../domain/order/order_repository.dart';

/// Pagamento MOCK (F3): escolhe a forma, "processa" e grava o pedido na fila
/// local com UUID + senha. A F6 substitui o mock pelo POST /vendas e a F4
/// insere o PORTÃO DE PAPEL antes desta tela (nunca cobrar sem poder imprimir).
class PagamentoScreen extends ConsumerStatefulWidget {
  const PagamentoScreen({super.key, this.processamento = const Duration(milliseconds: 900)});
  final Duration processamento;
  @override
  ConsumerState<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends ConsumerState<PagamentoScreen> {
  bool _processando = false;

  Future<void> _pagar(FormaPagamento forma) async {
    final cart = ref.read(cartProvider);
    if (cart.vazio || _processando) return;
    setState(() => _processando = true);
    await Future<void>.delayed(widget.processamento); // simula a integradora
    final pedido = PedidoLocal(
      itens: cart.itens,
      forma: forma,
      cpf: ref.read(checkoutProvider).cpf,
    );
    final repo = await ref.read(orderRepositoryProvider.future);
    final senha = await repo.salvarPedido(pedido);
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    if (mounted) context.go('/confirmacao?senha=$senha');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);
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
                    style: t.headlineMedium?.copyWith(color: GogemColors.cheese)),
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
