import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
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
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Produto do Vitrine (docs/templates/02 §6.3 e 00 §4.3): folha de vidro (top 140, raio
/// superior 56) sobre a foto do produto desfocada — ou só escurecida, sem blur. No topo da
/// folha, a foto (500 de altura, Ken Burns de 12 s) com o X; no corpo, nome, preço e os
/// grupos em cards; no rodapé, a quantidade e "Adicionar · R$".
class VitrineProdutoView extends StatefulWidget {
  const VitrineProdutoView({super.key, required this.p});
  final ProdutoProps p;

  @override
  State<VitrineProdutoView> createState() => _VitrineProdutoViewState();
}

class _VitrineProdutoViewState extends State<VitrineProdutoView> with TickerProviderStateMixin {
  late final AnimationController _folha;
  late final AnimationController _kb;

  @override
  void initState() {
    super.initState();
    final mov = widget.p.mov;
    // A folha sobe em 500 ms (Cubic .2,.9,.2,1); sem animação, já está no lugar.
    _folha = AnimationController(vsync: this, duration: mov.d(500));
    _kb = AnimationController(vsync: this, duration: mov.d(12000));
    if (mov.anima) {
      _folha.forward();
    } else {
      _folha.value = 1;
    }
    if (vitrineMovimentoCheio(mov)) _kb.forward();
  }

  @override
  void dispose() {
    _folha.dispose();
    _kb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final p = widget.p;
    final mov = p.mov;
    final produto = p.produto;
    final url = produto.imagemUrl?.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: LayoutBuilder(builder: (context, c) {
        final topo = math.min(context.dz(140), c.maxHeight * .08);
        final alturaFolha = c.maxHeight - topo;
        // A foto da folha: 500 de desenho, mas nunca mais de 1/3 da folha (tela baixa).
        final alturaFoto = math.min(context.dz(500), alturaFolha * .32);
        return Stack(fit: StackFit.expand, children: [
          // Fundo: a própria foto, desfocada (com blur) ou só escurecida.
          if (url.isNotEmpty)
            mov.blur
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: context.dz(30), sigmaY: context.dz(30)),
                    child: ProdutoArte(url: url, tokens: t, fundo: const Color(0xFF000000)),
                  )
                : ProdutoArte(url: url, tokens: t, fundo: const Color(0xFF000000)),
          ColoredBox(color: mov.blur ? const Color(0x99000000) : const Color(0xCC000000)),
          Positioned(
            top: topo,
            left: 0,
            right: 0,
            height: alturaFolha,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: _folha, curve: const Cubic(.2, .9, .2, 1))),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(context.dz(56))),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: vitrineFolha,
                    border: Border(top: BorderSide(color: const Color(0x29FFFFFF), width: context.dz(2))),
                  ),
                  child: Column(children: [
                    SizedBox(
                      height: alturaFoto,
                      child: _Heroi(produto: produto, mov: mov, kb: _kb, onFechar: p.onVoltar),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(34), context.dz(48), context.dz(30)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TituloVitrine(produto.nome, estilo: context.vDisplay(78, altura: 1, espacoEm: -.03)),
                          if (produto.descricao.trim().isNotEmpty) ...[
                            SizedBox(height: context.dz(12)),
                            Text(produto.descricao,
                                style: context.vTexto(28, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
                          ],
                          SizedBox(height: context.dz(12)),
                          Text(formatCentavos(produto.precoCentavos),
                              style: context.vTexto(46, peso: FontWeight.w800, cor: t.price)),
                          for (final g in produto.grupos) ...[
                            SizedBox(height: context.dz(30)),
                            _Grupo(
                              grupo: g,
                              selecionadas: p.selecoes[g.id] ?? const [],
                              mov: mov,
                              onToggle: (o) => p.onToggle(g, o),
                            ),
                          ],
                        ]),
                      ),
                    ),
                    _RodapeProduto(p: p),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Topo da folha: a foto (cover, Ken Burns) ou o recorte, o selo e o X de vidro.
class _Heroi extends StatelessWidget {
  const _Heroi({required this.produto, required this.mov, required this.kb, required this.onFechar});
  final Produto produto;
  final Movimento mov;
  final AnimationController kb;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final url = produto.imagemUrl?.trim() ?? '';
    final recorte = ProdutoArte.ehRecorte(url);
    final selo = produto.selo?.trim() ?? '';
    final Widget arte;
    if (recorte || url.isEmpty) {
      arte = ProdutoArte(url: url.isEmpty ? null : url, tokens: t, escalaRecorte: .78);
    } else {
      final foto = RepaintBoundary(child: ProdutoArte(url: url, tokens: t));
      arte = vitrineMovimentoCheio(mov)
          ? AnimatedBuilder(
              animation: kb,
              builder: (_, child) =>
                  Transform.scale(scale: 1.06 + .14 * Curves.easeOut.transform(kb.value), child: child),
              child: foto,
            )
          : Transform.scale(scale: 1.06, child: foto);
    }
    final d = context.dz(88);
    return ClipRect(
      child: ColoredBox(
        color: t.art,
        child: Stack(fit: StackFit.expand, children: [
          arte,
          if (selo.isNotEmpty)
            Positioned(
              left: context.dz(30),
              top: context.dz(30),
              child: Selo(texto: selo, tokens: t, altura: context.dz(44), fundo: t.accent2, tinta: t.onAccent2),
            ),
          Positioned(
            top: context.dz(26),
            right: context.dz(26),
            child: Semantics(
              button: true,
              label: 'Fechar',
              child: GestureDetector(
                key: const ValueKey('produto-fechar'),
                behavior: HitTestBehavior.opaque,
                onTap: onFechar,
                child: SizedBox(
                  width: d,
                  height: d,
                  child: VidroVitrine(
                    mov: mov,
                    raio: BorderRadius.circular(d / 2),
                    cor: const Color(0x80000000),
                    corSemBlur: const Color(0xB3000000),
                    borda: null,
                    sigma: 10,
                    child: Center(child: Icon(Icons.close_rounded, size: context.dz(44), color: t.text)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Um grupo de complementos: rótulo ("ACOMPANHAMENTO"), a regra ("Obrigatório" ou
/// "Até N") e os cards das opções em 4 colunas (raio 32; escolhida = borda `accent` +
/// fundo `hi` + ✓). `max == 1` vira escolha única — quem troca a opção é a tela.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.grupo, required this.selecionadas, required this.mov, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final Movimento mov;
  final void Function(OpcaoComplemento) onToggle;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final obrigatorio = minEfetivo(grupo) > 0;
    final ok = selecaoValida(grupo, selecionadas);
    final regra = obrigatorio ? 'Obrigatório' : 'Até ${grupo.max}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
          child: Text(grupo.nome.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.vTexto(23, peso: FontWeight.w800, cor: t.muted, espacoEm: .1)),
        ),
        SizedBox(width: context.dz(14)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(6)),
          decoration: BoxDecoration(
            color: obrigatorio && !ok ? t.hi : t.surface2,
            borderRadius: BorderRadius.circular(context.dz(20)),
          ),
          child: Text(regra,
              key: ValueKey('regra-${grupo.id}'),
              style: context.vTexto(20, peso: FontWeight.w800, cor: obrigatorio && !ok ? t.accent : t.muted)),
        ),
      ]),
      SizedBox(height: context.dz(14)),
      LayoutBuilder(builder: (context, c) {
        final esp = context.dz(14);
        final largura = (c.maxWidth - esp * 3) / 4;
        return Wrap(spacing: esp, runSpacing: esp, children: [
          for (final o in grupo.opcoes)
            SizedBox(
              width: largura,
              child: _CartaoOpcao(
                opcao: o,
                marcada: selecionadas.any((x) => x.id == o.id),
                mov: mov,
                onTap: () => onToggle(o),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _CartaoOpcao extends StatelessWidget {
  const _CartaoOpcao({required this.opcao, required this.marcada, required this.mov, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final foto = (opcao.imagemUrl ?? '').trim();
    final delta = opcao.precoCentavosDelta;
    final cartao = AnimatedContainer(
      duration: mov.anima ? mov.d(250) : Duration.zero,
      padding: EdgeInsets.fromLTRB(context.dz(10), context.dz(12), context.dz(10), context.dz(16)),
      decoration: BoxDecoration(
        color: marcada ? t.hi : t.surface,
        borderRadius: BorderRadius.circular(context.dz(t.raio - 8)),
        border: Border.all(color: marcada ? t.accent : t.line, width: context.dz(3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (foto.isNotEmpty) ...[
          SizedBox(
            height: context.dz(110),
            width: double.infinity,
            child: ProdutoArte(url: foto, tokens: t, raio: context.dz(t.raio - 16), escalaRecorte: .9),
          ),
          SizedBox(height: context.dz(8)),
        ],
        Text(opcao.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.vTexto(22, peso: FontWeight.w800, altura: 1.15)),
        if (delta != 0) ...[
          SizedBox(height: context.dz(6)),
          Text('+ ${formatCentavos(delta)}',
              textAlign: TextAlign.center,
              style: context.vTexto(20, peso: FontWeight.w400, cor: t.muted)),
        ],
      ]),
    );
    final d = context.dz(44);
    Widget conteudo = Stack(children: [
      cartao,
      if (marcada)
        Positioned(
          top: context.dz(8),
          right: context.dz(8),
          child: Container(
            key: ValueKey('op-marcada-${opcao.id}'),
            width: d,
            height: d,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: d * .62, color: t.onAccent),
          ),
        ),
    ]);
    // Opção indisponível: aparece, apagada e sem toque (o `menuProvider` normalmente já a tira).
    if (!opcao.disponivel) conteudo = IgnorePointer(child: Opacity(opacity: .4, child: conteudo));
    return Semantics(
      button: true,
      selected: marcada,
      enabled: opcao.disponivel,
      child: GestureDetector(
        key: ValueKey('op-${opcao.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: opcao.disponivel ? onTap : null,
        child: conteudo,
      ),
    );
  }
}

/// Rodapé da folha: quantidade e "Adicionar · R$ total" (desabilitado até a escolha valer).
class _RodapeProduto extends StatelessWidget {
  const _RodapeProduto({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(24), context.dz(48), context.dz(40)),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: context.dz(2)))),
      child: Row(children: [
        Quantidade(n: p.qtd, onMenos: p.onMenos, onMais: p.onMais, tokens: t, tamanho: 92),
        SizedBox(width: context.dz(24)),
        Expanded(
          child: BotaoVitrine(
            key: const ValueKey('adicionar'),
            rotulo: 'Adicionar · ${formatCentavos(p.totalCentavos)}',
            icone: Icons.shopping_bag_outlined,
            padH: 30,
            mov: p.mov,
            onTap: p.valido ? p.onAdicionar : null,
          ),
        ),
      ]),
    );
  }
}
