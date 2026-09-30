import 'dart:math' as math;
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
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Um produto do feed com a categoria a que pertence.
class _Pagina {
  const _Pagina(this.categoria, this.produto);
  final Categoria categoria;
  final Produto produto;
}

/// Catálogo do Vitrine (docs/templates/02 §6.2): feed VERTICAL em tela cheia, um produto
/// por página (encaixe de página), percorrendo as categorias em ordem. Por cima: o topo
/// com as etapas e os chips de categoria; embaixo, a sacola flutuante de vidro.
///
/// Esgotado: a página FICA no feed, em cinza, com "Esgotado" e sem toque (decisão do PR —
/// o cliente vê que o item existe e acabou; pular deixaria o chip da categoria sem página).
class VitrineCatalogoScreen extends ConsumerStatefulWidget {
  const VitrineCatalogoScreen({super.key});

  @override
  ConsumerState<VitrineCatalogoScreen> createState() => _VitrineCatalogoScreenState();
}

class _VitrineCatalogoScreenState extends ConsumerState<VitrineCatalogoScreen>
    with SingleTickerProviderStateMixin {
  final _paginas = PageController();
  final _chipsScroll = ScrollController();
  final _alvoSacola = GlobalKey();
  final _chipKeys = <String, GlobalKey>{};
  late final AnimationController _dica;
  bool _dicaVisivel = false;
  int _atual = 0;

  @override
  void initState() {
    super.initState();
    final mov = ref.read(movimentoProvider);
    // "Deslize para ver mais": a seta pulsa 3 vezes na primeira abertura (só com animação).
    _dica = AnimationController(vsync: this, duration: mov.d(2700))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) setState(() => _dicaVisivel = false);
      });
    if (mov.anima) {
      _dicaVisivel = true;
      _dica.forward();
    }
  }

  @override
  void dispose() {
    _dica.dispose();
    _paginas.dispose();
    _chipsScroll.dispose();
    super.dispose();
  }

  GlobalKey _chipKey(String categoriaId) => _chipKeys.putIfAbsent(categoriaId, GlobalKey.new);

  void _mudouPagina(int i, List<_Pagina> paginas, Movimento mov) {
    setState(() {
      _atual = i;
      _dicaVisivel = false;
    });
    // A página atual marca o chip — e o chip entra na área visível da fileira.
    final cat = paginas[i].categoria.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[cat]?.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: .15,
        duration: mov.anima ? mov.d(300) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Chip → 1º produto da categoria (450 ms, `easeOutCubic`; sem animação, pulo seco).
  void _irPara(int indice, Movimento mov) {
    if (!_paginas.hasClients) return;
    if (mov.anima) {
      _paginas.animateToPage(indice, duration: mov.d(450), curve: Curves.easeOutCubic);
    } else {
      _paginas.jumpToPage(indice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final sync = ref.watch(catalogSyncProvider);
    final carrinho = ref.watch(cartProvider);
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);

    Widget vazio(String titulo, {String? detalhe, Widget? acao}) => _EstadoVazio(
          mov: mov,
          onCancelar: () => acoes.cancelarPedido(context),
          titulo: titulo,
          detalhe: detalhe,
          acao: acao,
        );

    final corpo = menu.when(
      loading: () => _EstadoVazio(
        mov: mov,
        onCancelar: () => acoes.cancelarPedido(context),
        carregando: true,
      ),
      error: (e, _) => vazio('Não deu pra carregar o cardápio', detalhe: '$e'),
      data: (snap) {
        if (snap == null || snap.categorias.isEmpty) {
          return vazio(
            'Cardápio ainda não sincronizado',
            detalhe: sync.status == SyncStatus.offline
                ? 'Sem conexão e sem snapshot local.'
                : 'Baixando a primeira versão…',
            acao: BotaoVitrine(
              key: const ValueKey('catalogo-atualizar'),
              rotulo: 'Atualizar',
              icone: Icons.refresh_rounded,
              altura: 96,
              fonte: 30,
              mov: mov,
              onTap: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
            ),
          );
        }
        final dados = CatalogoDados.de(snap);
        final paginas = [
          for (final s in dados.secoes)
            for (final p in s.produtos) _Pagina(s.categoria, p),
        ];
        if (paginas.isEmpty) return vazio('Nada disponível nesta categoria');
        final atual = _atual.clamp(0, paginas.length - 1);
        final inicioDa = <String, int>{};
        for (var i = 0; i < paginas.length; i++) {
          inicioDa.putIfAbsent(paginas[i].categoria.id, () => i);
        }
        final catAtual = paginas[atual].categoria.id;

        return Stack(fit: StackFit.expand, children: [
          PageView.builder(
            key: const ValueKey('vitrine-feed'),
            controller: _paginas,
            scrollDirection: Axis.vertical,
            itemCount: paginas.length,
            onPageChanged: (i) => _mudouPagina(i, paginas, mov),
            itemBuilder: (context, i) {
              final pg = paginas[i];
              return _PaginaProduto(
                key: ValueKey('pagina-${pg.produto.id}'),
                pagina: pg,
                mov: mov,
                onPersonalizar: () => acoes.abrirProduto(context, pg.produto),
                onAdicionar: (origem) {
                  if (acoes.adicionarOuAbrir(context, pg.produto)) {
                    VooParaSacola.voar(
                      context,
                      origem: origem,
                      destino: _alvoSacola,
                      url: pg.produto.imagemUrl,
                      tokens: vitrineTokens,
                      mov: mov,
                    );
                  }
                },
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopoFeed(
              mov: mov,
              onCancelar: () => acoes.cancelarPedido(context),
              chips: [
                for (final s in dados.secoes)
                  KeyedSubtree(
                    key: _chipKey(s.categoria.id),
                    child: _Chip(
                      key: ValueKey('chip-${s.categoria.id}'),
                      nome: s.categoria.nome,
                      ativo: s.categoria.id == catAtual,
                      mov: mov,
                      onTap: () => _irPara(inicioDa[s.categoria.id] ?? 0, mov),
                    ),
                  ),
              ],
              chipsScroll: _chipsScroll,
            ),
          ),
          if (_dicaVisivel && paginas.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: context.dz(36 + 144 + 22),
              child: IgnorePointer(child: RepaintBoundary(child: _DicaDeslize(anim: _dica))),
            ),
          Positioned(
            left: context.dz(40),
            right: context.dz(40),
            bottom: context.dz(36),
            child: SafeArea(
              top: false,
              child: _BarraSacolaVitrine(
                itens: carrinho.totalItens,
                totalCentavos: carrinho.totalCentavos,
                onVerSacola: () => acoes.verSacola(context),
                alvo: _alvoSacola,
                mov: mov,
              ),
            ),
          ),
        ]);
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: EntradaVitrine(mov: mov, child: corpo),
    );
  }
}

/// Topo sobreposto ao feed: degradê `0xB8000000 → transparente`, logo, "Cancelar",
/// `Etapas(0)` e os chips de categoria (rolam na horizontal).
class _TopoFeed extends StatelessWidget {
  const _TopoFeed({
    required this.mov,
    required this.onCancelar,
    required this.chips,
    required this.chipsScroll,
  });
  final Movimento mov;
  final VoidCallback onCancelar;
  final List<Widget> chips;
  final ScrollController chipsScroll;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB8000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: context.dz(20)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopoVitrine(etapa: 0, onCancelar: onCancelar, mov: mov, sobreFoto: true),
            SizedBox(height: context.dz(6)),
            SizedBox(
              height: context.dz(74),
              child: SingleChildScrollView(
                key: const ValueKey('vitrine-chips'),
                controller: chipsScroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.dz(48)),
                child: Row(children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) SizedBox(width: context.dz(12)),
                    chips[i],
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Chip de categoria (§5): pílula de vidro, altura 74; o atual fica branco com texto
/// `0xFF111111` (transição de 300 ms).
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.nome, required this.ativo, required this.mov, required this.onTap});
  final String nome;
  final bool ativo;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(context.dz(37));
    Widget chip = AnimatedContainer(
      duration: mov.anima ? mov.d(300) : Duration.zero,
      height: context.dz(74),
      padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ativo ? const Color(0xFFFFFFFF) : (mov.blur ? const Color(0x1FFFFFFF) : vitrineVidroSemBlur),
        borderRadius: raio,
        border: Border.all(
          color: ativo ? const Color(0xFFFFFFFF) : const Color(0x47FFFFFF),
          width: context.dz(2),
        ),
      ),
      child: Text(nome,
          maxLines: 1,
          style: context.vTexto(26, cor: ativo ? vitrineTinta111 : const Color(0xFFFFFFFF), altura: 1)),
    );
    if (mov.blur) {
      chip = ClipRRect(
        borderRadius: raio,
        child: BackdropFilter(filter: vitrineDesfoque(context, 14), child: chip),
      );
    }
    return Semantics(
      button: true,
      selected: ativo,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: chip),
    );
  }
}

