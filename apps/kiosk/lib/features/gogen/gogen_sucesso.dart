import 'package:flutter/material.dart';
import 'gogen_tokens.dart';

/// Tela de sucesso no visual **GoGen**: selo flame com check, senha GIGANTE em
/// gradiente e (se não imprimiu) o aviso pra anotar. VIEW PURA — o timer de
/// auto-retorno e a navegação ficam no `ConfirmacaoScreen`.
class GogenSucessoView extends StatelessWidget {
  const GogenSucessoView({
    super.key,
    required this.senha,
    required this.impresso,
    required this.entrada, // 0..1 (anima de escala/opacidade)
    required this.onNovoPedido,
    this.dinheiro = false,
    this.segundos = 0,
  });

  final String senha;
  final bool impresso;
  final double entrada;
  final VoidCallback onNovoPedido;

  /// Pagamento em dinheiro: exibe a orientação de pagar no caixa.
  final bool dinheiro;

  /// Segundos restantes para voltar ao descanso (0 = não exibe o contador).
  final int segundos;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutBack.transform(entrada.clamp(0, 1));
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.6 + 0.4 * e,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: const BoxDecoration(
                          gradient: GogenColors.grad,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x66FF5A1F), blurRadius: 40, offset: Offset(0, 16)),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 78),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Pedido confirmado!',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 34, color: GogenColors.ink)),
                    const SizedBox(height: 6),
                    const Text('retire pelo número',
                        style: TextStyle(fontSize: 18, color: GogenColors.ink2)),
                    if (dinheiro)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                        child: Container(
                          key: const ValueKey('aviso-caixa'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: GogenColors.flame1.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: GogenColors.flame1, width: 2),
                          ),
                          child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.point_of_sale_rounded,
                                    color: GogenColors.flame1, size: 40),
                                SizedBox(height: 8),
                                Text('PAGUE NO CAIXA PARA RETIRAR',
                                    style: TextStyle(
                                        color: GogenColors.ink,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900)),
                                SizedBox(height: 4),
                                Text(
                                    'dirija-se ao caixa, informe a senha e efetue o pagamento',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: GogenColors.ink2,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ]),
                        ),
                      ),
                    if (!impresso)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          key: const ValueKey('aviso-sem-cupom'),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: GogenColors.flame1.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GogenColors.flame1),
                          ),
                          child: const Text(
                            'cupom não impresso — ANOTE A SENHA e informe o balcão',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GogenColors.flame1, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: entrada.clamp(0, 1),
                      child: ShaderMask(
                        shaderCallback: (r) => GogenColors.grad.createShader(r),
                        child: Text(
                          senha,
                          key: const ValueKey('senha'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 128,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextButton(
                      onPressed: onNovoPedido,
                      child: const Text('Novo pedido',
                          style: TextStyle(color: GogenColors.ink2, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if (segundos > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('voltando ao início em ${segundos}s',
                            key: const ValueKey('contador-standby'),
                            style: const TextStyle(
                                color: GogenColors.ink2, fontSize: 15)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
