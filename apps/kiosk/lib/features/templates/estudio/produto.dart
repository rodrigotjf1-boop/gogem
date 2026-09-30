import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../domain/order/order_models.dart';
import '../comum/produto_arte.dart';
import '../comum/quantidade.dart';
import '../comum/selo.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Produto do Estúdio (docs/03 §6.3): cartão central que entra GIRANDO (perspectiva,
/// −24° → 0 e 0,9 → 1 em 600 ms), topo com o disco azul e o produto flutuando, grupos em
/// cards brancos e o rodapé com a quantidade e "Adicionar · R$". VIEW PURA: seleção,
/// validação e preço vêm do `ProdutoScreen`.
class EstudioProduto extends StatefulWidget {
  const EstudioProduto({super.key, required this.p});
  final ProdutoProps p;

  @override
  State<EstudioProduto> createState() => _EstudioProdutoState();
}

class _EstudioProdutoState extends State<EstudioProduto> with TickerProviderStateMixin {
  late final AnimationController _giro;
  late final AnimationController _heroi;

  Movimento get _mov => widget.p.mov;

  @override
  void initState() {
    super.initState();
    _giro = AnimationController(vsync: this, duration: _mov.d(600));
    _heroi = AnimationController(vsync: this, duration: _mov.d(700));
    if (_mov.anima) {
      _giro.forward();
      _heroi.forward();
    } else {
      _giro.value = 1;
      _heroi.value = 1;
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    _heroi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cheio = movimentoCheio(_mov);
    final cartao = _Cartao(p: widget.p, heroi: _heroi);
    return TelaEstudio(
      entrada: false,
      child: Flutuacao(
        ligada: cheio,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: EstudioCores.cortina),
          Padding(
            padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(90), context.dz(48), context.dz(90)),
            child: AnimatedBuilder(
              animation: _giro,
              builder: (_, child) {
                final v = curvaEstudio.transform(_giro.value);
                // Reduzido/low: só o fade. Cheio: gira de −24° e cresce de 0,9.
                return Opacity(
                  opacity: _giro.value.clamp(0.0, 1.0),
                  child: cheio
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 1 / 1400)
                            ..rotateY(-24 * math.pi / 180 * (1 - v)),
                          child: Transform.scale(scale: .9 + .1 * v, child: child),
                        )
                      : child,
                );
              },
              child: cartao,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.p, required this.heroi});
  final ProdutoProps p;
  final Animation<double> heroi;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: const ValueKey('produto-cartao'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: EstudioCores.fundoModal,
        borderRadius: BorderRadius.circular(48 * k),
        boxShadow: sombraModal(k),
      ),
      child: LayoutBuilder(builder: (context, c) {
        // O topo tem 500 de desenho; em tela baixa, no máximo 40% do cartão.
        final alturaTopo = math.min(500 * k, c.maxHeight * .4);
        return Column(children: [
          SizedBox(height: alturaTopo, child: _Topo(p: p, heroi: heroi, altura: alturaTopo)),
          Expanded(child: _Corpo(p: p)),
          _Rodape(p: p),
        ]);
      }),
    );
  }
}

class _Topo extends StatelessWidget {
  const _Topo({required this.p, required this.heroi, required this.altura});
  final ProdutoProps p;
  final Animation<double> heroi;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final produto = p.produto;
    final url = produto.imagemUrl?.trim() ?? '';
    final disco = math.min(440 * k, altura * .88);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cheio = movimentoCheio(p.mov);
    final Widget arte;
    if (url.isEmpty) {
      arte = Icon(Icons.restaurant_menu_rounded, size: disco * .4, color: const Color(0x8CFFFFFF));
    } else if (ProdutoArte.ehRecorte(url)) {
      arte = SizedBox(
        width: disco * 1.05,
        height: disco * .82,
        child: ImagemEstudio(url: url, fit: BoxFit.contain, memCacheWidth: (disco * 1.05 * dpr).round()),
      );
    } else {
      arte = FotoCirculo(url: url, diametro: disco * .9, borda: 10 * k);
    }
    final selo = (produto.selo ?? '').trim();
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: EstudioCores.fundoHeroi),
      Center(
        child: Container(
          width: disco,
          height: disco,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _t.accent.withAlpha(230)),
        ),
      ),
      // heroIn: surge de 0,6 girado −10° (700 ms, com um leve pulo) e depois flutua.
      Center(
        child: AnimatedBuilder(
          animation: heroi,
          builder: (_, child) {
            final v = curvaPulo.transform(heroi.value);
            return Opacity(
              opacity: heroi.value.clamp(0.0, 1.0),
              child: cheio
                  ? Transform.rotate(
                      angle: -10 * math.pi / 180 * (1 - v),
                      child: Transform.scale(scale: .6 + .4 * v, child: child),
                    )
                  : child,
            );
          },
          child: Flutua(child: arte),
        ),
      ),
      if (selo.isNotEmpty)
        Positioned(left: 30 * k, top: 30 * k, child: Selo(texto: selo, tokens: _t, altura: 44 * k)),
      Positioned(
        top: 26 * k,
        right: 26 * k,
        child: Material(
          color: EstudioCores.botaoFechar,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('produto-fechar'),
            customBorder: const CircleBorder(),
            onTap: p.onVoltar,
            child: SizedBox(
              width: 88 * k,
              height: 88 * k,
              child: Icon(Icons.close_rounded, size: 44 * k, color: EstudioCores.branco),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final produto = p.produto;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(48 * k, 34 * k, 48 * k, 30 * k),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(produto.nome,
            style: _t.display(78 * k, altura: 1.02).copyWith(letterSpacing: -78 * .03 * k)),
        if (produto.descricao.trim().isNotEmpty) ...[
          SizedBox(height: 12 * k),
          Text(produto.descricao,
              style: _t.texto(28 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.4)),
        ],
        SizedBox(height: 12 * k),
        Text(formatCentavos(produto.precoCentavos),
            style: _t.texto(46 * k, peso: FontWeight.w800, cor: _t.price)),
        for (final g in produto.grupos) ...[
          SizedBox(height: 30 * k),
          _Grupo(
            grupo: g,
            selecionadas: p.selecoes[g.id] ?? const [],
            onToggle: (o) => p.onToggle(g, o),
            mov: p.mov,
          ),
        ],
      ]),
    );
  }
}