/// Uma página do feed: foto em cover (escala 1,04) com degradê de leitura, ou — sem foto —
/// o disco `accent` com o recorte flutuando; texto ancorado a 260 do rodapé.
class _PaginaProduto extends StatefulWidget {
  const _PaginaProduto({
    super.key,
    required this.pagina,
    required this.mov,
    required this.onPersonalizar,
    required this.onAdicionar,
  });

  final _Pagina pagina;
  final Movimento mov;
  final VoidCallback onPersonalizar;

  /// Recebe a âncora de onde a foto "voa" até a sacola.
  final void Function(GlobalKey origem) onAdicionar;

  @override
  State<_PaginaProduto> createState() => _PaginaProdutoState();
}

class _PaginaProdutoState extends State<_PaginaProduto> {
  final _origem = GlobalKey();

  static const _cinza = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final p = widget.pagina.produto;
    final esgotado = !p.disponivel;
    final url = p.imagemUrl?.trim() ?? '';
    final temFoto = url.isNotEmpty && !ProdutoArte.ehRecorte(url);
    Widget fundo = temFoto
        ? Transform.scale(
            scale: 1.04,
            child: RepaintBoundary(
              child: ProdutoArte(url: url, tokens: vitrineTokens, fundo: const Color(0xFF000000)),
            ),
          )
        : ArteSemFotoVitrine(url: url.isEmpty ? null : url, mov: widget.mov);
    if (esgotado) fundo = Opacity(opacity: .55, child: ColorFiltered(colorFilter: _cinza, child: fundo));

