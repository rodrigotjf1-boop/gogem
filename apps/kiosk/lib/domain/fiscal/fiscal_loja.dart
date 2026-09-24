/// O que o totem precisa saber do fiscal da loja ANTES de cobrar.
///
/// Vem do servidor da loja junto com o cardápio (campo `fiscal` do
/// `/catalogo/publicado`). Quem emite a nota é o Regem; o totem só usa isto para
/// não deixar o cliente pagar uma compra cuja nota o Regem vai recusar.
///
/// O caso que motivou: acima do limite de identificação da UF (R$ 2.000,00 no RJ), a
/// NFC-e sem CPF/CNPJ é recusada. No totem a nota só sai DEPOIS de o pagamento aprovar —
/// descobrir o problema ali significaria cobrar e ter de estornar. Então o CPF passa a ser
/// obrigatório na tela de identificação, antes da maquininha.
///
/// O limite NÃO é constante no app: é o valor que o fiscal do Regem usa para recusar a
/// emissão (tabela por UF ou o configurado pela loja).
class FiscalLoja {
  const FiscalLoja({this.ativo = false, this.limiteIdentificacaoCentavos});

  /// Sem informação do servidor (nuvem, servidor antigo, primeiro boot): não exige nada —
  /// o comportamento de antes.
  static const semFiscal = FiscalLoja();

  /// A loja emite NFC-e.
  final bool ativo;

  /// Acima deste valor (em centavos), o CPF é obrigatório. `null` = sem limite.
  final int? limiteIdentificacaoCentavos;

  factory FiscalLoja.fromJson(Object? j) {
    if (j is! Map) return semFiscal;
    final limite = j['limiteIdentificacaoCentavos'];
    return FiscalLoja(
      ativo: j['ativo'] == true,
      limiteIdentificacaoCentavos: limite is num ? limite.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'ativo': ativo,
        'limiteIdentificacaoCentavos': limiteIdentificacaoCentavos,
      };

  /// O CPF é obrigatório nesta compra? Mesma regra do fiscal do Regem: ACIMA do limite
  /// (`>`), não a partir dele — uma compra de exatamente R$ 2.000,00 dispensa o CPF.
  bool cpfObrigatorio(int totalCentavos) {
    final limite = limiteIdentificacaoCentavos;
    return ativo && limite != null && totalCentavos > limite;
  }
}
