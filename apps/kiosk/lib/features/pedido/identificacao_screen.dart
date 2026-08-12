import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/cpf.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../../domain/order/cart.dart';
import '../../widgets/numpad.dart';
import '../gogen/gogen_identificacao.dart';

/// CPF na nota — opcional. "PULAR" segue sem CPF; com CPF, só avança se os
/// dígitos verificadores baterem.
class IdentificacaoScreen extends ConsumerStatefulWidget {
  const IdentificacaoScreen({super.key});
  @override
  ConsumerState<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends ConsumerState<IdentificacaoScreen> {
  String _cpf = '';
  final _nomeCtrl = TextEditingController();
  bool get _completo => _cpf.length == 11;
  bool get _valido => cpfValido(_cpf);

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  /// Persiste o nome informado (opcional) no checkout antes de seguir.
  void _salvarNome() =>
      ref.read(checkoutProvider.notifier).setCliente(_nomeCtrl.text.trim());

  void _pular() {
    _salvarNome();
    ref.read(checkoutProvider.notifier).setCpf('');
    context.go('/pagamento');
  }

  void _confirmar() {
    _salvarNome();
    ref.read(checkoutProvider.notifier).setCpf(_cpf);
    context.go('/pagamento');
  }

  void _digito(String d) => setState(() {
        if (_cpf.length < 11) _cpf += d;
      });

  void _apagar() => setState(() {
        if (_cpf.isNotEmpty) _cpf = _cpf.substring(0, _cpf.length - 1);
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    if (ap.gogen) {
      return GogenIdentificacaoView(
        nomeController: _nomeCtrl,
        cpf: _cpf,
        completo: _completo,
        valido: _valido,
        onDigito: _digito,
        onApagar: _apagar,
        onPular: _pular,
        onConfirmar: _completo && _valido ? _confirmar : () {},
        onVoltar: () => context.go('/carrinho'),
      );
    }
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
              Text('SEUS DADOS', style: t.headlineMedium),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              key: const ValueKey('nome-cliente'),
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 22, color: GogemColors.ink),
              decoration: const InputDecoration(
                labelText: 'Seu nome (para chamar o pedido)',
                labelStyle: TextStyle(color: GogemColors.inkDim),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('CPF na nota?',
              style: t.titleLarge?.copyWith(color: GogemColors.inkDim)),
          const SizedBox(height: 12),
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
              // FittedBox: o teclado escala para caber em qualquer altura de
              // tela (totem alto = tamanho natural; telas baixas encolhem).
              child: FittedBox(
                child: NumPad(
                  onDigito: (d) => setState(() {
                    if (_cpf.length < 11) _cpf += d;
                  }),
                  onApagar: () => setState(() {
                    if (_cpf.isNotEmpty) {
                      _cpf = _cpf.substring(0, _cpf.length - 1);
                    }
                  }),
                ),
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
                    _salvarNome();
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
                          _salvarNome();
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
