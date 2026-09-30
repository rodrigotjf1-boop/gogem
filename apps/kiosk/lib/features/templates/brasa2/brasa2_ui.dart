import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../../catalogo/produto_imagem.dart';
import '../escala.dart';
import '../movimento.dart';
import 'brasa2_tokens.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Estilo de texto de título (DM Serif Display) com o espaçamento do protótipo.
TextStyle brasaTitulo(BuildContext context, double px, {Color? cor, double altura = 1, FontStyle? estilo}) =>
    _t.display(context.dz(px), cor: cor, altura: altura, estilo: estilo).copyWith(letterSpacing: -.01 * context.dz(px));

/// Estilo de texto corrido (Manrope), em px de desenho.
TextStyle brasaTexto(BuildContext context, double px,
        {FontWeight peso = FontWeight.w600, Color? cor, double? altura, double espacoEm = 0}) =>
    _t.texto(context.dz(px), peso: peso, cor: cor, altura: altura, espaco: espacoEm * context.dz(px));

/// Fundo, tipografia base e margem segura de uma tela do Brasa 2.0. A `DefaultTextStyle`
/// zera o espaçamento/fonte que o tema global do app (Tektur, `letterSpacing`) injetaria.
class Brasa2Tela extends StatelessWidget {
  const Brasa2Tela({super.key, required this.child, this.fundo});
  final Widget child;
  final Color? fundo;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: fundo ?? _t.bg,
        body: Brasa2Texto(child: SafeArea(child: child)),
      );
}

/// Só a tipografia base do template (para o descanso, que vive dentro da tela da loja).
class Brasa2Texto extends StatelessWidget {
  const Brasa2Texto({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
        style: _t
            .texto(context.dz(30))
            .copyWith(letterSpacing: 0, decoration: TextDecoration.none, height: 1.3),
        child: child,
      );
}

/// Entrada de tela do protótipo: fade + subida de 40 px em 550 ms (`scrIn`). Com
/// [Movimento.anima] desligado, aparece direto.
class Brasa2Entrada extends StatefulWidget {
  const Brasa2Entrada({
    super.key,
    required this.mov,
    required this.child,
    this.atraso = Duration.zero,
    this.duracaoMs = 550,
    this.subida = 40,
    this.escalaInicial = 1,
    this.curva = brasa2CurvaEntrada,
  });

  final Movimento mov;
  final Widget child;
  final Duration atraso;
  final int duracaoMs;

  /// Subida em px de desenho.
  final double subida;

  /// Escala de partida (1 = sem escala; o cartão da peça-também entra de 0,9).
  final double escalaInicial;
  final Curve curva;

  @override
  State<Brasa2Entrada> createState() => _Brasa2EntradaState();
}

class _Brasa2EntradaState extends State<Brasa2Entrada> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _v;
  late final Animation<double> _opacidade;

