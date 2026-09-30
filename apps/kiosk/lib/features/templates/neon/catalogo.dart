import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/cart.dart';
import '../comum/catalogo_dados.dart';
import '../comum/produto_arte.dart';
import '../comum/sacola.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'bento.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Cardápio do Neon 2.0 (docs/templates/04-neon-2.md §6.2): topo com `Etapas(0)`, abas de
/// categoria fixas, destaque com borda de néon girando, seções "// CATEGORIA" em mosaico
/// bento e a `BarraSacola` embaixo. Tela inteira: lê os providers como a GoGen.
class NeonCatalogoScreen extends ConsumerStatefulWidget {
  const NeonCatalogoScreen({super.key});

  @override
  ConsumerState<NeonCatalogoScreen> createState() => _NeonCatalogoScreenState();
}

class _NeonCatalogoScreenState extends ConsumerState<NeonCatalogoScreen> {
  final _rolagem = ScrollController();
  final _areaRolagem = GlobalKey();
  final _alvoSacola = GlobalKey();
  final _secoes = <String, GlobalKey>{};
  String? _ativa;
  bool _rolandoPorToque = false;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  GlobalKey _chaveSecao(String id) => _secoes.putIfAbsent(id, GlobalKey.new);

  /// Rolar marca a categoria visível: a última seção cujo topo já passou do topo da área.
  void _aoRolar() {
    if (_rolandoPorToque) return;
    final area = _areaRolagem.currentContext?.findRenderObject();
    if (area is! RenderBox) return;
    String? visivel;
    for (final e in _secoes.entries) {
      final ro = e.value.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final y = ro.localToGlobal(Offset.zero, ancestor: area).dy;
      if (y <= context.dz(120)) visivel = e.key;
    }
    if (visivel != null && visivel != _ativa) setState(() => _ativa = visivel);
  }

