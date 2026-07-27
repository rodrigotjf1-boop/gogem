import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/catalog_models.dart';
import '../../data/catalog/catalog_sync.dart';

/// Catálogo (Fatia 2): categorias + produtos do snapshot LOCAL (SQLite),
/// com selo de estado do sync. O fluxo de pedido (carrinho/complementos)
/// chega na Fatia 3 — o toque no produto ainda não navega.
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});
  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  String? _categoriaId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => context.go('/descanso'),
                icon: const Icon(Icons.arrow_back, color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('MONTE SEU PEDIDO', style: t.headlineMedium)),
              _SyncBadge(sync: sync),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: menu.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _Vazio(
                  titulo: 'Não foi possível carregar o cardápio',
                  detalhe: '$e',
                ),
                data: (snap) {
                  if (snap == null) {
                    return _Vazio(
                      titulo: 'Cardápio ainda não sincronizado',
                      detalhe: sync.status == SyncStatus.offline
                          ? 'Sem conexão e sem snapshot local — verifique a rede.'
                          : 'Toque em atualizar para baixar a primeira versão.',
                      acao: FilledButton(
                        onPressed: () =>
                            ref.read(catalogSyncProvider.notifier).sincronizar(),
                        child: const Text('ATUALIZAR'),
                      ),
                    );
                  }
                  final catId = _categoriaId ??
                      (snap.categorias.isNotEmpty ? snap.categorias.first.id : '');
                  final produtos = snap.produtosDa(catId);
                  return Column(children: [
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: snap.categorias.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final c = snap.categorias[i];
                          final sel = c.id == catId;
                          return ChoiceChip(
                            key: ValueKey('cat-${c.id}'),
                            selected: sel,
                            onSelected: (_) => setState(() => _categoriaId = c.id),
                            label: Text(c.nome.toUpperCase()),
                            labelStyle: TextStyle(
                              fontFamily: 'Tektur',
                              color: sel ? const Color(0xFF1A1206) : GogemColors.ink,
                            ),
                            selectedColor: GogemColors.cheese,
                            backgroundColor: GogemColors.panel,
                            side: const BorderSide(color: GogemColors.line),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: produtos.isEmpty
                          ? const _Vazio(titulo: 'Nada disponível nesta categoria')
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 420,
                                mainAxisExtent: 128,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                              ),
                              itemCount: produtos.length,
                              itemBuilder: (_, i) => _ProdutoCard(p: produtos[i]),
                            ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard({required this.p});
  final Produto p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('prod-tap-${p.id}'),
      onTap: () => context.push('/produto/${p.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      key: ValueKey('prod-${p.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GogemColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GogemColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.nome, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (p.descricao.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(p.descricao,
                style: t.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        const Spacer(),
        Text(formatCentavos(p.precoCentavos),
            style: t.titleLarge?.copyWith(color: GogemColors.cheese)),
      ]),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.sync});
  final SyncState sync;
  @override
  Widget build(BuildContext context) {
    final (cor, texto) = switch (sync.status) {
      SyncStatus.sincronizando => (GogemColors.cheese, 'SINCRONIZANDO'),
      SyncStatus.atualizado => (GogemColors.mint, 'v${sync.versao ?? '-'}'),
      SyncStatus.offline => (GogemColors.inkDim, 'OFFLINE'),
      SyncStatus.erro => (GogemColors.heat, 'ERRO'),
      SyncStatus.ocioso => (GogemColors.inkDim, '—'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: TextStyle(fontFamily: 'Tektur', fontSize: 13, color: cor)),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.titulo, this.detalhe, this.acao});
  final String titulo;
  final String? detalhe;
  final Widget? acao;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(titulo, style: t.titleLarge, textAlign: TextAlign.center),
        if (detalhe != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(detalhe!, style: t.bodyMedium, textAlign: TextAlign.center),
          ),
        if (acao != null) Padding(padding: const EdgeInsets.only(top: 20), child: acao!),
      ]),
    );
  }
}
