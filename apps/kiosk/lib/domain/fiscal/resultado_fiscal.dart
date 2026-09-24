/// O resultado fiscal da venda — o contrato do Regem (#574, `fiscal/nfce-totem.ts`).
///
/// No totem a compra só termina com o cupom fiscal na mão do cliente. O Regem responde a
/// venda (ou a liberação do pedido retido) com um de quatro casos no campo `nfce`:
///
/// | `nfce`                                    | o que o totem faz                          |
/// |-------------------------------------------|--------------------------------------------|
/// | `null` (loja sem fiscal / totem não emite) | segue sem DANFE                            |
/// | `autorizada`, com `danfe`                 | imprime o DANFE                            |
/// | `contingencia`, com `danfe`               | imprime (e a 2ª via, se a loja ligou)      |
/// | `nao_emitida`, com `erro`                 | a venda foi DESFEITA: estorna e avisa      |
sealed class ResultadoFiscal {
  const ResultadoFiscal();

  /// Lê o campo `nfce` da resposta. Status desconhecido com DANFE é impresso (o emitente
  /// mandou um documento); sem DANFE, é tratado como "sem nota" — nunca como não emitida,
  /// que desfaz a venda e estorna: isso só com o `nao_emitida` explícito do Regem.
  factory ResultadoFiscal.de(Object? nfce) {
    if (nfce is! Map) return const SemNota();
    if (nfce['status'] == 'nao_emitida') {
      final e = nfce['erro'];
      final erro = e is Map ? e : const {};
      final codigo = erro['codigo']?.toString().trim();
      final motivo = erro['motivo']?.toString().trim();
      return NotaNaoEmitida(
        etapa: erro['etapa']?.toString() ?? 'interno',
        codigo: (codigo == null || codigo.isEmpty) ? null : codigo,
        motivo: (motivo == null || motivo.isEmpty)
            ? 'a nota fiscal não foi emitida'
            : motivo,
        repete: erro['repete'] == true,
      );
    }
    final danfe = nfce['danfe'];
    if (danfe is String && danfe.isNotEmpty) {
      final contingencia =
          nfce['contingencia'] == true || nfce['status'] == 'contingencia';
      return NotaEmitida(
        danfe: danfe,
        contingencia: contingencia,
        // A 2ª via só existe na contingência, e só se a loja ligou (mig 287 do Regem).
        viaEstabelecimento: contingencia && nfce['viaEstabelecimento'] == true,
      );
    }
    return const SemNota();
  }
}

/// A loja não emite NFC-e (ou este totem está desmarcado no Regem): não se espera nota.
class SemNota extends ResultadoFiscal {
  const SemNota();
}

/// Nota autorizada ou em contingência — o DANFE vem pronto do emitente.
class NotaEmitida extends ResultadoFiscal {
  const NotaEmitida({
    required this.danfe,
    this.contingencia = false,
    this.viaEstabelecimento = false,
  });
  final String danfe;
  final bool contingencia;
  final bool viaEstabelecimento;
}

/// A nota NÃO saiu e o Regem desfez a venda (estoque, caixa, cozinha). O pagamento tem de
/// voltar ao cliente.
class NotaNaoEmitida extends ResultadoFiscal {
  const NotaNaoEmitida({
    required this.etapa,
    required this.codigo,
    required this.motivo,
    required this.repete,
  });

  /// `configuracao` | `rejeitada` | `denegada` | `sem_contingencia` | `interno`.
  final String etapa;

  /// O cStat da SEFAZ, quando houve resposta com código.
  final String? codigo;

  /// O texto do Regem — vai para o relatório.
  final String motivo;

  /// A próxima venda vai falhar igual (certificado, cadastro, emitente)? O totem alerta em
  /// vez de cobrar e estornar em série.
  final bool repete;

  /// O motivo no MESMO formato que o Regem grava no pedido cancelado — os dois relatórios
  /// mostram o mesmo texto.
  String get motivoRelatorio =>
      'NFC-e não emitida ($etapa${codigo != null ? ' $codigo' : ''}): $motivo';
}
