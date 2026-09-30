import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../comum/produto_arte.dart';
import '../comum/selo.dart';
import '../escala.dart';
import '../movimento.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Forma de um bloco do mosaico (docs/templates/04-neon-2.md §5, "Grade bento").
enum FormaBloco {
  /// 1º item GRANDE (2 linhas) + dois normais empilhados à direita.
  abertura,

  /// Só 2 itens: o GRANDE e um ALTO lado a lado (sem buraco na coluna da direita).
  dupla,

  /// Dois normais lado a lado.
  par,

  /// Um item LARGO (2 colunas, imagem à esquerda): o último quando a quantidade é par,
  /// ou o único da categoria.
  largo,
}

enum TipoTile { grande, alto, normal, largo }

/// Um bloco do mosaico: a forma e os índices (na ordem da categoria) dos itens dele.
class BlocoBento {
  const BlocoBento(this.forma, this.indices);
  final FormaBloco forma;
  final List<int> indices;

  /// Tipo do tile na posição [i] do bloco.
  TipoTile tipo(int i) => switch (forma) {
        FormaBloco.abertura => i == 0 ? TipoTile.grande : TipoTile.normal,
        FormaBloco.dupla => i == 0 ? TipoTile.grande : TipoTile.alto,
        FormaBloco.par => TipoTile.normal,
        FormaBloco.largo => TipoTile.largo,
      };

  @override
  String toString() => '${forma.name}$indices';
}

/// Monta o mosaico de [n] itens em 2 colunas e linhas de 340: o 1º é GRANDE (2 linhas);
/// com quantidade par, o último é LARGO. Casos sem par possível: 1 item vira LARGO e 2
/// itens viram GRANDE + ALTO (a grade do CSS deixaria meia tela vazia).
List<BlocoBento> montarBento(int n) {
  if (n <= 0) return const [];
  if (n == 1) {
    return const [BlocoBento(FormaBloco.largo, [0])];
  }
  if (n == 2) {
    return const [BlocoBento(FormaBloco.dupla, [0, 1])];
  }
  final blocos = <BlocoBento>[
    const BlocoBento(FormaBloco.abertura, [0, 1, 2])
  ];
  for (var i = 3; i < n; i += 2) {
    blocos.add(i + 1 < n ? BlocoBento(FormaBloco.par, [i, i + 1]) : BlocoBento(FormaBloco.largo, [i]));
  }
  return blocos;
}

/// A grade bento de uma categoria.
class NeonBento extends StatelessWidget {
  const NeonBento({
    super.key,
    required this.produtos,
    required this.mov,
    required this.onAbrir,
    required this.onMais,
  });

  final List<Produto> produtos;
  final Movimento mov;
  final void Function(Produto) onAbrir;

  /// "+" do tile: recebe a chave da foto (origem do voo até a sacola).
  final void Function(Produto, GlobalKey foto) onMais;

  static const linha = 340.0;
  static const vao = 18.0;

  @override
  Widget build(BuildContext context) {
    final alto = context.dz(linha);
    final duplo = context.dz(linha * 2 + vao);
    final g = context.dz(vao);
    Widget tile(BlocoBento b, int i) => NeonTile(
          key: ValueKey('neon-prod-${produtos[b.indices[i]].id}'),
          produto: produtos[b.indices[i]],
          tipo: b.tipo(i),
          mov: mov,
          onAbrir: onAbrir,
          onMais: onMais,
        );
    final blocos = montarBento(produtos.length);
    return Column(children: [
      for (var k = 0; k < blocos.length; k++) ...[
        if (k > 0) SizedBox(height: g),
        switch (blocos[k].forma) {
          FormaBloco.abertura => SizedBox(
              height: duplo,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: tile(blocos[k], 0)),
                SizedBox(width: g),
                Expanded(
                  child: Column(children: [
                    Expanded(child: tile(blocos[k], 1)),
                    SizedBox(height: g),
                    Expanded(child: tile(blocos[k], 2)),
                  ]),
                ),
              ]),
            ),
          FormaBloco.dupla => SizedBox(
              height: duplo,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: tile(blocos[k], 0)),
                SizedBox(width: g),
                Expanded(child: tile(blocos[k], 1)),
              ]),
            ),
          FormaBloco.par => SizedBox(
              height: alto,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: tile(blocos[k], 0)),
                SizedBox(width: g),
                Expanded(child: tile(blocos[k], 1)),
              ]),
            ),
          FormaBloco.largo => SizedBox(height: alto, width: double.infinity, child: tile(blocos[k], 0)),
        },
      ],
    ]);
  }
}

