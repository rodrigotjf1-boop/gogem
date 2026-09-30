import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/util/moeda.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// QR do PIX num quadro branco, cantos na cor do acento e uma linha de varredura que sobe
/// e desce (2,2 s, só com animação) — docs/templates/00 §3.5.
class QrPix extends StatefulWidget {
  const QrPix({
    super.key,
    required this.copiaECola,
    required this.tokens,
    this.mov = Movimento.parado,
    this.lado = 600,
    this.cantos,
  });

  final String copiaECola;
  final TemplateTokens tokens;
  final Movimento mov;

  /// Lado do QR em px de desenho.
  final double lado;
  final Color? cantos;

  @override
  State<QrPix> createState() => _QrPixState();
}

class _QrPixState extends State<QrPix> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(2200));
    if (widget.mov.anima) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.cantos ?? widget.tokens.accent;
    final lado = context.dz(widget.lado);
    final pad = context.dz(40);
    return SizedBox(
      width: lado + pad * 2,
      height: lado + pad * 2,
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(context.dz(40)),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _Cantos(cor, context.dz(9), context.dz(90)))),
        Positioned(
          left: pad,
          top: pad,
          child: QrImageView(
            key: const ValueKey('pix-qr'),
            data: widget.copiaECola,
            size: lado,
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xFFFFFFFF),
          ),
        ),
        if (widget.mov.anima)
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Positioned(
              left: pad * .6,
              right: pad * .6,
              top: pad + lado * Curves.easeInOut.transform(_c.value) - context.dz(3),
              child: Container(
                height: context.dz(6),
                decoration: BoxDecoration(
                  color: cor,
                  boxShadow: [BoxShadow(color: cor.withAlpha(140), blurRadius: context.dz(18))],
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Cantos extends CustomPainter {
  _Cantos(this.cor, this.esp, this.tam);
  final Color cor;
  final double esp;
  final double tam;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round;
    final m = esp / 2;
    void canto(Offset o, double dx, double dy) {
      c.drawLine(o, o + Offset(tam * dx, 0), p);
      c.drawLine(o, o + Offset(0, tam * dy), p);
    }

    canto(Offset(m, m), 1, 1);
    canto(Offset(s.width - m, m), -1, 1);
    canto(Offset(m, s.height - m), 1, -1);
    canto(Offset(s.width - m, s.height - m), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _Cantos o) => o.cor != cor || o.esp != esp;
}

/// "Aguardando pagamento" com três pontos que acendem em sequência.
class PontosAguardando extends StatefulWidget {
  const PontosAguardando({
    super.key,
    required this.tokens,
    this.mov = Movimento.parado,
    this.texto = 'Aguardando pagamento',
  });
  final TemplateTokens tokens;
  final Movimento mov;
  final String texto;

  @override
  State<PontosAguardando> createState() => _PontosAguardandoState();
}

class _PontosAguardandoState extends State<PontosAguardando> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.mov.anima) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final d = context.dz(12);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: d,
              height: d,
              margin: EdgeInsets.only(right: context.dz(8)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent.withAlpha(
                  widget.mov.anima
                      ? (90 + 165 * (0.5 + 0.5 * math.sin((_c.value - i / 3) * 2 * math.pi))).round().clamp(0, 255)
                      : 255,
                ),
              ),
            ),
        ]),
      ),
      SizedBox(width: context.dz(8)),
      Text(widget.texto, style: t.texto(context.dz(26), cor: t.muted)),
    ]);
  }
}

/// Maquininha desenhada em widgets (sem imagem): corpo escuro, tela clara com o total e
/// teclado; um cartão se aproxima em loop (2,6 s), com ondas de aproximação. É mostrada
/// quando o pagamento está na Point.
class MaquininhaAnimada extends StatefulWidget {
  const MaquininhaAnimada({
    super.key,
    required this.totalCentavos,
    required this.tokens,
    this.mov = Movimento.parado,
    this.corCartao,
    this.corTela = const Color(0xFFD9F2E3),
    this.corCorpo = const Color(0xFF26292E),
    this.largura = 380,
  });

