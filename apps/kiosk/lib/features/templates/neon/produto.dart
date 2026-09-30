import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../domain/order/order_models.dart';
import '../comum/produto_arte.dart';
import '../comum/quantidade.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Produto do Neon 2.0 (docs/templates/04-neon-2.md §6.3): folha que sobe (topo 60, raio
/// superior 52, fundo `0xFF0C0C14`), topo com brilho radial verde, o recorte entrando e
/// flutuando e o nome gigante vazado ao fundo; corpo com nome em CAIXA ALTA, preço em
/// `accent`, grupos com título em `accent2` e opções em 2 colunas; rodapé com
/// `Quantidade` e ADICIONAR · R$.
class NeonProdutoView extends StatefulWidget {
  const NeonProdutoView({super.key, required this.p});
  final ProdutoProps p;

  @override
  State<NeonProdutoView> createState() => _NeonProdutoViewState();
}

class _NeonProdutoViewState extends State<NeonProdutoView> with TickerProviderStateMixin {
  late final AnimationController _folha;
  late final AnimationController _entrada;

  @override
  void initState() {
    super.initState();
    final m = widget.p.mov;
    _folha = AnimationController(vsync: this, duration: m.d(500));
    _entrada = AnimationController(vsync: this, duration: m.d(700));
    if (m.anima) {
      _folha.forward();
      _entrada.forward();
    } else {
      _folha.value = 1;
      _entrada.value = 1;
    }
  }

