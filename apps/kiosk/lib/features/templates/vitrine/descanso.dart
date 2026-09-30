import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Um story do descanso: foto + legenda (kicker, título e preço).
class _Slide {
  const _Slide({this.url, this.kicker, this.titulo, this.preco});
  final String? url;
  final String? kicker;
  final String? titulo;
  final String? preco;
}

/// Descanso do Vitrine (docs/templates/02 §6.1): stories em tela cheia com barras de
/// progresso no topo, crossfade + Ken Burns na troca, legenda que sobe e o painel de
/// vidro com "Comer aqui" / "Para levar". Os portões e o canto admin são da
/// `DescansoScreen`, por cima disto.
class VitrineDescanso extends StatefulWidget {
  const VitrineDescanso({super.key, required this.p});
  final DescansoProps p;

  /// Até 6 stories: as mídias da loja; sem mídias, os produtos com selo e foto (sem
  /// foto nenhuma, os com selo mesmo assim — a arte vira disco + recorte/ícone).
  static List<_Slide> _slides(DescansoProps p) {
    if (p.midias.isNotEmpty) {
      return [
        for (final m in p.midias.take(6))
          _Slide(url: m.url, kicker: m.kicker, titulo: m.titulo, preco: m.subtitulo),
      ];
    }
    final comFoto = [
      for (final d in p.destaques)
        if ((d.imagemUrl ?? '').trim().isNotEmpty) d
    ];
    final fonte = comFoto.isNotEmpty ? comFoto : p.destaques;
    return [
      for (final d in fonte.take(6))
        _Slide(
          url: d.imagemUrl,
          kicker: d.selo,
          titulo: d.nome,
          preco: formatCentavos(d.precoCentavos),
        ),
    ];
  }

  @override
  State<VitrineDescanso> createState() => _VitrineDescansoState();
}

class _VitrineDescansoState extends State<VitrineDescanso> with TickerProviderStateMixin {
  late final AnimationController _progresso;
  late final AnimationController _pulso;
  Timer? _troca;
  int _atual = 0;
  int _n = 0;

  Movimento get _mov => widget.p.mov;

  @override
  void initState() {
    super.initState();
    _progresso = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.p.intervaloSeg.clamp(2, 60)),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _proximo();
      });
    _pulso = AnimationController(vsync: this, duration: _mov.d(1800));
    _n = VitrineDescanso._slides(widget.p).length;
    _configurar();
  }

  @override
  void didUpdateWidget(covariant VitrineDescanso old) {
    super.didUpdateWidget(old);
    final n = VitrineDescanso._slides(widget.p).length;
    final mudou = n != _n ||
        old.p.intervaloSeg != widget.p.intervaloSeg ||
        old.p.mov.anima != widget.p.mov.anima ||
        old.p.bloqueado != widget.p.bloqueado;
    if (mudou) {
      _n = n;
      if (_atual >= n) _atual = 0;
      _progresso.duration = Duration(seconds: widget.p.intervaloSeg.clamp(2, 60));
      _configurar();
    }
  }

  /// Liga o relógio dos stories e o pulso da chamada conforme o movimento permitido:
  /// - com animação: a barra do story atual enche em `intervaloSeg` e puxa o próximo;
  /// - `off`: barras paradas e a troca por um `Timer` (sem quadro nenhum no meio);
  /// - bloqueado: o pulso para (os portões da tela ficam por cima).
  void _configurar() {
    _troca?.cancel();
    _troca = null;
    _progresso.stop();
    if (_n > 1) {
      if (_mov.anima) {
        _progresso.forward(from: 0);
      } else {
        _troca = Timer.periodic(Duration(seconds: widget.p.intervaloSeg.clamp(2, 60)), (_) {
          if (mounted) setState(() => _atual = (_atual + 1) % _n);
        });
      }
    }
    if (_mov.anima && !widget.p.bloqueado) {
      if (!_pulso.isAnimating) _pulso.repeat();
    } else {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  void _proximo() {
    if (!mounted || _n < 2) return;
    setState(() => _atual = (_atual + 1) % _n);
    _progresso.forward(from: 0);
  }

  @override
  void dispose() {
    _troca?.cancel();
    _progresso.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final slides = VitrineDescanso._slides(p);
    final atual = slides.isEmpty ? 0 : _atual % slides.length;
    final slide = slides.isEmpty ? const _Slide() : slides[atual];
    final cheio = vitrineMovimentoCheio(_mov);

    return ColoredBox(
      color: const Color(0xFF000000),
      child: LayoutBuilder(builder: (context, c) {
        // Tela baixa (harness 800×600, totem em paisagem): a legenda encolhe junto.
        final hDesenho = c.maxHeight / context.k;
        final fv = (hDesenho / 1920).clamp(.45, 1.0);
        return Stack(fit: StackFit.expand, children: [
          // Fotos: crossfade de 1,2 s; a nova entra com Ken Burns de 9 s.
          AnimatedSwitcher(
            duration: _mov.anima ? _mov.d(1200) : Duration.zero,
            layoutBuilder: (cur, ant) => Stack(fit: StackFit.expand, children: [...ant, if (cur != null) cur]),
            child: _FotoSlide(key: ValueKey('story-$atual'), url: slide.url, mov: _mov, kenBurns: cheio),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
                  stops: [0, .20, .45, .78],
                ),
              ),
            ),
          ),
          if (slides.length > 1)
            Positioned(
              top: context.dz(28),
              left: context.dz(56),
              right: context.dz(56),
              child: RepaintBoundary(child: _Barras(n: slides.length, atual: atual, progresso: _progresso, mov: _mov)),
            ),
          Positioned(
            top: context.dz(74),
            left: context.dz(56),
            right: context.dz(56),
            child: Row(children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LogoVitrineMarca(nomeLoja: p.nomeLoja, logoUrl: p.logoUrl, tamanho: 58 * 1.1),
                ),
              ),
              if ((p.precoIsca ?? '').trim().isNotEmpty) ...[
                SizedBox(width: context.dz(20)),
                _PrecoIsca(texto: p.precoIsca!.trim()),
              ],
            ]),
          ),
          // Legenda: sai a anterior e entra a nova subindo 40 px (700 ms, atraso 250 ms).
          Positioned(
            left: context.dz(56),
            right: context.dz(56),
            bottom: context.dz(356 + 204 * fv),
            child: AnimatedSwitcher(
              duration: _mov.anima ? _mov.d(950) : Duration.zero,
              layoutBuilder: (cur, ant) => Stack(
                alignment: Alignment.bottomLeft,
                children: [...ant, if (cur != null) cur],
              ),
              transitionBuilder: (child, anim) {
                final curva = CurvedAnimation(parent: anim, curve: const Interval(250 / 950, 1, curve: Curves.ease));
                return FadeTransition(
                  opacity: curva,
                  child: AnimatedBuilder(
                    animation: curva,
                    builder: (_, filho) => Transform.translate(
                      offset: Offset(0, context.dz(40) * (1 - curva.value)),
                      child: filho,
                    ),
                    child: child,
                  ),
                );
              },
              child: _Legenda(key: ValueKey('legenda-$atual'), slide: slide, fv: fv, mov: _mov),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PainelInicio(p: p, pulso: _pulso),
          ),
        ]);
      }),
    );
  }
}

