import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_models.dart';
import '../../data/catalog/catalog_sync.dart';
import '../../domain/order/cart.dart';
import '../catalogo/produto_imagem.dart';
import 'gogen_category_wheel.dart';
import 'gogen_tokens.dart';

/// MENU do template **GoGen** (nativo): topbar quente, grid de produtos e a
/// **roleta cilíndrica de categorias** ancorada no rodapé. Só entra quando
/// `ap.gogen` — o catálogo padrão delega pra cá sem tocar nas outras telas.
class GogenCatalogoScreen extends ConsumerStatefulWidget {
  const GogenCatalogoScreen({super.key});
  @override
  ConsumerState<GogenCatalogoScreen> createState() => _GogenCatalogoScreenState();
}

class _GogenCatalogoScreenState extends ConsumerState<GogenCatalogoScreen> {
  String? _categoriaId;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final carrinho = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GogenColors.cream2, GogenColors.cream],
            stops: [0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Topbar(nomeLoja: ap.nomeLoja, logoUrl: ap.logoUrl, sync: sync),
              Expanded(
                child: menu.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Vazio(titulo: 'Não deu pra carregar o cardápio', detalhe: '$e'),
                  data: (snap) {
                    if (snap == null || snap.categorias.isEmpty) {
                      return _Vazio(
                        titulo: 'Cardápio ainda não sincronizado',
                        detalhe: sync.status == SyncStatus.offline
                            ? 'Sem conexão e sem snapshot local.'
                            : 'Baixando a primeira versão…',
                        acao: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: GogenColors.flame1),
                          onPressed: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
                          child: const Text('ATUALIZAR'),
                        ),
                      );
                    }
                    final catId = _categoriaId ?? snap.categorias.first.id;
                    final produtos = snap.produtosDa(catId);
                    return Column(
                      children: [
                        Expanded(
                          child: produtos.isEmpty
                              ? const _Vazio(titulo: 'Nada disponível nesta categoria')
                              : GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 340,
                                    mainAxisExtent: 320,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                  ),
                                  itemCount: produtos.length,
                                  itemBuilder: (_, i) => _GogenCard(p: produtos[i]),
                                ),
                        ),
                        // Roleta de categorias — a "estrela" do template.
                        GogenCategoryWheel(
                          categorias: snap.categorias,
                          selecionadaId: catId,
                          onSelecionar: (id) => setState(() => _categoriaId = id),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Barra do carrinho — flutua sobre a roleta quando há itens.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: carrinho.vazio
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 208),
              child: _BarraCarrinho(
                itens: carrinho.totalItens,
                totalCentavos: carrinho.totalCentavos,
                onTap: () => context.push('/carrinho'),
              ),
            ),
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({this.nomeLoja, this.logoUrl, required this.sync});
  final String? nomeLoja;
  final String? logoUrl;
  final SyncState sync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/descanso'),
            icon: const Icon(Icons.close_rounded, color: GogenColors.ink2, size: 30),
          ),
          const SizedBox(width: 4),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: GogenColors.grad,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x4DFF5A1F), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: (logoUrl != null && logoUrl!.isNotEmpty)
                ? ProdutoImagem(url: logoUrl)
                : const Center(child: Text('🔥', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nomeLoja ?? 'GoGen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: GogenColors.ink,
                  ),
                ),
                const Text(
                  'Monte seu pedido',
                  style: TextStyle(fontSize: 15, color: GogenColors.ink2),
                ),
              ],
            ),
          ),
          _SyncDot(sync: sync),
        ],
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.sync});
  final SyncState sync;
  @override
  Widget build(BuildContext context) {
    final (cor, texto) = switch (sync.status) {
      SyncStatus.sincronizando => (GogenColors.flame3, 'sincronizando'),
      SyncStatus.atualizado => (GogenColors.ok, 'v${sync.versao ?? '-'}'),
      SyncStatus.offline => (GogenColors.ink2, 'offline'),
      SyncStatus.erro => (GogenColors.flame1, 'erro'),
      SyncStatus.ocioso => (GogenColors.ink2, '—'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 13, color: GogenColors.ink2, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Card de produto GoGen: foto, nome/descrição, preço em pílula flame e o "＋".
class _GogenCard extends StatelessWidget {
  const _GogenCard({required this.p});
  final Produto p;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('gogen-prod-${p.id}'),
      onTap: () => context.push('/produto/${p.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GogenColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProdutoImagem(url: p.imagemUrl),
                  if (p.selo != null)
                    Positioned(left: 12, top: 12, child: _selo(p.selo!)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: GogenColors.ink,
                    ),
                  ),
                  if (p.descricao.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        p.descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: GogenColors.ink2),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        formatCentavos(p.precoCentavos),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: GogenColors.flame1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: GogenColors.grad,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Color(0x4DFF5A1F), blurRadius: 14, offset: Offset(0, 6)),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selo(String txt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: GogenColors.grad,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          txt.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      );
}

class _BarraCarrinho extends StatelessWidget {
  const _BarraCarrinho({required this.itens, required this.totalCentavos, required this.onTap});
  final int itens;
  final int totalCentavos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: GogenColors.grad,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0x59FF5A1F), blurRadius: 28, offset: Offset(0, 12)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Text('$itens', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            const Text('Ver carrinho', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(width: 16),
            Text(
              formatCentavos(totalCentavos),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ]),
        ),
      ),
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
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: GogenColors.ink),
            textAlign: TextAlign.center),
        if (detalhe != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(detalhe!, style: const TextStyle(fontSize: 15, color: GogenColors.ink2), textAlign: TextAlign.center),
          ),
        if (acao != null) Padding(padding: const EdgeInsets.only(top: 20), child: acao!),
      ]),
    );
  }
}
