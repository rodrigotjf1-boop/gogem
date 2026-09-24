import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trava de cartão/PIX quando a nota fiscal falha em SÉRIE.
///
/// O Regem diz, em cada `nao_emitida`, se a próxima venda vai falhar igual (`repete`:
/// certificado vencido, CSC, emitente irregular, cadastro). Sem trava, cada cliente seguinte
/// pagaria, veria "nota não emitida" e esperaria o estorno — o totem cobrando e devolvendo
/// em série. O contrato manda o contrário: alertar o gestor em vez de estornar em série.
///
/// A regra é conservadora: DUAS falhas seguidas com `repete` travam cartão e PIX por
/// [duracao]; uma nota emitida zera a contagem. Uma falha só não trava — `repete` também
/// vale para o problema de UM produto (NCM), e a venda seguinte, sem ele, passa.
/// O dinheiro segue: a nota dele é emitida no caixa, não no totem.
class BloqueioFiscal {
  const BloqueioFiscal({this.falhasSeguidas = 0, this.ate, this.motivo});
  final int falhasSeguidas;
  final DateTime? ate;
  final String? motivo;

  bool travadoEm(DateTime agora) => ate != null && agora.isBefore(ate!);
}

class BloqueioFiscalNotifier extends Notifier<BloqueioFiscal> {
  BloqueioFiscalNotifier({DateTime Function()? relogio})
      : _agora = relogio ?? DateTime.now;
  final DateTime Function() _agora;

  static const falhasParaTravar = 2;
  static const duracao = Duration(minutes: 10);

  @override
  BloqueioFiscal build() => const BloqueioFiscal();

  /// Cartão e PIX estão travados agora?
  bool get travado => state.travadoEm(_agora());

  /// Uma nota não saiu. Só as que repetem contam para a trava.
  void registrarNaoEmitida({required bool repete, required String motivo}) {
    if (!repete) {
      state = const BloqueioFiscal();
      return;
    }
    final n = state.falhasSeguidas + 1;
    state = BloqueioFiscal(
      falhasSeguidas: n,
      motivo: motivo,
      ate: n >= falhasParaTravar ? _agora().add(duracao) : state.ate,
    );
  }

  /// A nota saiu (ou a loja não emite): o problema não está mais repetindo.
  void registrarEmitida() {
    if (state.falhasSeguidas != 0 || state.ate != null) {
      state = const BloqueioFiscal();
    }
  }
}

final bloqueioFiscalProvider =
    NotifierProvider<BloqueioFiscalNotifier, BloqueioFiscal>(
        BloqueioFiscalNotifier.new);
