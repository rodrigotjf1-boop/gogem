import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart';
import '../../widgets/gogem_robot.dart';
import '../gogen/gogen_sucesso.dart';

/// Pedido confirmado: o robô "imprime" (paperExtent 0→1, animação única — sem
/// loop, seguro para pumpAndSettle) e a SENHA aparece em fonte gigante.
/// Auto-retorno ao descanso em 40s com CONTADOR VISÍVEL (a senha fica visível
/// mesmo se a impressora falhar). Em `dinheiro`, guia o cliente ao caixa.
class ConfirmacaoScreen extends ConsumerStatefulWidget {
  const ConfirmacaoScreen(
      {super.key,
      required this.senha,
      this.impresso = true,
      this.dinheiro = false});
  final String senha;
  final bool impresso;

  /// Pagamento em dinheiro: exibe a orientação de pagar no caixa.
  final bool dinheiro;
  @override
  ConsumerState<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends ConsumerState<ConfirmacaoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _print = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  static const int _totalSeg = 40;
  int _segundos = _totalSeg;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Contador decrescente (40s) até voltar ao descanso — visível na tela.
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _segundos = _segundos > 0 ? _segundos - 1 : 0);
      if (_segundos <= 0) {
        t.cancel();
        context.go('/descanso');
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _print.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    if (ap.gogen) {
      return AnimatedBuilder(
        animation: _print,
        builder: (_, __) => GogenSucessoView(
          senha: widget.senha,
          impresso: widget.impresso,
          entrada: _print.value,
          dinheiro: widget.dinheiro,
          segundos: _segundos,
          onNovoPedido: () => context.go('/descanso'),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        // Rola se o conteúdo (senha gigante + aviso opcional) exceder telas
        // baixas; centraliza quando cabe. Mantém tudo na árvore (findável).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
            AnimatedBuilder(
              animation: _print,
              builder: (_, __) => GogemRobot(size: 260, paperExtent: _print.value),
            ),
            const SizedBox(height: 24),
            Text('PEDIDO CONFIRMADO!', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text('retire pelo número', style: t.bodyMedium),
            if (widget.dinheiro)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Container(
                  key: const ValueKey('aviso-caixa'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: GogemColors.cheese.withValues(alpha: 0.12),
                    border: Border.all(color: GogemColors.cheese, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.point_of_sale,
                        color: GogemColors.cheese, size: 40),
                    const SizedBox(height: 8),
                    Text('PAGUE NO CAIXA PARA RETIRAR',
                        style: t.titleLarge?.copyWith(
                            color: GogemColors.ink,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('dirija-se ao caixa, informe a senha e efetue o pagamento',
                        textAlign: TextAlign.center,
                        style: t.bodyMedium?.copyWith(
                            color: GogemColors.inkDim)),
                  ]),
                ),
              ),
            if (!widget.impresso)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  key: const ValueKey('aviso-sem-cupom'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: GogemColors.heat),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                      'cupom nao impresso — ANOTE A SENHA e informe o balcao',
                      style: TextStyle(color: GogemColors.heat, fontSize: 16)),
                ),
              ),
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
            const SizedBox(height: 4),
            Text('voltando ao início em ${_segundos}s',
                key: const ValueKey('contador-standby'),
                style: t.bodyMedium?.copyWith(color: GogemColors.inkDim)),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