/// Tile do mosaico (`.ntile`): fundo `surface`, borda 2 `line`, raio 22; no toque a borda
/// acende em `accent` e o tile sobe 4 px. O GRANDE ganha a borda de néon girando e a
/// descrição. Indisponível: cinza, "Esgotado" e sem toque.
class NeonTile extends StatefulWidget {
  const NeonTile({
    super.key,
    required this.produto,
    required this.tipo,
    required this.mov,
    required this.onAbrir,
    required this.onMais,
  });

  final Produto produto;
  final TipoTile tipo;
  final Movimento mov;
  final void Function(Produto) onAbrir;
  final void Function(Produto, GlobalKey foto) onMais;

  @override
  State<NeonTile> createState() => _NeonTileState();
}

class _NeonTileState extends State<NeonTile> {
  final _foto = GlobalKey();
  bool _apertado = false;

  void _aperto(bool v) {
    if (_apertado != v) setState(() => _apertado = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final tipo = widget.tipo;
    final grande = tipo == TipoTile.grande;
    final largo = tipo == TipoTile.largo;
    final comDescricao = tipo != TipoTile.normal && p.descricao.trim().isNotEmpty;
    final pad = context.dz(20);

    final foto = KeyedSubtree(key: _foto, child: _FotoTile(url: p.imagemUrl));
    final textos = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t.caixa(p.nome),
          maxLines: grande ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: neonDisplay(context.dz(grande ? 40 : 26), peso: FontWeight.w700, altura: 1.05, espaco: 0),
        ),
        if (comDescricao) ...[
          SizedBox(height: context.dz(10)),
          Text(p.descricao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: neonTexto(context.dz(22), cor: _t.muted, altura: 1.35)),
        ],
        SizedBox(height: context.dz(10)),
        Row(children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatCentavos(p.precoCentavos),
                  style: neonTexto(context.dz(34), peso: FontWeight.w700, cor: _t.price)),
            ),
          ),
          NeonBotaoMais(
            key: ValueKey('neon-add-${p.id}'),
            onTap: () => widget.onMais(p, _foto),
          ),
        ]),
      ],
    );

    final miolo = Padding(
      padding: EdgeInsets.all(pad),
      child: largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: context.dz(360), child: foto),
              SizedBox(width: context.dz(22)),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: textos)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: foto),
              SizedBox(height: context.dz(12)),
              textos,
            ]),
    );

    final raio = context.dz(22);
    final Widget caixa = grande
        ? BordaNeon(mov: widget.mov, raio: 22, espessura: 3, child: miolo)
        : AnimatedContainer(
            duration: widget.mov.anima ? const Duration(milliseconds: 250) : Duration.zero,
            decoration: BoxDecoration(
              color: _t.surface,
              borderRadius: BorderRadius.circular(raio),
              border: Border.all(color: _apertado ? _t.accent : _t.line, width: context.dz(2)),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(raio), child: miolo),
          );

    final selo = (p.selo ?? '').trim();
    final tile = Stack(children: [
      Positioned.fill(child: caixa),
      if (selo.isNotEmpty && p.disponivel)
        Positioned(left: context.dz(18), top: context.dz(18), child: SeloNeon(texto: selo)),
    ]);

    return Indisponivel(
      ativo: !p.disponivel,
      tokens: _t,
      alturaSelo: context.dz(44),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _aperto(true),
        onTapUp: (_) => _aperto(false),
        onTapCancel: () => _aperto(false),
        onTap: () => widget.onAbrir(p),
        child: Transform.translate(
          offset: Offset(0, _apertado ? -context.dz(4) : 0),
          child: tile,
        ),
      ),
    );
  }
}

/// Área da foto do tile: fundo `0xFF171724`; o recorte (`.png`) ganha fundo mais fechado
/// com brilho radial verde.
class _FotoTile extends StatelessWidget {
  const _FotoTile({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final raio = context.dz(14);
    final recorte = ProdutoArte.ehRecorte(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: ColoredBox(
        color: recorte ? neonFundoRecorte : neonFundoFoto,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: recorte
                ? const RadialGradient(
                    center: Alignment(0, .2),
                    radius: .7,
                    colors: [Color(0x29C8FF2E), Color(0x00C8FF2E)],
                  )
                : null,
          ),
          child: ProdutoArte(
            url: url,
            tokens: _t,
            raio: raio,
            escalaRecorte: .92,
            fundo: const Color(0x00000000),
          ),
        ),
      ),
    );
  }
}
