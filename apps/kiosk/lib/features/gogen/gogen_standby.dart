import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'gogen_tokens.dart';

/// Atrator (standby) do template **GoGen**: fundo quente com brasas subindo,
/// herói central (logo/nome), isca de preço e "toque para começar" pulsante com
/// um ticker de chamadas. Só visual — os PORTÕES (saúde da impressora, canto
/// admin, auto-update) continuam no `DescansoScreen`, que renderiza isto como
/// camada de fundo. Respeita `anima` (reduzido/off desliga as brasas).
class GogenStandby extends StatefulWidget {
  const GogenStandby({
    super.key,
    this.nomeLoja,
    this.logoUrl,
    required this.chamada,
    this.precoIsca,
    this.anima = true,
  });

  final String? nomeLoja;
  final String? logoUrl;
  final String chamada;
  final String? precoIsca;
  final bool anima;

  @override
  State<GogenStandby> createState() => _GogenStandbyState();
}

class _GogenStandbyState extends State<GogenStandby>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Brasa> _brasas;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    if (widget.anima) _c.repeat();
    // Conjunto fixo de brasas (semente fixa → estável em teste e sem "pisca").
    final r = math.Random(42);
    _brasas = List.generate(
      28,
      (_) => _Brasa(
        x: r.nextDouble(),
        fase: r.nextDouble(),
        vel: 0.5 + r.nextDouble(),
        raio: 1.5 + r.nextDouble() * 3.5,
        deriva: (r.nextDouble() - 0.5) * 0.08,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo quente (radial flame no topo sobre "carvão" escuro).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.65),
              radius: 1.25,
              colors: [Color(0xFF3A1B0C), Color(0xFF1B1008), Color(0xFF120A06)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        // Brasas subindo (CustomPainter animado).
        if (widget.anima)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _BrasasPainter(brasas: _brasas, t: _c.value),
              ),
            ),
          ),
        // Conteúdo central.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Heroi(logoUrl: widget.logoUrl, nomeLoja: widget.nomeLoja),
              const SizedBox(height: 28),
              if (widget.precoIsca != null) ...[
                _IscaFlame(texto: widget.precoIsca!),
                const SizedBox(height: 20),
              ],
              ShaderMask(
                shaderCallback: (r) => GogenColors.grad.createShader(r),
                child: Text(
                  widget.chamada.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 52,
                    height: 1.05,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'rápido · sem fila · do seu jeito',
                style: TextStyle(fontSize: 20, color: Color(0xFFE9D6C4)),
              ),
              const SizedBox(height: 40),
              _TocarPulse(anima: widget.anima),
            ],
          ),
        ),
        // Ticker de chamadas no rodapé.
        Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: _Ticker(controller: _c, anima: widget.anima),
        ),
      ],
    );
  }
}

class _Heroi extends StatelessWidget {
  const _Heroi({this.logoUrl, this.nomeLoja});
  final String? logoUrl;
  final String? nomeLoja;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            gradient: GogenColors.grad,
            borderRadius: BorderRadius.circular(44),
            boxShadow: const [
              BoxShadow(color: Color(0x80FF5A1F), blurRadius: 60, offset: Offset(0, 24)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: (logoUrl != null && logoUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: logoUrl!,
                  fit: BoxFit.cover,
                  width: 168,
                  height: 168,
                  errorWidget: (_, __, ___) => const Text('🔥', style: TextStyle(fontSize: 76)),
                )
              : const Text('🔥', style: TextStyle(fontSize: 76)),
        ),
        if (nomeLoja != null && nomeLoja!.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            nomeLoja!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 40,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

class _IscaFlame extends StatelessWidget {
  const _IscaFlame({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GogenColors.flame3.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: GogenColors.flame3,
        ),
      ),
    );
  }
}

/// "Toque para começar" com um halo pulsante.
class _TocarPulse extends StatefulWidget {
  const _TocarPulse({required this.anima});
  final bool anima;
  @override
  State<_TocarPulse> createState() => _TocarPulseState();
}

class _TocarPulseState extends State<_TocarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.anima) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = widget.anima ? _c.value : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06 + 0.06 * v),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: GogenColors.flame2.withValues(alpha: 0.5 + 0.5 * v)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded, color: GogenColors.flame3, size: 26),
              SizedBox(width: 10),
              Text(
                'Toque para começar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ticker (marquee) de chamadas curtas deslizando no rodapé.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.controller, required this.anima});
  final AnimationController controller;
  final bool anima;

  static const _itens = [
    'MONTE DO SEU JEITO',
    'PAGUE NO TOTEM',
    'RETIRE COM SUA SENHA',
    'COMBOS QUENTINHOS',
    'SEM FILA',
  ];

  @override
  Widget build(BuildContext context) {
    final texto = _itens.join('   •   ');
    if (!anima) {
      return _faixa(
        child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: _estilo),
      );
    }
    return _faixa(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, __) {
            final w = MediaQuery.sizeOf(context).width;
            final dx = (0.5 - controller.value).abs() * 2; // 1→0→1
            return Transform.translate(
              offset: Offset(-w * (1 - dx) * 0.4, 0),
              child: Text('$texto   •   $texto',
                  maxLines: 1, softWrap: false, style: _estilo),
            );
          },
        ),
      ),
    );
  }

  static const _estilo = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 15,
    letterSpacing: 2,
    color: Color(0x99FFD9B0),
  );

  Widget _faixa({required Widget child}) => Container(
        height: 34,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: child,
      );
}

/// Uma brasa: posição/velocidade/tamanho normalizados (0..1 na largura/altura).
class _Brasa {
  const _Brasa({
    required this.x,
    required this.fase,
    required this.vel,
    required this.raio,
    required this.deriva,
  });
  final double x; // 0..1 posição horizontal base
  final double fase; // 0..1 deslocamento no ciclo
  final double vel; // multiplicador de velocidade
  final double raio; // px
  final double deriva; // deslocamento horizontal ao subir
}

class _BrasasPainter extends CustomPainter {
  _BrasasPainter({required this.brasas, required this.t});
  final List<_Brasa> brasas;
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in brasas) {
      // Progresso de subida (do rodapé ao topo), com fase por brasa.
      final p = (t * b.vel + b.fase) % 1.0;
      final y = size.height * (1 - p);
      final x = size.width * (b.x + b.deriva * p);
      // Some ao chegar no topo e no nascimento (fade nas pontas).
      final alpha = (math.sin(p * math.pi)).clamp(0.0, 1.0);
      final cor = Color.lerp(GogenColors.flame3, GogenColors.flame1, p)!
          .withValues(alpha: alpha * 0.85);
      final paint = Paint()
        ..color = cor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), b.raio, paint);
    }
  }

  @override
  bool shouldRepaint(_BrasasPainter old) => old.t != t;
}
