import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/order/cart.dart';

/// Desde quando há uma VENDA em andamento (cobrança na maquininha/PIX, confirmação com o
/// servidor, emissão da nota, impressão). `null` = nenhuma.
///
/// Durante a venda o cliente não toca na tela — paga no celular, na maquininha, espera a
/// nota. Sem esta marca, o retorno por inatividade (90 s sem toque) levava o totem ao
/// descanso NO MEIO da venda: a tela de pagamento era descartada e a finalização, que ainda
/// ia marcar o pedido pago, enviá-lo e imprimir, morria no primeiro `ref.read` (ERR-021).
final vendaEmAndamentoDesdeProvider = StateProvider<DateTime?>((ref) => null);

/// Teto da suspensão: PIX (5 min) + confirmação (45 s) + folga. Se a marca ficar presa
/// (tela descartada sem limpá-la), o totem não fica para sempre fora do descanso.
const tetoVendaEmAndamento = Duration(minutes: 8);

/// Idle inteligente (F4): sem toque por [limite] no meio de um pedido → volta ao descanso
/// e limpa carrinho/checkout (o próximo cliente começa do zero). NUNCA durante uma venda.
class InatividadeGuard extends ConsumerStatefulWidget {
  const InatividadeGuard({
    super.key,
    required this.child,
    required this.aoExpirar,
    this.limite = const Duration(seconds: 90),
    this.agora = DateTime.now,
  });
  final Widget child;

  /// O que fazer ao expirar (no app: ir para /descanso).
  final VoidCallback aoExpirar;
  final Duration limite;
  final DateTime Function() agora;

  @override
  ConsumerState<InatividadeGuard> createState() => _InatividadeGuardState();
}

class _InatividadeGuardState extends ConsumerState<InatividadeGuard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _reset() {
    _t?.cancel();
    _t = Timer(widget.limite, _expirou);
  }

  void _expirou() {
    final desde = ref.read(vendaEmAndamentoDesdeProvider);
    if (desde != null &&
        widget.agora().difference(desde) < tetoVendaEmAndamento) {
      _reset(); // venda em andamento: volta a contar do zero
      return;
    }
    // Ir para /descanso é seguro em qualquer rota (o redirect trata /parear;
    // /descanso→/descanso é no-op). Limpa o pedido em andamento.
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    widget.aoExpirar();
  }

  @override
  Widget build(BuildContext context) {
    // Começou ou terminou uma venda: a contagem recomeça do zero. Sem isto, o prazo que já
    // vinha correndo durante a venda podia vencer 1 s depois dela — e a confirmação, com a
    // senha do cliente, sumia da tela antes de ele ler.
    ref.listen(vendaEmAndamentoDesdeProvider, (_, __) => _reset());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      child: widget.child,
    );
  }
}
