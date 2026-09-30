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
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Produto do **Brasa 2.0** (docs/templates/01 §6.3): folha que sobe de baixo, foto sobre o
/// brilho quente (recorte entra girando e flutua), grupos de complemento em cards e o
/// rodapé com a quantidade e "Adicionar · R$ total". VIEW PURA: a seleção, a validação e o
/// preço vêm do `ProdutoScreen`.
class Brasa2Produto extends StatefulWidget {
  const Brasa2Produto(this.p, {super.key});
  final ProdutoProps p;

  @override
  State<Brasa2Produto> createState() => _Brasa2ProdutoState();
}

class _Brasa2ProdutoState extends State<Brasa2Produto> with TickerProviderStateMixin {
  late final AnimationController _folha;
  late final AnimationController _heroi;
  late final AnimationController _flutua;
  late final AnimationController _kenBurns;

  Movimento get mov => widget.p.mov;

  @override
  void initState() {
    super.initState();
    _folha = AnimationController(vsync: this, duration: mov.d(500));
    _heroi = AnimationController(vsync: this, duration: mov.d(700));
    _flutua = AnimationController(vsync: this, duration: mov.d(1700));
    _kenBurns = AnimationController(vsync: this, duration: mov.d(12000));
    if (mov.anima) {
      _folha.forward();
      // A foto entra (escala + giro) e depois flutua ±18 px em 3,4 s.
      _heroi.forward().whenCompleteOrCancel(() {
        if (mounted) _flutua.repeat(reverse: true);
      });
      _kenBurns.repeat(reverse: true);
    } else {
      _folha.value = 1;
      _heroi.value = 1;
    }
  }

