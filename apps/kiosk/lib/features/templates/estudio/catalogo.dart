import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/cart.dart';
import '../comum/catalogo_dados.dart';
import '../comum/sacola.dart';
import '../comum/selo.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

// Medidas fixas (px de desenho) — a rolagem até cada seção é calculada com elas, sem
// depender de layout (as seções fora da tela nem são construídas).
const _altFaixa = 12.0 + 420 + 28;
const _altPilulas = 12.0 + 88 + 18;
const _altCabecalho = 34.0 + 70 + 20;
const _altCard = 18.0 + 240 + 12 + 70 + 12 + 64 + 22;
const _altDescricao = 6.0 + 56;
const _espaco = 22.0;

/// Catálogo do Estúdio (docs/03 §6.2): faixa de destaques com rolagem automática,
/// pílulas de categoria fixas ao rolar, seções com grade de 3 colunas de cards que
/// inclinam em 3D e a `BarraSacola` escura embaixo. Tela inteira: lê os providers e usa
/// `AcoesPedido` (mesma regra das telas atuais).
class EstudioCatalogo extends ConsumerStatefulWidget {
  const EstudioCatalogo({super.key});

  @override
  ConsumerState<EstudioCatalogo> createState() => _EstudioCatalogoState();
}

class _EstudioCatalogoState extends ConsumerState<EstudioCatalogo> {
  final _rolagem = ScrollController();
  final _rolagemPilulas = ScrollController();
  final _alvoSacola = GlobalKey();
  final _chavesArte = <String, GlobalKey>{};
  final _chavesPilula = <String, GlobalKey>{};

  /// Categoria marcada nas pílulas.
  String? _categoria;

  /// Deslocamento de rolagem que deixa cada seção logo abaixo das pílulas fixas.
  List<double> _inicios = const [];
  List<String> _ids = const [];
  bool _rolandoPorToque = false;