  @override
  void initState() {
    super.initState();
    // O atraso entra no próprio controller (Interval) — sem Timer solto.
    final atraso = widget.atraso.inMilliseconds;
    final total = atraso + widget.duracaoMs;
    final inicio = total == 0 ? 0.0 : atraso / total;
    _c = AnimationController(vsync: this, duration: widget.mov.d(total));
    _v = CurvedAnimation(parent: _c, curve: Interval(inicio, 1, curve: widget.curva));
    _opacidade = CurvedAnimation(parent: _c, curve: Interval(inicio, 1));
    if (widget.mov.anima) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mov.anima) return widget.child;
    final subida = context.dz(widget.subida);
    return AnimatedBuilder(
      animation: _v,
      builder: (_, child) {
        final v = _v.value;
        return Opacity(
          opacity: _opacidade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, subida * (1 - v)),
            child: widget.escalaInicial == 1
                ? child
                : Transform.scale(scale: widget.escalaInicial + (1 - widget.escalaInicial) * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Variante do botão (docs/templates/01 §5).
enum Brasa2Variante { primario, fantasma, suave }

/// Botão do Brasa 2.0: altura 124 (xl 170), raio 22, Manrope 800. Ao tocar, escala 0,97
/// por 150 ms. Sem [onTap], fica esmaecido (35%) e não reage.
class Brasa2Botao extends StatefulWidget {
  const Brasa2Botao({
    super.key,
    required this.rotulo,
    required this.onTap,
    this.variante = Brasa2Variante.primario,
    this.icone,
    this.iconeDepois,
    this.altura = 124,
    this.fonte = 34,
    this.tamanhoIcone,
    this.mov = Movimento.parado,
    this.largura,
  });

  final String rotulo;
  final VoidCallback? onTap;
  final Brasa2Variante variante;
  final BrasaIcone? icone;
  final BrasaIcone? iconeDepois;

  /// Altura e fonte em px de desenho.
  final double altura;
  final double fonte;
  final double? tamanhoIcone;
  final Movimento mov;

  /// Largura em px de TELA (nulo = do conteúdo, ou a que o pai impuser).
  final double? largura;

  @override
  State<Brasa2Botao> createState() => _Brasa2BotaoState();
}

class _Brasa2BotaoState extends State<Brasa2Botao> {
  bool _baixo = false;

  void _solta() {
    if (_baixo) setState(() => _baixo = false);
  }

  @override
  Widget build(BuildContext context) {
    final ativo = widget.onTap != null;
    final (fundo, tinta, borda) = switch (widget.variante) {
      Brasa2Variante.primario => (_t.accent, _t.onAccent, null),
      Brasa2Variante.fantasma => (const Color(0x00000000), _t.text, _t.line2),
      Brasa2Variante.suave => (_t.surface2, _t.text, null),
    };
    final raio = BorderRadius.circular(context.dz(_t.raioBotao));
    final ic = context.dz(widget.tamanhoIcone ?? widget.fonte * 1.1);
    final rotulo = Text(widget.rotulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: brasaTexto(context, widget.fonte, peso: FontWeight.w800, cor: tinta, altura: 1));
    // Com largura imposta (Expanded, largura cheia), o rótulo encolhe com reticências;
    // solto numa linha (ex.: "Pular"), o botão tem a largura do conteúdo.
    final conteudo = LayoutBuilder(
      builder: (context, c) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icone != null) ...[
            IconeBrasa(widget.icone!, tamanho: ic, cor: tinta),
            SizedBox(width: context.dz(16)),
          ],
          if (c.hasBoundedWidth) Flexible(child: rotulo) else rotulo,
          if (widget.iconeDepois != null) ...[
            SizedBox(width: context.dz(16)),
            IconeBrasa(widget.iconeDepois!, tamanho: ic, cor: tinta, traco: 2.6),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: ativo,
      label: widget.rotulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: ativo ? (_) => setState(() => _baixo = true) : null,
        onTapUp: ativo ? (_) => _solta() : null,
        onTapCancel: ativo ? _solta : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _baixo ? .97 : 1,
          duration: widget.mov.anima ? const Duration(milliseconds: 150) : Duration.zero,
          child: Opacity(
            opacity: ativo ? 1 : .35,
            child: Container(
              height: context.dz(widget.altura),
              width: widget.largura,
              padding: EdgeInsets.symmetric(horizontal: context.dz(44)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: raio,
                border: borda == null ? null : Border.all(color: borda, width: context.dz(3)),
              ),
              child: conteudo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão redondo de "+" (76 no card, 64 na sugestão).
class Brasa2BotaoMais extends StatelessWidget {
  const Brasa2BotaoMais({super.key, required this.onTap, this.tamanho = 76, this.adicionado = false});
  final VoidCallback? onTap;
  final double tamanho;
  final bool adicionado;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(tamanho);
    return Semantics(
      button: true,
      label: adicionado ? 'Adicionado' : 'Adicionar',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
          child: IconeBrasa(adicionado ? BrasaIcone.check : BrasaIcone.mais,
              tamanho: d * .5, cor: _t.onAccent, traco: 3),
        ),
      ),
    );
  }
}

/// Logo do topo. Com `logoUrl`, a imagem da loja (altura 64 × [escala]); com `nomeLoja`, a
/// chama + o nome em DM Serif espaçado; sem nenhum dos dois, o logo padrão do template
/// ("BRASA / BURGER & STEAK", docs/templates/01 §4).
///
/// [daLoja] = lê `nomeLoja`/`logoUrl` da aparência publicada quando há um `ProviderScope`
/// acima (as telas de pedido não recebem a marca nas props); sem escopo, o padrão.
class Brasa2Marca extends StatelessWidget {
  const Brasa2Marca({
    super.key,
    this.escala = 1,
    this.nomeLoja,
    this.logoUrl,
    this.daLoja = true,
    this.alinhamento = Alignment.centerLeft,
  });

  final double escala;
  final String? nomeLoja;
  final String? logoUrl;
  final bool daLoja;
  final Alignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final temEscopo = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (!daLoja || !temEscopo) return _desenho(context, nomeLoja, logoUrl);
    return Consumer(builder: (context, ref, _) {
      final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
      return _desenho(context, nomeLoja ?? ap.nomeLoja, logoUrl ?? ap.logoUrl);
    });
  }

  Widget _desenho(BuildContext context, String? nome, String? logo) {
    final s = escala;
    final Widget marca;
    if (logo != null && logo.trim().isNotEmpty) {
      final h = context.dz(64 * s);
      marca = SizedBox(
        key: const ValueKey('marca-logo'),
        height: h,
        width: h * 2.6,
        child: ProdutoImagem(url: logo, fit: BoxFit.contain, memCacheWidth: (h * 2.6 * 2).round()),
      );
    } else {
      final nomeLimpo = (nome ?? '').trim();
      final padrao = nomeLimpo.isEmpty;
      final fs = context.dz(48 * s);
      marca = Row(
        key: const ValueKey('marca'),
        mainAxisSize: MainAxisSize.min,
        children: [
          IconeBrasa(BrasaIcone.chama, tamanho: context.dz(52 * s), cor: _t.accent, traco: 2),
          SizedBox(width: context.dz(14 * s)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(padrao ? 'BRASA' : nomeLimpo.toUpperCase(),
                  maxLines: 1,
                  style: _t.display(fs, altura: 1).copyWith(letterSpacing: .26 * fs)),
              if (padrao) ...[
                SizedBox(height: context.dz(6 * s)),
                Text('BURGER & STEAK',
                    maxLines: 1,
                    style: brasaTexto(context, 16 * s, peso: FontWeight.w700, cor: _t.muted, altura: 1, espacoEm: .42)),
              ],
            ],
          ),
        ],
      );
    }
    return FittedBox(fit: BoxFit.scaleDown, alignment: alinhamento, child: marca);
  }
}

/// Ação do topo ("Voltar" cheio, "Cancelar" só com borda).
class Brasa2AcaoTopo extends StatelessWidget {
  const Brasa2AcaoTopo({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.onTap,
    this.contorno = false,
  });

  final String rotulo;
  final BrasaIcone icone;
  final VoidCallback onTap;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    final cor = contorno ? _t.muted : _t.text;
    return Semantics(
      button: true,
      label: rotulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: context.dz(72),
          padding: EdgeInsets.symmetric(horizontal: context.dz(26)),
          decoration: BoxDecoration(
            color: contorno ? const Color(0x00000000) : _t.surface2,
            borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
            border: contorno ? Border.all(color: _t.line, width: context.dz(2)) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconeBrasa(icone, tamanho: context.dz(contorno ? 28 : 30), cor: cor, traco: 2.6),
            SizedBox(width: context.dz(10)),
            Text(rotulo, style: brasaTexto(context, 26, peso: FontWeight.w700, cor: contorno ? _t.text : cor)),
          ]),
        ),
      ),
    );
  }
}

