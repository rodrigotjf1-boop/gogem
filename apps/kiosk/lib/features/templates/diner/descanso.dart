import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';
import 'pintores.dart';

const _t = dinerTokens;

/// Chamada que o painel manda quando o lojista não escreveu nenhuma (`Aparencia.padrao`).
const _chamadaDoApp = 'TOQUE PARA PEDIR';

/// Chamada do template (mockup 01): "Toque para começar".
const _chamadaDoTemplate = 'Toque para começar';

/// Uma foto redonda do descanso: a imagem e o texto do selo embaixo (preço do produto, ou a
/// legenda da mídia da loja).
class _Foto {
  const _Foto(this.url, this.selo);
  final String? url;
  final String? selo;
}

/// Descanso do **Diner 58** (docs/templates/05 §6.1): fundo vermelho, letreiro com lâmpadas
/// em perseguição, "Aberto" em néon, três fotos redondas balançando, a frase da loja, a
/// chamada em cursiva, Comer aqui / Para levar e a faixa quadriculada correndo no pé.
///
/// O desenho é feito em px de 1080 de largura e ESCALADO para caber na tela (retrato mais
/// alto ganha altura; paisagem e o harness 800×600 ficam centralizados) — nada transborda.
/// Os portões (papel/offline) e o canto do admin são da `DescansoScreen`, por cima disto.
class DinerDescanso extends StatefulWidget {
  const DinerDescanso({super.key, required this.p});
  final DescansoProps p;

  @override
  State<DinerDescanso> createState() => _DinerDescansoState();
}

class _DinerDescansoState extends State<DinerDescanso> with TickerProviderStateMixin {
  late final AnimationController _lampadas;
  late final AnimationController _aberto;
  late final AnimationController _chamada;
  late final AnimationController _balanco;
  late final AnimationController _faixa;
  late final Animation<double> _cintilaAberto;
  late final Animation<double> _cintilaChamada;

  Movimento get _mov => widget.p.mov;

  /// Lâmpadas, cintilação, fotos balançando e faixa correndo só com movimento CHEIO
  /// (reduzido e o perfil fraco não têm partículas; `off` não anima nada).
  bool get _cheio => _mov.anima && _mov.particulas && !widget.p.bloqueado;