    return LayoutBuilder(builder: (context, c) {
      // Tela baixa (harness 800×600, totem em paisagem): título e descrição encolhem.
      final baixa = c.maxHeight < context.dz(1500);
      final alturaSelo = context.dz(44);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: esgotado ? null : widget.onPersonalizar,
        child: Stack(fit: StackFit.expand, children: [
          fundo,
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: vitrineDegradeLeitura))),
          Positioned(
            left: c.maxWidth / 2 - context.dz(200),
            top: c.maxHeight * .32,
            width: context.dz(400),
            height: context.dz(400),
            child: IgnorePointer(child: SizedBox(key: _origem)),
          ),
          Positioned(
            left: context.dz(56) - (esgotado ? alturaSelo * .3 : 0),
            right: context.dz(56),
            bottom: context.dz(baixa ? 236 : 260),
            child: Indisponivel(
              ativo: esgotado,
              tokens: vitrineTokens,
              alturaSelo: alturaSelo,
              child: Padding(
                padding: EdgeInsets.only(left: esgotado ? alturaSelo * .3 : 0),
                child: _TextoPagina(
                  pagina: widget.pagina,
                  baixa: baixa,
                  alturaSelo: alturaSelo,
                  mov: widget.mov,
                  onPersonalizar: widget.onPersonalizar,
                  onAdicionar: () => widget.onAdicionar(_origem),
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _TextoPagina extends StatelessWidget {
  const _TextoPagina({
    required this.pagina,
    required this.baixa,
    required this.alturaSelo,
    required this.mov,
    required this.onPersonalizar,
    required this.onAdicionar,
  });

  final _Pagina pagina;
  final bool baixa;
  final double alturaSelo;
  final Movimento mov;
  final VoidCallback onPersonalizar;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final p = pagina.produto;
    final esgotado = !p.disponivel;
    final selo = p.selo?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selo em cima do nome (§5). Esgotado: a vaga é do selo "Esgotado" do `Indisponivel`.
        if (esgotado)
          SizedBox(height: alturaSelo * 1.3)
        else if (selo.isNotEmpty)
          Selo(texto: selo, tokens: t, altura: alturaSelo, fundo: t.accent2, tinta: t.onAccent2),
        if (esgotado || selo.isNotEmpty) SizedBox(height: context.dz(16)),
        Text(pagina.categoria.nome.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.vTexto(24, cor: const Color(0xBFFFFFFF), espacoEm: .16)),
        SizedBox(height: context.dz(14)),
        TituloVitrine(p.nome, maxLines: baixa ? 2 : 3, estilo: context.vDisplay(baixa ? 84 : 118, altura: .9)),
        if (p.descricao.trim().isNotEmpty) ...[
          SizedBox(height: context.dz(16)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.dz(880)),
            child: Text(p.descricao,
                maxLines: baixa ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: context.vTexto(30, peso: FontWeight.w400, cor: const Color(0xD9FFFFFF), altura: 1.35)),
          ),
        ],
        SizedBox(height: context.dz(26)),
        Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatCentavos(p.precoCentavos),
                    style: context.vDisplay(64, cor: t.accent2, espacoEm: -.02)),
              ),
            ),
          ),
          SizedBox(width: context.dz(18)),
          if (esgotado)
            _PilulaEsgotado(mov: mov)
          else ...[
            BotaoVitrine(
              key: ValueKey('personalizar-${p.id}'),
              rotulo: 'Personalizar',
              estilo: EstiloBotaoVitrine.vidro,
              altura: 96,
              fonte: 30,
              padH: 34,
              mov: mov,
              onTap: onPersonalizar,
            ),
            SizedBox(width: context.dz(18)),
            BotaoVitrine(
              key: ValueKey('adicionar-${p.id}'),
              rotulo: 'Adicionar',
              icone: Icons.add_rounded,
              altura: 96,
              fonte: 30,
              padH: 34,
              mov: mov,
              onTap: onAdicionar,
            ),
          ],
        ]),
      ],
    );
  }
}