/// Topo das telas internas: logo (0,78) à esquerda, ações à direita e, embaixo, as etapas
/// (padding 40/48/16, espaço 26 — `.tb` do protótipo).
class Brasa2Topo extends StatelessWidget {
  const Brasa2Topo({
    super.key,
    this.onVoltar,
    this.onCancelar,
    this.etapa,
    this.mov = Movimento.parado,
  });

  final VoidCallback? onVoltar;
  final VoidCallback? onCancelar;

  /// 0..3 (nulo = sem a barra de etapas).
  final int? etapa;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(40), context.dz(48), context.dz(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Expanded(child: Brasa2Marca(escala: .78)),
          if (onVoltar != null) ...[
            SizedBox(width: context.dz(12)),
            Brasa2AcaoTopo(
                key: const ValueKey('topo-voltar'), rotulo: 'Voltar', icone: BrasaIcone.voltar, onTap: onVoltar!),
          ],
          if (onCancelar != null) ...[
            SizedBox(width: context.dz(12)),
            Brasa2AcaoTopo(
              key: const ValueKey('topo-cancelar'),
              rotulo: 'Cancelar',
              icone: BrasaIcone.fechar,
              onTap: onCancelar!,
              contorno: true,
            ),
          ],
        ]),
        if (etapa != null) ...[
          SizedBox(height: context.dz(26)),
          Brasa2Etapas(atual: etapa!, mov: mov),
        ],
      ]),
    );
  }
}