/// Um grupo de complementos: rótulo em caixa alta, a regra ("Obrigatório" / "Até N") e
/// as opções em cards de 4 colunas (borda `line`; marcada com borda no acento, fundo `hi`
/// e ✓ no canto).
class _Grupo extends StatelessWidget {
  const _Grupo({required this.grupo, required this.selecionadas, required this.onToggle, required this.mov});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final void Function(OpcaoComplemento) onToggle;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final obrigatorio = minEfetivo(grupo) > 0;
    final ok = selecaoValida(grupo, selecionadas);
    final comImagem = grupo.opcoes.any((o) => (o.imagemUrl ?? '').trim().isNotEmpty);
    final linhas = <List<OpcaoComplemento>>[
      for (var i = 0; i < grupo.opcoes.length; i += 4)
        grupo.opcoes.sublist(i, math.min(i + 4, grupo.opcoes.length)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
          child: Text(grupo.nome.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t.texto(23 * k, peso: FontWeight.w800, cor: _t.muted, espaco: 23 * .1 * k)),
        ),
        SizedBox(width: 14 * k),
        Container(
          key: ValueKey('regra-${grupo.id}'),
          padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 6 * k),
          decoration: BoxDecoration(
            color: obrigatorio && !ok ? _t.hi : _t.surface2,
            borderRadius: BorderRadius.circular(20 * k),
          ),
          child: Text(obrigatorio ? 'Obrigatório' : 'Até ${grupo.max}',
              style: _t.texto(20 * k, peso: FontWeight.w800, cor: obrigatorio && !ok ? _t.accent : _t.muted)),
        ),
      ]),
      SizedBox(height: 14 * k),
      for (var l = 0; l < linhas.length; l++) ...[
        if (l > 0) SizedBox(height: 14 * k),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(width: 14 * k),
              Expanded(
                child: i < linhas[l].length
                    ? _Opcao(
                        opcao: linhas[l][i],
                        marcada: selecionadas.any((x) => x.id == linhas[l][i].id),
                        comImagem: comImagem,
                        onTap: () => onToggle(linhas[l][i]),
                        mov: mov,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.opcao,
    required this.marcada,
    required this.comImagem,
    required this.onTap,
    required this.mov,
  });
  final OpcaoComplemento opcao;
  final bool marcada;
  final bool comImagem;
  final VoidCallback onTap;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final raio = BorderRadius.circular(30 * k);
    final livre = opcao.disponivel;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Opacity(
      opacity: livre ? 1 : .45,
      child: GestureDetector(
        key: ValueKey('op-${opcao.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: livre ? onTap : null,
        child: Stack(fit: StackFit.passthrough, children: [
          AnimatedContainer(
            duration: duracao(mov, 250),
            padding: EdgeInsets.fromLTRB(10 * k, 12 * k, 10 * k, 16 * k),
            decoration: BoxDecoration(
              color: marcada ? _t.hi : _t.surface,
              borderRadius: raio,
              border: Border.all(color: marcada ? _t.accent : _t.line, width: 3 * k),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (comImagem) ...[
                SizedBox(
                  height: 110 * k,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22 * k),
                    child: ColoredBox(
                      color: _t.art,
                      // ~1/4 da largura do cartão (4 colunas).
                      child: ImagemEstudio(url: opcao.imagemUrl, memCacheWidth: (220 * k * dpr).round()),
                    ),
                  ),
                ),
                SizedBox(height: 8 * k),
              ],
              Text(opcao.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t.texto(22 * k, peso: FontWeight.w700, altura: 1.15)),
              if (opcao.precoCentavosDelta != 0) ...[
                SizedBox(height: 6 * k),
                Text('+ ${formatCentavos(opcao.precoCentavosDelta)}',
                    style: _t.texto(20 * k, peso: FontWeight.w600, cor: _t.muted)),
              ],
            ]),
          ),
          if (marcada)
            Positioned(
              top: 8 * k,
              right: 8 * k,
              child: Container(
                width: 44 * k,
                height: 44 * k,
                decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 28 * k, color: _t.onAccent),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: 2 * k))),
      child: Padding(
        padding: EdgeInsets.fromLTRB(48 * k, 24 * k, 48 * k, 40 * k),
        child: Row(children: [
          Quantidade(n: p.qtd, onMenos: p.onMenos, onMais: p.onMais, tokens: _t, tamanho: 92),
          SizedBox(width: 24 * k),
          Expanded(
            child: BotaoEstudio(
              chave: 'adicionar',
              rotulo: 'Adicionar · ${formatCentavos(p.totalCentavos)}',
              icone: Icons.shopping_bag_outlined,
              onTap: p.valido ? p.onAdicionar : null,
            ),
          ),
        ]),
      ),
    );
  }
}
