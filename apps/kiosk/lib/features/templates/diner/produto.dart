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
import 'diner_comum.dart';
import 'diner_tokens.dart';
import 'pintores.dart';

const _t = dinerTokens;

/// Produto do **Diner 58** (docs/templates/05 §6.3): cartão central com borda marrom de 6
/// e sombra dura, topo xadrez creme com a foto (recorte flutuando ou foto num círculo de
/// borda branca), nome em Bungee, grupos em cards e o rodapé com a quantidade e
/// "Adicionar · R$". VIEW PURA: seleção, validação e preço vêm da `ProdutoScreen`.
class DinerProduto extends StatelessWidget {
  const DinerProduto({super.key, required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    final mov = p.mov;
    return DinerTema(
      child: Scaffold(
        backgroundColor: dinerVeu,
        body: SafeArea(
          child: Stack(children: [
            Positioned.fill(child: DinerVeu(cabecalho: true, onTap: p.onVoltar)),
            Positioned(
              left: context.dz(48),
              right: context.dz(48),
              top: context.dz(90),
              bottom: context.dz(90),
              child: _Pop(mov: mov, child: _Cartao(p: p)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Entrada do cartão: escala 0,86 → 1 em 450 ms (`Cubic(.2,1.2,.4,1)`). Reduzido: só fade.
class _Pop extends StatelessWidget {
  const _Pop({required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!mov.anima) return child;
    final cheio = mov.particulas;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(cheio ? 450 : 300),
      curve: cheio ? const Cubic(.2, 1.2, .4, 1) : Curves.easeOut,
      child: child,
      builder: (_, v, filho) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: cheio ? Transform.scale(scale: .86 + .14 * v, child: filho) : filho,
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    final produto = p.produto;
    final raio = context.dz(48);
    return Container(
      key: const ValueKey('produto-cartao'),
      decoration: BoxDecoration(
        color: dinerModal,
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: _t.text, width: context.dz(6)),
        boxShadow: [sombraDura(context.dz(14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(raio - context.dz(6)),
        child: LayoutBuilder(builder: (context, c) {
          final alturaTopo = math.min(context.dz(500), c.maxHeight * .36);
          return Column(children: [
            SizedBox(height: alturaTopo, child: _Topo(p: p)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(34), context.dz(48), context.dz(30)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(produto.nome, style: _t.display(context.dz(56), altura: 1.05)),
                  if (produto.descricao.trim().isNotEmpty) ...[
                    SizedBox(height: context.dz(12)),
                    Text(produto.descricao, style: _t.texto(context.dz(28), cor: _t.muted, altura: 1.4)),
                  ],
                  SizedBox(height: context.dz(12)),
                  Text(formatCentavos(produto.precoCentavos),
                      style: _t.texto(context.dz(46), peso: FontWeight.w900, cor: _t.accent)),
                  for (final g in produto.grupos) ...[
                    SizedBox(height: context.dz(30)),
                    _Grupo(
                      grupo: g,
                      selecionadas: p.selecoes[g.id] ?? const [],
                      onToggle: (o) => p.onToggle(g, o),
                    ),
                  ],
                ]),
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
              padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(24), context.dz(48), context.dz(40)),
              child: Row(children: [
                Quantidade(
                  n: p.qtd,
                  onMenos: p.onMenos,
                  onMais: p.onMais,
                  tokens: _t,
                  tamanho: 92,
                  corMais: _t.accent,
                  chave: 'qtd',
                ),
                SizedBox(width: context.dz(24)),
                Expanded(
                  child: DinerBotao(
                    key: const ValueKey('adicionar'),
                    rotulo: 'Adicionar · ${formatCentavos(p.totalCentavos)}',
                    icone: Icons.shopping_bag_outlined,
                    expandir: true,
                    onTap: p.valido ? p.onAdicionar : null,
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

/// Topo xadrez creme (casas de 40) com a foto, o selo e o X de fechar.
class _Topo extends StatelessWidget {
  const _Topo({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    final produto = p.produto;
    final mov = p.mov;
    final url = produto.imagemUrl;
    final recorte = ProdutoArte.ehRecorte(url);
    return Stack(children: [
      Positioned.fill(
        child: CustomPaint(
          painter: XadrezPainter(casa: context.dz(40), escura: _t.surface2, clara: _t.bg),
        ),
      ),
      Positioned.fill(
        child: LayoutBuilder(builder: (context, c) {
          final lado = math.min(c.maxHeight * .82, context.dz(420));
          final arte = recorte
              ? SizedBox(
                  width: c.maxWidth * .78,
                  height: lado,
                  child: DinerArte(url: url, fundo: const Color(0x00000000), escalaRecorte: 1),
                )
              : Container(
                  width: lado,
                  height: lado,
                  padding: EdgeInsets.all(context.dz(10)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _t.surface,
                    boxShadow: [BoxShadow(color: const Color(0x1F2A1512), offset: Offset(0, context.dz(14)))],
                  ),
                  child: DinerArte(url: url, circulo: true),
                );
          return Center(child: _Heroi(mov: mov, flutua: recorte, child: arte));
        }),
      ),
      if ((produto.selo ?? '').trim().isNotEmpty)
        Positioned(
          left: context.dz(30),
          top: context.dz(30),
          child: Selo(texto: produto.selo!.trim(), tokens: _t, altura: context.dz(44)),
        ),
      Positioned(
        top: context.dz(26),
        right: context.dz(26),
        child: DinerToque(
          key: const ValueKey('produto-fechar'),
          onTap: p.onVoltar,
          child: Container(
            width: context.dz(88),
            height: context.dz(88),
            decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: context.dz(40), color: const Color(0xFFFFFFFF)),
          ),
        ),
      ),
    ]);
  }
}

/// A foto entra girando e crescendo (`heroIn`, 700 ms) e o recorte flutua (3,4 s).
class _Heroi extends StatefulWidget {
  const _Heroi({required this.mov, required this.flutua, required this.child});
  final Movimento mov;
  final bool flutua;
  final Widget child;

  @override
  State<_Heroi> createState() => _HeroiState();
}

class _HeroiState extends State<_Heroi> with TickerProviderStateMixin {
  late final AnimationController _entrada;
  late final AnimationController _flutua;
  late final CurvedAnimation _curva;

  bool get _cheio => widget.mov.anima && widget.mov.particulas;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(vsync: this, duration: widget.mov.d(700));
    _flutua = AnimationController(vsync: this, duration: widget.mov.d(3400));
    _curva = CurvedAnimation(parent: _entrada, curve: const Cubic(.2, 1.2, .4, 1));
    if (_cheio) {
      _entrada.forward().whenComplete(() {
        if (mounted && widget.flutua) _flutua.repeat();
      });
    } else {
      _entrada.value = 1;
    }
  }

  @override
  void dispose() {
    _curva.dispose();
    _entrada.dispose();
    _flutua.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cheio) return widget.child;
    return AnimatedBuilder(
      animation: Listenable.merge([_entrada, _flutua]),
      child: RepaintBoundary(child: widget.child),
      builder: (context, filho) {
        final v = _curva.value;
        final y = -context.dz(18) * (.5 - .5 * math.cos(2 * math.pi * _flutua.value));
        return Opacity(
          opacity: _entrada.value,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.rotate(
              angle: (1 - v) * -10 * math.pi / 180,
              child: Transform.scale(scale: .6 + .4 * v, child: filho),
            ),
          ),
        );
      },
    );
  }
}

/// Um grupo de complementos: rótulo, a regra ("Obrigatório"/"Até N") e as opções.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.grupo, required this.selecionadas, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final void Function(OpcaoComplemento) onToggle;

  /// Grupo de "tirar ingrediente": todas grátis e começando por "sem " → chips em pílula.
  bool get _remocao =>
      grupo.opcoes.isNotEmpty &&
      grupo.opcoes.every((o) => o.precoCentavosDelta == 0 && o.nome.trim().toLowerCase().startsWith('sem '));

  @override
  Widget build(BuildContext context) {
    final min = minEfetivo(grupo);
    final ok = selecaoValida(grupo, selecionadas);
    final unica = grupo.max <= 1;
    final regra = min > 0 ? 'Obrigatório' : 'Até ${grupo.max}';
    final (fundoRegra, tintaRegra) =
        min > 0 ? (ok ? (_t.ok, _t.surface) : (_t.accent, _t.onAccent)) : (_t.surface2, _t.muted);
    final comFoto = grupo.opcoes.any((o) => (o.imagemUrl ?? '').isNotEmpty);
    Widget opcoes;
    if (_remocao) {
      opcoes = Wrap(spacing: context.dz(12), runSpacing: context.dz(12), children: [
        for (final o in grupo.opcoes)
          _Chip(opcao: o, marcada: selecionadas.any((x) => x.id == o.id), onTap: () => onToggle(o)),
      ]);
    } else {
      final colunas = comFoto ? 4 : 2;
      opcoes = LayoutBuilder(builder: (context, c) {
        final vao = context.dz(14);
        final largura = (c.maxWidth - vao * (colunas - 1)) / colunas;
        return Wrap(spacing: vao, runSpacing: vao, children: [
          for (final o in grupo.opcoes)
            SizedBox(
              width: largura,
              child: comFoto
                  ? _CardFoto(opcao: o, marcada: selecionadas.any((x) => x.id == o.id), onTap: () => onToggle(o))
                  : _CardTexto(
                      opcao: o,
                      marcada: selecionadas.any((x) => x.id == o.id),
                      unica: unica,
                      onTap: () => onToggle(o),
                    ),
            ),
        ]);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: Text(grupo.nome.toUpperCase(), style: dinerRotulo(context))),
        SizedBox(width: context.dz(14)),
        Container(
          key: ValueKey('regra-${grupo.id}'),
          padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(6)),
          decoration: BoxDecoration(color: fundoRegra, borderRadius: BorderRadius.circular(context.dz(22))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (min > 0 && ok) ...[
              Icon(Icons.check_rounded, size: context.dz(22), color: tintaRegra),
              SizedBox(width: context.dz(6)),
            ],
            Text(regra, style: _t.texto(context.dz(20), peso: FontWeight.w800, cor: tintaRegra)),
          ]),
        ),
      ]),
      SizedBox(height: context.dz(14)),
      opcoes,
    ]);
  }
}

String? _precoOpcao(OpcaoComplemento o) {
  final d = o.precoCentavosDelta;
  if (d == 0) return null;
  return d > 0 ? '+ ${formatCentavos(d)}' : '− ${formatCentavos(-d)}';
}

/// Opção com foto (grade de 4): card branco, borda 3 `line`; marcada com borda vermelha,
/// fundo `hi` e ✓ no canto.
class _CardFoto extends StatelessWidget {
  const _CardFoto({required this.opcao, required this.marcada, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preco = _precoOpcao(opcao);
    return _Desabilitada(
      ativa: opcao.disponivel,
      child: DinerToque(
        key: ValueKey('op-${opcao.id}'),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(context.dz(10), context.dz(12), context.dz(10), context.dz(16)),
          decoration: BoxDecoration(
            color: marcada ? _t.hi : _t.surface,
            borderRadius: BorderRadius.circular(context.dz(22)),
            border: Border.all(color: marcada ? _t.accent : _t.line, width: context.dz(3)),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(children: [
              SizedBox(
                height: context.dz(110),
                width: double.infinity,
                child: DinerArte(url: opcao.imagemUrl, raio: context.dz(14)),
              ),
              SizedBox(height: context.dz(8)),
              Text(opcao.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t.texto(context.dz(22), peso: FontWeight.w800, altura: 1.15)),
              if (preco != null) Text(preco, style: _t.texto(context.dz(20), cor: _t.muted)),
            ]),
            if (marcada)
              Positioned(
                top: -context.dz(4),
                right: -context.dz(2),
                child: Container(
                  width: context.dz(44),
                  height: context.dz(44),
                  decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: context.dz(28), color: _t.onAccent),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Opção só com texto (grade de 2): marcador redondo (escolha única) ou quadrado (várias).
class _CardTexto extends StatelessWidget {
  const _CardTexto({required this.opcao, required this.marcada, required this.unica, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final bool unica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preco = _precoOpcao(opcao);
    final m = context.dz(38);
    return _Desabilitada(
      ativa: opcao.disponivel,
      child: DinerToque(
        key: ValueKey('op-${opcao.id}'),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: context.dz(104)),
          padding: EdgeInsets.symmetric(horizontal: context.dz(22), vertical: context.dz(18)),
          decoration: BoxDecoration(
            color: marcada ? _t.hi : _t.surface,
            borderRadius: BorderRadius.circular(context.dz(22)),
            border: Border.all(color: marcada ? _t.accent : _t.line, width: context.dz(3)),
          ),
          child: Row(children: [
            Container(
              width: m,
              height: m,
              decoration: BoxDecoration(
                color: marcada ? _t.accent : _t.surface,
                shape: unica ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: unica ? null : BorderRadius.circular(context.dz(10)),
                border: Border.all(color: marcada ? _t.accent : _t.line2, width: context.dz(3)),
              ),
              child: marcada ? Icon(Icons.check_rounded, size: m * .7, color: _t.onAccent) : null,
            ),
            SizedBox(width: context.dz(16)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opcao.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(context.dz(26), peso: FontWeight.w800, altura: 1.15)),
                if (preco != null) Text(preco, style: _t.texto(context.dz(22), peso: FontWeight.w800, cor: _t.price)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Chip de remoção ("Sem cebola") em pílula; marcado fica marrom com ✓.
class _Chip extends StatelessWidget {
  const _Chip({required this.opcao, required this.marcada, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Desabilitada(
      ativa: opcao.disponivel,
      child: DinerToque(
        key: ValueKey('op-${opcao.id}'),
        onTap: onTap,
        child: Container(
          height: context.dz(72),
          padding: EdgeInsets.symmetric(horizontal: context.dz(28)),
          decoration: BoxDecoration(
            color: marcada ? _t.text : const Color(0x00000000),
            borderRadius: BorderRadius.circular(context.dz(36)),
            border: Border.all(color: marcada ? _t.text : _t.line2, width: context.dz(2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (marcada) ...[
              Icon(Icons.check_rounded, size: context.dz(26), color: _t.bg),
              SizedBox(width: context.dz(8)),
            ],
            Text(opcao.nome, style: _t.texto(context.dz(26), peso: FontWeight.w800, cor: marcada ? _t.bg : _t.text)),
          ]),
        ),
      ),
    );
  }
}

/// Opção indisponível: apagada e sem toque (o preço continua à vista).
class _Desabilitada extends StatelessWidget {
  const _Desabilitada({required this.ativa, required this.child});
  final bool ativa;
  final Widget child;
  @override
  Widget build(BuildContext context) => ativa ? child : IgnorePointer(child: Opacity(opacity: .4, child: child));
}