/// Barra de 4 passos no desenho do Brasa (variante local de `comum/Etapas`): rótulo 22,
/// concluído com o ✓ de traço e o nome no acento, atual em 800 e o que falta em `muted`.
class Brasa2Etapas extends StatelessWidget {
  const Brasa2Etapas({super.key, required this.atual, this.mov = Movimento.parado});

  static const nomes = ['Cardápio', 'Sacola', 'Identificação', 'Pagamento'];
  final int atual;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final alto = context.dz(8);
    return Row(
      key: ValueKey('etapas-$atual'),
      children: [
        for (var i = 0; i < nomes.length; i++) ...[
          if (i > 0) SizedBox(width: context.dz(14)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(alto / 2),
                child: SizedBox(
                  height: alto,
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: _t.line),
                    if (i < atual)
                      ColoredBox(color: _t.accent)
                    else if (i == atual)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: mov.anima ? 0 : 1, end: 1),
                        duration: mov.anima ? mov.d(800) : Duration.zero,
                        curve: brasa2CurvaEntrada,
                        builder: (_, v, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: ColoredBox(color: _t.accent),
                        ),
                      ),
                  ]),
                ),
              ),
              SizedBox(height: context.dz(10)),
              Row(children: [
                if (i < atual) ...[
                  IconeBrasa(BrasaIcone.check, tamanho: context.dz(22), cor: _t.accent, traco: 3),
                  SizedBox(width: context.dz(6)),
                ],
                Flexible(
                  child: Text(
                    i < atual ? nomes[i] : '${i + 1}. ${nomes[i]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: brasaTexto(
                      context,
                      22,
                      peso: i == atual ? FontWeight.w800 : FontWeight.w600,
                      cor: i < atual ? _t.accent : (i == atual ? _t.text : _t.muted),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Brilho quente atrás das fotos (docs/templates/01 §3): o degradê radial laranja sobre o
/// marrom escuro. Duas camadas — num `BoxDecoration` a cor some sob o degradê.
class Brasa2BrilhoQuente extends StatelessWidget {
  const Brasa2BrilhoQuente({super.key, this.fundo = brasa2FundoBrilho, this.brilho = brasa2Brilho});
  final Color fundo;
  final Gradient brilho;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: fundo),
        child: DecoratedBox(decoration: BoxDecoration(gradient: brilho), child: const SizedBox.expand()),
      );
}

/// Kicker/eyebrow: Manrope 800 26, CAIXA ALTA, espaçado, no acento.
class Brasa2Kicker extends StatelessWidget {
  const Brasa2Kicker(this.texto, {super.key, this.icone, this.espacoEm = .12, this.tamanho = 26});
  final String texto;
  final BrasaIcone? icone;
  final double espacoEm;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[
          IconeBrasa(icone!, tamanho: context.dz(tamanho * 1.2), cor: _t.accent, traco: 2),
          SizedBox(width: context.dz(12)),
        ],
        Flexible(
          child: Text(texto.toUpperCase(),
              style: brasaTexto(context, tamanho, peso: FontWeight.w800, cor: _t.accent, espacoEm: espacoEm)),
        ),
      ]);
}

