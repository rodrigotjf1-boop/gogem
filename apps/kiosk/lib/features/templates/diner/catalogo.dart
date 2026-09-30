import 'dart:math' as math;
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
import '../comum/selo.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';
import 'pintores.dart';

const _t = dinerTokens;

/// Cardápio do **Diner 58** (docs/templates/05 §6.2): cabeçalho vermelho com lâmpadas,
/// botões "jukebox" das categorias, especial do dia e a "lousa" com fotos redondas,
/// pontilhado até o preço e preços em selos vermelhos inclinados. Tela inteira: lê os
/// providers como a GoGen; as ações de pedido são as do `AcoesPedido` comum.
class DinerCatalogo extends ConsumerStatefulWidget {
  const DinerCatalogo({super.key});

  @override
  ConsumerState<DinerCatalogo> createState() => _DinerCatalogoState();
}

class _DinerCatalogoState extends ConsumerState<DinerCatalogo> {
  final _scroll = ScrollController();
  final _alvoSacola = GlobalKey();
  final _viewport = GlobalKey();
  final Map<String, GlobalKey> _secoes = {};
  final Map<String, GlobalKey> _botoes = {};
  List<String> _ordem = const [];
  String? _ativa;
  bool _rolandoPorToque = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _scroll.removeListener(_aoRolar);
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _chaveSecao(String id) => _secoes.putIfAbsent(id, GlobalKey.new);
  GlobalKey _chaveBotao(String id) => _botoes.putIfAbsent(id, GlobalKey.new);

  /// Rolar marca a categoria visível (a última seção cujo topo já passou do topo da lista).
  void _aoRolar() {
    if (_rolandoPorToque || _ordem.isEmpty) return;
    final vp = _viewport.currentContext?.findRenderObject();
    if (vp is! RenderBox || !vp.hasSize) return;
    final limite = vp.localToGlobal(Offset.zero).dy + context.dz(90);
    String atual = _ordem.first;
    for (final id in _ordem) {
      final ro = _secoes[id]?.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) continue;
      if (ro.localToGlobal(Offset.zero).dy <= limite) {
        atual = id;
      } else {
        break;
      }
    }
    if (atual != _ativa) {
      setState(() => _ativa = atual);
      _mostraBotao(atual);
    }
  }

  /// Leva o botão jukebox ativo para a vista (quando há mais categorias que cabem).
  void _mostraBotao(String id) {
    if (_ordem.length <= 5) return;
    final ctx = _botoes[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 200));
  }

  /// Toque na jukebox: rola até a seção.
  Future<void> _irPara(String id, Movimento mov) async {
    setState(() => _ativa = id);
    final ctx = _secoes[id]?.currentContext;
    if (ctx == null) return;
    _rolandoPorToque = true;
    try {
      await Scrollable.ensureVisible(
        ctx,
        duration: mov.anima ? mov.d(500) : Duration.zero,
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
    final cart = ref.watch(cartProvider);
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);

    final corpo = menu.when(
      loading: () => const _Estado(carregando: true, titulo: 'Carregando o cardápio…'),
      error: (e, _) => _Estado(titulo: 'Não deu pra carregar o cardápio', detalhe: '$e'),
      data: (snap) {
        if (snap == null || snap.categorias.isEmpty) {
          return _Estado(
            titulo: 'Cardápio ainda não sincronizado',
            detalhe:
                sync.status == SyncStatus.offline ? 'Sem conexão e sem snapshot local.' : 'Baixando a primeira versão…',
            acao: DinerBotao(
              key: const ValueKey('catalogo-atualizar'),
              rotulo: 'Atualizar',
              icone: Icons.refresh_rounded,
              altura: 96,
              fonte: 30,
              onTap: () => ref.read(catalogSyncProvider.notifier).sincronizar(),
            ),
          );
        }
        final dados = CatalogoDados.de(snap);
        if (dados.secoes.isEmpty) {
          return const _Estado(titulo: 'Nada disponível agora', detalhe: 'Chame um atendente, por favor.');
        }
        _ordem = [for (final s in dados.secoes) s.categoria.id];
        final ativa = _ordem.contains(_ativa) ? _ativa! : _ordem.first;
        final especial = [
          for (final s in dados.secoes)
            for (final p in s.produtos)
              if (p.disponivel && (p.selo ?? '').trim().isNotEmpty) p
        ].firstOrNull;
        return Column(children: [
          _Jukebox(
            secoes: dados.secoes,
            ativa: ativa,
            chaveBotao: _chaveBotao,
            onTocar: (id) => _irPara(id, mov),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: _viewport,
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(context.dz(40), context.dz(24), context.dz(40), 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (especial != null) _Especial(produto: especial, onTap: () => acoes.abrirProduto(context, especial)),
                for (final s in dados.secoes)
                  _Secao(
                    key: _chaveSecao(s.categoria.id),
                    secao: s,
                    mov: mov,
                    alvoSacola: _alvoSacola,
                    acoes: acoes,
                  ),
                SizedBox(height: context.dz(40)),
              ]),
            ),
          ),
        ]);
      },
    );

    return DinerTema(
      child: Scaffold(
        backgroundColor: _t.bg,
        body: SafeArea(
          child: DinerEntrada(
            mov: mov,
            child: Column(children: [
              _Cabecalho(ap: ap, mov: mov, onCancelar: () => acoes.cancelarPedido(context)),
              Expanded(child: corpo),
              Padding(
                padding: EdgeInsets.fromLTRB(context.dz(40), context.dz(18), context.dz(40), context.dz(36)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.dz(999)),
                    boxShadow: [sombraDura(context.dz(8), cor: _t.accent)],
                  ),
                  child: BarraSacola(
                    itens: cart.totalItens,
                    totalCentavos: cart.totalCentavos,
                    onVerSacola: () => acoes.verSacola(context),
                    tokens: _t,
                    alvo: _alvoSacola,
                    mov: mov,
                    fundo: _t.text,
                    tinta: _t.bg,
                    botaoFundo: _t.accent,
                    botaoTinta: _t.bg,
                    raio: 999,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho vermelho: 18 lâmpadas em perseguição, logo, Cancelar e as etapas em creme.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.ap, required this.mov, required this.onCancelar});
  final Aparencia ap;
  final Movimento mov;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _t.accent,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.dz(30), context.dz(6), context.dz(30), 0),
          child: FileiraLampadas(quantidade: 18, diametro: 16, mov: mov),
        ),
        DinerTopo(
          etapa: 0,
          mov: mov,
          nomeLoja: ap.nomeLoja,
          logoUrl: ap.logoUrl,
          onCancelar: onCancelar,
          invertido: true,
          paddingTopo: 15,
        ),
      ]),
    );
  }
}

