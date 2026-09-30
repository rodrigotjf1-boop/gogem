import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../../catalogo/produto_imagem.dart';
import '../comum/etapas.dart';
import '../comum/selo.dart';
import '../escala.dart';
import '../movimento.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Logo do Neon (docs/templates/04-neon-2.md §4): `logoUrl` da loja; sem ele, o nome da
/// loja em Unbounded com a "/" verde; sem nenhum dos dois, o padrão "NEON/" + "SMASH CLUB".
///
/// Nas Views puras (produto, identificação, pagamento, sucesso) a loja vem do
/// `aparenciaProvider` quando existe um `ProviderScope` acima; sem ele, fica o padrão.
class NeonMarca extends StatelessWidget {
  const NeonMarca({
    super.key,
    this.escala = 1,
    this.nomeLoja,
    this.logoUrl,
    this.centro = false,
  });

  final double escala;
  final String? nomeLoja;
  final String? logoUrl;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final temEscopo = context.getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (nomeLoja == null && logoUrl == null && temEscopo) {
      return Consumer(builder: (context, ref, _) {
        final ap = ref.watch(aparenciaProvider).valueOrNull;
        return _desenho(context, ap?.nomeLoja, ap?.logoUrl);
      });
    }
    return _desenho(context, nomeLoja, logoUrl);
  }

  Widget _desenho(BuildContext context, String? nome, String? logo) {
    final s = escala;
    final alinhamento = centro ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    if (logo != null && logo.trim().isNotEmpty) {
      return SizedBox(
        key: const ValueKey('neon-logo'),
        height: context.dz(84 * s),
        width: context.dz(300 * s),
        child: Align(
          alignment: centro ? Alignment.center : Alignment.centerLeft,
          child: ProdutoImagem(url: logo, fit: BoxFit.contain),
        ),
      );
    }
    final titulo = (nome == null || nome.trim().isEmpty) ? 'NEON' : nome.trim().toUpperCase();
    final padrao = nome == null || nome.trim().isEmpty;
    return ConstrainedBox(
      key: const ValueKey('neon-logo'),
      constraints: BoxConstraints(maxWidth: context.dz(520 * s)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alinhamento,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: titulo),
              TextSpan(text: '/', style: TextStyle(color: _t.accent)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: neonDisplay(context.dz(48 * s)),
          ),
          if (padrao) ...[
            SizedBox(height: context.dz(4 * s)),
            Text('SMASH CLUB',
                maxLines: 1, style: neonTexto(context.dz(16 * s), peso: FontWeight.w700, cor: _t.accent2, espaco: .38)),
          ],
        ],
      ),
    );
  }
}

/// Topo das telas internas: logo, Voltar/Cancelar e as `Etapas` (prototipo `.tb`).
class NeonTopo extends StatelessWidget {
  const NeonTopo({
    super.key,
    required this.mov,
    this.etapa,
    this.onVoltar,
    this.onCancelar,
    this.nomeLoja,
    this.logoUrl,
  });

  final Movimento mov;
  final int? etapa;
  final VoidCallback? onVoltar;
  final VoidCallback? onCancelar;
  final String? nomeLoja;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(40), context.dz(48), context.dz(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: NeonMarca(escala: .78, nomeLoja: nomeLoja, logoUrl: logoUrl),
            ),
          ),
          if (onVoltar != null) ...[
            SizedBox(width: context.dz(12)),
            _BotaoTopo(
              key: const ValueKey('topo-voltar'),
              rotulo: 'Voltar',
              icone: Icons.chevron_left_rounded,
              onTap: onVoltar!,
            ),
          ],
          if (onCancelar != null) ...[
            SizedBox(width: context.dz(12)),
            _BotaoTopo(
              key: const ValueKey('topo-cancelar'),
              rotulo: 'Cancelar',
              icone: Icons.close_rounded,
              contorno: true,
              onTap: onCancelar!,
            ),
          ],
        ]),
        if (etapa != null) ...[
          SizedBox(height: context.dz(26)),
          Etapas(atual: etapa!, tokens: _t, mov: mov, corTrilho: _t.line),
        ],
      ]),
    );
  }
}