  @override
  void dispose() {
    _folha.dispose();
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final prod = p.produto;
    return Scaffold(
      backgroundColor: const Color(0xFF030306),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: context.dz(60)),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: _folha, curve: Curves.easeOutCubic)),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(context.dz(52))),
              child: ColoredBox(
                color: neonFolha,
                child: Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _Topo(p: p, entrada: _entrada),
                        Padding(
                          padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(34), context.dz(48), context.dz(30)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(_t.caixa(prod.nome),
                                key: const ValueKey('produto-nome'), style: neonDisplay(context.dz(62), espaco: -.03)),
                            if (prod.descricao.trim().isNotEmpty) ...[
                              SizedBox(height: context.dz(12)),
                              Text(prod.descricao, style: neonTexto(context.dz(28), cor: _t.muted, altura: 1.4)),
                            ],
                            SizedBox(height: context.dz(12)),
                            Text(formatCentavos(prod.precoCentavos),
                                style: neonDisplay(context.dz(50), cor: _t.accent)),
                            for (final g in prod.grupos) ...[
                              SizedBox(height: context.dz(34)),
                              _Grupo(
                                grupo: g,
                                selecionadas: p.selecoes[g.id] ?? const [],
                                onToggle: (o) => p.onToggle(g, o),
                              ),
                            ],
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  _Rodape(p: p),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Topo extends StatelessWidget {
  const _Topo({required this.p, required this.entrada});
  final ProdutoProps p;
  final Animation<double> entrada;

  @override
  Widget build(BuildContext context) {
    final prod = p.produto;
    final recorte = ProdutoArte.ehRecorte(prod.imagemUrl) || prod.imagemUrl == null;
    final selo = (prod.selo ?? '').trim();
    return SizedBox(
      height: context.dz(500),
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: recorte ? const Color(0xFF10101A) : _t.art),
        if (recorte)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, .2),
                radius: .75,
                colors: [Color(0x38C8FF2E), Color(0x00C8FF2E)],
              ),
            ),
          ),
        if (recorte) _NomeVazado(nome: prod.nome),
        if (recorte)
          Center(
            child: SizedBox(
              width: context.dz(700),
              height: context.dz(420),
              child: _EntradaHeroi(
                entrada: entrada,
                child: NeonFlutua(
                  mov: p.mov,
                  ms: 3400,
                  child: ProdutoArte(
                    url: prod.imagemUrl,
                    tokens: _t,
                    escalaRecorte: 1,
                    fundo: const Color(0x00000000),
                  ),
                ),
              ),
            ),
          )
        else
          ProdutoArte(url: prod.imagemUrl, tokens: _t),
        if (selo.isNotEmpty) Positioned(left: context.dz(30), top: context.dz(30), child: SeloNeon(texto: selo)),
        Positioned(
          top: context.dz(26),
          right: context.dz(26),
          child: Material(
            color: const Color(0x80000000),
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey('produto-fechar'),
              customBorder: const CircleBorder(),
              onTap: p.onVoltar,
              child: SizedBox(
                width: context.dz(88),
                height: context.dz(88),
                child: Icon(Icons.close_rounded, size: context.dz(44), color: const Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// O recorte entra girando e crescendo (`heroIn`, 700 ms).
class _EntradaHeroi extends StatelessWidget {
  const _EntradaHeroi({required this.entrada, required this.child});
  final Animation<double> entrada;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: entrada,
        child: child,
        builder: (_, child) {
          final v = Curves.easeOutBack.transform(entrada.value);
          return Opacity(
            opacity: entrada.value.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: -0.1745 * (1 - v),
              child: Transform.scale(scale: .6 + .4 * v, child: child),
            ),
          );
        },
      );
}

/// Nome gigante vazado ao fundo do topo ("DUPLO /" + "BACON").
class _NomeVazado extends StatelessWidget {
  const _NomeVazado({required this.nome});
  final String nome;

  static List<String> linhas(String nome) {
    final p = nome.trim().toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (p.isEmpty) return const [];
    if (p.length == 1) return [p.first];
    return ['${p.first} /', p.skip(1).take(2).join(' ')];
  }

  @override
  Widget build(BuildContext context) {
    final l = linhas(nome);
    if (l.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.dz(30), vertical: context.dz(40)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final t in l)
              LetreiroNeon(
                texto: t,
                tamanho: context.dz(170),
                altura: .95,
                cor: const Color(0x40C8FF2E),
                traco: context.dz(2),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.grupo, required this.selecionadas, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final void Function(OpcaoComplemento) onToggle;

  /// "Obrigatório" ou "Até N" (docs/templates/00 §4.3).
  static String regra(GrupoComplemento g) {
    final min = minEfetivo(g);
    if (min == 0) return 'Até ${g.max}';
    if (g.max <= 1) return 'Obrigatório';
    if (min > 1) return 'Escolha $min a ${g.max}';
    return 'Obrigatório · até ${g.max}';
  }

  @override
  Widget build(BuildContext context) {
    final ok = selecaoValida(grupo, selecionadas);
    final obrigatorio = minEfetivo(grupo) > 0;
    final opcoes = grupo.opcoes;
    final linhas = <Widget>[];
    for (var i = 0; i < opcoes.length; i += 2) {
      Widget op(OpcaoComplemento o) => _Opcao(
            opcao: o,
            marcada: selecionadas.any((x) => x.id == o.id),
            radio: grupo.max <= 1,
            onTap: () => onToggle(o),
          );
      linhas.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: op(opcoes[i])),
          SizedBox(width: context.dz(14)),
          Expanded(child: i + 1 < opcoes.length ? op(opcoes[i + 1]) : const SizedBox.shrink()),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Flexible(
          child: Text(grupo.nome.toUpperCase(),
              style: neonTexto(context.dz(24), peso: FontWeight.w700, cor: _t.accent2, espaco: .1)),
        ),
        SizedBox(width: context.dz(14)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.dz(14), vertical: context.dz(6)),
          decoration: BoxDecoration(
            color: obrigatorio && !ok ? _t.accent2 : _t.surface2,
            borderRadius: BorderRadius.circular(context.dz(10)),
          ),
          child: Text(regra(grupo),
              key: ValueKey('regra-${grupo.id}'),
              style:
                  neonTexto(context.dz(20), peso: FontWeight.w700, cor: obrigatorio && !ok ? _t.onAccent2 : _t.muted)),
        ),
      ]),
      for (final l in linhas) ...[
        SizedBox(height: context.dz(14)),
        l,
      ],
    ]);
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({required this.opcao, required this.marcada, required this.radio, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final bool radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(context.dz(_t.raio - 8));
    final marca = context.dz(44);
    final corpo = Container(
      constraints: BoxConstraints(minHeight: context.dz(104)),
      padding: EdgeInsets.symmetric(horizontal: context.dz(20), vertical: context.dz(16)),
      decoration: BoxDecoration(
        color: marcada ? _t.hi : _t.surface,
        borderRadius: raio,
        border: Border.all(color: marcada ? _t.accent : _t.line, width: context.dz(3)),
      ),
      child: Row(children: [
        if (opcao.imagemUrl != null && opcao.imagemUrl!.isNotEmpty) ...[
          SizedBox(
            width: context.dz(72),
            height: context.dz(72),
            child: ProdutoArte(url: opcao.imagemUrl, tokens: _t, raio: context.dz(12)),
          ),
          SizedBox(width: context.dz(16)),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(opcao.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: neonTexto(context.dz(26), peso: FontWeight.w700, altura: 1.15)),
            if (opcao.precoCentavosDelta != 0) ...[
              SizedBox(height: context.dz(4)),
              Text('+ ${formatCentavos(opcao.precoCentavosDelta)}', style: neonTexto(context.dz(22), cor: _t.muted)),
            ],
          ]),
        ),
        SizedBox(width: context.dz(12)),
        Container(
          width: marca,
          height: marca,
          decoration: BoxDecoration(
            color: marcada ? _t.accent : const Color(0x00000000),
            shape: radio ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: radio ? null : BorderRadius.circular(context.dz(12)),
            border: marcada ? null : Border.all(color: _t.line2, width: context.dz(2)),
          ),
          child: marcada ? Icon(Icons.check_rounded, size: marca * .62, color: _t.onAccent) : null,
        ),
      ]),
    );
    return Opacity(
      opacity: opcao.disponivel ? 1 : .4,
      child: IgnorePointer(
        ignoring: !opcao.disponivel,
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            key: ValueKey('op-${opcao.id}'),
            borderRadius: raio,
            onTap: onTap,
            child: corpo,
          ),
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.p});
  final ProdutoProps p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(24), context.dz(48), context.dz(40)),
      decoration: BoxDecoration(
        color: neonFolha,
        border: Border(top: BorderSide(color: _t.line, width: context.dz(2))),
      ),
      child: Row(children: [
        Quantidade(
          n: p.qtd,
          onMenos: p.onMenos,
          onMais: p.onMais,
          tokens: _t,
          tamanho: 92,
          corMenos: _t.surface2,
        ),
        SizedBox(width: context.dz(24)),
        Expanded(
          child: NeonBotao(
            key: const ValueKey('adicionar'),
            rotulo: 'Adicionar · ${formatCentavos(p.totalCentavos)}',
            icone: Icons.shopping_bag_outlined,
            onTap: p.valido ? p.onAdicionar : null,
          ),
        ),
      ]),
    );
  }
}
