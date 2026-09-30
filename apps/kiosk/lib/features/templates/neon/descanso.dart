import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/aparencia.dart';
import '../comum/produto_arte.dart';
import '../kiosk_template.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Descanso do Neon 2.0 (docs/templates/04-neon-2.md §6.1): faixas de texto gigante
/// correndo em sentidos opostos, scanlines, dois anéis de luz girando em volta do produto,
/// adesivo balançando e o letreiro "PEDE AÍ." cintilando.
///
/// A composição é desenhada numa tela de 1080×1920 e encaixada (contain) na tela real: em
/// paisagem ou no harness de teste ela fica inteira, sem sobrepor os botões. Os portões
/// (papel/offline) e o canto do admin continuam na `DescansoScreen`, por cima disto.
class NeonDescanso extends StatefulWidget {
  const NeonDescanso({super.key, required this.p});
  final DescansoProps p;

  @override
  State<NeonDescanso> createState() => _NeonDescansoState();
}

class _NeonDescansoState extends State<NeonDescanso> with TickerProviderStateMixin {
  /// Um relógio só para as seis faixas: 390 s = 15 voltas de 26 s (esquerda) e 13 de 30 s
  /// (direita).
  late final AnimationController _faixas;
  late final AnimationController _anel1; // 4 s
  late final AnimationController _anel2; // 7 s, sentido inverso
  late final AnimationController _adesivo; // 2,6 s, vai e volta
  late final AnimationController _cintila; // 4 s
  late final AnimationController _ponto; // 1 s, degrau
  late final Animation<double> _opacidadeLetreiro;
  late final Animation<double> _giro2;

  Timer? _troca;
  int _midia = 0;