/// Barras de progresso dos stories (§8): anteriores cheias, a atual enchendo.
class _Barras extends StatelessWidget {
  const _Barras({required this.n, required this.atual, required this.progresso, required this.mov});
  final int n;
  final int atual;
  final Animation<double> progresso;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    return Row(key: const ValueKey('stories-barras'), children: [
      for (var i = 0; i < n; i++) ...[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.dz(4)),
            child: Container(
              height: context.dz(7),
              color: const Color(0x4DFFFFFF),
              alignment: Alignment.centerLeft,
              child: i < atual
                  ? const SizedBox.expand(child: ColoredBox(color: Color(0xFFFFFFFF)))
                  : i == atual
                      ? AnimatedBuilder(
                          animation: progresso,
                          // Sem animação: barra parada (cheia), a troca vem do Timer.
                          builder: (_, __) => FractionallySizedBox(
                            widthFactor: mov.anima ? progresso.value : 1,
                            heightFactor: 1,
                            child: const ColoredBox(color: Color(0xFFFFFFFF)),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
        if (i < n - 1) SizedBox(width: context.dz(10)),
      ],
    ]);
  }
}

/// A foto do story: cobre a tela; com movimento cheio, Ken Burns (1,06 → 1,2 em 9 s).
/// Sem foto, a arte do template (disco `accent` + recorte ou ícone).
class _FotoSlide extends StatefulWidget {
  const _FotoSlide({super.key, required this.url, required this.mov, required this.kenBurns});
  final String? url;
  final Movimento mov;
  final bool kenBurns;

  @override
  State<_FotoSlide> createState() => _FotoSlideState();
}

class _FotoSlideState extends State<_FotoSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _kb;

  @override
  void initState() {
    super.initState();
    _kb = AnimationController(vsync: this, duration: widget.mov.d(9000));
    if (widget.kenBurns) _kb.forward();
  }

  @override
  void dispose() {
    _kb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url?.trim() ?? '';
    if (url.isEmpty || ProdutoArte.ehRecorte(url)) {
      return ArteSemFotoVitrine(url: url.isEmpty ? null : url, mov: widget.mov);
    }
    final foto = RepaintBoundary(
      child: ProdutoArte(url: url, tokens: vitrineTokens, fundo: const Color(0xFF000000)),
    );
    if (!widget.kenBurns) return Transform.scale(scale: 1.06, child: foto);
    return AnimatedBuilder(
      animation: _kb,
      builder: (_, child) {
        final v = Curves.easeOut.transform(_kb.value);
        return Transform.translate(
          offset: Offset(-context.dz(22) * v, -context.dz(38) * v),
          child: Transform.scale(scale: 1.06 + .14 * v, child: child),
        );
      },
      child: foto,
    );
  }
}