  static Animation<double> _cintila(AnimationController c) => TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1), weight: 18),
        TweenSequenceItem(tween: Tween(begin: 1, end: .35), weight: 2),
        TweenSequenceItem(tween: Tween(begin: .35, end: 1), weight: 2),
        TweenSequenceItem(tween: ConstantTween(1), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1, end: .35), weight: 1),
        TweenSequenceItem(tween: Tween(begin: .35, end: 1), weight: 1),
        TweenSequenceItem(tween: ConstantTween(1), weight: 36),
      ]).animate(c);

  @override
  void initState() {
    super.initState();
    _lampadas = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _aberto = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
    _chamada = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
    _balanco = AnimationController(vsync: this, duration: _mov.d(3200));
    _faixa = AnimationController(vsync: this, duration: _mov.d(3000));
    _cintilaAberto = _cintila(_aberto);
    _cintilaChamada = _cintila(_chamada);
    _aplicaMovimento();
  }

  @override
  void didUpdateWidget(covariant DinerDescanso old) {
    super.didUpdateWidget(old);
    if (old.p.bloqueado != widget.p.bloqueado ||
        old.p.mov.anima != _mov.anima ||
        old.p.mov.particulas != _mov.particulas) {
      _aplicaMovimento();
    }
  }

  void _aplicaMovimento() {
    final todos = [_lampadas, _aberto, _chamada, _balanco, _faixa];
    if (_cheio) {
      for (final c in todos) {
        if (!c.isAnimating) c.repeat();
      }
    } else {
      for (final c in todos) {
        c.stop();
        c.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _lampadas.dispose();
    _aberto.dispose();
    _chamada.dispose();
    _balanco.dispose();
    _faixa.dispose();
    super.dispose();
  }

  List<_Foto> _fotos() {
    final midias = [
      for (final m in widget.p.midias.take(3))
        _Foto(m.url, (m.titulo ?? '').trim().isNotEmpty ? m.titulo!.trim() : (m.kicker ?? '').trim()),
    ];
    if (midias.isNotEmpty) return midias;
    // Sem mídias: os destaques do cardápio, os com foto primeiro (ordem estável).
    final ds = widget.p.destaques;
    final comFoto = [
      for (final p in ds)
        if ((p.imagemUrl ?? '').isNotEmpty) p
    ];
    final semFoto = [
      for (final p in ds)
        if ((p.imagemUrl ?? '').isEmpty) p
    ];
    return [
      for (final p in [...comFoto, ...semFoto].take(3)) _Foto(p.imagemUrl, formatCentavos(p.precoCentavos)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final chamadaPadrao = p.chamada.trim().isEmpty || p.chamada.trim().toUpperCase() == _chamadaDoApp;
    final subtitulo = p.midias.isEmpty ? '' : (p.midias.first.subtitulo ?? '').trim();
    // Frase: legenda da 1ª mídia; sem ela, a chamada da loja (se ela escreveu uma).
    final frase = subtitulo.isNotEmpty ? subtitulo : (chamadaPadrao ? '' : p.chamada.trim());
    // Chamada em cursiva: a da loja, a menos que ela já tenha virado a frase.
    final chamada = chamadaPadrao || frase == p.chamada.trim() ? _chamadaDoTemplate : p.chamada.trim();

    return ColoredBox(
      color: _t.accent,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        // Escala do desenho: retrato mais alto que 9:16 usa a largura (e ganha altura);
        // mais largo (paisagem, harness) usa a altura e centraliza.
        final alto = w / h <= 1080 / 1920;
        final k = alto ? w / 1080 : h / 1920;
        final altura = alto ? h / k : 1920.0;
        final faixa = 96 * k;
        return Stack(children: [
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 1080 * k,
                height: altura * k,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: Size(1080, altura)),
                    child: SizedBox(
                      width: 1080,
                      height: altura,
                      child: _desenho(context, frase, chamada),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: faixa,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('diner-faixa'),
                painter: XadrezPainter(
                  casa: 48 * k,
                  escura: _t.text,
                  clara: _t.bg,
                  deslocamento: _cheio ? _faixa : null,
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  /// O desenho em px de 1080 (dentro do `MediaQuery` de 1080, `dz(px) == px`).
  Widget _desenho(BuildContext context, String frase, String chamada) {
    final p = widget.p;
    final fotos = _fotos();
    return Stack(clipBehavior: Clip.none, children: [
      // Letreiro.
      Positioned(
        left: 80,
        top: 170,
        width: 920,
        height: 560,
        child: _Letreiro(
          nomeLoja: p.nomeLoja,
          logoUrl: p.logoUrl,
          mov: _mov,
          persegue: _cheio,
          lampadas: _lampadas,
          cintila: _cheio ? _cintilaAberto : null,
        ),
      ),
      if ((p.precoIsca ?? '').trim().isNotEmpty)
        Positioned(
          right: 56,
          top: 690,
          child: Transform.rotate(
            angle: -6 * math.pi / 180,
            child: Container(
              key: const ValueKey('preco-isca'),
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: _t.accent2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _t.text, width: 4),
                boxShadow: [sombraDura(6)],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(p.precoIsca!.trim(), maxLines: 1, style: _t.display(34, cor: _t.onAccent2)),
              ),
            ),
          ),
        ),
      // Fotos redondas balançando.
      if (fotos.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          top: 800,
          height: 520,
          child: _Fotos(fotos: fotos, balanco: _balanco, balanca: _cheio),
        ),
      if (frase.isNotEmpty)
        Positioned(
          left: 60,
          right: 60,
          top: 1350,
          child: Text(
            frase,
            key: const ValueKey('diner-frase'),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _t.texto(40, peso: FontWeight.w900, cor: _t.bg, altura: 1.2),
          ),
        ),
      // Rodapé: chamada em cursiva + Comer aqui / Para levar (padding inferior 150: a faixa).
      Positioned(
        left: 56,
        right: 56,
        bottom: 150,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Cintilante(
            animacao: _cheio ? _cintilaChamada : null,
            child: Text(
              chamada,
              key: const ValueKey('diner-chamada'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dinerScript(74,
                  cor: _t.accent2,
                  altura: 1.25,
                  sombras: _mov.blur ? const [Shadow(color: Color(0xCC8FD5C7), blurRadius: 18)] : null),
            ),
          ),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(
              child: DinerBotao(
                key: const ValueKey('descanso-local'),
                rotulo: 'Comer aqui',
                icone: Icons.restaurant_rounded,
                estilo: DinerEstilo.invertido,
                altura: 170,
                fonte: 40,
                expandir: true,
                onTap: p.bloqueado ? null : () => p.onIniciar('local'),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: DinerBotao(
                key: const ValueKey('descanso-viagem'),
                rotulo: 'Para levar',
                icone: Icons.shopping_bag_outlined,
                estilo: DinerEstilo.mint,
                altura: 170,
                fonte: 40,
                expandir: true,
                onTap: p.bloqueado ? null : () => p.onIniciar('viagem'),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

/// Opacidade que cintila (néon falhando); sem animação, 1.
class _Cintilante extends StatelessWidget {
  const _Cintilante({required this.animacao, required this.child});
  final Animation<double>? animacao;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final a = animacao;
    if (a == null) return child;
    return FadeTransition(opacity: a, child: child);
  }
}

/// O letreiro: caixa creme com borda marrom de 10 e sombra vermelho-escura 0/18, lâmpadas
/// nas 4 bordas (22 + 22 + 9 + 9, um painter), "Aberto" em néon verde girado −10° e, no
/// centro, a marca (logo da loja, nome em Yellowtail, ou "Diner 58").
class _Letreiro extends StatefulWidget {
  const _Letreiro({
    required this.nomeLoja,
    required this.logoUrl,
    required this.mov,
    required this.persegue,
    required this.lampadas,
    required this.cintila,
  });

  final String? nomeLoja;
  final String? logoUrl;
  final Movimento mov;
  final bool persegue;
  final AnimationController lampadas;
  final Animation<double>? cintila;

  @override
  State<_Letreiro> createState() => _LetreiroState();
}

class _LetreiroState extends State<_Letreiro> {
  /// Área interna (dentro da borda de 10) do letreiro de 920×560.
  static const _interno = Size(900, 540);

  /// Pontos das 62 lâmpadas, calculados UMA vez (o letreiro tem tamanho fixo no desenho).
  static final List<Lampada> _pontos = _calculaPontos();

  static List<Lampada> _calculaPontos() {
    const r = 11.0;
    const w = 900.0, h = 540.0;
    final out = <Lampada>[];
    // Em cima e embaixo: 22 lâmpadas entre 36 e w-36, a 16 da borda.
    const passoH = (w - 72 - 22) / 21;
    for (var i = 0; i < 22; i++) {
      out.add(Lampada(Offset(36 + r + i * passoH, 16 + r), i));
    }
    for (var i = 0; i < 22; i++) {
      out.add(Lampada(Offset(36 + r + i * passoH, h - 16 - r), i));
    }
    // Laterais: 9 lâmpadas entre 60 e h-60, a 16 da borda.
    const passoV = (h - 120 - 22) / 8;
    for (var i = 0; i < 9; i++) {
      out.add(Lampada(Offset(16 + r, 60 + r + i * passoV), i));
    }
    for (var i = 0; i < 9; i++) {
      out.add(Lampada(Offset(w - 16 - r, 60 + r + i * passoV), i));
    }
    return List.unmodifiable(out);
  }

  @override
  Widget build(BuildContext context) {
    final nome = (widget.nomeLoja ?? '').trim();
    final logo = (widget.logoUrl ?? '').trim();
    final aberto = Text(
      'Aberto',
      style: dinerScript(62,
          cor: _t.ok,
          altura: 1.2,
          sombras: widget.mov.blur ? const [Shadow(color: Color(0xE68FD5C7), blurRadius: 12)] : null),
    );
    Widget centro;
    if (logo.isNotEmpty) {
      centro = SizedBox(
        width: 680,
        height: 360,
        child: CachedNetworkImage(
          key: const ValueKey('letreiro-logo'),
          imageUrl: logo,
          fit: BoxFit.contain,
          memCacheWidth: 680,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => nome.isEmpty
              ? const SizedBox.shrink()
              : FittedBox(fit: BoxFit.scaleDown, child: Text(nome, style: _nomeLetreiro())),
        ),
      );
    } else if (nome.isNotEmpty) {
      centro = SizedBox(
        width: 760,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(nome, key: const ValueKey('letreiro-nome'), maxLines: 1, style: _nomeLetreiro()),
        ),
      );
    } else {
      centro = Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Diner', key: const ValueKey('letreiro-nome'), style: _nomeLetreiro()),
        const SizedBox(height: 6),
        Text('BURGERS · SHAKES · FRITAS', style: _t.display(30, cor: _t.text).copyWith(letterSpacing: 30 * .16)),
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        color: _t.bg,
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: _t.text, width: 10),
        boxShadow: [sombraDura(18, cor: dinerVermelhoEscuro)],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('diner-lampadas'),
              size: _interno,
              painter: LampadasPainter(
                pontos: _pontos,
                raio: 11,
                brilho: widget.mov.blur,
                t: widget.persegue ? widget.lampadas : null,
              ),
            ),
          ),
        ),
        Positioned.fill(child: Center(child: centro)),
        if (logo.isEmpty && nome.isEmpty)
          Positioned(
            right: 110,
            top: 150,
            child: Transform.rotate(
              angle: 8 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                decoration: BoxDecoration(color: _t.text, borderRadius: BorderRadius.circular(18)),
                child: Text('58', style: _t.display(84, cor: _t.bg, altura: 1.1)),
              ),
            ),
          ),
        Positioned(
          left: 70,
          top: 50,
          child: Transform.rotate(
            angle: -10 * math.pi / 180,
            child: _Cintilante(animacao: widget.cintila, child: aberto),
          ),
        ),
      ]),
    );
  }

  TextStyle _nomeLetreiro() => dinerScript(230,
      cor: _t.accent, altura: 1.05, sombras: [const Shadow(color: Color(0xFF2A1512), offset: Offset(6, 6))]);
}

/// As fotos redondas (até 3) com moldura creme e sombra dura, balançando ±18 px em 3,2 s
/// com fases defasadas (−0,8 s, 0 e −1,6 s). A do meio fica por cima das outras.
class _Fotos extends StatelessWidget {
  const _Fotos({required this.fotos, required this.balanco, required this.balanca});
  final List<_Foto> fotos;
  final AnimationController balanco;
  final bool balanca;

  @override
  Widget build(BuildContext context) {
    // Vagas do protótipo: esquerda (320, fase .25), centro (430, fase 0), direita (310, fase .5).
    Widget vaga(_Foto f,
            {required double? left, double? right, required double top, required double lado, required double fase}) =>
        Positioned(
          left: left,
          right: right,
          top: top,
          width: lado,
          height: lado + 30,
          child: _FotoRedonda(foto: f, lado: lado, balanco: balanco, balanca: balanca, fase: fase),
        );
    final esquerda = <Widget>[];
    Widget? centro;
    switch (fotos.length) {
      case 1:
        centro = vaga(fotos[0], left: 325, top: 0, lado: 430, fase: 0);
      case 2:
        esquerda
          ..add(vaga(fotos[0], left: 120, top: 60, lado: 380, fase: .25))
          ..add(vaga(fotos[1], left: null, right: 120, top: 60, lado: 380, fase: .5));
      default:
        esquerda
          ..add(vaga(fotos[1], left: 40, top: 120, lado: 320, fase: .25))
          ..add(vaga(fotos[2], left: null, right: 40, top: 130, lado: 310, fase: .5));
        centro = vaga(fotos[0], left: 330, top: 0, lado: 430, fase: 0);
    }
    return Stack(clipBehavior: Clip.none, children: [...esquerda, if (centro != null) centro]);
  }
}

class _FotoRedonda extends StatelessWidget {
  const _FotoRedonda({
    required this.foto,
    required this.lado,
    required this.balanco,
    required this.balanca,
    required this.fase,
  });

  final _Foto foto;
  final double lado;
  final AnimationController balanco;
  final bool balanca;
  final double fase;

  @override
  Widget build(BuildContext context) {
    final selo = (foto.selo ?? '').trim();
    final corpo = RepaintBoundary(
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _t.bg,
            boxShadow: const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 20))],
          ),
          padding: const EdgeInsets.all(14),
          child: DinerArte(url: foto.url, circulo: true, fundo: _t.art),
        ),
        if (selo.isNotEmpty)
          Positioned(
            top: lado - 44,
            child: Transform.rotate(
              angle: -5 * math.pi / 180,
              child: Container(
                constraints: BoxConstraints(maxWidth: lado * .95),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: _t.text, borderRadius: BorderRadius.circular(14)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(selo, maxLines: 1, style: _t.display(30, cor: _t.bg, altura: 1.15)),
                ),
              ),
            ),
          ),
      ]),
    );
    if (!balanca) return corpo;
    return AnimatedBuilder(
      animation: balanco,
      child: corpo,
      builder: (_, filho) {
        final y = -18 * (.5 - .5 * math.cos(2 * math.pi * (balanco.value + fase)));
        return Transform.translate(offset: Offset(0, y), child: filho);
      },
    );
  }
}
