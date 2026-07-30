import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/catalog_models.dart';
import '../../data/catalog/catalog_sync.dart' show menuProvider;
import '../../domain/order/cart.dart';
import '../../domain/order/order_models.dart';

/// "Peça também" (F2): entre o carrinho e a identificação, sugere produtos
/// configurados (upsell) nos itens do carrinho. Sem sugestões → segue direto.
/// Produto com etapa obrigatória abre a tela do produto; senão adiciona direto.
class PecaTambemScreen extends ConsumerStatefulWidget {
  const PecaTambemScreen({super.key});
  @override
  ConsumerState<PecaTambemScreen> createState() => _PecaTambemScreenState();
}

class _PecaTambemScreenState extends ConsumerState<PecaTambemScreen> {
  bool _redirecionou = false;
  // Havia sugestões na primeira avaliação com o menu carregado? Distingue
  // "vazio desde o início" (pula) de "esvaziou após adicionar" (mostra ok).
  bool? _inicialTinha;

  /// Upsell agregado dos itens do carrinho: na ordem, único, disponível e que
  /// ainda não está no carrinho.
  List<Produto> _sugeridos(MenuSnapshot snap) {
    final noCarrinho =
        ref.read(cartProvider).itens.map((i) => i.produto.id).toSet();
    final vistos = <String>{};
    final out = <Produto>[];
    for (final item in ref.read(cartProvider).itens) {
      for (final id in item.produto.upsell) {
        if (!vistos.add(id) || noCarrinho.contains(id)) continue;
        final p = snap.porId(id);
        if (p != null && p.disponivel) out.add(p);
      }
    }
    return out;
  }

  bool _temEtapaObrigatoria(Produto p) =>
      p.grupos.any((g) => minEfetivo(g) > 0);

  void _adicionar(Produto p) {
    if (_temEtapaObrigatoria(p)) {
      // Precisa escolher complementos: abre a tela do produto.
      context.go('/produto/${p.id}');
      return;
    }
    ref.read(cartProvider.notifier).adicionar(
          ItemCarrinho(produto: p, selecoes: const {}),
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Recalcula a cada mudança do carrinho (itens adicionados somem da lista).
    ref.watch(cartProvider);
    final menu = ref.watch(menuProvider);
    final snap = menu.valueOrNull;

    // Menu ainda carregando: aguarda (não decide pular sem os dados).
    if (menu.isLoading && snap == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sugeridos = snap == null ? const <Produto>[] : _sugeridos(snap);
    _inicialTinha ??= sugeridos.isNotEmpty;

    // Vazio desde o início: pula o passo (uma vez). Se esvaziou por adição
    // (_inicialTinha == true), mostramos o estado "tudo certo" com Continuar.
    if (_inicialTinha == false) {
      if (!_redirecionou) {
        _redirecionou = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/identificacao');
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.go('/carrinho'),
                icon: const Icon(Icons.arrow_back,
                    color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('PEÇA TAMBÉM', style: t.headlineMedium)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('Que tal adicionar ao seu pedido?',
                style: t.bodyLarge?.copyWith(color: GogemColors.inkDim)),
          ),
          Expanded(
            child: sugeridos.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle,
                          color: GogemColors.mint, size: 56),
                      const SizedBox(height: 12),
                      Text('Tudo certo! Adicionado ao pedido.',
                          style: t.titleLarge),
                    ]),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 132,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: sugeridos.length,
                    itemBuilder: (_, i) => _SugestaoCard(
                      key: ValueKey('sugestao-${sugeridos[i].id}'),
                      produto: sugeridos[i],
                      onAdicionar: () => _adicionar(sugeridos[i]),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: GogemColors.line))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('peca-tambem-pular'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 68),
                    side: const BorderSide(color: GogemColors.line),
                    foregroundColor: GogemColors.ink,
                  ),
                  onPressed: () => context.go('/identificacao'),
                  child: const Text('AGORA NÃO'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('peca-tambem-continuar'),
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

class _SugestaoCard extends StatelessWidget {
  const _SugestaoCard({
    super.key,
    required this.produto,
    required this.onAdicionar,
  });
  final Produto produto;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GogemColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GogemColors.line),
      ),
      child: Row(children: [
        if (produto.imagemUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(produto.imagemUrl!,
                width: 72, height: 72, fit: BoxFit.cover),
          )
        else
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: GogemColors.line,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fastfood, color: GogemColors.inkDim),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(produto.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium),
              const SizedBox(height: 4),
              Text(formatCentavos(produto.precoCentavos),
                  style: t.bodyLarge?.copyWith(color: GogemColors.cheese)),
            ],
          ),
        ),
        IconButton(
          onPressed: onAdicionar,
          icon: const Icon(Icons.add_circle, color: GogemColors.mint, size: 34),
          tooltip: 'Adicionar',
        ),
      ]),
    );
  }
}