  @override
  void initState() {
    super.initState();
    final m = widget.p.mov;
    _faixas = AnimationController(vsync: this, duration: m.d(390000));
    _anel1 = AnimationController(vsync: this, duration: m.d(4000));
    _anel2 = AnimationController(vsync: this, duration: m.d(7000));
    _adesivo = AnimationController(vsync: this, duration: m.d(1300));
    _cintila = AnimationController(vsync: this, duration: m.d(4000));
    _ponto = AnimationController(vsync: this, duration: m.d(1000));
    _giro2 = Tween<double>(begin: 1, end: 0).animate(_anel2);
    // Cintilação do letreiro: 1 → 0,35 nos pontos 20% e 63% (keyframes do protótipo).
    _opacidadeLetreiro = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1, end: .35), weight: 2),
      TweenSequenceItem(tween: Tween(begin: .35, end: 1), weight: 2),
      TweenSequenceItem(tween: ConstantTween(1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: .35), weight: 1),
      TweenSequenceItem(tween: Tween(begin: .35, end: 1), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1), weight: 36),
    ]).animate(_cintila);
    _loops();
    _agendarTroca();
  }

  @override
  void didUpdateWidget(covariant NeonDescanso old) {
    super.didUpdateWidget(old);
    if (old.p.mov.escala != widget.p.mov.escala) {
      final m = widget.p.mov;
      _faixas.duration = m.d(390000);
      _anel1.duration = m.d(4000);
      _anel2.duration = m.d(7000);
      _adesivo.duration = m.d(1300);
      _cintila.duration = m.d(4000);
      _ponto.duration = m.d(1000);
    }
    _loops();
    if (old.p.midias.length != widget.p.midias.length || old.p.intervaloSeg != widget.p.intervaloSeg) {
      _agendarTroca();
    }
  }

  /// Liga ou para cada loop conforme o movimento e o bloqueio. Parado = quadro estático
  /// (faixas no lugar, anéis parados, letreiro aceso, ponto aceso, adesivo em 9°).
  void _loops() {
    final vivo = widget.p.mov.loops;
    final pulsa = vivo && !widget.p.bloqueado;
    void liga(AnimationController c, bool on, {bool vaiEVolta = false}) {
      if (on) {
        if (!c.isAnimating) c.repeat(reverse: vaiEVolta);
      } else if (c.isAnimating || c.value != 0) {
        c
          ..stop()
          ..value = 0;
      }
    }

    liga(_faixas, vivo);
    liga(_anel1, vivo);
    liga(_anel2, vivo);
    liga(_adesivo, vivo, vaiEVolta: true);
    liga(_cintila, pulsa);
    liga(_ponto, pulsa);
  }

  /// Mídias da loja trocando a cada `intervaloSeg` (como o carrossel padrão).
  void _agendarTroca() {
    _troca?.cancel();
    _troca = null;
    if (widget.p.midias.length > 1) {
      _troca = Timer.periodic(Duration(seconds: math.max(2, widget.p.intervaloSeg)), (_) {
        if (mounted) setState(() => _midia = (_midia + 1) % widget.p.midias.length);
      });
    }
  }

  @override
  void dispose() {
    _troca?.cancel();
    _faixas.dispose();
    _anel1.dispose();
    _anel2.dispose();
    _adesivo.dispose();
    _cintila.dispose();
    _ponto.dispose();
    super.dispose();
  }

  DescansoMidia? get _midiaAtual {
    final m = widget.p.midias;
    return m.isEmpty ? null : m[_midia % m.length];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SizedBox.expand(
      key: const ValueKey('neon-descanso'),
      child: ColoredBox(
        color: _t.bg,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1080,
            height: 1920,
            child: MediaQuery(
              data: mq.copyWith(size: const Size(1080, 1920)),
              child: _conteudo(),
            ),
          ),
        ),
      ),
    );
  }

  /// Tudo em px de desenho (a caixa tem exatamente 1080×1920).
  Widget _conteudo() {
    final p = widget.p;
    final mov = p.mov;
    final midia = _midiaAtual;
    final url = midia?.url ?? _primeiraFoto();
    final adesivo = textoAdesivo(p);
    return Stack(clipBehavior: Clip.hardEdge, children: [
      // Faixas giradas −8°, deslocadas 160 para fora dos dois lados.
      Positioned(
        left: -160,
        right: -160,
        top: 190,
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: -8 * math.pi / 180,
            child: _Faixas(textos: textosFaixas(p.midias), relogio: _faixas, correndo: mov.loops),
          ),
        ),
      ),
      const Positioned.fill(
        child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _Scanlines()))),
      ),
      // Palco: anéis, produto e adesivo.
      Positioned(
        left: 0,
        right: 0,
        top: 500,
        height: 820,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 120,
            top: -10,
            width: 840,
            height: 840,
            child: RepaintBoundary(
              child: AnelNeon(
                giro: _giro2,
                inicio: 0,
                // conic-gradient(from 90deg, #FF3EA5, transparent 30%, #3EE0FF 60%,
                // transparent 80%) a 60% de opacidade.
                cores: const [
                  Color(0x99FF3EA5),
                  Color(0x00FF3EA5),
                  Color(0x003EE0FF),
                  Color(0x993EE0FF),
                  Color(0x003EE0FF),
                ],
                paradas: const [0, .3, .3, .6, .8],
              ),
            ),
          ),
          if (mov.brilho)
            const Positioned(
              left: 170,
              top: 40,
              width: 740,
              height: 740,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x59C8FF2E), Color(0x00C8FF2E)],
                      stops: [0, .62],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 170,
            top: 40,
            width: 740,
            height: 740,
            child: RepaintBoundary(
              child: AnelNeon(
                giro: _anel1,
                // conic-gradient(#C8FF2E, #FF3EA5, transparent 55%, #C8FF2E).
                cores: [_t.accent, _t.accent2, const Color(0x00FF3EA5), const Color(0x00C8FF2E), _t.accent],
                paradas: const [0, .275, .55, .55, 1],
                brilho: mov.brilho ? _t.accent : null,
                mascara: const [1, 1, 0, 0, 1],
              ),
            ),
          ),
          Positioned(
            left: 220,
            top: 190,
            width: 640,
            height: 520,
            child: NeonFlutua(
              mov: mov,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: mov.anima ? 600 : 0),
                child: _Produto(key: ValueKey(url ?? '-'), url: url),
              ),
            ),
          ),
          if (adesivo != null)
            Positioned(
              top: 60,
              right: 70,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _adesivo,
                  child: _Adesivo(rotulo: adesivo.$1, valor: adesivo.$2, brilho: mov.brilho),
                  builder: (_, child) {
                    final v = Curves.easeInOut.transform(_adesivo.value);
                    return Transform.rotate(
                      angle: (9 - 6 * v) * math.pi / 180,
                      child: Transform.scale(scale: 1 + .04 * v, child: child),
                    );
                  },
                ),
              ),
            ),
          if (midia != null && ((midia.titulo ?? '').isNotEmpty || (midia.subtitulo ?? '').isNotEmpty))
            Positioned(
              left: 140,
              right: 140,
              top: 730,
              child: _Legenda(midia: midia),
            ),
        ]),
      ),
      Positioned(
        top: 56,
        left: 56,
        right: 56,
        child: Row(children: [NeonMarca(escala: 1.15, nomeLoja: p.nomeLoja, logoUrl: p.logoUrl)]),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 40, 56, 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: FadeTransition(
                  opacity: _opacidadeLetreiro,
                  child: SizedBox(
                    width: 968,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PEDE AÍ.',
                        key: const ValueKey('neon-letreiro'),
                        maxLines: 1,
                        style: neonDisplay(
                          170,
                          cor: _t.accent,
                          altura: .9,
                          espaco: -.01,
                          sombras: mov.brilho ? const [Shadow(color: Color(0x8CC8FF2E), blurRadius: 30)] : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _ponto,
                    builder: (_, __) => Opacity(
                      opacity: _ponto.value < .5 ? 1 : 0,
                      child: Container(
                        key: const ValueKey('neon-ponto'),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _t.accent2,
                          shape: BoxShape.circle,
                          boxShadow: mov.brilho ? [BoxShadow(color: _t.accent2, blurRadius: 16)] : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    p.chamada.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: neonTexto(28, peso: FontWeight.w700, espaco: .14),
                  ),
                ),
              ]),
              const SizedBox(height: 30),
              Row(children: [
                Expanded(
                  child: NeonBotao(
                    key: const ValueKey('neon-local'),
                    rotulo: 'Comer aqui',
                    icone: Icons.restaurant_rounded,
                    altura: 170,
                    fonte: 40,
                    onTap: p.bloqueado ? null : () => p.onIniciar('local'),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: NeonBotao(
                    key: const ValueKey('neon-viagem'),
                    rotulo: 'Para levar',
                    icone: Icons.shopping_bag_outlined,
                    tipo: NeonBotaoTipo.fantasma,
                    altura: 170,
                    fonte: 40,
                    onTap: p.bloqueado ? null : () => p.onIniciar('viagem'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ]);
  }

  /// Sem mídias, a arte padrão é a foto do 1º destaque (o mais vendido).
  String? _primeiraFoto() {
    for (final d in widget.p.destaques) {
      final u = d.imagemUrl;
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }
}

/// Textos das seis faixas: os `kicker` das mídias da loja (em CAIXA ALTA) ou os do
/// template ("SMASH ✦ BACON ✦ CHEDDAR ✦", "FOME DE MADRUGADA ✦", "ABERTO ATÉ 4H ✦",
/// "PEDE AÍ ✦").
List<String> textosFaixas(List<DescansoMidia> midias) {
  final kickers = [
    for (final m in midias)
      if ((m.kicker ?? '').trim().isNotEmpty) '${m.kicker!.trim().toUpperCase()} ✦',
  ];
  if (kickers.isEmpty) {
    return const [
      'SMASH ✦ BACON ✦ CHEDDAR ✦',
      'FOME DE MADRUGADA ✦',
      'SMASH ✦ BACON ✦ CHEDDAR ✦',
      'ABERTO ATÉ 4H ✦',
      'SMASH ✦ BACON ✦ CHEDDAR ✦',
      'PEDE AÍ ✦ PEDE AÍ ✦',
    ];
  }
  return [for (var i = 0; i < 6; i++) kickers[i % kickers.length]];
}

/// O adesivo do palco: (rótulo, valor). Com `precoIsca`, "COMBO DA NOITE" + o preço — se
/// a isca tiver texto antes do preço ("Combo Duplo R$ 52,90"), esse texto vira o rótulo.
/// Sem isca, o selo e o preço do 1º produto com selo. Nenhum dos dois: sem adesivo.
(String, String)? textoAdesivo(DescansoProps p) {
  final isca = p.precoIsca?.trim() ?? '';
  if (isca.isNotEmpty) {
    final m = RegExp(r'R\$\s*[\d.]+(,\d{1,2})?').firstMatch(isca);
    if (m != null) {
      final antes = isca.substring(0, m.start).replaceAll(RegExp(r'[\s·:\-–—]+$'), '').trim();
      return (antes.isEmpty ? 'COMBO DA NOITE' : antes.toUpperCase(), m.group(0)!);
    }
    return ('COMBO DA NOITE', isca.toUpperCase());
  }
  for (final d in p.destaques) {
    final selo = d.selo?.trim() ?? '';
    if (selo.isNotEmpty) return (selo.toUpperCase(), formatCentavos(d.precoCentavos));
  }
  return null;
}

/// As seis faixas (prototipo `.mqs`): vazada verde, vazada magenta, CHEIA verde, vazada
/// magenta, vazada verde, vazada magenta. Ímpares correm para a esquerda (26 s); pares,
/// para a direita (30 s). Paradas, ficam no lugar.
class _Faixas extends StatelessWidget {
  const _Faixas({required this.textos, required this.relogio, required this.correndo});
  final List<String> textos;
  final Animation<double> relogio;
  final bool correndo;

  static const _cores = [
    Color(0x38C8FF2E),
    Color(0x47FF3EA5),
    Color(0xE6C8FF2E),
    Color(0x47FF3EA5),
    Color(0x38C8FF2E),
    Color(0x47FF3EA5),
  ];
  static const _cheia = [false, false, true, false, false, false];
  // Fase inicial de cada faixa (as paradas não ficam todas alinhadas à esquerda).
  static const _fase = [0.0, .35, .6, .15, .8, .45];

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 6; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        SizedBox(
          height: 153,
          child: _Faixa(
            key: ValueKey('neon-faixa-$i'),
            texto: textos[i % textos.length],
            cor: _cores[i],
            cheia: _cheia[i],
            paraEsquerda: i.isEven,
            fase: _fase[i],
            relogio: relogio,
            correndo: correndo,
          ),
        ),
      ],
    ]);
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({
    super.key,
    required this.texto,
    required this.cor,
    required this.cheia,
    required this.paraEsquerda,
    required this.fase,
    required this.relogio,
    required this.correndo,
  });

  final String texto;
  final Color cor;
  final bool cheia;
  final bool paraEsquerda;
  final double fase;
  final Animation<double> relogio;
  final bool correndo;

  @override
  Widget build(BuildContext context) {
    // Vazada = contorno de 2 px (`-webkit-text-stroke`); cheia = cor sólida. Cada cópia
    // cobre a faixa inteira (1400 px): o letreiro repete o texto o necessário.
    final copia = Padding(
      padding: const EdgeInsets.only(right: 40),
      child: LetreiroNeon(texto: '$texto ', tamanho: 150, cor: cor, vazado: !cheia, repetirAte: 1500),
    );
    final duas = RepaintBoundary(child: Row(mainAxisSize: MainAxisSize.min, children: [copia, copia]));
    // Voltas por ciclo do relógio de 390 s: 15 (26 s, esquerda) e 13 (30 s, direita).
    final voltas = paraEsquerda ? 15 : 13;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        child: correndo
            ? AnimatedBuilder(
                animation: relogio,
                child: duas,
                builder: (_, child) {
                  final v = (relogio.value * voltas + fase) % 1.0;
                  final x = paraEsquerda ? -v : -(1 - v);
                  return FractionalTranslation(translation: Offset(x / 2, 0), child: child);
                },
              )
            : FractionalTranslation(translation: Offset(-fase / 2, 0), child: duas),
      ),
    );
  }
}

