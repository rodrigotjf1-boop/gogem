import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Um item do palco giratório: foto (recorte ou comum), legenda e a cor do disco.
class _ItemPalco {
  const _ItemPalco({required this.cor, this.url, this.nome, this.linha2});
  final Color cor;
  final String? url;
  final String? nome;
  final String? linha2;
}

/// Descanso do Estúdio (docs/03 §6.1): fundo claro com um círculo no canto, o H1
/// "Monte. / Toque. / Saboreie." e o PALCO — um carrossel de destaques que troca a cor do
/// disco a cada 3 s, com o produto entrando girando e flutuando sobre uma sombra que
/// "respira". Os portões e o canto do admin continuam na `DescansoScreen`, por cima.
class EstudioDescanso extends StatefulWidget {
  const EstudioDescanso({super.key, required this.p});
  final DescansoProps p;

  @override
  State<EstudioDescanso> createState() => _EstudioDescansoState();
}

class _EstudioDescansoState extends State<EstudioDescanso> with SingleTickerProviderStateMixin {
  late final AnimationController _troca;
  Timer? _timer;
  int _atual = 0;
  int? _anterior;

  DescansoProps get p => widget.p;

  /// Fonte dos itens: as mídias da loja; sem elas, os produtos com selo (com foto
  /// primeiro); sem nenhum, o palco fica só com o disco.
  List<_ItemPalco> get _itens {
    if (p.midias.isNotEmpty) {
      return [
        for (var i = 0; i < p.midias.length; i++)
          _ItemPalco(cor: corDisco(i), url: p.midias[i].url, nome: p.midias[i].kicker),
      ];
    }
    final comFoto = [
      for (final d in p.destaques)
        if ((d.imagemUrl ?? '').trim().isNotEmpty) d
    ];
    final fonte = (comFoto.isNotEmpty ? comFoto : p.destaques).take(4).toList();
    return [
      for (var i = 0; i < fonte.length; i++)
        _ItemPalco(
          cor: corDisco(i),
          url: fonte[i].imagemUrl,
          nome: fonte[i].nome,
          linha2: formatCentavos(fonte[i].precoCentavos),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _troca = AnimationController(vsync: this, duration: p.mov.d(1100))..value = 1;
    _agendar();
  }

  @override
  void didUpdateWidget(covariant EstudioDescanso old) {
    super.didUpdateWidget(old);
    final n = _itens.length;
    if (_atual >= n) {
      _atual = 0;
      _anterior = null;
    }
    if (old.p.mov.anima != p.mov.anima ||
        old.p.bloqueado != p.bloqueado ||
        old.p.intervaloSeg != p.intervaloSeg ||
        old.p.midias.length != p.midias.length ||
        old.p.destaques.length != p.destaques.length) {
      _agendar();
    }
  }

  /// Timer do carrossel: só com animação, mais de um item e fora do bloqueio.
  void _agendar() {
    _timer?.cancel();
    _timer = null;
    if (!p.mov.anima || p.bloqueado || _itens.length < 2) return;
    final seg = p.midias.isNotEmpty ? math.max(2, p.intervaloSeg) : 3;
    _timer = Timer.periodic(Duration(seconds: seg), (_) => _avancar());
  }

  void _avancar() {
    if (!mounted) return;
    final n = _itens.length;
    if (n < 2) return;
    setState(() {
      _anterior = _atual;
      _atual = (_atual + 1) % n;
    });
    _troca.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _troca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Theme(
      data: temaEstudio,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: _t.bg,
          // O descanso é uma composição fixa de 1080×1920: em tela mais baixa (paisagem,
          // harness 800×600) ela é reduzida por inteiro e centralizada, sem sobrepor nada.
          child: LayoutBuilder(builder: (context, c) {
            final s = math.min(c.maxWidth / 1080, c.maxHeight / 1920);
            final tam = Size(1080 * s, 1920 * s);
            return ClipRect(
              child: Center(
                child: SizedBox.fromSize(
                  size: tam,
                  child: MediaQuery(
                    data: mq.copyWith(size: tam),
                    child: Flutuacao(
                      ligada: movimentoCheio(p.mov) && !p.bloqueado,
                      child: _composicao(context),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _composicao(BuildContext context) {
    return Builder(builder: (context) {
      final itens = _itens;
      return Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: -context.dz(260),
          top: -context.dz(200),
          width: context.dz(760),
          height: context.dz(760),
          child: const DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: EstudioCores.circuloDescanso),
          ),
        ),
        Positioned(
          top: context.dz(56),
          left: context.dz(56),
          right: context.dz(56),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LogoEstudio(escala: 1.1, nomeLoja: p.nomeLoja, logoUrl: p.logoUrl),
          ),
        ),
        Positioned(
          top: context.dz(220),
          left: context.dz(64),
          right: context.dz(64),
          child: _Chamada(p: p),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: context.dz(820),
          height: context.dz(720),
          child: _Palco(itens: itens, atual: _atual, anterior: _anterior, troca: _troca, p: p),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _Rodape(p: p)),
      ]);
    });
  }
}

/// H1 + subtítulo (+ preço-isca). O título e o subtítulo da 1ª mídia, se houver,
/// substituem o texto padrão.
class _Chamada extends StatelessWidget {
  const _Chamada({required this.p});
  final DescansoProps p;

  @override
  Widget build(BuildContext context) {
    final m = p.midias.isEmpty ? null : p.midias.first;
    final titulo = m?.titulo?.trim() ?? '';
    final sub = m?.subtitulo?.trim() ?? '';
    final h1 = _t
        .display(context.dz(132), altura: .93)
        .copyWith(letterSpacing: context.dz(-132 * .05));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (titulo.isNotEmpty)
        Text(titulo, key: const ValueKey('descanso-titulo'), maxLines: 3, overflow: TextOverflow.ellipsis, style: h1)
      else
        Text.rich(
          key: const ValueKey('descanso-titulo'),
          TextSpan(style: h1, children: [
            const TextSpan(text: 'Monte.\nToque.\n'),
            TextSpan(text: 'Saboreie.', style: TextStyle(color: _t.accent)),
          ]),
        ),
      SizedBox(height: context.dz(22)),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.dz(640)),
        child: Text(
          sub.isNotEmpty ? sub : 'Burgers artesanais montados na hora, do seu jeito.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _t.texto(context.dz(34), peso: FontWeight.w400, cor: _t.muted, altura: 1.3),
        ),
      ),
      if ((p.precoIsca ?? '').trim().isNotEmpty) ...[
        SizedBox(height: context.dz(26)),
        Container(
          key: const ValueKey('preco-isca'),
          height: context.dz(64),
          padding: EdgeInsets.symmetric(horizontal: context.dz(26)),
          decoration: BoxDecoration(color: _t.accent2, borderRadius: BorderRadius.circular(context.dz(32))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_offer_rounded, size: context.dz(30), color: _t.onAccent2),
            SizedBox(width: context.dz(12)),
            Text(p.precoIsca!.trim(),
                style: _t.texto(context.dz(28), peso: FontWeight.w800, cor: _t.onAccent2)),
          ]),
        ),
      ],
    ]);
  }
}

