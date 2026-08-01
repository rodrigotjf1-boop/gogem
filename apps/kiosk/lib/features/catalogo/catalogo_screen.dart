import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_models.dart';
import '../../data/catalog/catalog_sync.dart';
import 'produto_imagem.dart';

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
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final lateral = ap.cardLateral;
    return Scaffold(
      body: Container(
        // Preset "brasa": brilho ember no topo (steakhouse). "burger" (Burger
        // House): fundo quente escuro + brasa vermelha no topo. Padrão: sem fundo.
        decoration: ap.burger
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                        ap.corDestaque.withValues(alpha: 0.16), ap.corFundo),
                    ap.corFundo,
                  ],
                ),
              )
            : ap.brasa
                ? BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.1),
                      radius: 1.1,
                      colors: [
                        ap.corPrimaria.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  )
                : null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                              padding: const EdgeInsets.only(bottom: 16),
                              gridDelegate: lateral
                                  ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 520,
                                      mainAxisExtent: 112,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                    )
                                  : const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 320,
                                      mainAxisExtent: 288,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                    ),
                              itemCount: produtos.length,
                              itemBuilder: (_, i) => _ProdutoCard(
                                  p: produtos[i],
                                  lateral: lateral,
                                  brasa: ap.brasa,
                                  burger: ap.burger),
                            ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
          ),
        ),
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard(
      {required this.p,
      this.lateral = false,
      this.brasa = false,
      this.burger = false});
  final Produto p;
  final bool lateral;
  final bool brasa;
  final bool burger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const raio = 18.0;
    // "brasa": card com brilho diagonal (sheen) + borda tingida (steakhouse).
    // "burger" (Burger House): painel quente escuro, borda âmbar sutil e sombra
    // — foto-forward. Padrão: painel liso.
    final BoxDecoration decor;
    if (burger) {
      decor = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF201814), Color(0xFF14100D)],
        ),
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );
    } else if (brasa) {
      decor = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241A12), Color(0xFF14100C)],
        ),
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: cs.primary.withValues(alpha: 0.55)),
      );
    } else {
      decor = BoxDecoration(
        color: GogemColors.panel,
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: GogemColors.line),
      );
    }
    return InkWell(
      key: ValueKey('prod-tap-${p.id}'),
      onTap: () => context.push('/produto/${p.id}'),
      borderRadius: BorderRadius.circular(raio),
      child: Container(
        key: ValueKey('prod-${p.id}'),
        clipBehavior: Clip.antiAlias,
        decoration: decor,
        child: lateral ? _lateral(context, t) : _cheia(context, t),
      ),
    );
  }

  /// Foto-cheia: imagem no topo + selo de preço + nome/descrição embaixo.
  Widget _cheia(BuildContext context, TextTheme t) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProdutoImagem(url: p.imagemUrl),
                Positioned(right: 10, bottom: 10, child: _selo(context)),
                if (p.selo != null)
                  Positioned(left: 10, top: 10, child: _seloDestaque(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.nome, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (p.descricao.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.descricao,
                        style: t.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      );

  /// Foto-lateral: miniatura à esquerda + nome/descrição + preço à direita.
  Widget _lateral(BuildContext context, TextTheme t) => Row(
        children: [
          SizedBox(width: 112, height: double.infinity, child: ProdutoImagem(url: p.imagemUrl)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.selo != null) ...[
                    _seloDestaque(context),
                    const SizedBox(height: 6),
                  ],
                  Text(p.nome, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (p.descricao.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p.descricao,
                          style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: 8),
                  _selo(context),
                ],
              ),
            ),
          ),
        ],
      );

  /// Selo de preço na cor primária da loja (segue o tema dinâmico).
  Widget _selo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
      child: Text(
        formatCentavos(p.precoCentavos),
        style: TextStyle(
          fontFamily: 'Tektur',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: cs.onPrimary,
        ),
      ),
    );
  }

  /// Selo de destaque (F4) — ex.: "Mais vendido". Fundo na cor primária;
  /// no Burger House usa a cor de destaque (vermelho), como no mockup.
  Widget _seloDestaque(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fundo = burger ? cs.secondary : cs.primary;
    final tinta = fundo.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: fundo, borderRadius: BorderRadius.circular(999)),
      child: Text(
        p.selo!.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Tektur',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
          color: tinta,
        ),
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