/// Listras horizontais de 2 px a cada 6 px, desenhadas uma vez.
class _Scanlines extends CustomPainter {
  const _Scanlines();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x09FFFFFF);
    for (var y = 0.0; y < s.height; y += 6) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, 2), p);
    }
  }

  @override
  bool shouldRepaint(_Scanlines o) => false;
}

/// O produto no centro dos anéis: recorte (`.png`) inteiro; foto, num círculo.
class _Produto extends StatelessWidget {
  const _Produto({super.key, required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (ProdutoArte.ehRecorte(url) || url == null) {
      return ProdutoArte(
        url: url,
        tokens: _t,
        fundo: const Color(0x00000000),
        escalaRecorte: 1,
        sombra: false,
      );
    }
    return Center(
      child: SizedBox(
        width: 580,
        height: 580,
        child: ClipOval(child: ProdutoArte(url: url, tokens: _t)),
      ),
    );
  }
}

class _Adesivo extends StatelessWidget {
  const _Adesivo({required this.rotulo, required this.valor, required this.brilho});
  final String rotulo;
  final String valor;
  final bool brilho;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('neon-adesivo'),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: _t.accent2,
        borderRadius: BorderRadius.circular(18),
        boxShadow: brilho ? const [BoxShadow(color: Color(0x8CFF3EA5), blurRadius: 40)] : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: neonDisplay(22, peso: FontWeight.w700, cor: _t.onAccent2, espaco: 0)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valor, maxLines: 1, style: neonDisplay(54, cor: _t.onAccent2)),
        ),
      ]),
    );
  }
}

/// Título/subtítulo da mídia da loja, numa etiqueta escura sob o produto.
class _Legenda extends StatelessWidget {
  const _Legenda({required this.midia});
  final DescansoMidia midia;

  @override
  Widget build(BuildContext context) {
    final titulo = midia.titulo?.trim() ?? '';
    final sub = midia.subtitulo?.trim() ?? '';
    return Center(
      child: Container(
        key: const ValueKey('descanso-legenda'),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xD907070C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _t.line2, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (titulo.isNotEmpty)
            Text(titulo.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: neonDisplay(34, peso: FontWeight.w700)),
          if (sub.isNotEmpty)
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: neonTexto(24, cor: _t.muted)),
        ]),
      ),
    );
  }
}