/// O palco (top 820, altura 720): discos, produto, sombra, legenda e pontos.
class _Palco extends StatelessWidget {
  const _Palco({
    required this.itens,
    required this.atual,
    required this.anterior,
    required this.troca,
    required this.p,
  });

  final List<_ItemPalco> itens;
  final int atual;
  final int? anterior;
  final AnimationController troca;
  final DescansoProps p;

  @override
  Widget build(BuildContext context) {
    final mov = p.mov;
    final cheio = movimentoCheio(mov);
    // Intervalos da troca (em ms dos 1100 do controller): disco 0–1000, produto 120–1020,
    // legenda 300–900; quem sai volta pelo mesmo caminho, sem atraso.
    double faixa(double v, double de, double ate) => ((v * 1100 - de) / (ate - de)).clamp(0.0, 1.0);

    Widget disco(_ItemPalco it, bool entrando) => AnimatedBuilder(
          animation: troca,
          builder: (_, __) {
            final v = troca.value;
            final e = curvaEstudio.transform(faixa(v, 0, 1000));
            final o = faixa(v, 0, 800);
            final escala = !cheio ? 1.0 : (entrando ? .5 + .5 * e : 1 - .5 * e);
            return Opacity(
              opacity: entrando ? o : 1 - o,
              child: Transform.scale(
                scale: escala,
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: it.cor)),
              ),
            );
          },
        );

    Widget produto(_ItemPalco it, bool entrando) => AnimatedBuilder(
          animation: troca,
          builder: (_, child) {
            final v = troca.value;
            final e = entrando ? curvaEstudio.transform(faixa(v, 120, 1020)) : curvaEstudio.transform(faixa(v, 0, 900));
            final o = entrando ? faixa(v, 120, 820) : 1 - faixa(v, 0, 700);
            // Fora da posição: +160 px à direita, girado 12° e em 70%.
            final fora = entrando ? 1 - e : e;
            return Opacity(
              opacity: o,
              child: cheio
                  ? Transform.translate(
                      offset: Offset(context.dz(160) * fora, 0),
                      child: Transform.rotate(
                        angle: 12 * math.pi / 180 * fora,
                        child: Transform.scale(scale: 1 - .3 * fora, child: child),
                      ),
                    )
                  : child,
            );
          },
          child: _ArtePalco(item: it),
        );

    Widget legenda(_ItemPalco it, bool entrando) => AnimatedBuilder(
          animation: troca,
          builder: (_, child) {
            final v = troca.value;
            final o = entrando ? faixa(v, 300, 900) : 1 - faixa(v, 0, 600);
            return Opacity(
              opacity: o,
              child: Transform.translate(offset: Offset(0, context.dz(20) * (1 - o) * (cheio ? 1 : 0)), child: child),
            );
          },
          child: _Legenda(item: it),
        );

    if (itens.isEmpty) {
      return Stack(children: [
        Positioned(
          left: context.dz(250),
          top: context.dz(40),
          width: context.dz(580),
          height: context.dz(580),
          child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: _t.accent)),
        ),
      ]);
    }
    final ant = anterior != null && anterior! < itens.length && anterior != atual ? itens[anterior!] : null;
    final cur = itens[atual];
    return RepaintBoundary(
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: context.dz(250),
          top: context.dz(40),
          width: context.dz(580),
          height: context.dz(580),
          child: Stack(fit: StackFit.expand, children: [
            if (ant != null) disco(ant, false),
            disco(cur, true),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: context.dz(600),
          child: Stack(fit: StackFit.expand, children: [
            // Sombra elíptica no chão, que "respira" com a flutuação.
            Positioned(
              left: context.dz(330),
              width: context.dz(420),
              bottom: context.dz(10),
              height: context.dz(40),
              child: const Flutua(
                respira: true,
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: EstudioCores.sombraChao, shape: OvalBorder()),
                ),
              ),
            ),
            if (ant != null) produto(ant, false),
            produto(cur, true),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: context.dz(30),
          height: context.dz(100),
          child: Stack(fit: StackFit.expand, children: [
            if (ant != null) legenda(ant, false),
            legenda(cur, true),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -context.dz(10),
          height: context.dz(14),
          child: Row(
            key: const ValueKey('palco-pontos'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                if (i > 0) SizedBox(width: context.dz(12)),
                AnimatedContainer(
                  duration: duracao(p.mov, 400),
                  width: context.dz(i == atual ? 44 : 14),
                  height: context.dz(14),
                  decoration: BoxDecoration(
                    color: i == atual ? _t.text : _t.line2,
                    borderRadius: BorderRadius.circular(context.dz(7)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

/// O produto do palco: recorte de até 720×540 flutuando, ou a foto comum num círculo
/// com borda branca centrado no disco.
class _ArtePalco extends StatelessWidget {
  const _ArtePalco({required this.item});
  final _ItemPalco item;

  @override
  Widget build(BuildContext context) {
    final u = item.url?.trim() ?? '';
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (u.isEmpty) {
      return Align(
        alignment: const Alignment(0, .1),
        child: Icon(Icons.restaurant_menu_rounded, size: context.dz(170), color: const Color(0x8CFFFFFF)),
      );
    }
    if (ProdutoArte.ehRecorte(u)) {
      return Center(
        child: Flutua(
          child: SizedBox(
            width: context.dz(720),
            height: context.dz(540),
            child: ImagemEstudio(url: u, fit: BoxFit.contain, memCacheWidth: (context.dz(720) * dpr).round()),
          ),
        ),
      );
    }
    // O disco tem o centro 30 px abaixo do centro desta área (disco em top 40, 580).
    return Align(
      alignment: const Alignment(0, .1),
      child: Flutua(child: FotoCirculo(url: u, diametro: context.dz(500), borda: context.dz(12))),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.item});
  final _ItemPalco item;

  @override
  Widget build(BuildContext context) {
    final nome = item.nome?.trim() ?? '';
    final l2 = item.linha2?.trim() ?? '';
    if (nome.isEmpty && l2.isEmpty) return const SizedBox.shrink();
    // A caixa da legenda tem 100 de altura: com fonte maior, encolhe em vez de vazar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.dz(960)),
        child: _conteudo(context, nome, l2),
      ),
    );
  }

  Widget _conteudo(BuildContext context, String nome, String l2) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (nome.isNotEmpty)
        Text(nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _t.display(context.dz(46), altura: 1.15).copyWith(letterSpacing: context.dz(-.9))),
      if (l2.isNotEmpty) ...[
        SizedBox(height: context.dz(4)),
        Text(l2, style: _t.texto(context.dz(32), peso: FontWeight.w700, cor: _t.accent, altura: 1.2)),
      ],
    ]);
  }
}

/// "Toque para começar" e os botões Comer aqui / Para levar.
class _Rodape extends StatelessWidget {
  const _Rodape({required this.p});
  final DescansoProps p;

  @override
  Widget build(BuildContext context) {
    final livre = !p.bloqueado;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(40), context.dz(56), context.dz(72)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // A mão "pulsa" com a flutuação da tela (parada no bloqueio e sem animação).
          Flutua(respira: true, child: Icon(Icons.touch_app_outlined, size: context.dz(44), color: _t.text)),
          SizedBox(width: context.dz(16)),
          Flexible(
            child: Text(p.chamada,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t.texto(context.dz(32), peso: FontWeight.w700)),
          ),
        ]),
        SizedBox(height: context.dz(30)),
        Row(children: [
          Expanded(
            child: BotaoEstudio(
              chave: 'descanso-local',
              rotulo: 'Comer aqui',
              icone: Icons.restaurant_rounded,
              altura: 170,
              fonte: 40,
              onTap: livre ? () => p.onIniciar('local') : null,
            ),
          ),
          SizedBox(width: context.dz(22)),
          Expanded(
            child: BotaoEstudio(
              chave: 'descanso-viagem',
              rotulo: 'Para levar',
              icone: Icons.shopping_bag_outlined,
              tipo: TipoBotao.soft,
              altura: 170,
              fonte: 40,
              onTap: livre ? () => p.onIniciar('viagem') : null,
            ),
          ),
        ]),
      ]),
    );
  }
}
