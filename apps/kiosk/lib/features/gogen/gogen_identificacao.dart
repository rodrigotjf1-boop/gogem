import 'package:flutter/material.dart';
import '../../core/util/cpf.dart';
import '../../widgets/numpad.dart';
import 'gogen_tokens.dart';

/// Identificação (nome + CPF) no visual **GoGen**. VIEW PURA: recebe o
/// controller do nome, o CPF atual e os callbacks do `IdentificacaoScreen`
/// (mesma validação de CPF e navegação).
class GogenIdentificacaoView extends StatelessWidget {
  const GogenIdentificacaoView({
    super.key,
    required this.nomeController,
    required this.cpf,
    required this.completo,
    required this.valido,
    required this.onDigito,
    required this.onApagar,
    required this.onPular,
    required this.onConfirmar,
    required this.onVoltar,
  });

  final TextEditingController nomeController;
  final String cpf;
  final bool completo;
  final bool valido;
  final void Function(String) onDigito;
  final VoidCallback onApagar;
  final VoidCallback onPular;
  final VoidCallback onConfirmar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final corCpf = completo ? (valido ? GogenColors.ok : GogenColors.flame1) : GogenColors.ink;
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: onVoltar,
                icon: const Icon(Icons.arrow_back_rounded, color: GogenColors.ink, size: 30),
              ),
              const SizedBox(width: 4),
              const Text('Seus dados',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              key: const ValueKey('nome-cliente'),
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20, color: GogenColors.ink),
              decoration: InputDecoration(
                labelText: 'Seu nome (para chamar o pedido)',
                labelStyle: const TextStyle(color: GogenColors.ink2),
                filled: true,
                fillColor: GogenColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: GogenColors.flame2, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('CPF na nota?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: GogenColors.ink2)),
          const SizedBox(height: 10),
          Text(cpf.isEmpty ? '___.___.___-__' : formatCpf(cpf),
              key: const ValueKey('cpf-display'),
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 38, letterSpacing: 1, color: corCpf)),
          if (completo && !valido)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('CPF inválido — confira os dígitos',
                  style: TextStyle(color: GogenColors.flame1, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: FittedBox(
                child: NumPad(onDigito: onDigito, onApagar: onApagar),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('pular'),
                    onPressed: onPular,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 64),
                      foregroundColor: GogenColors.ink,
                      side: const BorderSide(color: Color(0x1A000000), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                    ),
                    child: const Text('Pular'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Opacity(
                    opacity: (completo && valido) ? 1 : 0.4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('confirmar-cpf'),
                        onTap: (completo && valido) ? onConfirmar : null,
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          decoration: BoxDecoration(
                              gradient: GogenColors.grad, borderRadius: BorderRadius.circular(999)),
                          child: Container(
                            height: 64,
                            alignment: Alignment.center,
                            child: const Text('Confirmar',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
