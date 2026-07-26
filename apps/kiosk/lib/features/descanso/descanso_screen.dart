import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/hardware/hardware_profile.dart';
import '../../core/theme/gogem_theme.dart';
import '../../widgets/gogem_robot.dart';

/// Tela de descanso (atrator): robô flutuando + piscada, CTA de toque.
/// 5 toques no canto superior esquerdo abrem o portão administrativo.
class DescansoScreen extends ConsumerStatefulWidget {
  const DescansoScreen({super.key});
  @override
  ConsumerState<DescansoScreen> createState() => _DescansoScreenState();
}

class _DescansoScreenState extends ConsumerState<DescansoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  int _adminTaps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _tapAdminCorner() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > const Duration(seconds: 2)) _adminTaps = 0;
    _lastTap = now;
    if (++_adminTaps >= 5) {
      _adminTaps = 0;
      context.push('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(hardwareCapsProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/catalogo'),
        child: Stack(children: [
          // portão admin invisível (canto sup. esquerdo)
          Positioned(
            left: 0, top: 0, width: 96, height: 96,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _tapAdminCorner),
          ),
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedBuilder(
                animation: _idle,
                builder: (_, __) {
                  final v = _idle.value;
                  final dy = caps.animationScale *
                      -12 *
                      (0.5 - (v - 0.5).abs()) * 2; // flutuação triangular barata
                  // piscada dupla perto de v=0.55
                  double blink = 1;
                  for (final c in [0.55, 0.63]) {
                    final d = (v - c).abs();
                    if (d < 0.03) blink = (d / 0.03).clamp(0.1, 1.0);
                  }
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: GogemRobot(size: 300, blink: blink),
                  );
                },
              ),
              const SizedBox(height: 36),
              Text('TOQUE PARA PEDIR', style: t.displayLarge?.copyWith(fontSize: 46)),
              const SizedBox(height: 12),
              Text('rápido · sem fila · do seu jeito',
                  style: t.bodyMedium?.copyWith(fontSize: 20)),
              const SizedBox(height: 48),
              const _PulseDot(),
            ]),
          ),
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: Center(
              child: Text('GoGeM · by DMS',
                  style: t.bodyMedium?.copyWith(color: GogemColors.inkDim, fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 22 + 10 * _c.value,
          height: 22 + 10 * _c.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GogemColors.mint.withValues(alpha: 1 - _c.value * .8),
          ),
        ),
      );
}
