import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// A senha "conta" de 000 até o valor em ~1 s. Sem animação — ou senha que não é número
/// (ex.: com letra de série) — mostra direto.
class ContagemSenha extends StatefulWidget {
  const ContagemSenha({
    super.key,
    required this.senha,
    required this.estilo,
    this.mov = Movimento.parado,
  });

  final String senha;
  final TextStyle estilo;
  final Movimento mov;

  @override
  State<ContagemSenha> createState() => _ContagemSenhaState();
}

class _ContagemSenhaState extends State<ContagemSenha> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final int? _alvo = int.tryParse(widget.senha);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(1000));
    if (widget.mov.anima && _alvo != null) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alvo = _alvo;
    if (!widget.mov.anima || alvo == null) {
      return Text(widget.senha, key: const ValueKey('senha'), style: widget.estilo);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = (alvo * Curves.easeOutCubic.transform(_c.value)).round();
        final texto = _c.isCompleted ? widget.senha : '$v'.padLeft(widget.senha.length, '0');
        return Text(texto, key: const ValueKey('senha'), style: widget.estilo);
      },
    );
  }
}

/// Recibo que "sai" da fenda da impressora em degraus (2,4 s). Só é mostrado quando o
/// comprovante foi impresso. O conteúdo é ilustrativo: nome da loja e a senha.
class ReciboImpresso extends StatefulWidget {
  const ReciboImpresso({
    super.key,
    required this.senha,
    required this.tokens,
    this.nomeLoja,
    this.mov = Movimento.parado,
    this.corFenda,
  });

  final String senha;
  final String? nomeLoja;
  final TemplateTokens tokens;
  final Movimento mov;
  final Color? corFenda;

  @override
  State<ReciboImpresso> createState() => _ReciboImpressoState();
}

class _ReciboImpressoState extends State<ReciboImpresso> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(2400));
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
    final t = widget.tokens;
    final largura = context.dz(320);
    final altura = context.dz(190);
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: context.dz(15),
      color: const Color(0xFF222222),
      height: 1.35,
    );
    return Column(key: const ValueKey('recibo'), mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: largura * 1.2,
        height: context.dz(16),
        decoration: BoxDecoration(
          color: widget.corFenda ?? t.surface2,
          borderRadius: BorderRadius.circular(context.dz(8)),
        ),
      ),
      AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // Sai em 6 degraus, como papel empurrado pela guilhotina.
          final degraus = (_c.value * 6).ceil() / 6;
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: degraus.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: largura,
          height: altura,
          padding: EdgeInsets.symmetric(horizontal: context.dz(20), vertical: context.dz(14)),
          color: const Color(0xFFFFFFFF),
          child: Column(children: [
            Text((widget.nomeLoja ?? '').toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: mono.copyWith(fontWeight: FontWeight.w700)),
            Text('SENHA ${widget.senha}', style: mono.copyWith(fontSize: context.dz(22), fontWeight: FontWeight.w700)),
            const Spacer(),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(top: context.dz(6)),
                child: Container(height: context.dz(4), color: const Color(0xFFDDDDDD)),
              ),
          ]),
        ),
      ),
    ]);
  }
}

/// Confete: 170 peças, gravidade 0,55, 230 quadros, num único `CustomPainter` com a lista
/// alocada uma vez (docs/templates/00 §3.4). Só com [Movimento.particulas].
class Confete extends StatefulWidget {
  const Confete({super.key, required this.cores, this.mov = Movimento.parado, this.pecas = 170});
  final List<Color> cores;
  final Movimento mov;
  final int pecas;

  @override
  State<Confete> createState() => _ConfeteState();
}

class _Peca {
  _Peca(math.Random r, this.cor)
      : x = .5 + (r.nextDouble() - .5) * .3,
        y = .35,
        vx = (r.nextDouble() - .5) * 26,
        vy = -12 - r.nextDouble() * 22,
        giro = r.nextDouble() * math.pi,
        vgiro = (r.nextDouble() - .5) * .4,
        w = 10 + r.nextDouble() * 12,
        h = 6 + r.nextDouble() * 8;
  double x, y, vx, vy, giro, vgiro;
  final double w, h;
  final Color cor;
}

class _ConfeteState extends State<Confete> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _quadro = ValueNotifier<int>(0);
  late final List<_Peca> _pecas;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    _pecas = [
      for (var i = 0; i < widget.pecas; i++) _Peca(r, widget.cores[i % widget.cores.length]),
    ];
    if (widget.mov.particulas && widget.mov.anima) {
      _ticker = createTicker((_) {
        if (_quadro.value >= 230) {
          _ticker?.stop();
          return;
        }
        _quadro.value++;
      })
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _quadro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ticker == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('confete'),
        size: Size.infinite,
        painter: _ConfetePainter(_pecas, _quadro, context.k),
      ),
    );
  }
}

class _ConfetePainter extends CustomPainter {
  _ConfetePainter(this.pecas, this.quadro, this.k) : super(repaint: quadro);
  final List<_Peca> pecas;
  final ValueNotifier<int> quadro;
  final double k;
  final _p = Paint();

  @override
  void paint(Canvas c, Size s) {
    final fim = quadro.value >= 230;
    for (final p in pecas) {
      if (!fim) {
        p.vy += .55;
        p.vx *= .99;
        p.x += p.vx / s.width;
        p.y += p.vy / s.height;
        p.giro += p.vgiro;
      }
      if (p.y > 1.1) continue;
      _p.color = p.cor;
      c.save();
      c.translate(p.x * s.width, p.y * s.height);
      c.rotate(p.giro);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.w * k, height: p.h * k), _p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Selo de check com anel pulsando (o "Pagamento aprovado" dos templates).
class CheckPulsante extends StatefulWidget {
  const CheckPulsante({
    super.key,
    required this.cor,
    required this.tinta,
    this.mov = Movimento.parado,
    this.tamanho = 190,
    this.icone = Icons.check_rounded,
  });
  final Color cor;
  final Color tinta;
  final Movimento mov;

  /// Diâmetro em px de desenho.
  final double tamanho;
  final IconData icone;

  @override
  State<CheckPulsante> createState() => _CheckPulsanteState();
}

class _CheckPulsanteState extends State<CheckPulsante> with TickerProviderStateMixin {
  late final AnimationController _pop;
  late final AnimationController _anel;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: widget.mov.d(600));
    _anel = AnimationController(vsync: this, duration: widget.mov.d(1800));
    if (widget.mov.anima) {
      _pop.forward();
      _anel.repeat();
    } else {
      _pop.value = 1;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _anel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = context.dz(widget.tamanho);
    return SizedBox(
      width: d * 1.6,
      height: d * 1.6,
      child: Stack(alignment: Alignment.center, children: [
        if (widget.mov.anima)
          AnimatedBuilder(
            animation: _anel,
            builder: (_, __) => Container(
              width: d * (1 + .55 * _anel.value),
              height: d * (1 + .55 * _anel.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.cor.withAlpha((200 * (1 - _anel.value)).round()),
                  width: context.dz(6),
                ),
              ),
            ),
          ),
        ScaleTransition(
          scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(color: widget.cor, shape: BoxShape.circle),
            child: Icon(widget.icone, size: d * .55, color: widget.tinta),
          ),
        ),
      ]),
    );
  }
}
