import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../../domain/order/conclusao_venda.dart';
import '../gogen/gogen_tokens.dart';

/// A compra NÃO se concluiu depois do pagamento aprovado — a NFC-e não foi emitida, o
/// sistema da loja recusou a venda, ou o cupom fiscal não imprimiu. O cliente precisa
/// saber três coisas: que não há pedido, o que aconteceu com o dinheiro, e o que fazer.
///
/// O motivo técnico aparece pequeno, para o atendente; o relatório guarda o mesmo texto.
/// Volta sozinha ao descanso em 40 s, como a confirmação.
class VendaNaoConcluidaScreen extends ConsumerStatefulWidget {
  const VendaNaoConcluidaScreen({
    super.key,
    required this.etapa,
    required this.estorno,
    this.motivo = '',
    this.senha = '',
  });

  /// `recusada` | `impressao` | etapa fiscal do Regem (`rejeitada`, `sem_contingencia`…).
  final String etapa;
  final SituacaoEstorno estorno;
  final String motivo;
  final String senha;

  @override
  ConsumerState<VendaNaoConcluidaScreen> createState() =>
      _VendaNaoConcluidaScreenState();
}

class _VendaNaoConcluidaScreenState
    extends ConsumerState<VendaNaoConcluidaScreen> {
  static const int _totalSeg = 40;
  int _segundos = _totalSeg;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  String get _titulo => switch (widget.etapa) {
        'recusada' => 'NÃO FOI POSSÍVEL REGISTRAR O PEDIDO',
        'impressao' => 'O CUPOM FISCAL NÃO PÔDE SER IMPRESSO',
        _ => 'NÃO FOI POSSÍVEL EMITIR O CUPOM FISCAL',
      };

  String get _dinheiro => switch (widget.estorno) {
        SituacaoEstorno.feito =>
          'Seu pagamento foi ESTORNADO. O valor volta para o seu cartão ou conta '
              'em alguns dias.',
        SituacaoEstorno.pendente =>
          'O estorno do seu pagamento está sendo processado. Se preferir, fale com '
              'um atendente.',
        SituacaoEstorno.manual =>
          'Procure um atendente para receber o valor de volta.',
        SituacaoEstorno.semCobranca => 'Nada foi cobrado.',
      };

  @override
  Widget build(BuildContext context) {
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final gogen = ap.gogen;
    final fundo = gogen ? GogenColors.cream : GogemColors.bg;
    final tinta = gogen ? GogenColors.ink : GogemColors.ink;
    final tinta2 = gogen ? GogenColors.ink2 : GogemColors.inkDim;
    final alerta = gogen ? GogenColors.flame1 : GogemColors.heat;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: fundo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    key: const ValueKey('venda-nao-concluida'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: alerta, size: 88),
                      const SizedBox(height: 20),
                      Text(_titulo,
                          textAlign: TextAlign.center,
                          style: t.headlineMedium?.copyWith(color: tinta)),
                      const SizedBox(height: 12),
                      Text('A compra foi cancelada.',
                          textAlign: TextAlign.center,
                          style: t.titleLarge?.copyWith(color: tinta)),
                      const SizedBox(height: 16),
                      Container(
                        key: ValueKey('estorno-${widget.estorno.name}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: alerta, width: 2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_dinheiro,
                            textAlign: TextAlign.center,
                            style: t.titleMedium?.copyWith(color: tinta)),
                      ),
                      if (widget.motivo.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text('Detalhe para o atendente: ${widget.motivo}',
                            key: const ValueKey('motivo-tecnico'),
                            textAlign: TextAlign.center,
                            style: t.bodyMedium
                                ?.copyWith(color: tinta2, fontSize: 13)),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        key: const ValueKey('voltar-inicio'),
                        onPressed: () => context.go('/descanso'),
                        child: const Text('VOLTAR AO INÍCIO'),
                      ),
                      const SizedBox(height: 8),
                      Text('voltando ao início em ${_segundos}s',
                          style: t.bodyMedium?.copyWith(color: tinta2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