/// Fileira de botões "jukebox" sobre listras creme, com borda marrom de 6 embaixo.
class _Jukebox extends StatelessWidget {
  const _Jukebox({
    required this.secoes,
    required this.ativa,
    required this.chaveBotao,
    required this.onTocar,
  });

  final List<SecaoCatalogo> secoes;
  final String ativa;
  final GlobalKey Function(String) chaveBotao;
  final void Function(String) onTocar;

  @override
  Widget build(BuildContext context) {
    final vao = context.dz(12);
    final pad = context.dz(40);
    Widget botao(SecaoCatalogo s, {double? largura}) => SizedBox(
          key: chaveBotao(s.categoria.id),
          width: largura,
          child: _BotaoJukebox(
            key: ValueKey('jukebox-${s.categoria.id}'),
            rotulo: s.categoria.nome,
            ativo: s.categoria.id == ativa,
            onTap: () => onTocar(s.categoria.id),
          ),
        );
    final cabe = secoes.length <= 5;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _t.text, width: context.dz(6)))),
      child: CustomPaint(
        painter: ListrasPainter(largura: context.dz(30), a: _t.surface2, b: _t.bg),
        child: LayoutBuilder(builder: (context, c) {
          if (cabe) {
            return Padding(
              padding: EdgeInsets.fromLTRB(pad, context.dz(22), pad, context.dz(22)),
              child: Row(children: [
                for (var i = 0; i < secoes.length; i++) ...[
                  if (i > 0) SizedBox(width: vao),
                  Expanded(child: botao(secoes[i])),
                ],
              ]),
            );
          }
          // Mais de 5 categorias: rola na horizontal, 5 botões por tela.
          final largura = (c.maxWidth - pad * 2 - vao * 4) / 5;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(pad, context.dz(22), pad, context.dz(22)),
            child: Row(children: [
              for (var i = 0; i < secoes.length; i++) ...[
                if (i > 0) SizedBox(width: vao),
                botao(secoes[i], largura: largura),
              ],
            ]),
          );
        }),
      ),
    );
  }
}

