import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/moeda.dart';
import '../../domain/order/cart.dart';
import '../../domain/order/order_models.dart';
import 'gogen_tokens.dart';

/// Carrinho no visual **GoGen** (claro/flame). Mesma lógica do `CarrinhoScreen`
/// (lê `cartProvider`/`checkoutProvider`, mesmas mutações e navegação), só a
/// apresentação muda.
class GogenCarrinhoScreen extends ConsumerWidget {
  const GogenCarrinhoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
            child: Row(children: [
              IconButton(
                onPressed: () => context.go('/catalogo'),
                icon: const Icon(Icons.arrow_back_rounded, color: GogenColors.ink, size: 30),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Seu pedido',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
              ),
              TextButton(
                onPressed: cart.vazio ? null : () => ref.read(cartProvider.notifier).limpar(),
                child: Text('Limpar',
                    style: TextStyle(
                        color: cart.vazio ? GogenColors.ink2.withValues(alpha: 0.4) : GogenColors.flame1,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Expanded(
            child: cart.vazio
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Carrinho vazio',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: GogenColors.ink)),
                      const SizedBox(height: 16),
                      _FlameButton(rotulo: 'Ver cardápio', onTap: () => context.go('/catalogo')),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: cart.itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _Linha(item: cart.itens[i]),
                  ),
          ),
          if (!cart.vazio) const _ConsumoToggle(),
          if (!cart.vazio) _Rodape(totalCentavos: cart.totalCentavos),
        ]),
      ),
    );
  }
}

class _Linha extends ConsumerWidget {
  const _Linha({required this.item});
  final ItemCarrinho item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: ValueKey('linha-${item.linhaId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GogenColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.produto.nome,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: GogenColors.ink)),
            if (item.todasOpcoes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.todasOpcoes.map((o) => o.nome).join(' · '),
                    style: const TextStyle(fontSize: 14, color: GogenColors.ink2)),
              ),
            const SizedBox(height: 6),
            Text(formatCentavos(item.totalCentavos),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: GogenColors.flame1)),
          ]),
        ),
        _StepBtn(
          chave: 'menos-${item.linhaId}',
          icon: Icons.remove_rounded,
          onTap: () => ref.read(cartProvider.notifier).alterarQuantidade(item.linhaId, item.quantidade - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('${item.quantidade}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: GogenColors.ink)),
        ),
        _StepBtn(
          chave: 'mais-${item.linhaId}',
          icon: Icons.add_rounded,
          flame: true,
          onTap: () => ref.read(cartProvider.notifier).alterarQuantidade(item.linhaId, item.quantidade + 1),
        ),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.chave, required this.icon, required this.onTap, this.flame = false});
  final String chave;
  final IconData icon;
  final VoidCallback onTap;
  final bool flame;
  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey(chave),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: flame ? GogenColors.grad : null,
            color: flame ? null : GogenColors.cream2,
            borderRadius: BorderRadius.circular(12),
            border: flame ? null : Border.all(color: const Color(0x14000000)),
          ),
          child: Icon(icon, color: flame ? Colors.white : GogenColors.ink, size: 24),
        ),
      );
}

/// Consumo (comer aqui / viagem) — segue ao Regem via checkoutProvider.
class _ConsumoToggle extends ConsumerWidget {
  const _ConsumoToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Row(children: [
        Expanded(
          child: _ConsumoOpcao(
            chave: 'consumo-local',
            rotulo: 'Comer aqui',
            icone: Icons.restaurant_rounded,
            ativo: consumo == 'local',
            onTap: () => ref.read(checkoutProvider.notifier).setConsumo('local'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ConsumoOpcao(
            chave: 'consumo-viagem',
            rotulo: 'Para viagem',
            icone: Icons.shopping_bag_outlined,
            ativo: consumo == 'viagem',
            onTap: () => ref.read(checkoutProvider.notifier).setConsumo('viagem'),
          ),
        ),
      ]),
    );
  }
}

class _ConsumoOpcao extends StatelessWidget {
  const _ConsumoOpcao({
    required this.chave,
    required this.rotulo,
    required this.icone,
    required this.ativo,
    required this.onTap,
  });
  final String chave;
  final String rotulo;
  final IconData icone;
  final bool ativo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(chave),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ativo ? GogenColors.grad : null,
          color: ativo ? null : GogenColors.card,
          borderRadius: BorderRadius.circular(16),
          border: ativo ? null : Border.all(color: const Color(0x1A000000), width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 24, color: ativo ? Colors.white : GogenColors.ink),
          const SizedBox(width: 10),
          Text(rotulo,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17, color: ativo ? Colors.white : GogenColors.ink)),
        ]),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.totalCentavos});
  final int totalCentavos;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Total', style: TextStyle(fontSize: 14, color: GogenColors.ink2)),
            Text(formatCentavos(totalCentavos),
                key: const ValueKey('total'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: GogenColors.flame1)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: _FlameButton(
              chave: 'continuar',
              rotulo: 'Continuar',
              onTap: () => _go(context),
            ),
          ),
        ]),
      ),
    );
  }

  void _go(BuildContext context) => GoRouter.of(context).go('/peca-tambem');
}

class _FlameButton extends StatelessWidget {
  const _FlameButton({required this.rotulo, required this.onTap, this.chave});
  final String rotulo;
  final VoidCallback onTap;
  final String? chave;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: chave == null ? null : ValueKey<String>(chave!),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(gradient: GogenColors.grad, borderRadius: BorderRadius.circular(999)),
          child: Container(
            height: 64,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(rotulo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
        ),
      ),
    );
  }
}
