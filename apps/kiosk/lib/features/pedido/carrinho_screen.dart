import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../domain/order/cart.dart';

class CarrinhoScreen extends ConsumerWidget {
  const CarrinhoScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.go('/catalogo'),
                icon: const Icon(Icons.arrow_back, color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('SEU PEDIDO', style: t.headlineMedium)),
              TextButton(
                onPressed: cart.vazio
                    ? null
                    : () => ref.read(cartProvider.notifier).limpar(),
                child: const Text('LIMPAR',
                    style: TextStyle(color: GogemColors.inkDim)),
              ),
            ]),
          ),
          Expanded(
            child: cart.vazio
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Carrinho vazio', style: t.titleLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => context.go('/catalogo'),
                        child: const Text('VER CARDÁPIO')),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: cart.itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = cart.itens[i];
                      return Container(
                        key: ValueKey('linha-${item.linhaId}'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GogemColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GogemColors.line),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.produto.nome, style: t.titleLarge),
                                  if (item.todasOpcoes.isNotEmpty)
                                    Text(
                                      item.todasOpcoes.map((o) => o.nome).join(' · '),
                                      style: t.bodyMedium,
                                    ),
                                  const SizedBox(height: 6),
                                  Text(formatCentavos(item.totalCentavos),
                                      style: t.bodyLarge?.copyWith(
                                          color: GogemColors.cheese)),
                                ]),
                          ),
                          IconButton(
                            key: ValueKey('menos-${item.linhaId}'),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .alterarQuantidade(item.linhaId, item.quantidade - 1),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: GogemColors.inkDim, size: 30),
                          ),
                          Text('${item.quantidade}',
                              style: const TextStyle(
                                  fontFamily: 'Tektur', fontSize: 22)),
                          IconButton(
                            key: ValueKey('mais-${item.linhaId}'),
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .alterarQuantidade(item.linhaId, item.quantidade + 1),
                            icon: const Icon(Icons.add_circle_outline,
                                color: GogemColors.mint, size: 30),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
          if (!cart.vazio)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GogemColors.line))),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TOTAL', style: t.bodyMedium),
                  Text(formatCentavos(cart.totalCentavos),
                      key: const ValueKey('total'),
                      style: t.headlineMedium
                          ?.copyWith(color: GogemColors.cheese)),
                ]),
                const SizedBox(width: 24),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('continuar'),
                    onPressed: () => context.go('/identificacao'),
                    child: const Text('CONTINUAR'),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
