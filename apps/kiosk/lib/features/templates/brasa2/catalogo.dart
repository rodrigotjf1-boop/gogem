import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/cart.dart';
import '../comum/catalogo_dados.dart';
import '../comum/produto_arte.dart';
import '../comum/sacola.dart';
import '../comum/selo.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';

const _t = brasa2Tokens;

/// Catálogo do **Brasa 2.0** (docs/templates/01 §6.2): trilho de categorias à esquerda,
/// carrossel de destaques, seções em grade de 2 e a barra da sacola. Tela inteira: lê o
/// cardápio, a sacola e o sync como a GoGen; as ações são as de `AcoesPedido`.
class Brasa2Catalogo extends ConsumerStatefulWidget {
  const Brasa2Catalogo({super.key});

  @override
  ConsumerState<Brasa2Catalogo> createState() => _Brasa2CatalogoState();
}

class _Brasa2CatalogoState extends ConsumerState<Brasa2Catalogo> {
  final _rolagem = ScrollController();
  final _alvoSacola = GlobalKey(debugLabel: 'alvo-sacola');
  final _chavesSecao = <String, GlobalKey>{};
  final _chavesFoto = <String, GlobalKey>{};
  String? _ativa;
  bool _rolandoPorToque = false;

  GlobalKey _secao(String id) => _chavesSecao.putIfAbsent(id, () => GlobalKey(debugLabel: 'secao-$id'));
  GlobalKey _foto(String id) => _chavesFoto.putIfAbsent(id, () => GlobalKey(debugLabel: 'foto-$id'));

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  /// Tocar numa categoria rola até a seção dela.
  Future<void> _irPara(List<SecaoCatalogo> secoes, String id, Movimento mov) async {
    setState(() => _ativa = id);
    final ctx = _chavesSecao[id]?.currentContext;
    if (ctx == null || !_rolagem.hasClients) return;
    _rolandoPorToque = true;
    final dur = mov.anima ? mov.d(450) : Duration.zero;
    if (secoes.isNotEmpty && secoes.first.categoria.id == id) {
      // A primeira volta ao topo (com o carrossel de destaques).
      if (dur == Duration.zero) {
        _rolagem.jumpTo(0);
      } else {
        await _rolagem.animateTo(0, duration: dur, curve: Curves.easeInOutCubic);
      }
    } else {
      await Scrollable.ensureVisible(ctx, duration: dur, curve: Curves.easeInOutCubic);
    }
    _rolandoPorToque = false;
  }

  /// Rolar marca a categoria visível (a última seção cujo topo já passou do alto da lista).
  bool _aoRolar(ScrollNotification n, List<SecaoCatalogo> secoes) {
    if (_rolandoPorToque || n.depth != 0 || secoes.isEmpty) return false;
    final lista = context.findRenderObject();
    if (lista is! RenderBox) return false;
    String? visivel = secoes.first.categoria.id;
    if (n.metrics.extentAfter < 2) {
      visivel = secoes.last.categoria.id;
    } else {
      final limite = context.dz(420);
      for (final s in secoes) {
        final ro = _chavesSecao[s.categoria.id]?.currentContext?.findRenderObject();
        if (ro is! RenderBox || !ro.attached) continue;
        final y = ro.localToGlobal(Offset.zero, ancestor: lista).dy;
        if (y <= limite) visivel = s.categoria.id;
      }
    }
    if (visivel != _ativa) setState(() => _ativa = visivel);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    final carrinho = ref.watch(cartProvider);
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);