class _BotaoTopo extends StatelessWidget {
  const _BotaoTopo({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.onTap,
    this.contorno = false,
  });
  final String rotulo;
  final IconData icone;
  final VoidCallback onTap;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(context.dz(_t.raioBotao));
    final cor = contorno ? _t.muted : _t.text;
    return Material(
      color: contorno ? const Color(0x00000000) : _t.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: contorno ? BorderSide(color: _t.line, width: context.dz(2)) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: raio,
        onTap: onTap,
        child: SizedBox(
          height: context.dz(72),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.dz(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icone, size: context.dz(32), color: cor),
              SizedBox(width: context.dz(8)),
              Text(rotulo, style: neonTexto(context.dz(26), peso: FontWeight.w600, cor: cor)),
            ]),
          ),
        ),
      ),
    );
  }
}

enum NeonBotaoTipo { primario, fantasma, suave }

/// Botão do Neon (§5): raio 16, Rubik em CAIXA ALTA com espaçamento 0,04 em. Primário em
/// `accent`; fantasma com borda `line2`. `onTap` nulo = desabilitado (35% e sem toque).
class NeonBotao extends StatelessWidget {
  const NeonBotao({
    super.key,
    required this.rotulo,
    required this.onTap,
    this.tipo = NeonBotaoTipo.primario,
    this.icone,
    this.iconeFim,
    this.altura = 124,
    this.fonte = 34,
  });

  final String rotulo;
  final VoidCallback? onTap;
  final NeonBotaoTipo tipo;
  final IconData? icone;
  final IconData? iconeFim;

  /// Em px de desenho.
  final double altura;
  final double fonte;

  @override
  Widget build(BuildContext context) {
    final (fundo, tinta) = switch (tipo) {
      NeonBotaoTipo.primario => (_t.accent, _t.onAccent),
      NeonBotaoTipo.fantasma => (const Color(0x00000000), _t.text),
      NeonBotaoTipo.suave => (_t.surface2, _t.text),
    };
    final raio = BorderRadius.circular(context.dz(_t.raioBotao));
    final fs = context.dz(fonte);
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: tipo == NeonBotaoTipo.fantasma ? BorderSide(color: _t.line2, width: context.dz(3)) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: raio,
          onTap: onTap,
          child: SizedBox(
            height: context.dz(altura),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.dz(28)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: fs * 1.2, color: tinta),
                    SizedBox(width: context.dz(16)),
                  ],
                  Flexible(
                    child: Text(
                      rotulo.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: neonTexto(fs, peso: FontWeight.w800, cor: tinta, espaco: .04),
                    ),
                  ),
                  if (iconeFim != null) ...[
                    SizedBox(width: context.dz(14)),
                    Icon(iconeFim, size: fs * 1.05, color: tinta),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão "+" do Neon: QUADRADO de raio 16 em `accent` (§5).
class NeonBotaoMais extends StatelessWidget {
  const NeonBotaoMais({
    super.key,
    required this.onTap,
    this.tamanho = 76,
    this.redondo = false,
    this.feito = false,
  });

  final VoidCallback? onTap;
  final double tamanho;
  final bool redondo;

  /// Item já adicionado: mostra ✓.
  final bool feito;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(tamanho);
    final forma =
        redondo ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.dz(16)));
    return Material(
      color: _t.accent,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: onTap,
        child: SizedBox(
          width: d,
          height: d,
          child: Icon(feito ? Icons.check_rounded : Icons.add_rounded, size: d * .52, color: _t.onAccent),
        ),
      ),
    );
  }
}

/// Selo do tile (§5): retângulo de raio 10. "Mais pedido" em `accent2` com estrela; os
/// outros em `text` (como no mockup: "Novo" claro).
class SeloNeon extends StatelessWidget {
  const SeloNeon({super.key, required this.texto, this.altura = 44});
  final String texto;

