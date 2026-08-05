/// Erros do contrato de pagamento.
library;

/// Falha ao operar a integradora/pinpad. `código` é opcional (do provider).
class PaymentException implements Exception {
  const PaymentException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'PaymentException(${code ?? '-'}): $message';
}

/// Falha de COMUNICAÇÃO com o TEF/pinpad (serviço local fora, cabo arrancado,
/// sem resposta). A UI trata como "tente novamente / chame o atendente" — nunca
/// como venda concluída.
class PaymentCommunicationException extends PaymentException {
  // ignore: use_super_parameters  (não dá p/ super-param junto com super(code:))
  const PaymentCommunicationException([
    String message = 'falha de comunicação com o TEF',
  ]) : super(message, code: 'COMM');
}
