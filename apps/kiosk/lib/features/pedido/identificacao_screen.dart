import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/cpf.dart';
import '../../domain/order/cart.dart';
import '../../widgets/numpad.dart';

/// CPF na nota — opcional. "PULAR" segue sem CPF; com CPF, só avança se os
/// dígitos verificadores baterem.
class IdentificacaoScreen extends ConsumerStatefulWidget {
  const IdentificacaoScreen({super.key});
  @override
  ConsumerState<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends ConsumerState<IdentificacaoScreen> {
  String _cpf = '';
  bool get _completo => _cpf.length == 11;
  bool get _valido => cpfValido(_cpf);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.go('/carrinho'),
                icon: const Icon(Icons.arrow_back, color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Text('CPF NA NOTA?', style: t.headlineMedium),
            ]),
          ),
          const SizedBox(height: 24),
          Text(_cpf.isEmpty ? '___.___.___-__' : formatCpf(_cpf),
              key: const ValueKey('cpf-display'),
              style: t.displayLarge?.copyWith(
                  fontSize: 40,
                  color: _completo
                      ? (_valido ? GogemColors.mint : GogemColors.heat)
                      : GogemColors.ink)),
          if (_completo && !_valido)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('CPF inválido — confira os dígitos',
                  style: TextStyle(color: GogemColors.heat, fontSize: 16)),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: NumPad(
                onDigito: (d) => setState(() {
                  if (_cpf.length < 11) _cpf += d;
                }),
                onApagar: () => setState(() {
                  if (_cpf.isNotEmpty) _cpf = _cpf.substring(0, _cpf.length - 1);
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('pular'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 68),
                    side: const BorderSide(color: GogemColors.line),
                    foregroundColor: GogemColors.ink,
                  ),
                  onPressed: () {
                    ref.read(checkoutProvider.notifier).setCpf('');
                    context.go('/pagamento');
                  },
                  child: const Text('PULAR'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('confirmar-cpf'),
                  onPressed: _completo && _valido
                      ? () {
                          ref.read(checkoutProvider.notifier).setCpf(_cpf);
                          context.go('/pagamento');
                        }
                      : null,
                  child: const Text('CONFIRMAR'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