  /// Em px de desenho.
  final double altura;

  @override
  Widget build(BuildContext context) {
    final destaque = Selo.ehMaisPedido(texto);
    final fundo = destaque ? _t.accent2 : _t.text;
    final tinta = destaque ? _t.onAccent2 : _t.bg;
    final h = context.dz(altura);
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: h * .36),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(context.dz(10))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (destaque) ...[
          Icon(Icons.star_border_rounded, size: h * .5, color: tinta),
          SizedBox(width: h * .12),
        ],
        Flexible(
          child: Text(texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: neonTexto(h * .45, peso: FontWeight.w700, cor: tinta)),
        ),
      ]),
    );
  }
}

/// Anel de néon (§8): um `SweepGradient` em traço, girado por `RotationTransition` (sem
/// repintar). O brilho é feito em degraus de traços largos e translúcidos (sem
/// `MaskFilter.blur`) e só existe quando [brilho] vem preenchido (perfil forte).
class AnelNeon extends StatelessWidget {
  const AnelNeon({
    super.key,
    required this.giro,
    required this.cores,
    required this.paradas,
    this.largura = 10,
    this.inicio = -math.pi / 2,
    this.brilho,
    this.mascara,
  });

  final Animation<double> giro;
  final List<Color> cores;
  final List<double> paradas;

  /// Opacidade (0..1) do halo em cada parada — onde o anel é transparente, o brilho some.
  final List<double>? mascara;

  /// Espessura do traço em px de TELA.
  final double largura;

  /// Ângulo inicial do gradiente (−π/2 = 12 h, como o `conic-gradient` do CSS).
  final double inicio;
  final Color? brilho;

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: giro,
        // O desenho do anel fica numa camada própria: girar só recompõe, não repinta.
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _AnelPainter(cores, paradas, largura, inicio, brilho, mascara),
            child: const SizedBox.expand(),
          ),
        ),
      );
}

class _AnelPainter extends CustomPainter {
  _AnelPainter(this.cores, this.paradas, this.w, this.inicio, this.brilho, this.mascara);
  final List<Color> cores;
  final List<double> paradas;
  final double w;
  final double inicio;
  final Color? brilho;
  final List<double>? mascara;

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    final area = Offset.zero & s;
    final b = brilho;
    final m = mascara;
    if (b != null && m != null && m.length == cores.length) {
      // Halo: mesmo desenho do anel, na cor do brilho, em três traços largos e fracos.
      for (final (extra, alfa) in const [(40.0, .07), (22.0, .13), (10.0, .24)]) {
        final corHalo = [
          for (final x in m) b.withAlpha((x * alfa * 255).round().clamp(0, 255)),
        ];
        c.drawOval(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w + extra
            ..shader = SweepGradient(
              colors: corHalo,
              stops: paradas,
              transform: GradientRotation(inicio),
            ).createShader(area),
        );
      }
    }
    c.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..shader = SweepGradient(colors: cores, stops: paradas, transform: GradientRotation(inicio)).createShader(area),
    );
  }

  @override
  bool shouldRepaint(_AnelPainter o) => false; // gira via RotationTransition, sem repintar
}

/// Borda de néon girando (§5, `.glow`): `SweepGradient` [accent, accent2, ciano, accent]
/// dando uma volta em 5 s, desenhado SÓ na faixa da borda (anel entre dois RRect). Sem
/// loops (reduzido/low/off), borda sólida `accent`.
class BordaNeon extends StatefulWidget {
  const BordaNeon({
    super.key,
    required this.mov,
    required this.child,
    this.raio = 22,
    this.espessura = 3,
    this.fundo,
  });

  final Movimento mov;
  final Widget child;

  /// Em px de desenho.
  final double raio;
  final double espessura;
  final Color? fundo;

  @override
  State<BordaNeon> createState() => _BordaNeonState();
}