/// Círculo de 124 com o ícone no acento (CPF, nome).
class Brasa2IconeRedondo extends StatelessWidget {
  const Brasa2IconeRedondo(this.icone, {super.key});
  final BrasaIcone icone;

  @override
  Widget build(BuildContext context) => Container(
        width: context.dz(124),
        height: context.dz(124),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _t.surface2, shape: BoxShape.circle),
        child: IconeBrasa(icone, tamanho: context.dz(64), cor: _t.accent, traco: 1.8),
      );
}

/// Rodapé das telas internas: borda superior `line`, padding 22/48/48 (`.foot`).
class Brasa2Rodape extends StatelessWidget {
  const Brasa2Rodape({super.key, required this.children, this.semBorda = false});
  final List<Widget> children;
  final bool semBorda;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
        decoration: BoxDecoration(
          border: semBorda ? null : Border(top: BorderSide(color: _t.line, width: context.dz(2))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: context.dz(18)),
            children[i],
          ],
        ]),
      );
}

/// Corpo rolável que ocupa ao menos a altura disponível — assim um item pode ir para o pé
/// com `Spacer` (o teclado, o resumo) e, em tela baixa, tudo rola em vez de estourar.
class Brasa2CorpoRolavel extends StatelessWidget {
  const Brasa2CorpoRolavel({super.key, required this.children, this.padding, this.centro = false, this.espaco = 26});
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool centro;
  final double espaco;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30));
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (c.maxHeight - pad.vertical).clamp(0, double.infinity)),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: centro ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0 && children[i] is! Spacer) SizedBox(height: context.dz(espaco)),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vazio no visual do template (carregando, sem cardápio, sem conexão).
class Brasa2Estado extends StatelessWidget {
  const Brasa2Estado({
    super.key,
    required this.titulo,
    this.detalhe,
    this.icone = BrasaIcone.chama,
    this.carregando = false,
    this.acao,
  });

  final String titulo;
  final String? detalhe;
  final BrasaIcone icone;
  final bool carregando;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.dz(56)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (carregando)
              SizedBox(
                width: context.dz(90),
                height: context.dz(90),
                child: CircularProgressIndicator(color: _t.accent, strokeWidth: context.dz(7)),
              )
            else
              IconeBrasa(icone, tamanho: context.dz(96), cor: _t.accent, traco: 1.6),
            SizedBox(height: context.dz(30)),
            Text(titulo, textAlign: TextAlign.center, style: brasaTitulo(context, 56)),
            if (detalhe != null) ...[
              SizedBox(height: context.dz(14)),
              Text(detalhe!, textAlign: TextAlign.center, style: brasaTexto(context, 28, cor: _t.muted, altura: 1.4)),
            ],
            if (acao != null) ...[SizedBox(height: context.dz(36)), acao!],
          ]),
        ),
      );
}

/// Aviso de segurança da confirmação (sem cupom, sem nota, pague no caixa): fundo `hi`,
/// borda no acento, texto forte — nunca some por causa do template (ERR-022/V20).
class Brasa2Aviso extends StatelessWidget {
  const Brasa2Aviso({super.key, required this.titulo, this.detalhe, this.icone});
  final String titulo;
  final String? detalhe;
  final BrasaIcone? icone;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(22)),
        decoration: BoxDecoration(
          color: _t.hi,
          borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
          border: Border.all(color: _t.accent, width: context.dz(3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[
            IconeBrasa(icone!, tamanho: context.dz(52), cor: _t.accent, traco: 2),
            SizedBox(height: context.dz(10)),
          ],
          Text(titulo,
              textAlign: TextAlign.center,
              style: brasaTexto(context, detalhe == null ? 28 : 32, peso: FontWeight.w800, cor: _t.accent, altura: 1.3)),
          if (detalhe != null) ...[
            SizedBox(height: context.dz(6)),
            Text(detalhe!,
                textAlign: TextAlign.center, style: brasaTexto(context, 26, cor: _t.text, altura: 1.35)),
          ],
        ]),
      );
}