  GlobalKey _chaveArte(String id) => _chavesArte.putIfAbsent(id, GlobalKey.new);
  GlobalKey _chavePilula(String id) => _chavesPilula.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _rolagem.dispose();
    _rolagemPilulas.dispose();
    super.dispose();
  }

  /// Rolar marca a categoria visível.
  void _aoRolar() {
    if (_rolandoPorToque || _inicios.isEmpty || !_rolagem.hasClients) return;
    final pos = _rolagem.position;
    var i = 0;
    for (var j = 0; j < _inicios.length; j++) {
      if (_inicios[j] <= pos.pixels + 1) i = j;
    }
    if (pos.pixels >= pos.maxScrollExtent - 1) i = _inicios.length - 1;
    final id = _ids[i];
    if (id != _categoria) {
      setState(() => _categoria = id);
      _mostrarPilula(id);
    }
  }

  /// Tocar numa categoria rola até a seção dela.
  Future<void> _irPara(String id, Movimento mov) async {
    final i = _ids.indexOf(id);
    if (i < 0) return;
    setState(() => _categoria = id);
    _mostrarPilula(id);
    if (!_rolagem.hasClients) return;
    final alvo = _inicios[i].clamp(0.0, _rolagem.position.maxScrollExtent);
    _rolandoPorToque = true;
    try {
      if (mov.anima) {
        await _rolagem.animateTo(alvo, duration: mov.d(520), curve: Curves.easeInOutCubic);
      } else {
        _rolagem.jumpTo(alvo);
      }
    } finally {
      _rolandoPorToque = false;
    }
  }

  /// Traz a pílula marcada para o meio da faixa de pílulas.
  void _mostrarPilula(String id) {
    final ro = _chavesPilula[id]?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !_rolagemPilulas.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) return;
    final alvo = viewport
        .getOffsetToReveal(ro, .5)
        .offset
        .clamp(0.0, _rolagemPilulas.position.maxScrollExtent);
    _rolagemPilulas.animateTo(alvo, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _adicionar(BuildContext context, Produto p, GlobalKey origem, Movimento mov) {
    if (AcoesPedido(ref).adicionarOuAbrir(context, p)) {
      VooParaSacola.voar(context, origem: origem, destino: _alvoSacola, url: p.imagemUrl, tokens: _t, mov: mov);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    final carrinho = ref.watch(cartProvider);
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);

    final Widget conteudo = menu.when(
      loading: () => EstadoEstudio(carregando: true, mov: mov),
      error: (e, _) => EstadoEstudio(
        titulo: 'Não deu pra carregar o cardápio',
        detalhe: '$e',
        icone: Icons.cloud_off_rounded,
      ),
      data: (snap) {
        if (snap == null || snap.categorias.isEmpty) {
          final offline = sync.status == SyncStatus.offline;
          return EstadoEstudio(
            titulo: 'Cardápio ainda não sincronizado',
            detalhe: offline ? 'Sem conexão e sem snapshot local.' : 'Baixando a primeira versão…',
            icone: offline ? Icons.cloud_off_rounded : Icons.cloud_download_outlined,
            acao: BotaoEstudio(
              chave: 'catalogo-atualizar',
              rotulo: 'Atualizar',
              icone: Icons.refresh_rounded,
              onTap: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
            ),
          );
        }
        final dados = CatalogoDados.de(snap);
        if (dados.secoes.isEmpty) {
          return const EstadoEstudio(titulo: 'Nada disponível nesta categoria');
        }
        return _cardapio(context, dados, mov);
      },
    );

    return TelaEstudio(
      mov: mov,
      child: Flutuacao(
        ligada: movimentoCheio(mov),
        child: Column(children: [
          TopoEstudio(etapa: 0, onCancelar: () => acoes.cancelarPedido(context), mov: mov),
          Expanded(child: conteudo),
          Padding(
            padding: EdgeInsets.fromLTRB(context.dz(40), context.dz(18), context.dz(40), context.dz(36)),
            child: AnimatedOpacity(
              opacity: carrinho.vazio ? .55 : 1,
              duration: duracao(mov, 200),
              child: BarraSacola(
                itens: carrinho.totalItens,
                totalCentavos: carrinho.totalCentavos,
                onVerSacola: () => acoes.verSacola(context),
                tokens: _t,
                alvo: _alvoSacola,
                mov: mov,
                fundo: _t.text,
                tinta: EstudioCores.branco,
                botaoFundo: _t.accent,
                botaoTinta: _t.onAccent,
                raio: _t.raioBotao,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cardapio(BuildContext context, CatalogoDados dados, Movimento mov) {
    final k = context.k;
    final faixa = dados.destaques.isEmpty ? 0.0 : _altFaixa * k;
    final inicios = <double>[];
    final ids = <String>[];
    final alturas = <double>[];
    final comDescricao = <bool>[];
    var y = faixa;
    for (final s in dados.secoes) {
      final desc = s.produtos.any((p) => p.descricao.trim().isNotEmpty);
      final hc = (_altCard + (desc ? _altDescricao : 0)) * k;
      final linhas = (s.produtos.length / 3).ceil();
      inicios.add(y);
      ids.add(s.categoria.id);
      alturas.add(hc);
      comDescricao.add(desc);
      y += _altCabecalho * k + linhas * hc + (linhas - 1) * _espaco * k;
    }
    _inicios = inicios;
    _ids = ids;
    final selecionada = ids.contains(_categoria) ? _categoria! : ids.first;

    return CustomScrollView(
      key: const ValueKey('catalogo-rolagem'),
      controller: _rolagem,
      slivers: [
        if (dados.destaques.isNotEmpty)
          SliverToBoxAdapter(
            child: _FaixaDestaques(
              destaques: dados.destaques,
              mov: mov,
              chave: (id) => _chaveArte('destaque-$id'),
              onAbrir: (p) => AcoesPedido(ref).abrirProduto(context, p),
              onAdicionar: (p, origem) => _adicionar(context, p, origem, mov),
            ),
          ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _Pilulas(
            altura: _altPilulas * k,
            categorias: [for (final s in dados.secoes) s.categoria],
            selecionada: selecionada,
            controller: _rolagemPilulas,
            chave: _chavePilula,
            onTap: (id) => _irPara(id, mov),
          ),
        ),
        for (var i = 0; i < dados.secoes.length; i++) ...[
          SliverToBoxAdapter(child: _CabecalhoSecao(secao: dados.secoes[i])),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 48 * k),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: _espaco * k,
                crossAxisSpacing: _espaco * k,
                mainAxisExtent: alturas[i],
              ),
              delegate: SliverChildBuilderDelegate(
                (context, j) {
                  final s = dados.secoes[i];
                  final p = s.produtos[j];
                  final chave = _chaveArte(p.id);
                  return _CardProduto(
                    p: p,
                    cor: corDisco(j, s.categoria.cor),
                    chaveArte: chave,
                    mov: mov,
                    comDescricao: comDescricao[i],
                    onAbrir: () => AcoesPedido(ref).abrirProduto(context, p),
                    onAdicionar: () => _adicionar(context, p, chave, mov),
                  );
                },
                childCount: dados.secoes[i].produtos.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: 40 * k)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── destaques

/// Faixa de destaques: cartões de 880×420 com encaixe, rolando sozinha a cada 3,5 s
/// (pausa enquanto há dedo na faixa; sem animação, não rola sozinha).
class _FaixaDestaques extends StatefulWidget {
  const _FaixaDestaques({
    required this.destaques,
    required this.mov,
    required this.chave,
    required this.onAbrir,
    required this.onAdicionar,
  });

  final List<Produto> destaques;
  final Movimento mov;
  final GlobalKey Function(String id) chave;
  final void Function(Produto p) onAbrir;
  final void Function(Produto p, GlobalKey origem) onAdicionar;

  @override
  State<_FaixaDestaques> createState() => _FaixaDestaquesState();
}

class _FaixaDestaquesState extends State<_FaixaDestaques> {
  // Página = cartão de 880 + espaço de 26, numa janela de 1080 − 48 de margem. Como tudo
  // escala com a largura, a fração é a mesma em qualquer tela.
  late final PageController _pc;
  Timer? _timer;
  bool _tocando = false;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 906 / 1032);
    _agendar();
  }

  @override
  void didUpdateWidget(covariant _FaixaDestaques old) {
    super.didUpdateWidget(old);
    if (old.mov.anima != widget.mov.anima || old.destaques.length != widget.destaques.length) _agendar();
  }

  void _agendar() {
    _timer?.cancel();
    _timer = null;
    if (!widget.mov.anima || widget.destaques.length < 2) return;
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) => _passar());
  }

  void _passar() {
    if (!mounted || _tocando || !_pc.hasClients) return;
    final n = widget.destaques.length;
    final atual = (_pc.page ?? 0).round();
    _pc.animateToPage((atual + 1) % n, duration: widget.mov.d(700), curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.only(left: 48 * k, top: 12 * k, bottom: 28 * k),
      child: SizedBox(
        height: 420 * k,
        child: Listener(
          onPointerDown: (_) => _tocando = true,
          onPointerUp: (_) => _tocando = false,
          onPointerCancel: (_) => _tocando = false,
          child: PageView.builder(
            key: const ValueKey('faixa-destaques'),
            controller: _pc,
            padEnds: false,
            clipBehavior: Clip.none,
            itemCount: widget.destaques.length,
            itemBuilder: (context, i) {
              final p = widget.destaques[i];
              final chave = widget.chave(p.id);
              return Align(
                alignment: Alignment.centerLeft,
                child: _CartaoDestaque(
                  p: p,
                  cor: corDisco(i),
                  chaveArte: chave,
                  mov: widget.mov,
                  onAbrir: () => widget.onAbrir(p),
                  onAdicionar: () => widget.onAdicionar(p, chave),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CartaoDestaque extends StatelessWidget {
  const _CartaoDestaque({
    required this.p,
    required this.cor,
    required this.chaveArte,
    required this.mov,
    required this.onAbrir,
    required this.onAdicionar,
  });

  final Produto p;
  final Color cor;
  final GlobalKey chaveArte;
  final Movimento mov;
  final VoidCallback onAbrir;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tinta = tintaSobre(cor);
    final selo = (p.selo ?? '').trim();
    return GestureDetector(
      key: ValueKey('destaque-${p.id}'),
      onTap: onAbrir,
      child: Container(
        width: 880 * k,
        height: 420 * k,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(44 * k)),
        child: Stack(children: [
          Positioned(
            right: -120 * k,
            bottom: -160 * k,
            width: 560 * k,
            height: 560 * k,
            child: const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: EstudioCores.brilhoDestaque),
            ),
          ),
          Positioned(
            right: 26 * k,
            bottom: 24 * k,
            width: 440 * k,
            height: 360 * k,
            child: Flutua(
              child: KeyedSubtree(
                key: chaveArte,
                child: ArteEstudio(
                  url: p.imagemUrl,
                  foto: .86,
                  borda: 8,
                  recorteLargura: 1,
                  recorteAltura: 1,
                  mov: mov,
                ),
              ),
            ),
          ),
          Positioned(
            left: 48 * k,
            top: 44 * k,
            bottom: 44 * k,
            width: 430 * k,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((selo.isEmpty ? 'Destaque' : selo).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t.texto(22 * k, peso: FontWeight.w800, cor: tinta.withAlpha(217), espaco: 22 * .14 * k)),
              SizedBox(height: 10 * k),
              Text(p.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t.display(62 * k, cor: tinta, altura: 1).copyWith(letterSpacing: -62 * .03 * k)),
              SizedBox(height: 10 * k),
              Text(formatCentavos(p.precoCentavos), style: _t.texto(40 * k, peso: FontWeight.w800, cor: tinta)),
              const Spacer(),
              Material(
                color: EstudioCores.branco,
                borderRadius: BorderRadius.circular(36 * k),
                child: InkWell(
                  key: ValueKey('destaque-mais-${p.id}'),
                  borderRadius: BorderRadius.circular(36 * k),
                  onTap: onAdicionar,
                  child: SizedBox(
                    height: 72 * k,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28 * k),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Adicionar', style: _t.texto(26 * k, peso: FontWeight.w800)),
                        SizedBox(width: 10 * k),
                        Icon(Icons.arrow_forward_rounded, size: 28 * k, color: _t.text),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── pílulas

/// Pílulas de categoria FIXAS no topo ao rolar (fundo `bg`).
class _Pilulas extends SliverPersistentHeaderDelegate {
  _Pilulas({
    required this.altura,
    required this.categorias,
    required this.selecionada,
    required this.controller,
    required this.chave,
    required this.onTap,
  });

  final double altura;
  final List<Categoria> categorias;
  final String selecionada;
  final ScrollController controller;
  final GlobalKey Function(String id) chave;
  final void Function(String id) onTap;

  @override
  double get minExtent => altura;
  @override
  double get maxExtent => altura;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final k = context.k;
    return ColoredBox(
      color: _t.bg,
      child: ListView.separated(
        key: const ValueKey('pilulas'),
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(48 * k, 12 * k, 48 * k, 18 * k),
        itemCount: categorias.length,
        separatorBuilder: (_, __) => SizedBox(width: 14 * k),
        itemBuilder: (context, i) {
          final c = categorias[i];
          return _Pilula(
            key: chave(c.id),
            categoria: c,
            selecionada: c.id == selecionada,
            onTap: () => onTap(c.id),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _Pilulas old) =>
      old.selecionada != selecionada || old.altura != altura || old.categorias != categorias;
}

class _Pilula extends StatelessWidget {
  const _Pilula({super.key, required this.categoria, required this.selecionada, required this.onTap});
  final Categoria categoria;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final raio = BorderRadius.circular(44 * k);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [BoxShadow(color: _t.line, offset: Offset(0, 2 * k))],
      ),
      child: Material(
        color: selecionada ? _t.text : _t.surface,
        borderRadius: raio,
        child: InkWell(
          key: ValueKey('categoria-${categoria.id}'),
          borderRadius: raio,
          onTap: onTap,
          child: SizedBox(
            height: 88 * k,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10 * k, 0, 28 * k, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _IconeCategoria(categoria: categoria, diametro: 68 * k),
                SizedBox(width: 12 * k),
                Text(categoria.nome,
                    style: _t.texto(26 * k,
                        peso: FontWeight.w700, cor: selecionada ? EstudioCores.branco : _t.text)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Imagem circular da categoria: a foto do painel ▸ o emoji ▸ a inicial na cor dela.
class _IconeCategoria extends StatelessWidget {
  const _IconeCategoria({required this.categoria, required this.diametro});
  final Categoria categoria;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    final url = c.imagemUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return ClipOval(
        child: SizedBox(
          width: diametro,
          height: diametro,
          child: ColoredBox(
            color: _t.art,
            child: ImagemEstudio(url: url, memCacheWidth: (diametro * dpr).round()),
          ),
        ),
      );
    }
    final temCor = (c.cor ?? '').trim().isNotEmpty;
    final fundo = temCor ? corDisco(0, c.cor) : _t.hi;
    final emoji = c.emoji?.trim() ?? '';
    final nome = c.nome.trim();
    return Container(
      width: diametro,
      height: diametro,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fundo),
      child: emoji.isNotEmpty
          ? Text(emoji, style: TextStyle(fontSize: diametro * .5))
          : Text(nome.isEmpty ? '•' : nome.substring(0, 1).toUpperCase(),
              style: _t.display(diametro * .44, cor: temCor ? tintaSobre(fundo) : _t.accent, altura: 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────── seções e cards

class _CabecalhoSecao extends StatelessWidget {
  const _CabecalhoSecao({required this.secao});
  final SecaoCatalogo secao;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: _altCabecalho * k,
      child: Padding(
        padding: EdgeInsets.fromLTRB(48 * k, 34 * k, 48 * k, 20 * k),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(secao.categoria.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t.display(56 * k, altura: 1.1).copyWith(letterSpacing: -56 * .03 * k)),
            ),
            SizedBox(width: 16 * k),
            Text('${secao.produtos.length}',
                style: _t.texto(26 * k, peso: FontWeight.w600, cor: _t.muted)),
          ],
        ),
      ),
    );
  }
}

/// Card de produto (`.ecard`): foto sobre o disco na cor da posição, selo, nome, preço e
/// "+". Inclina em 3D sob o dedo (movimento cheio) e a arte sobe no toque. Indisponível:
/// cinza, "Esgotado" e sem toque.
class _CardProduto extends StatelessWidget {
  const _CardProduto({
    required this.p,
    required this.cor,
    required this.chaveArte,
    required this.mov,
    required this.comDescricao,
    required this.onAbrir,
    required this.onAdicionar,
  });

  final Produto p;
  final Color cor;
  final GlobalKey chaveArte;
  final Movimento mov;
  final bool comDescricao;
  final VoidCallback onAbrir;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final esgotado = !p.disponivel;
    final selo = (p.selo ?? '').trim();
    final card = CartaoInclinavel(
      inclina: movimentoCheio(mov) && !esgotado,
      builder: (context, premido) => GestureDetector(
        key: ValueKey('estudio-prod-${p.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: esgotado ? null : onAbrir,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: EdgeInsets.fromLTRB(18 * k, 18 * k, 18 * k, 22 * k),
            decoration: BoxDecoration(
              color: _t.surface,
              borderRadius: BorderRadius.circular(36 * k),
              boxShadow: sombraCard(k),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 240 * k,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26 * k),
                  child: KeyedSubtree(
                    key: chaveArte,
                    child: ArteEstudio(url: p.imagemUrl, corDisco: cor, levantado: premido && !esgotado, mov: mov),
                  ),
                ),
              ),
              SizedBox(height: 12 * k),
              // Nome (até 2 linhas) e, quando a seção tem descrições, a descrição logo
              // abaixo (até 2 linhas) — numa caixa de altura fixa, para a grade alinhar.
              SizedBox(
                height: (70 + (comDescricao ? _altDescricao : 0)) * k,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t.texto(30 * k, peso: FontWeight.w800, altura: 1.15)),
                  if (comDescricao && p.descricao.trim().isNotEmpty) ...[
                    SizedBox(height: 6 * k),
                    Flexible(
                      child: Text(p.descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t.texto(22 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.25)),
                    ),
                  ],
                ]),
              ),
              SizedBox(height: 12 * k),
              SizedBox(
                height: 64 * k,
                child: Row(children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatCentavos(p.precoCentavos),
                          style: _t.texto(34 * k, peso: FontWeight.w800, cor: _t.price)),
                    ),
                  ),
                  BotaoMais(diametro: 64, chave: 'estudio-mais-${p.id}', onTap: esgotado ? null : onAdicionar),
                ]),
              ),
            ]),
          ),
          if (selo.isNotEmpty && !esgotado)
            Positioned(left: 14 * k, top: 14 * k, child: Selo(texto: selo, tokens: _t, altura: 44 * k)),
        ]),
      ),
    );
    return Indisponivel(ativo: esgotado, tokens: _t, alturaSelo: 44 * k, child: card);
  }
}