class _BordaNeonState extends State<BordaNeon> with SingleTickerProviderStateMixin {
  late final AnimationController _giro;

  @override
  void initState() {
    super.initState();
    _giro = AnimationController(vsync: this, duration: widget.mov.d(5000));
    if (widget.mov.loops) _giro.repeat();
  }

  @override
  void didUpdateWidget(covariant BordaNeon old) {
    super.didUpdateWidget(old);
    if (widget.mov.loops && !_giro.isAnimating) {
      _giro
        ..duration = widget.mov.d(5000)
        ..repeat();
    } else if (!widget.mov.loops && _giro.isAnimating) {
      _giro
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raio = context.dz(widget.raio);
    final esp = context.dz(widget.espessura);
    // A borda repinta a cada quadro; o conteúdo do tile fica noutra camada e não repinta.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BordaPainter(_giro, raio, esp, widget.mov.loops),
        child: Padding(
          padding: EdgeInsets.all(esp),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(math.max(0, raio - esp)),
              child: ColoredBox(color: widget.fundo ?? _t.surface, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _BordaPainter extends CustomPainter {
  _BordaPainter(this.giro, this.raio, this.esp, this.gira) : super(repaint: giro);
  final Animation<double> giro;
  final double raio;
  final double esp;
  final bool gira;

  @override
  void paint(Canvas c, Size s) {
    final fora = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(raio));
    final dentro = fora.deflate(esp);
    final p = Paint();
    if (gira) {
      p.shader = SweepGradient(
        colors: [_t.accent, _t.accent2, neonCiano, _t.accent],
        transform: GradientRotation(giro.value * 2 * math.pi - math.pi / 2),
      ).createShader(Offset.zero & s);
    } else {
      p.color = _t.accent;
    }
    c.drawDRRect(fora, dentro, p);
  }

  @override
  bool shouldRepaint(_BordaPainter o) => o.gira != gira || o.raio != raio || o.esp != esp;
}

/// Borda tracejada (lista da sacola, §6.4).
class BordaTracejada extends CustomPainter {
  BordaTracejada({required this.cor, required this.espessura, required this.raio, this.traco = 12, this.vao = 9});
  final Color cor;
  final double espessura;
  final double raio;
  final double traco;
  final double vao;

  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(
      (Offset.zero & s).deflate(espessura / 2),
      Radius.circular(raio),
    );
    final p = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + traco, m.length)), p);
        d += traco + vao;
      }
    }
  }

  @override
  bool shouldRepaint(BordaTracejada o) => o.cor != cor || o.espessura != espessura || o.raio != raio;
}

/// Entrada de tela (§7, "glitch"): 500 ms em 5 degraus — faixas recortadas com salto
/// horizontal (−16, 14, −8, 0) — junto de um fade subindo. Em `reduzido`/`low` só o fade;
/// sem animação, a tela aparece direto.
class NeonEntrada extends StatefulWidget {
  const NeonEntrada({super.key, required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  State<NeonEntrada> createState() => _NeonEntradaState();
}

class _NeonEntradaState extends State<NeonEntrada> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;

  // (topo, base, deslocamento x) de cada degrau, como o `glitchIn` do protótipo.
  static const _degraus = [
    (0.0, .2, -16.0),
    (.3, .6, 14.0),
    (.6, .9, -8.0),
    (.1, .4, 0.0),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(500));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
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
    final glitch = widget.mov.particulas;
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final v = _c.value;
          final dy = context.dz(40) * (1 - _fade.value);
          final i = (v * 5).floor();
          if (!glitch || i >= _degraus.length || v >= 1) {
            return Transform.translate(offset: Offset(0, dy), child: child);
          }
          final (topo, base, dx) = _degraus[i];
          return Transform.translate(
            offset: Offset(context.dz(dx), dy),
            child: ClipRect(clipper: _Faixa(topo, base), child: child),
          );
        },
      ),
    );
  }
}