/// "Esgotado" no lugar dos botões: pílula de vidro sem toque (o `Indisponivel` em volta
/// já apaga e desliga a página).
class _PilulaEsgotado extends StatelessWidget {
  const _PilulaEsgotado({required this.mov});
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final h = context.dz(96);
    return SizedBox(
      height: h,
      child: VidroVitrine(
        mov: mov,
        raio: BorderRadius.circular(h / 2),
        padding: EdgeInsets.symmetric(horizontal: context.dz(34)),
        child: Center(
          widthFactor: 1,
          child: Text('Esgotado', style: context.vTexto(30, peso: FontWeight.w800, altura: 1)),
        ),
      ),
    );
  }
}

/// A seta "Deslize para ver mais", que pulsa 3 vezes acima da sacola.
class _DicaDeslize extends StatelessWidget {
  const _DicaDeslize({required this.anim});
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    const sombra = [Shadow(color: Color(0x99000000), blurRadius: 12)];
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) {
        final v = anim.value;
        final pulso = math.sin(((v * 3) % 1) * math.pi);
        final opacidade = v > .9 ? (1 - (v - .9) / .1).clamp(0.0, 1.0) : 1.0;
        return Opacity(
          opacity: opacidade,
          child: Transform.translate(offset: Offset(0, -context.dz(14) * pulso), child: child),
        );
      },
      child: Row(key: const ValueKey('dica-deslize'), mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.keyboard_arrow_up_rounded, size: context.dz(44), color: const Color(0xFFFFFFFF), shadows: sombra),
        SizedBox(width: context.dz(8)),
        Text('Deslize para ver mais',
            style: context.vTexto(24, peso: FontWeight.w800).copyWith(shadows: sombra)),
      ]),
    );
  }
}

/// Sacola flutuante do feed (§6.2): vidro, borda `0x2EFFFFFF`, contador `accent2` e o
/// botão interno "Ver sacola" em `accent`. Mesma regra da `BarraSacola` da base (texto,
/// total, "pulo" quando o total muda, alvo do voo) — variante local porque a da base não
/// tem vidro, borda nem a cor própria do contador.
class _BarraSacolaVitrine extends StatefulWidget {
  const _BarraSacolaVitrine({
    required this.itens,
    required this.totalCentavos,
    required this.onVerSacola,
    required this.alvo,
    required this.mov,
  });
  final int itens;
  final int totalCentavos;
  final VoidCallback onVerSacola;
  final GlobalKey alvo;
  final Movimento mov;

  @override
  State<_BarraSacolaVitrine> createState() => _BarraSacolaVitrineState();
}