  final int totalCentavos;
  final TemplateTokens tokens;
  final Movimento mov;
  final Color? corCartao;
  final Color corTela;
  final Color corCorpo;

  /// Largura do corpo em px de desenho (altura = 1,58 × largura).
  final double largura;

  @override
  State<MaquininhaAnimada> createState() => _MaquininhaAnimadaState();
}

class _MaquininhaAnimadaState extends State<MaquininhaAnimada> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(2600));
    if (widget.mov.anima) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final w = context.dz(widget.largura);
    final h = w * 1.58;
    final cartao = widget.corCartao ?? t.accent;
    return SizedBox(
      key: const ValueKey('maquininha'),
      width: w * 1.9,
      height: h * 1.05,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: w * .2,
          top: 0,
          child: Container(
            width: w,
            height: h,
            padding: EdgeInsets.all(w * .08),
            decoration: BoxDecoration(
              color: widget.corCorpo,
              borderRadius: BorderRadius.circular(w * .14),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 16))],
            ),
            child: Column(children: [
              Container(
                height: h * .3,
                width: double.infinity,
                padding: EdgeInsets.all(w * .06),
                decoration: BoxDecoration(
                  color: widget.corTela,
                  borderRadius: BorderRadius.circular(w * .06),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatCentavos(widget.totalCentavos),
                      style: t.texto(w * .14, peso: FontWeight.w800, cor: const Color(0xFF1B2A22))),
                ),
              ),
              SizedBox(height: h * .05),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: w * .05,
                  crossAxisSpacing: w * .05,
                  childAspectRatio: 1.25,
                  children: [
                    for (var i = 1; i <= 9; i++)
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3E45),
                          borderRadius: BorderRadius.circular(w * .04),
                        ),
                        child: Text('$i',
                            style: t.texto(w * .07, peso: FontWeight.w700, cor: const Color(0xFFCFD3DA))),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            // Aproxima (0→.45), encosta (.45→.7), recua (.7→1).
            final v = _c.value;
            final ida = widget.mov.anima
                ? (v < .45 ? Curves.easeOut.transform(v / .45) : v < .7 ? 1.0 : 1 - Curves.easeIn.transform((v - .7) / .3))
                : 1.0;
            return Stack(clipBehavior: Clip.none, children: [
              if (widget.mov.anima && v > .35 && v < .8)
                for (var k = 0; k < 3; k++)
                  Positioned(
                    left: w * .95 - k * w * .08,
                    top: h * .12 - k * w * .08,
                    child: Opacity(
                      opacity: ((1 - k / 3) * (1 - ((v - .35) / .45 - .5).abs() * 2)).clamp(0.0, 1.0),
                      child: Container(
                        width: w * (.5 + k * .16),
                        height: w * (.5 + k * .16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cartao.withAlpha(120), width: w * .012),
                        ),
                      ),
                    ),
                  ),
              Positioned(
                left: w * (1.25 - .35 * ida),
                top: h * (.05 + .08 * (1 - ida)),
                child: Transform.rotate(
                  angle: -math.pi / 14 * (1 - ida) - math.pi / 28,
                  child: Container(
                    width: w * .8,
                    height: w * .5,
                    padding: EdgeInsets.all(w * .06),
                    decoration: BoxDecoration(
                      color: cartao,
                      borderRadius: BorderRadius.circular(w * .06),
                      boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: w * .14,
                        height: w * .1,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2C14E),
                          borderRadius: BorderRadius.circular(w * .02),
                        ),
                      ),
                      const Spacer(),
                      Text('•••• •••• 4417',
                          style: t.texto(w * .055, peso: FontWeight.w800, cor: t.onAccent)),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}