class _Faixa extends CustomClipper<Rect> {
  const _Faixa(this.topo, this.base);
  final double topo;
  final double base;
  @override
  Rect getClip(Size s) => Rect.fromLTRB(0, s.height * topo, s.width, s.height * base);
  @override
  bool shouldReclip(_Faixa o) => o.topo != topo || o.base != base;
}

/// Flutuação (sobe e desce [amplitude] px de desenho em [ms]) — só com loops (§7).
class NeonFlutua extends StatefulWidget {
  const NeonFlutua({
    super.key,
    required this.mov,
    required this.child,
    this.amplitude = 18,
    this.ms = 3000,
    this.fase = 0,
  });
  final Movimento mov;
  final Widget child;
  final double amplitude;
  final int ms;

  /// Defasagem 0..1 (dois recortes flutuando fora de compasso).
  final double fase;

  @override
  State<NeonFlutua> createState() => _NeonFlutuaState();
}

class _NeonFlutuaState extends State<NeonFlutua> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(widget.ms), value: widget.fase);
    if (widget.mov.loops) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mov.loops) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          // 0 → −amplitude → 0 (o `bob` do protótipo), com entrada e saída suaves.
          final y = -context.dz(widget.amplitude) * (1 - math.cos(_c.value * 2 * math.pi)) / 2;
          return Transform.translate(offset: Offset(0, y), child: child);
        },
      ),
    );
  }
}

/// Estado vazio no visual do Neon (carregando, sem cardápio, offline, sacola vazia).
class NeonVazio extends StatelessWidget {
  const NeonVazio({super.key, required this.titulo, this.detalhe, this.acao, this.icone});
  final String titulo;
  final String? detalhe;
  final Widget? acao;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[
            Icon(icone, size: context.dz(96), color: _t.muted),
            SizedBox(height: context.dz(22)),
          ],
          Text(_t.caixa(titulo), textAlign: TextAlign.center, style: neonDisplay(context.dz(44), altura: 1.1)),
          if (detalhe != null) ...[
            SizedBox(height: context.dz(14)),
            Text(detalhe!, textAlign: TextAlign.center, style: neonTexto(context.dz(28), cor: _t.muted, altura: 1.35)),
          ],
          if (acao != null) ...[
            SizedBox(height: context.dz(34)),
            acao!,
          ],
        ]),
      ),
    );
  }
}

/// "//" em `accent2` antes do título de seção (§4).
class TituloSecaoNeon extends StatelessWidget {
  const TituloSecaoNeon(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '//', style: TextStyle(color: _t.accent2)),
          TextSpan(text: ' ${_t.caixa(texto)}'),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: neonDisplay(context.dz(46), altura: 1.05),
      );
}

/// Letreiro de uma linha em Unbounded 800, cheio ou VAZADO, com "✦" desenhado (a fonte não
/// tem esse glifo). No vazado, o traço largo é recortado pelo próprio preenchimento
/// (`BlendMode.dstOut` numa camada): sobra só o contorno externo, sem as linhas internas
/// que os glifos sobrepostos da Unbounded mostrariam num traço simples.
class LetreiroNeon extends StatefulWidget {
  const LetreiroNeon({
    super.key,
    required this.texto,
    required this.tamanho,
    required this.cor,
    this.vazado = true,
    this.traco = 2,
    this.altura = 1.02,
    this.repetirAte = 0,
  });

  final String texto;

  /// Tamanho da fonte em px de TELA.
  final double tamanho;
  final Color cor;
  final bool vazado;

  /// Espessura visível do contorno, em px de TELA.
  final double traco;
  final double altura;

  /// Repete o texto até passar desta largura (px de TELA). 0 = uma vez só.
  final double repetirAte;

  @override
  State<LetreiroNeon> createState() => _LetreiroNeonState();
}

class _LetreiroNeonState extends State<LetreiroNeon> {
  late _Desenho _d;

  @override
  void initState() {
    super.initState();
    _d = _Desenho(widget);
  }