/// Botão jukebox: 100 de altura, raio 24, borda 4 marrom e sombra dura 0/6. O ativo fica
/// menta, desce 4 px (sombra 0/2) e acende a luz vermelha do canto.
class _BotaoJukebox extends StatelessWidget {
  const _BotaoJukebox({super.key, required this.rotulo, required this.ativo, required this.onTap});
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luz = context.dz(14);
    return Semantics(
      button: true,
      selected: ativo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: context.dz(100),
          transform: Matrix4.translationValues(0, ativo ? context.dz(4) : 0, 0),
          decoration: BoxDecoration(
            color: ativo ? _t.accent2 : _t.surface,
            borderRadius: BorderRadius.circular(context.dz(24)),
            border: Border.all(color: _t.text, width: context.dz(4)),
            boxShadow: [sombraDura(context.dz(ativo ? 2 : 6))],
          ),
          child: Stack(children: [
            Positioned(
              top: context.dz(6),
              right: context.dz(8),
              child: Container(
                width: luz,
                height: luz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ativo ? dinerLuzJukebox : _t.line2,
                  boxShadow: ativo ? const [BoxShadow(color: dinerLuzJukebox, blurRadius: 10)] : null,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.dz(12)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(rotulo, maxLines: 1, style: _t.display(context.dz(22), altura: 1.1)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Especial do dia": caixa branca com borda tracejada vermelha, texto à esquerda (560) e a
/// foto à direita. Fonte: o 1º produto com selo.
class _Especial extends StatelessWidget {
  const _Especial({required this.produto, required this.onTap});
  final Produto produto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = SizedBox(
      width: context.dz(560),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.dz(330)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.dz(34), vertical: context.dz(30)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Especial do dia', style: dinerScript(context.dz(58), altura: 1.15)),
                SizedBox(height: context.dz(8)),
                Text(produto.nome,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: _t.display(context.dz(40), altura: 1.05)),
                if (produto.descricao.trim().isNotEmpty) ...[
                  SizedBox(height: context.dz(8)),
                  Text(produto.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t.texto(context.dz(24), cor: _t.muted, altura: 1.3)),
                ],
              ]),
              Padding(
                padding: EdgeInsets.only(top: context.dz(12)),
                child: Text(formatCentavos(produto.precoCentavos),
                    style: _t.display(context.dz(48), cor: _t.accent, altura: 1.1)),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: context.dz(10)),
      child: DinerToque(
        key: const ValueKey('especial-do-dia'),
        onTap: onTap,
        child: CaixaTracejada(
          recortar: true,
          child: SizedBox(
            width: double.infinity,
            child: Stack(children: [
              texto,
              Positioned(
                left: context.dz(560),
                right: 0,
                top: 0,
                bottom: 0,
                child: DinerArte(url: produto.imagemUrl, fundo: _t.art),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Uma categoria: "★ Nome ★" em Bungee vermelho e as linhas do cardápio.
class _Secao extends StatelessWidget {
  const _Secao({
    super.key,
    required this.secao,
    required this.mov,
    required this.alvoSacola,
    required this.acoes,
  });

  final SecaoCatalogo secao;
  final Movimento mov;
  final GlobalKey alvoSacola;
  final AcoesPedido acoes;

  @override
  Widget build(BuildContext context) {
    final estrela = Icon(Icons.star_rounded, size: context.dz(30), color: _t.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.only(top: context.dz(34), bottom: context.dz(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          estrela,
          SizedBox(width: context.dz(14)),
          Flexible(
            child: Text(secao.categoria.nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: _t.display(context.dz(48), cor: _t.accent, altura: 1.1)),
          ),
          SizedBox(width: context.dz(14)),
          estrela,
        ]),
      ),
      for (final p in secao.produtos)
        _LinhaCardapio(
          key: ValueKey('linha-${p.id}'),
          produto: p,
          mov: mov,
          alvoSacola: alvoSacola,
          acoes: acoes,
        ),
    ]);
  }
}

/// Linha da lousa: foto redonda (gira −8° e cresce ao toque), nome em Bungee com pontilhado
/// até o preço, descrição, selo, e à direita o preço em selo inclinado e o "+" marrom.
class _LinhaCardapio extends StatefulWidget {
  const _LinhaCardapio({
    super.key,
    required this.produto,
    required this.mov,
    required this.alvoSacola,
    required this.acoes,
  });

  final Produto produto;
  final Movimento mov;
  final GlobalKey alvoSacola;
  final AcoesPedido acoes;

  @override
  State<_LinhaCardapio> createState() => _LinhaCardapioState();
}

class _LinhaCardapioState extends State<_LinhaCardapio> {
  final _foto = GlobalKey();
  bool _pressionada = false;
  int _giros = 0;

  void _marca(bool v) {
    if (_pressionada != v && mounted) setState(() => _pressionada = v);
  }

  void _mais() {
    final p = widget.produto;
    if (widget.acoes.adicionarOuAbrir(context, p)) {
      VooParaSacola.voar(
        context,
        origem: _foto,
        destino: widget.alvoSacola,
        url: p.imagemUrl,
        tokens: _t,
        mov: widget.mov,
      );
      setState(() => _giros++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final mov = widget.mov;
    final lado = context.dz(176);
    final cheio = mov.anima && mov.particulas;
    final recorte = ProdutoArte.ehRecorte(p.imagemUrl);
    final foto = Container(
      key: _foto,
      width: lado,
      height: lado,
      padding: EdgeInsets.all(context.dz(8)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _t.surface,
        boxShadow: [
          BoxShadow(color: const Color(0x1F2A1512), offset: Offset(0, context.dz(12))),
          BoxShadow(color: _t.accent, spreadRadius: context.dz(4)),
        ],
      ),
      child: DinerArte(url: p.imagemUrl, circulo: true, escalaRecorte: recorte ? .8 : .86),
    );
    final linha = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _marca(true),
      onTapUp: (_) => _marca(false),
      onTapCancel: () => _marca(false),
      onTap: () => widget.acoes.abrirProduto(context, p),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.dz(22)),
        child: Row(children: [
          AnimatedRotation(
            turns: _pressionada && cheio ? -8 / 360 : 0,
            duration: mov.anima ? mov.d(400) : Duration.zero,
            curve: Curves.elasticOut,
            child: AnimatedScale(
              scale: _pressionada && mov.anima ? 1.05 : 1,
              duration: mov.anima ? mov.d(400) : Duration.zero,
              curve: Curves.elasticOut,
              child: foto,
            ),
          ),
          SizedBox(width: context.dz(26)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _NomeComPontilhado(nome: p.nome, pontilhado: p.disponivel),
              if (p.descricao.trim().isNotEmpty) ...[
                SizedBox(height: context.dz(6)),
                Text(p.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(context.dz(23), cor: _t.muted, altura: 1.3)),
              ],
              if ((p.selo ?? '').trim().isNotEmpty && p.disponivel) ...[
                SizedBox(height: context.dz(10)),
                Selo(texto: p.selo!.trim(), tokens: _t, altura: context.dz(44)),
              ],
            ]),
          ),
          SizedBox(width: context.dz(20)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SeloPreco(texto: formatCentavos(p.precoCentavos), giros: _giros, mov: mov),
            SizedBox(height: context.dz(14)),
            DinerMais(
              key: ValueKey('mais-${p.id}'),
              onTap: p.disponivel ? _mais : null,
              fundo: _t.text,
              tinta: _t.bg,
            ),
          ]),
        ]),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Indisponivel(ativo: !p.disponivel, tokens: _t, alturaSelo: context.dz(44), child: linha),
      SizedBox(
        height: context.dz(4),
        child: CustomPaint(painter: PontilhadoPainter(cor: _t.line, espessura: context.dz(4))),
      ),
    ]);
  }
}

/// Nome em Bungee 32 com o pontilhado "de cardápio" correndo até a borda (o nome tem fundo
/// creme e cobre a linha por baixo).
class _NomeComPontilhado extends StatelessWidget {
  const _NomeComPontilhado({required this.nome, this.pontilhado = true});
  final String nome;

  /// Esgotado fica sem o pontilhado: o fundo creme do nome viraria uma caixa cinza no filtro.
  final bool pontilhado;

  @override
  Widget build(BuildContext context) {
    final texto =
        Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t.display(context.dz(32), altura: 1.08));
    if (!pontilhado) return texto;
    return Stack(children: [
      Positioned(
        left: 0,
        right: 0,
        bottom: context.dz(9),
        height: context.dz(4),
        child: CustomPaint(painter: PontilhadoPainter(cor: const Color(0x4D2A1512), espessura: context.dz(4))),
      ),
      Container(
        color: _t.bg,
        padding: EdgeInsets.only(right: context.dz(12)),
        child: texto,
      ),
    ]);
  }
}

/// Estados vazios do cardápio (carregando, sem retrato, erro) no visual do Diner.
class _Estado extends StatelessWidget {
  const _Estado({required this.titulo, this.detalhe, this.acao, this.carregando = false});
  final String titulo;
  final String? detalhe;
  final Widget? acao;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(key: const ValueKey('catalogo-estado'), mainAxisSize: MainAxisSize.min, children: [
          if (carregando)
            SizedBox(
              width: context.dz(90),
              height: context.dz(90),
              child: CircularProgressIndicator(strokeWidth: context.dz(8), color: _t.accent),
            )
          else
            Transform.rotate(
              angle: -4 * math.pi / 180,
              child: Icon(Icons.menu_book_rounded, size: context.dz(120), color: _t.accent),
            ),
          SizedBox(height: context.dz(30)),
          Text(titulo, textAlign: TextAlign.center, style: _t.display(context.dz(44), altura: 1.1)),
          if ((detalhe ?? '').isNotEmpty) ...[
            SizedBox(height: context.dz(14)),
            Text(detalhe!, textAlign: TextAlign.center, style: _t.texto(context.dz(28), cor: _t.muted)),
          ],
          if (acao != null) ...[SizedBox(height: context.dz(34)), acao!],
        ]),
      ),
    );
  }
}