/// Legenda do story: kicker em pílula `accent2`, título 170 e preço em vidro.
class _Legenda extends StatelessWidget {
  const _Legenda({super.key, required this.slide, required this.fv, required this.mov});
  final _Slide slide;

  /// Fator da tela baixa (1 no totem em retrato).
  final double fv;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final kicker = slide.kicker?.trim() ?? '';
    final titulo = slide.titulo?.trim() ?? '';
    final preco = slide.preco?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.dz(20), vertical: context.dz(10)),
            decoration: BoxDecoration(color: t.accent2, borderRadius: BorderRadius.circular(context.dz(30))),
            child: Text(kicker.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.vKicker(26 * math.max(fv, .7), cor: t.onAccent2, espacoEm: .08)),
          ),
          SizedBox(height: context.dz(22)),
        ],
        if (titulo.isNotEmpty) ...[
          TituloVitrine(titulo,
              key: const ValueKey('story-titulo'), maxLines: 3, estilo: context.vDisplay(170 * fv, altura: .86)),
          SizedBox(height: context.dz(22)),
        ],
        if (preco.isNotEmpty)
          VidroVitrine(
            mov: mov,
            raio: BorderRadius.circular(context.dz(40)),
            cor: const Color(0x24FFFFFF),
            borda: const Color(0x40FFFFFF),
            sigma: 16,
            padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(10)),
            child: Text(preco, maxLines: 1, style: context.vDisplay(60 * math.max(fv, .7), espacoEm: 0)),
          ),
      ],
    );
  }
}

/// Selo do preço-isca (`ap.precoIsca`) no canto superior direito.
class _PrecoIsca extends StatelessWidget {
  const _PrecoIsca({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      key: const ValueKey('preco-isca'),
      height: context.dz(64),
      padding: EdgeInsets.symmetric(horizontal: context.dz(24)),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.accent2, borderRadius: BorderRadius.circular(context.dz(32))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sell_rounded, size: context.dz(28), color: t.onAccent2),
        SizedBox(width: context.dz(10)),
        Flexible(
          child: Text(texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.vTexto(24, peso: FontWeight.w800, cor: t.onAccent2)),
        ),
      ]),
    );
  }
}

/// Painel inferior de vidro (raio superior 56, padding 40/56/72): chamada com o toque
/// pulsando e os botões xl "Comer aqui" (primário) e "Para levar" (vidro).
class _PainelInicio extends StatelessWidget {
  const _PainelInicio({required this.p, required this.pulso});
  final DescansoProps p;
  final AnimationController pulso;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final raio = BorderRadius.vertical(top: Radius.circular(context.dz(56)));
    void iniciar(String consumo) {
      if (!p.bloqueado) p.onIniciar(consumo);
    }

    return VidroVitrine(
      mov: p.mov,
      raio: raio,
      cor: const Color(0x6B0A0A0A),
      borda: const Color(0x24FFFFFF),
      sigma: 26,
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(40), context.dz(56), context.dz(72)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: context.dz(64),
            height: context.dz(64),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              if (p.mov.anima && !p.bloqueado)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: pulso,
                    builder: (_, __) {
                      final v = pulso.value;
                      return Transform.scale(
                        scale: .7 + 1.1 * v,
                        child: Container(
                          width: context.dz(80),
                          height: context.dz(80),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: t.accent.withAlpha((230 * (1 - v)).round().clamp(0, 255)),
                              width: context.dz(3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Icon(Icons.touch_app_outlined, size: context.dz(44), color: t.text),
            ]),
          ),
          SizedBox(width: context.dz(16)),
          Flexible(
            child: Text(p.chamada,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.vTexto(32, peso: FontWeight.w800)),
          ),
        ]),
        SizedBox(height: context.dz(30)),
        Row(children: [
          Expanded(
            child: BotaoVitrine(
              key: const ValueKey('descanso-local'),
              rotulo: 'Comer aqui',
              icone: Icons.restaurant_rounded,
              altura: 170,
              fonte: 40,
              padH: 30,
              mov: p.mov,
              onTap: p.bloqueado ? null : () => iniciar('local'),
            ),
          ),
          SizedBox(width: context.dz(22)),
          Expanded(
            child: BotaoVitrine(
              key: const ValueKey('descanso-viagem'),
              rotulo: 'Para levar',
              icone: Icons.shopping_bag_outlined,
              estilo: EstiloBotaoVitrine.vidro,
              blur: false, // já está sobre o vidro do painel
              altura: 170,
              fonte: 40,
              padH: 30,
              mov: p.mov,
              onTap: p.bloqueado ? null : () => iniciar('viagem'),
            ),
          ),
        ]),
      ]),
    );
  }
}