  @override
  void didUpdateWidget(covariant LetreiroNeon old) {
    super.didUpdateWidget(old);
    if (old.texto != widget.texto ||
        old.tamanho != widget.tamanho ||
        old.cor != widget.cor ||
        old.vazado != widget.vazado ||
        old.traco != widget.traco ||
        old.repetirAte != widget.repetirAte) {
      _d.dispose();
      _d = _Desenho(widget);
    }
  }

  @override
  void dispose() {
    _d.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(_d.largura, _d.alturaLinha), painter: _LetreiroPainter(_d));
}

/// Pedaços do letreiro já medidos: texto (traço + recorte, ou cheio) e estrelas.
class _Desenho {
  _Desenho(LetreiroNeon w)
      : cor = w.cor,
        vazado = w.vazado,
        traco = w.traco,
        raioEstrela = w.tamanho * .36 {
    final base = TextStyle(
      fontFamily: _t.fonteDisplay,
      fontWeight: FontWeight.w800,
      fontSize: w.tamanho,
      height: w.altura,
    );
    final partes = w.texto.split('✦');
    var x = 0.0;
    var voltas = 0;
    do {
      for (var i = 0; i < partes.length; i++) {
        final txt = partes[i];
        if (txt.isNotEmpty) {
          final desenho = _pintor(
              txt,
              base.copyWith(
                color: vazado ? null : cor,
                foreground: vazado
                    ? (Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = traco * 2
                      ..color = cor)
                    : null,
              ));
          final corte = vazado
              ? _pintor(
                  txt,
                  base.copyWith(
                    foreground: Paint()
                      ..color = const Color(0xFF000000)
                      ..blendMode = BlendMode.dstOut,
                  ))
              : null;
          textos.add((x, desenho, corte));
          x += desenho.width;
          alturaLinha = math.max(alturaLinha, desenho.height);
          linhaBase = desenho.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        }
        if (i < partes.length - 1) {
          estrelas.add(x + raioEstrela + w.tamanho * .06);
          x += raioEstrela * 2 + w.tamanho * .12;
        }
      }
      voltas++;
    } while (x < w.repetirAte && voltas < 40);
    largura = x;
    centroEstrela = linhaBase - w.tamanho * .36;
  }

  static TextPainter _pintor(String t, TextStyle s) =>
      TextPainter(text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr, maxLines: 1)..layout();

  final Color cor;
  final bool vazado;
  final double traco;
  final double raioEstrela;
  final textos = <(double, TextPainter, TextPainter?)>[];
  final estrelas = <double>[];
  double largura = 0;
  double alturaLinha = 0;
  double linhaBase = 0;
  double centroEstrela = 0;

  Path estrela(double cx) {
    final r = raioEstrela;
    final cy = centroEstrela;
    final k = r * .14;
    return Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
      ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
      ..close();
  }

  void dispose() {
    for (final (_, a, b) in textos) {
      a.dispose();
      b?.dispose();
    }
  }
}

class _LetreiroPainter extends CustomPainter {
  _LetreiroPainter(this.d);
  final _Desenho d;

  @override
  void paint(Canvas c, Size s) {
    if (d.vazado) {
      c.saveLayer((Offset.zero & s).inflate(d.traco * 2), Paint());
    }
    for (final (x, desenho, corte) in d.textos) {
      desenho.paint(c, Offset(x, 0));
      corte?.paint(c, Offset(x, 0));
    }
    for (final cx in d.estrelas) {
      final p = d.estrela(cx);
      if (d.vazado) {
        c.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = d.traco * 2
              ..color = d.cor);
        c.drawPath(
            p,
            Paint()
              ..color = const Color(0xFF000000)
              ..blendMode = BlendMode.dstOut);
      } else {
        c.drawPath(p, Paint()..color = d.cor);
      }
    }
    if (d.vazado) c.restore();
  }

  @override
  bool shouldRepaint(_LetreiroPainter o) => !identical(o.d, d);
}
