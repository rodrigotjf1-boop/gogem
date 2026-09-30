import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/aparencia.dart';
import '../../catalogo/produto_imagem.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/brasas.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Uma frase do letreiro de ofertas: "**Nome** R$ preço", ou o preço-isca da loja.
class _Frase {
  const _Frase({required this.forte, this.fraco});
  final String forte;
  final String? fraco;
}

/// Descanso do **Brasa 2.0** (docs/templates/01 §6.1): a foto em tela cheia com zoom lento,
/// brasas subindo, o título em serifa e os botões Comer aqui / Para levar. Os portões
/// (papel/offline) e o canto do admin são desenhados pela `DescansoScreen` por cima.
class Brasa2Descanso extends StatefulWidget {
  const Brasa2Descanso(this.p, {super.key});
  final DescansoProps p;

  @override
  State<Brasa2Descanso> createState() => _Brasa2DescansoState();
}

class _Brasa2DescansoState extends State<Brasa2Descanso> with TickerProviderStateMixin {
  late final AnimationController _kenBurns;
  late final AnimationController _anel;
  Timer? _trocaMidia;
  Timer? _trocaFrase;
  int _midia = 0;
  int _frase = 0;

  DescansoProps get p => widget.p;

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(vsync: this, duration: p.mov.d(20000));
    _anel = AnimationController(vsync: this, duration: p.mov.d(1800));
    if (p.mov.anima) _kenBurns.repeat(reverse: true);
    _ajustarAnel();
    // Várias mídias: trocam a cada `intervaloSeg` (com animação desligada, troca seca —
    // como o carrossel padrão da loja).
    if (p.midias.length > 1) {
      _trocaMidia = Timer.periodic(Duration(seconds: p.intervaloSeg < 2 ? 2 : p.intervaloSeg), (_) {
        if (mounted) setState(() => _midia = (_midia + 1) % p.midias.length);
      });
    }
    // Letreiro de ofertas: 3,2 s por frase; sem animação, fica só a primeira.
    if (p.mov.anima && _frases.length > 1) {
      _trocaFrase = Timer.periodic(p.mov.d(3200), (_) {
        if (mounted) setState(() => _frase = (_frase + 1) % _frases.length);
      });
    }
  }

  void _ajustarAnel() {
    if (p.mov.anima && !p.bloqueado) {
      if (!_anel.isAnimating) _anel.repeat();
    } else {
      _anel.stop();
    }
  }

  @override
  void didUpdateWidget(covariant Brasa2Descanso old) {
    super.didUpdateWidget(old);
    if (old.p.bloqueado != p.bloqueado) _ajustarAnel();
  }

  @override
  void dispose() {
    _trocaMidia?.cancel();
    _trocaFrase?.cancel();
    _kenBurns.dispose();
    _anel.dispose();
    super.dispose();
  }

  List<_Frase> get _frases => [
        if ((p.precoIsca ?? '').trim().isNotEmpty) _Frase(forte: p.precoIsca!.trim()),
        for (final d in p.destaques) _Frase(forte: d.nome, fraco: formatCentavos(d.precoCentavos)),
      ].take(3).toList();

  DescansoMidia? get _midiaAtual => p.midias.isEmpty ? null : p.midias[_midia % p.midias.length];

  /// Foto do fundo: a mídia da vez ou, sem mídias, a do 1º destaque (o mais vendido).
  String? get _fotoAtual {
    final m = _midiaAtual;
    if (m != null) return m.url;
    for (final d in p.destaques) {
      if ((d.imagemUrl ?? '').isNotEmpty) return d.imagemUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final foto = _fotoAtual;
    return Brasa2Texto(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: brasa2FundoDescanso),
        AnimatedSwitcher(
          duration: p.mov.anima ? p.mov.d(1200) : Duration.zero,
          child: KeyedSubtree(
            key: ValueKey(foto ?? 'arte-padrao'),
            child: foto == null ? const _ArtePadrao() : _FotoKenBurns(url: foto, kb: _kenBurns, anima: p.mov.anima),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xD90C0907),
                Color(0x000C0907),
                Color(0x000C0907),
                Color(0xE00C0907),
                Color(0xFF0C0907),
              ],
              stops: [0, .22, .42, .66, .84],
            ),
          ),
        ),
        if (p.mov.particulas && p.mov.anima) const Positioned.fill(child: Brasas()),
        Positioned(
          top: context.dz(56),
          left: context.dz(56),
          right: context.dz(56),
          child: Row(children: [
            Flexible(child: Brasa2Marca(nomeLoja: p.nomeLoja, logoUrl: p.logoUrl, daLoja: false)),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: context.dz(56 + 96),
          child: Align(
            alignment: Alignment.bottomCenter,
            // Tela baixa (paisagem / harness 800×600): o bloco inteiro encolhe junto, em
            // vez de o título subir por baixo do logo.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: tela.width,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _copia(context),
                  SizedBox(height: context.dz(114)),
                  _rodape(context),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _copia(BuildContext context) {
    final m = _midiaAtual;
    // Legenda da mídia (kicker/título/subtítulo) quando a loja escreveu; senão, a do template.
    final leg = (m != null && m.temLegenda) ? m : null;
    String? limpo(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final kicker = limpo(leg?.kicker) ?? 'Grelhado na brasa · feito na hora';
    final String? linha1;
    final String? linha2;
    if (limpo(leg?.titulo) != null || limpo(leg?.subtitulo) != null) {
      linha1 = limpo(leg?.titulo);
      linha2 = limpo(leg?.subtitulo);
    } else {
      linha1 = 'Fogo alto.';
      linha2 = 'Sabor que marca.';
    }
    // O quadro de tipografia fala em 150/0,94, mas no protótipo a regra `.scr h1` (92, altura 1)
    // vem depois de `.att-brasa h1` e vence — é o que o PNG e o protótipo mostram: cada frase
    // numa linha. Seguimos o desenho.
    final h1 = brasaTitulo(context, 92);
    final frases = _frases;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dz(56)),
      child: AnimatedSwitcher(
        duration: p.mov.anima ? p.mov.d(600) : Duration.zero,
        // Alinhado à esquerda e ao pé (o padrão do AnimatedSwitcher centraliza).
        layoutBuilder: (atual, anteriores) => Stack(
          alignment: Alignment.bottomLeft,
          children: [...anteriores, if (atual != null) atual],
        ),
        child: Column(
          key: ValueKey('legenda-${m?.url ?? ''}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Brasa2Kicker(kicker, icone: BrasaIcone.chama, espacoEm: .2),
            SizedBox(height: context.dz(26)),
            Text.rich(
              key: const ValueKey('descanso-titulo'),
              TextSpan(children: [
                if (linha1 != null) TextSpan(text: linha1),
                if (linha1 != null && linha2 != null) const TextSpan(text: '\n'),
                if (linha2 != null)
                  TextSpan(text: linha2, style: h1.copyWith(color: _t.accent, fontStyle: FontStyle.italic)),
              ]),
              style: h1,
            ),
            if (frases.isNotEmpty) ...[
              SizedBox(height: context.dz(26)),
              SizedBox(
                height: context.dz(64),
                child: AnimatedSwitcher(
                  duration: p.mov.anima ? p.mov.d(600) : Duration.zero,
                  layoutBuilder: (atual, anteriores) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...anteriores, if (atual != null) atual],
                  ),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, .375), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: _linhaFrase(context, frases[_frase % frases.length], _frase),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linhaFrase(BuildContext context, _Frase f, int i) => Text.rich(
        key: ValueKey('frase-$i'),
        TextSpan(children: [
          TextSpan(text: f.forte, style: brasaTexto(context, 34, peso: FontWeight.w800, cor: _t.text)),
          if (f.fraco != null)
            TextSpan(text: '  ${f.fraco}', style: brasaTexto(context, 34, peso: FontWeight.w600, cor: _t.muted)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  Widget _rodape(BuildContext context) {
    final bloq = p.bloqueado;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(40), context.dz(56), context.dz(72)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: context.dz(80),
            height: context.dz(80),
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              _AnelDeToque(anel: _anel, pulsando: p.mov.anima && !bloq),
              IconeBrasa(BrasaIcone.toque, tamanho: context.dz(44), cor: _t.text, traco: 2),
            ]),
          ),
          SizedBox(width: context.dz(4)),
          Flexible(
            child: Text(p.chamada,
                key: const ValueKey('descanso-chamada'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: brasaTexto(context, 32, peso: FontWeight.w700, cor: _t.text)),
          ),
        ]),
        SizedBox(height: context.dz(30)),
        Row(children: [
          Expanded(
            child: Brasa2Botao(
              key: const ValueKey('descanso-local'),
              rotulo: 'Comer aqui',
              icone: BrasaIcone.comerAqui,
              altura: 170,
              fonte: 40,
              tamanhoIcone: 44,
              mov: p.mov,
              onTap: bloq ? null : () => p.onIniciar('local'),
            ),
          ),
          SizedBox(width: context.dz(22)),
          Expanded(
            child: Brasa2Botao(
              key: const ValueKey('descanso-viagem'),
              rotulo: 'Para levar',
              icone: BrasaIcone.paraLevar,
              variante: Brasa2Variante.fantasma,
              altura: 170,
              fonte: 40,
              tamanhoIcone: 44,
              mov: p.mov,
              onTap: bloq ? null : () => p.onIniciar('viagem'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Foto do descanso em cover com Ken Burns (escala 1,06 → 1,2 e −2%, 20 s ida e volta).
/// Sem animação: quadro fixo em escala 1,1.
class _FotoKenBurns extends StatelessWidget {
  const _FotoKenBurns({required this.url, required this.kb, required this.anima});
  final String url;
  final AnimationController kb;
  final bool anima;

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final foto = RepaintBoundary(
      child: ProdutoImagem(url: url, memCacheWidth: (tela.width * dpr * 1.2).round().clamp(64, 2200)),
    );
    if (!anima) return Transform.scale(scale: 1.1, child: foto);
    return AnimatedBuilder(
      animation: kb,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(kb.value);
        return Transform.scale(
          scale: 1.06 + .14 * v,
          child: Transform.translate(offset: Offset(-.02 * tela.width * v, -.02 * tela.height * v), child: child),
        );
      },
      child: foto,
    );
  }
}

/// Arte padrão quando a loja não tem mídia nem foto de destaque: fogo em degradê.
class _ArtePadrao extends StatelessWidget {
  const _ArtePadrao();

  @override
  Widget build(BuildContext context) => const Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.45, -.1),
              radius: 1.05,
              colors: [Color(0xFF7A3413), Color(0xFF3A1A0B), brasa2FundoDescanso],
              stops: [0, .45, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.5, .35),
              radius: .8,
              colors: [Color(0x66F4B63F), Color(0x00F4B63F)],
            ),
          ),
        ),
      ]);
}

/// Anel `accent` que pulsa em volta da mão (escala 0,7 → 1,8, opacidade 0,9 → 0, 1,8 s).
class _AnelDeToque extends StatelessWidget {
  const _AnelDeToque({required this.anel, required this.pulsando});
  final AnimationController anel;
  final bool pulsando;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(80);
    final circulo = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _t.accent, width: context.dz(3)),
      ),
    );
    if (!pulsando) return Opacity(opacity: .6, child: circulo);
    return AnimatedBuilder(
      animation: anel,
      builder: (_, child) {
        final v = Curves.easeOut.transform(anel.value);
        return Opacity(
          opacity: (.9 * (1 - v)).clamp(0.0, 1.0),
          child: Transform.scale(scale: .7 + 1.1 * v, child: child),
        );
      },
      child: circulo,
    );
  }
}