    final Widget corpo = menu.when(
      loading: () => const Brasa2Estado(titulo: 'Carregando o cardápio…', carregando: true),
      error: (e, _) => Brasa2Estado(titulo: 'Não deu pra carregar o cardápio', detalhe: '$e'),
      data: (snap) {
        if (snap == null || snap.categorias.isEmpty) {
          return Brasa2Estado(
            key: const ValueKey('catalogo-vazio'),
            titulo: 'Cardápio ainda não sincronizado',
            detalhe: sync.status == SyncStatus.offline
                ? 'Sem conexão e sem snapshot local.'
                : 'Baixando a primeira versão…',
            acao: Brasa2Botao(
              key: const ValueKey('catalogo-atualizar'),
              rotulo: 'Atualizar',
              altura: 96,
              fonte: 30,
              mov: mov,
              onTap: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
            ),
          );
        }
        final dados = CatalogoDados.de(snap);
        if (dados.secoes.isEmpty) {
          return const Brasa2Estado(titulo: 'Nada disponível no momento');
        }
        final ativa = _ativa ?? dados.secoes.first.categoria.id;
        return Padding(
          padding: EdgeInsets.only(top: context.dz(10), left: context.dz(22)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: context.dz(190),
              child: _Trilho(
                secoes: dados.secoes,
                ativa: ativa,
                mov: mov,
                onTocar: (id) => _irPara(dados.secoes, id, mov),
              ),
            ),
            SizedBox(width: context.dz(10)),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => _aoRolar(n, dados.secoes),
                child: SingleChildScrollView(
                  key: const ValueKey('catalogo-lista'),
                  controller: _rolagem,
                  padding: EdgeInsets.fromLTRB(context.dz(18), context.dz(8), context.dz(40), context.dz(40)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (dados.destaques.isNotEmpty)
                      _Destaques(
                        itens: dados.destaques.take(3).toList(),
                        mov: mov,
                        onAbrir: (p) => acoes.abrirProduto(context, p),
                      ),
                    for (final s in dados.secoes)
                      _Secao(
                        key: _secao(s.categoria.id),
                        secao: s,
                        mov: mov,
                        chaveFoto: _foto,
                        onAbrir: (p) => acoes.abrirProduto(context, p),
                        onMais: (p) {
                          if (acoes.adicionarOuAbrir(context, p)) {
                            VooParaSacola.voar(context,
                                origem: _foto(p.id),
                                destino: _alvoSacola,
                                url: p.imagemUrl,
                                tokens: _t,
                                mov: mov);
                          }
                        },
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );

    return Brasa2Tela(
      child: Brasa2Entrada(
        mov: mov,
        child: Column(children: [
          Brasa2Topo(onCancelar: () => acoes.cancelarPedido(context), etapa: 0, mov: mov),
          Expanded(child: corpo),
          Padding(
            padding: EdgeInsets.fromLTRB(context.dz(40), context.dz(18), context.dz(40), context.dz(36)),
            // Sacola vazia fica esmaecida (`.cbar.is-empty`).
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
                botaoTinta: _t.text,
                raio: _t.raioBotao,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Trilho de categorias (190 de largura): círculo de 104 com a imagem da categoria (ou a
/// cor com a inicial) e o nome; a selecionada ganha o fundo do acento (300 ms).
class _Trilho extends StatelessWidget {
  const _Trilho({required this.secoes, required this.ativa, required this.mov, required this.onTocar});
  final List<SecaoCatalogo> secoes;
  final String ativa;
  final Movimento mov;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: EdgeInsets.only(bottom: context.dz(20)),
        itemCount: secoes.length,
        separatorBuilder: (_, __) => SizedBox(height: context.dz(10)),
        itemBuilder: (context, i) {
          final c = secoes[i].categoria;
          final on = c.id == ativa;
          return Semantics(
            button: true,
            selected: on,
            label: c.nome,
            child: GestureDetector(
              key: ValueKey('categoria-${c.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTocar(c.id),
              child: AnimatedContainer(
                duration: mov.anima ? mov.d(300) : Duration.zero,
                padding: EdgeInsets.symmetric(vertical: context.dz(18), horizontal: context.dz(6)),
                decoration: BoxDecoration(
                  color: on ? _t.accent : const Color(0x00EC7433),
                  borderRadius: BorderRadius.circular(context.dz(26)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _CirculoCategoria(categoria: c),
                  SizedBox(height: context.dz(10)),
                  Text(c.nome,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: brasaTexto(context, 23, peso: FontWeight.w800, cor: on ? _t.onAccent : _t.text, altura: 1.15)),
                ]),
              ),
            ),
          );
        },
      );
}

class _CirculoCategoria extends StatelessWidget {
  const _CirculoCategoria({required this.categoria});
  final Categoria categoria;

  static Color? _cor(String? hex) {
    final h = (hex ?? '').replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final d = context.dz(104);
    final url = categoria.imagemUrl;
    final Widget miolo;
    if ((url ?? '').isNotEmpty) {
      miolo = ProdutoArte(url: url, tokens: _t, fundo: _t.surface, sombra: false, escalaRecorte: .9);
    } else {
      final emoji = (categoria.emoji ?? '').trim();
      final inicial = categoria.nome.trim().isEmpty ? '?' : categoria.nome.trim()[0].toUpperCase();
      miolo = ColoredBox(
        color: _cor(categoria.cor) ?? _t.surface2,
        child: Center(
          child: Text(emoji.isNotEmpty ? emoji : inicial,
              style: emoji.isNotEmpty
                  ? TextStyle(fontSize: context.dz(46))
                  : brasaTitulo(context, 50, cor: _t.text)),
        ),
      );
    }
    return SizedBox(width: d, height: d, child: ClipOval(child: miolo));
  }
}

/// Carrossel de destaques (altura 340, raio 30): foto em cover com Ken Burns de 8 s,
/// degradê horizontal, kicker/nome/preço; troca a cada 3,8 s com crossfade de 1 s.
class _Destaques extends StatefulWidget {
  const _Destaques({required this.itens, required this.mov, required this.onAbrir});
  final List<Produto> itens;
  final Movimento mov;
  final ValueChanged<Produto> onAbrir;

  @override
  State<_Destaques> createState() => _DestaquesState();
}

class _DestaquesState extends State<_Destaques> with SingleTickerProviderStateMixin {
  late final AnimationController _kb;
  Timer? _troca;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _kb = AnimationController(vsync: this, duration: widget.mov.d(8000));
    if (widget.mov.anima) {
      _kb.repeat(reverse: true);
      if (widget.itens.length > 1) {
        _troca = Timer.periodic(widget.mov.d(3800), (_) {
          if (mounted) setState(() => _i = (_i + 1) % widget.itens.length);
        });
      }
    }
  }

  @override
  void dispose() {
    _troca?.cancel();
    _kb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.itens[_i % widget.itens.length];
    final raio = BorderRadius.circular(context.dz(30));
    final selo = (p.selo ?? '').trim();
    return Padding(
      padding: EdgeInsets.only(bottom: context.dz(6)),
      child: GestureDetector(
        key: const ValueKey('destaque'),
        onTap: () => widget.onAbrir(p),
        child: ClipRRect(
          borderRadius: raio,
          child: SizedBox(
            height: context.dz(340),
            child: Stack(fit: StackFit.expand, children: [
              AnimatedSwitcher(
                duration: widget.mov.anima ? widget.mov.d(1000) : Duration.zero,
                child: Stack(key: ValueKey('destaque-${p.id}'), fit: StackFit.expand, children: [
                  ColoredBox(color: _t.art),
                  if ((p.imagemUrl ?? '').isEmpty)
                    // Sem foto: só o brilho quente (o ícone do placeholder brigaria com o texto).
                    const Brasa2BrilhoQuente(brilho: brasa2BrilhoHeroi)
                  else
                    AnimatedBuilder(
                      animation: _kb,
                      builder: (_, child) => Transform.scale(
                        scale: widget.mov.anima ? 1.06 + .14 * Curves.easeInOut.transform(_kb.value) : 1.1,
                        child: child,
                      ),
                      child: ProdutoArte(url: p.imagemUrl, tokens: _t, fundo: brasa2FundoBrilho),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xEB120E0C), Color(0x99120E0C), Color(0x00120E0C)],
                        stops: [0, .45, .75],
                      ),
                    ),
                  ),
                  Positioned(
                    left: context.dz(40),
                    bottom: context.dz(40),
                    width: context.dz(470),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text((selo.isEmpty ? 'Combo da casa' : selo).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: brasaTexto(context, 22, peso: FontWeight.w800, cor: _t.accent, espacoEm: .2)),
                      SizedBox(height: context.dz(8)),
                      Text(p.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: brasaTitulo(context, 56)),
                      SizedBox(height: context.dz(8)),
                      Text(formatCentavos(p.precoCentavos),
                          style: brasaTexto(context, 38, peso: FontWeight.w800, cor: _t.accent2)),
                    ]),
                  ),
                ]),
              ),
              if (widget.itens.length > 1)
                Positioned(
                  right: context.dz(30),
                  bottom: context.dz(30),
                  child: Row(children: [
                    for (var i = 0; i < widget.itens.length; i++) ...[
                      if (i > 0) SizedBox(width: context.dz(10)),
                      AnimatedContainer(
                        duration: widget.mov.anima ? widget.mov.d(400) : Duration.zero,
                        width: context.dz(i == _i % widget.itens.length ? 40 : 12),
                        height: context.dz(12),
                        decoration: BoxDecoration(
                          color: i == _i % widget.itens.length ? const Color(0xFFFFFFFF) : const Color(0x59FFFFFF),
                          borderRadius: BorderRadius.circular(context.dz(6)),
                        ),
                      ),
                    ],
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Uma categoria: título em DM Serif 66 e a grade de 2 colunas (espaço 22).
class _Secao extends StatelessWidget {
  const _Secao({
    super.key,
    required this.secao,
    required this.mov,
    required this.chaveFoto,
    required this.onAbrir,
    required this.onMais,
  });

  final SecaoCatalogo secao;
  final Movimento mov;
  final GlobalKey Function(String) chaveFoto;
  final ValueChanged<Produto> onAbrir;
  final ValueChanged<Produto> onMais;

  @override
  Widget build(BuildContext context) {
    final ps = secao.produtos;
    final espaco = context.dz(22);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.only(top: context.dz(34), bottom: context.dz(20)),
        child: Text(secao.categoria.nome, style: brasaTitulo(context, 66)),
      ),
      for (var i = 0; i < ps.length; i += 2) ...[
        if (i > 0) SizedBox(height: espaco),
        // A linha tem a altura do card mais alto (grade do CSS): o rodapé de preço vai para
        // o pé nos dois. A foto tem altura fixa, então a medida não desce até a imagem.
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _card(ps[i])),
            SizedBox(width: espaco),
            Expanded(child: i + 1 < ps.length ? _card(ps[i + 1]) : const SizedBox.shrink()),
          ]),
        ),
      ],
    ]);
  }

  Widget _card(Produto p) => _CardProduto(
        key: ValueKey('produto-${p.id}'),
        produto: p,
        mov: mov,
        chaveFoto: chaveFoto(p.id),
        onAbrir: () => onAbrir(p),
        onMais: () => onMais(p),
      );
}

/// Card de produto (docs/templates/01 §5): foto com brilho quente, selo, nome, descrição,
/// preço e "+". Esgotado: cinza, "Esgotado" e sem toque (`Indisponivel`).
class _CardProduto extends StatefulWidget {
  const _CardProduto({
    super.key,
    required this.produto,
    required this.mov,
    required this.chaveFoto,
    required this.onAbrir,
    required this.onMais,
  });

  final Produto produto;
  final Movimento mov;
  final GlobalKey chaveFoto;
  final VoidCallback onAbrir;
  final VoidCallback onMais;

  @override
  State<_CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<_CardProduto> {
  bool _baixo = false;

  void _pressao(bool v) {
    if (widget.mov.anima && _baixo != v) setState(() => _baixo = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final selo = (p.selo ?? '').trim();
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onAbrir,
      onTapDown: (_) => _pressao(true),
      onTapUp: (_) => _pressao(false),
      onTapCancel: () => _pressao(false),
      child: Container(
        padding: EdgeInsets.fromLTRB(context.dz(16), context.dz(16), context.dz(16), context.dz(22)),
        decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: context.dz(250),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
              child: Stack(fit: StackFit.expand, children: [
                const Brasa2BrilhoQuente(),
                AnimatedScale(
                  scale: _baixo ? 1.06 : 1,
                  duration: widget.mov.d(400),
                  child: KeyedSubtree(
                    key: widget.chaveFoto,
                    child: ProdutoArte(
                      url: p.imagemUrl,
                      tokens: _t,
                      raio: _t.raioBotao,
                      fundo: const Color(0x00000000),
                    ),
                  ),
                ),
                if (selo.isNotEmpty && p.disponivel)
                  Positioned(
                    left: context.dz(12),
                    top: context.dz(12),
                    child: Selo(texto: selo, tokens: _t, altura: context.dz(44)),
                  ),
              ]),
            ),
          ),
          SizedBox(height: context.dz(10)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.dz(6)),
            child: Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: brasaTitulo(context, 38, altura: 1.02)),
          ),
          if (p.descricao.trim().isNotEmpty) ...[
            SizedBox(height: context.dz(10)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.dz(6)),
              child: Text(p.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: brasaTexto(context, 22, cor: _t.muted, altura: 1.35)),
            ),
          ],
          SizedBox(height: context.dz(10)),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.dz(6)),
            child: Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatCentavos(p.precoCentavos),
                      style: brasaTexto(context, 34, peso: FontWeight.w800, cor: _t.price)),
                ),
              ),
              SizedBox(width: context.dz(12)),
              Brasa2BotaoMais(key: ValueKey('adicionar-${p.id}'), onTap: widget.onMais),
            ]),
          ),
        ]),
      ),
    );
    return Indisponivel(ativo: !p.disponivel, tokens: _t, alturaSelo: context.dz(44), child: card);
  }
}