  @override
  void dispose() {
    _folha.dispose();
    _heroi.dispose();
    _flutua.dispose();
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final folha = CurvedAnimation(parent: _folha, curve: brasa2CurvaFolha);
    return Brasa2Tela(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: brasa2Veu),
        Positioned(
          top: context.dz(60),
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: folha,
            builder: (_, child) => FractionalTranslation(translation: Offset(0, 1 - folha.value), child: child),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(context.dz(52))),
              child: ColoredBox(
                color: brasa2FundoModal,
                child: Column(children: [
                  _heroiFoto(context),
                  Expanded(child: _corpo(context)),
                  _rodape(context, p),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _heroiFoto(BuildContext context) {
    final produto = widget.p.produto;
    final url = produto.imagemUrl;
    // Sem foto, o placeholder entra como um recorte: sobre o brilho quente, não num bloco cinza.
    final recorte = ProdutoArte.ehRecorte(url) || (url ?? '').isEmpty;
    final selo = (produto.selo ?? '').trim();
    final largura = MediaQuery.sizeOf(context).width;
    final Widget foto;
    if (recorte) {
      final entrada = CurvedAnimation(parent: _heroi, curve: brasa2CurvaPop);
      foto = Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([entrada, _flutua]),
          builder: (_, child) {
            final e = entrada.value;
            final bob = mov.anima ? Curves.easeInOut.transform(_flutua.value) : 0.0;
            return Transform.translate(
              offset: Offset(0, -context.dz(18) * bob),
              child: Transform.rotate(
                angle: -10 * math.pi / 180 * (1 - e),
                child: Transform.scale(
                  scale: .6 + .4 * e,
                  child: Opacity(opacity: _heroi.value.clamp(0.0, 1.0), child: child),
                ),
              ),
            );
          },
          child: SizedBox(
            width: largura * .78,
            height: context.dz(420),
            child: ProdutoArte(url: url, tokens: _t, fundo: const Color(0x00000000), escalaRecorte: 1),
          ),
        ),
      );
    } else {
      foto = AnimatedBuilder(
        animation: _kenBurns,
        builder: (_, child) => Transform.scale(
          scale: mov.anima ? 1.06 + .14 * Curves.easeOut.transform(_kenBurns.value) : 1.1,
          child: child,
        ),
        child: ProdutoArte(url: url, tokens: _t, fundo: _t.art),
      );
    }
    return SizedBox(
      height: context.dz(500),
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          if (recorte)
            const Brasa2BrilhoQuente(fundo: brasa2FundoHeroi, brilho: brasa2BrilhoHeroi)
          else
            ColoredBox(color: _t.art),
          RepaintBoundary(child: foto),
          if (selo.isNotEmpty)
            Positioned(
              left: context.dz(30),
              top: context.dz(30),
              child: Selo(texto: selo, tokens: _t, altura: context.dz(44)),
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
                onTap: widget.p.onVoltar,
                child: Container(
                  width: context.dz(88),
                  height: context.dz(88),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
                  child: IconeBrasa(BrasaIcone.fechar,
                      tamanho: context.dz(40), cor: const Color(0xFFFFFFFF), traco: 2.8),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _corpo(BuildContext context) {
    final p = widget.p;
    final produto = p.produto;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(34), context.dz(48), context.dz(30)),
      child: Brasa2Entrada(
        mov: mov,
        atraso: const Duration(milliseconds: 100),
        duracaoMs: 500,
        subida: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(produto.nome, key: const ValueKey('produto-nome'), style: brasaTitulo(context, 78)),
          if (produto.descricao.trim().isNotEmpty) ...[
            SizedBox(height: context.dz(12)),
            Text(produto.descricao, style: brasaTexto(context, 28, cor: _t.muted, altura: 1.4)),
          ],
          SizedBox(height: context.dz(12)),
          Text(formatCentavos(produto.precoCentavos),
              style: brasaTexto(context, 46, peso: FontWeight.w800, cor: _t.price)),
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
    );
  }

  Widget _rodape(BuildContext context, ProdutoProps p) => Container(
        padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(24), context.dz(48), context.dz(40)),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
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
            child: Brasa2Botao(
              key: const ValueKey('adicionar'),
              rotulo: 'Adicionar · ${formatCentavos(p.totalCentavos)}',
              icone: BrasaIcone.sacola,
              mov: mov,
              onTap: p.valido ? p.onAdicionar : null,
            ),
          ),
        ]),
      );
}

/// Um grupo de complemento: título em CAIXA ALTA com a regra ("Obrigatório" / "Até N") e as
/// opções em cards — com foto, grade de 4; só texto, grade de 2 com "+ R$" ou "incluso".
class _Grupo extends StatelessWidget {
  const _Grupo({required this.grupo, required this.selecionadas, required this.mov, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final Movimento mov;
  final ValueChanged<OpcaoComplemento> onToggle;

  @override
  Widget build(BuildContext context) {
    final min = minEfetivo(grupo);
    final ok = selecaoValida(grupo, selecionadas);
    final regra = min > 0 ? (grupo.max > 1 ? 'Obrigatório · até ${grupo.max}' : 'Obrigatório') : 'Até ${grupo.max}';
    final comFoto = grupo.opcoes.any((o) => (o.imagemUrl ?? '').isNotEmpty);
    final colunas = comFoto ? 4 : 2;
    final espaco = context.dz(14);
    final ops = grupo.opcoes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(grupo.nome.toUpperCase(),
              style: brasaTexto(context, 23, peso: FontWeight.w800, cor: _t.muted, espacoEm: .1)),
        ),
        SizedBox(width: context.dz(12)),
        Container(
          height: context.dz(44),
          padding: EdgeInsets.symmetric(horizontal: context.dz(18)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: min > 0 && !ok ? _t.hi : _t.surface2,
            borderRadius: BorderRadius.circular(context.dz(22)),
          ),
          child: Text(regra,
              key: ValueKey('regra-${grupo.id}'),
              style: brasaTexto(context, 20, peso: FontWeight.w800, cor: min > 0 && !ok ? _t.accent : _t.muted)),
        ),
      ]),
      SizedBox(height: espaco),
      for (var i = 0; i < ops.length; i += colunas) ...[
        if (i > 0) SizedBox(height: espaco),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var j = 0; j < colunas; j++) ...[
            if (j > 0) SizedBox(width: espaco),
            Expanded(
              child: i + j < ops.length
                  ? _Opcao(
                      opcao: ops[i + j],
                      marcada: selecionadas.any((x) => x.id == ops[i + j].id),
                      comFoto: comFoto,
                      mov: mov,
                      onTap: () => onToggle(ops[i + j]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ]),
      ],
    ]);
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.opcao,
    required this.marcada,
    required this.comFoto,
    required this.mov,
    required this.onTap,
  });
  final OpcaoComplemento opcao;
  final bool marcada;
  final bool comFoto;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preco = opcao.precoCentavosDelta > 0 ? '+ ${formatCentavos(opcao.precoCentavosDelta)}' : 'incluso';
    final raio = BorderRadius.circular(context.dz(_t.raio - 8));
    final nome = Text(opcao.nome,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: comFoto ? TextAlign.center : TextAlign.start,
        style: brasaTexto(context, comFoto ? 22 : 26, peso: FontWeight.w700, altura: 1.15));
    final valor = Text(preco,
        maxLines: 1,
        style: brasaTexto(context, comFoto ? 20 : 22, cor: _t.muted, altura: 1.3));
    final Widget miolo = comFoto
        ? Column(children: [
            SizedBox(
              height: context.dz(110),
              child: ProdutoArte(url: opcao.imagemUrl, tokens: _t, raio: _t.raio - 16, sombra: false),
            ),
            SizedBox(height: context.dz(8)),
            nome,
            const Spacer(),
            valor,
          ])
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [nome, SizedBox(height: context.dz(6)), valor],
          );
    return Opacity(
      opacity: opcao.disponivel ? 1 : .4,
      child: Semantics(
        button: true,
        selected: marcada,
        label: opcao.nome,
        child: GestureDetector(
          key: ValueKey('op-${opcao.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: opcao.disponivel ? onTap : null,
          child: AnimatedContainer(
            duration: mov.anima ? mov.d(250) : Duration.zero,
            height: context.dz(comFoto ? 236 : 140),
            padding: comFoto
                ? EdgeInsets.fromLTRB(context.dz(10), context.dz(12), context.dz(10), context.dz(16))
                : EdgeInsets.symmetric(horizontal: context.dz(26), vertical: context.dz(18)),
            decoration: BoxDecoration(
              color: marcada ? _t.hi : _t.surface,
              borderRadius: raio,
              border: Border.all(color: marcada ? _t.accent : _t.line, width: context.dz(3)),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: miolo),
              if (marcada)
                Positioned(
                  top: comFoto ? context.dz(-4) : context.dz(-8),
                  right: comFoto ? context.dz(-2) : context.dz(-14),
                  child: _Marca(mov: mov),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ✓ num círculo `accent` de 44 que entra com "pop".
class _Marca extends StatelessWidget {
  const _Marca({required this.mov});
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(44);
    final marca = Container(
      key: const ValueKey('opcao-marcada'),
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
      child: IconeBrasa(BrasaIcone.check, tamanho: d * .55, cor: _t.onAccent, traco: 3.2),
    );
    if (!mov.anima) return marca;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .86, end: 1),
      duration: mov.d(300),
      curve: brasa2CurvaPop,
      builder: (_, v, child) => Opacity(
        opacity: ((v - .86) / .14).clamp(0.0, 1.0),
        child: Transform.scale(scale: v, child: child),
      ),
      child: marca,
    );
  }
}