class _BarraSacolaVitrineState extends State<_BarraSacolaVitrine> with SingleTickerProviderStateMixin {
  late final AnimationController _bump;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _bump = AnimationController(vsync: this, duration: widget.mov.d(500));
    _escala = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: .98), weight: 30),
      TweenSequenceItem(tween: Tween(begin: .98, end: 1), weight: 40),
    ]).animate(CurvedAnimation(parent: _bump, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _BarraSacolaVitrine old) {
    super.didUpdateWidget(old);
    if (old.totalCentavos != widget.totalCentavos && widget.mov.anima) _bump.forward(from: 0);
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final vazia = widget.itens == 0;
    final h = context.dz(144);
    final rotulo = vazia
        ? 'Sua sacola está vazia'
        : 'Sua sacola · ${widget.itens} ${widget.itens == 1 ? 'item' : 'itens'}';
    return ScaleTransition(
      scale: _escala,
      child: Opacity(
        opacity: vazia ? .55 : 1,
        child: VidroVitrine(
          mov: widget.mov,
          raio: BorderRadius.circular(h / 2),
          cor: const Color(0xB8181818),
          borda: const Color(0x2EFFFFFF),
          sigma: 24,
          child: GestureDetector(
            key: const ValueKey('barra-sacola'),
            behavior: HitTestBehavior.opaque,
            onTap: vazia ? null : widget.onVerSacola,
            child: SizedBox(
              height: h,
              child: Padding(
                padding: EdgeInsets.only(left: context.dz(36), right: context.dz(22)),
                child: Row(children: [
                  SizedBox(
                    key: widget.alvo,
                    width: context.dz(72),
                    height: context.dz(72),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Center(child: Icon(Icons.shopping_bag_outlined, size: context.dz(54), color: t.text)),
                      Positioned(
                        top: -context.dz(6),
                        right: -context.dz(10),
                        child: Container(
                          constraints: BoxConstraints(minWidth: context.dz(40)),
                          height: context.dz(40),
                          padding: EdgeInsets.symmetric(horizontal: context.dz(8)),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.accent2,
                            borderRadius: BorderRadius.circular(context.dz(20)),
                          ),
                          child: Text('${widget.itens}',
                              key: const ValueKey('sacola-contador'),
                              style: context.vTexto(22, peso: FontWeight.w800, cor: t.onAccent2, altura: 1)),
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(width: context.dz(26)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rotulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.vTexto(24, cor: const Color(0xCCFFFFFF))),
                        Text(formatCentavos(widget.totalCentavos),
                            key: const ValueKey('sacola-total'),
                            maxLines: 1,
                            style: context.vTexto(46, peso: FontWeight.w800, altura: 1.1)),
                      ],
                    ),
                  ),
                  Container(
                    height: context.dz(100),
                    padding: EdgeInsets.symmetric(horizontal: context.dz(36)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(context.dz(50)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Ver sacola', style: context.vTexto(32, peso: FontWeight.w800, cor: t.onAccent, altura: 1)),
                      SizedBox(width: context.dz(12)),
                      Icon(Icons.arrow_forward_rounded, size: context.dz(32), color: t.onAccent),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carregando, sem cardápio e erro — no visual do template, com o "Cancelar" do topo.
class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({
    required this.mov,
    required this.onCancelar,
    this.titulo,
    this.detalhe,
    this.acao,
    this.carregando = false,
  });

  final Movimento mov;
  final VoidCallback onCancelar;
  final String? titulo;
  final String? detalhe;
  final Widget? acao;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return ColoredBox(
      color: t.bg,
      child: SafeArea(
        child: Column(children: [
          TopoVitrine(etapa: 0, onCancelar: onCancelar, mov: mov),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: context.dz(56), vertical: context.dz(24)),
                child: carregando
                    ? SizedBox(
                        width: context.dz(88),
                        height: context.dz(88),
                        child: CircularProgressIndicator(color: t.accent, strokeWidth: context.dz(8)),
                      )
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.restaurant_menu_rounded, size: context.dz(120), color: t.accent),
                        SizedBox(height: context.dz(30)),
                        Text(titulo ?? '',
                            key: const ValueKey('catalogo-vazio'),
                            textAlign: TextAlign.center,
                            style: context.vDisplay(56, altura: 1.05)),
                        if (detalhe != null) ...[
                          SizedBox(height: context.dz(16)),
                          Text(detalhe!,
                              textAlign: TextAlign.center,
                              style: context.vTexto(30, peso: FontWeight.w400, cor: t.muted, altura: 1.35)),
                        ],
                        if (acao != null) ...[SizedBox(height: context.dz(36)), acao!],
                      ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