  /// Tocar na aba rola até a seção.
  Future<void> _irPara(String id, Movimento mov) async {
    setState(() => _ativa = id);
    final ctx = _secoes[id]?.currentContext;
    if (ctx == null) return;
    _rolandoPorToque = true;
    try {
      await Scrollable.ensureVisible(
        ctx,
        duration: mov.anima ? mov.d(450) : Duration.zero,
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _rolandoPorToque = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final carrinho = ref.watch(cartProvider);
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);

    return Scaffold(
      backgroundColor: _t.bg,
      body: SafeArea(
        child: NeonEntrada(
          mov: mov,
          child: Column(children: [
            NeonTopo(
              mov: mov,
              etapa: 0,
              nomeLoja: ap.nomeLoja,
              logoUrl: ap.logoUrl,
              onCancelar: () => acoes.cancelarPedido(context),
            ),
            Expanded(
              child: menu.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: _t.accent,
                    value: mov.anima ? null : .7,
                  ),
                ),
                error: (e, _) => NeonVazio(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não deu pra carregar o cardápio',
                  detalhe: '$e',
                ),
                data: (snap) {
                  if (snap == null || snap.categorias.isEmpty) {
                    return NeonVazio(
                      icone: sync.status == SyncStatus.offline ? Icons.wifi_off_rounded : Icons.sync_rounded,
                      titulo: 'Cardápio ainda não sincronizado',
                      detalhe: sync.status == SyncStatus.offline
                          ? 'Sem conexão e sem snapshot local.'
                          : 'Baixando a primeira versão…',
                      acao: SizedBox(
                        width: context.dz(420),
                        child: NeonBotao(
                          key: const ValueKey('neon-atualizar'),
                          rotulo: 'Atualizar',
                          icone: Icons.refresh_rounded,
                          onTap: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
                        ),
                      ),
                    );
                  }
                  final dados = CatalogoDados.de(snap);
                  if (dados.secoes.isEmpty) {
                    return const NeonVazio(
                      icone: Icons.no_food_outlined,
                      titulo: 'Nada disponível nesta categoria',
                    );
                  }
                  return _cardapio(context, dados, mov, acoes);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(context.dz(40), context.dz(18), context.dz(40), context.dz(36)),
              child: Opacity(
                opacity: carrinho.vazio ? .55 : 1,
                child: BarraSacola(
                  itens: carrinho.totalItens,
                  totalCentavos: carrinho.totalCentavos,
                  onVerSacola: () => acoes.verSacola(context),
                  tokens: _t,
                  alvo: _alvoSacola,
                  mov: mov,
                  fundo: _t.accent,
                  tinta: _t.onAccent,
                  botaoFundo: _t.onAccent,
                  botaoTinta: _t.accent,
                  raio: _t.raioBotao,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cardapio(BuildContext context, CatalogoDados dados, Movimento mov, AcoesPedido acoes) {
    final ativa = _ativa ?? dados.secoes.first.categoria.id;
    void mais(Produto p, GlobalKey foto) {
      if (acoes.adicionarOuAbrir(context, p)) {
        VooParaSacola.voar(
          context,
          origem: foto,
          destino: _alvoSacola,
          url: p.imagemUrl,
          tokens: _t,
          mov: mov,
        );
      }
    }

    return Column(children: [
      _Abas(
        categorias: [for (final s in dados.secoes) s.categoria],
        ativa: ativa,
        mov: mov,
        onTocar: (id) => _irPara(id, mov),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: _areaRolagem,
          controller: _rolagem,
          padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(24), context.dz(48), context.dz(40)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (dados.destaques.isNotEmpty)
              _Destaque(
                produto: dados.destaques.first,
                mov: mov,
                onAbrir: () => acoes.abrirProduto(context, dados.destaques.first),
              ),
            for (final s in dados.secoes)
              KeyedSubtree(
                key: _chaveSecao(s.categoria.id),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: EdgeInsets.only(top: context.dz(34), bottom: context.dz(20)),
                    child: TituloSecaoNeon(s.categoria.nome),
                  ),
                  NeonBento(
                    produtos: s.produtos,
                    mov: mov,
                    onAbrir: (p) => acoes.abrirProduto(context, p),
                    onMais: mais,
                  ),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

/// Barra de abas (`.ntabs`): `surface` com borda `line` e raio 22; abas iguais de 78 de
/// altura, a ativa em `accent` com brilho (só perfil forte). Muitas categorias: rola.
class _Abas extends StatelessWidget {
  const _Abas({required this.categorias, required this.ativa, required this.mov, required this.onTocar});
  final List<Categoria> categorias;
  final String ativa;
  final Movimento mov;
  final void Function(String id) onTocar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(context.dz(48), context.dz(4), context.dz(48), 0),
      padding: EdgeInsets.all(context.dz(8)),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(context.dz(22)),
        border: Border.all(color: _t.line, width: context.dz(2)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final cabem = categorias.length <= 5 && c.maxWidth / categorias.length >= context.dz(150);
        Widget aba(Categoria cat) => _Aba(
              key: ValueKey('aba-${cat.id}'),
              nome: cat.nome,
              ativa: cat.id == ativa,
              mov: mov,
              onTap: () => onTocar(cat.id),
            );
        if (cabem) {
          return Row(children: [
            for (var i = 0; i < categorias.length; i++) ...[
              if (i > 0) SizedBox(width: context.dz(8)),
              Expanded(child: aba(categorias[i])),
            ],
          ]);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < categorias.length; i++) ...[
              if (i > 0) SizedBox(width: context.dz(8)),
              aba(categorias[i]),
            ],
          ]),
        );
      }),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({super.key, required this.nome, required this.ativa, required this.mov, required this.onTap});
  final String nome;
  final bool ativa;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: mov.anima ? const Duration(milliseconds: 250) : Duration.zero,
        height: context.dz(78),
        padding: EdgeInsets.symmetric(horizontal: context.dz(18)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativa ? _t.accent : const Color(0x00000000),
          borderRadius: BorderRadius.circular(context.dz(14)),
          boxShadow: ativa && mov.brilho ? [BoxShadow(color: neonBrilho, blurRadius: context.dz(26))] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            nome.toUpperCase(),
            maxLines: 1,
            style: neonTexto(context.dz(23), peso: FontWeight.w600, cor: ativa ? _t.onAccent : _t.text, espaco: .05),
          ),
        ),
      ),
    );
  }
}

/// Destaque (`.nhero`): 370 de altura, raio 26, borda de néon girando e fundo `0xFF0E0E17`.
/// Kicker magenta (o selo do produto, ou "COMBO DA NOITE · ATÉ 4H"), nome em Unbounded 46,
/// preço em `accent` 50 e o produto flutuando à direita.
class _Destaque extends StatelessWidget {
  const _Destaque({required this.produto, required this.mov, required this.onAbrir});
  final Produto produto;
  final Movimento mov;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    final selo = (p.selo ?? '').trim();
    final kicker = selo.isNotEmpty ? selo.toUpperCase() : 'COMBO DA NOITE · ATÉ 4H';
    final recorte = ProdutoArte.ehRecorte(p.imagemUrl);
    return GestureDetector(
      key: const ValueKey('neon-destaque'),
      behavior: HitTestBehavior.opaque,
      onTap: onAbrir,
      child: Container(
        height: context.dz(370),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.dz(26)),
          boxShadow: mov.brilho ? [BoxShadow(color: const Color(0x40FF3EA5), blurRadius: context.dz(44))] : null,
        ),
        child: BordaNeon(
          mov: mov,
          raio: 26,
          espessura: 4,
          fundo: neonFundoDestaque,
          child: Stack(children: [
            if (mov.brilho && recorte)
              Positioned(
                right: context.dz(20),
                top: 0,
                bottom: 0,
                width: context.dz(480),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [Color(0x33C8FF2E), Color(0x00C8FF2E)], stops: [0, .7]),
                  ),
                ),
              ),
            Positioned(
              right: context.dz(recorte ? 50 : 36),
              top: context.dz(recorte ? 26 : 36),
              bottom: context.dz(recorte ? 26 : 36),
              width: context.dz(recorte ? 420 : 380),
              child: NeonFlutua(
                mov: mov,
                child: ProdutoArte(
                  url: p.imagemUrl,
                  tokens: _t,
                  raio: context.dz(20),
                  escalaRecorte: 1,
                  fundo: recorte ? const Color(0x00000000) : null,
                ),
              ),
            ),
            Positioned(
              left: context.dz(40),
              top: context.dz(36),
              bottom: context.dz(36),
              width: context.dz(520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: neonTexto(context.dz(22), peso: FontWeight.w700, cor: _t.accent2, espaco: .18)),
                SizedBox(height: context.dz(12)),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _t.caixa(p.nome),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: neonDisplay(context.dz(46), altura: 1.04),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatCentavos(p.precoCentavos),
                      key: const ValueKey('neon-destaque-preco'), style: neonDisplay(context.dz(50), cor: _t.accent)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
