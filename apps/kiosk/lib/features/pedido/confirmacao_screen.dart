import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../widgets/gogem_robot.dart';

/// Pedido confirmado: o robô "imprime" (paperExtent 0→1, animação única — sem
/// loop, seguro para pumpAndSettle) e a SENHA aparece em fonte gigante.
/// Auto-retorno ao descanso em 8s (regra da tela: senha visível mesmo se a
/// impressora falhar — antecipa o comportamento da F4).
class ConfirmacaoScreen extends StatefulWidget {
  const ConfirmacaoScreen({super.key, required this.senha});
  final String senha;
  @override
  State<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends State<ConfirmacaoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _print = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();
  Timer? _volta;

  @override
  void initState() {
    super.initState();
    _volta = Timer(const Duration(seconds: 8), () {
      if (mounted) context.go('/descanso');
    });
  }

  @override
  void dispose() {
    _volta?.cancel();
    _print.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _print,
              builder: (_, __) => GogemRobot(size: 260, paperExtent: _print.value),
            ),
            const SizedBox(height: 24),
            Text('PEDIDO CONFIRMADO!', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text('retire pelo número', style: t.bodyMedium),
            const SizedBox(height: 12),
            Text(widget.senha,
                key: const ValueKey('senha'),
                style: t.displayLarge?.copyWith(
                    fontSize: 120, color: GogemColors.cheese, height: 1)),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => context.go('/descanso'),
              child: const Text('NOVO PEDIDO',
                  style: TextStyle(color: GogemColors.inkDim, fontSize: 18)),
            ),
          ]),
        ),
      ),
    );
  }
}
