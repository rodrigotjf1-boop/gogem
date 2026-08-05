/// Modelos do contrato de pagamento (agnósticos de integradora).
///
/// Valores monetários SEMPRE em centavos (int), nunca double. Nada de dado de
/// cartão (PAN/trilha/CVV) trafega aqui — a UI só vê status e mensagens.
library;

/// Forma de captura no pinpad/QR.
enum PaymentMethod { credito, debito, pix, voucher }

/// Pedido de cobrança. `orderId` é o UUID do pedido = chave de idempotência.
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.amountCents,
    required this.method,
    this.installments = 1,
    this.cpfCnpj,
    this.receiptNumber,
  });

  final String orderId;
  final int amountCents;
  final PaymentMethod method;

  /// 1 = à vista.
  final int installments;
  final String? cpfCnpj;

  /// Número do cupom, quando houver.
  final String? receiptNumber;
}

/// Desfecho de uma transação.
enum PaymentStatus { approved, denied, cancelled, timeout, error, pending }

/// Resultado da cobrança. As vias (`customerReceipt`/`merchantReceipt`) já vêm
/// prontas para o `escpos` — a UI não reformata.
class PaymentResult {
  const PaymentResult({
    required this.status,
    required this.orderId,
    this.providerTxnId,
    this.nsu,
    this.authCode,
    this.brand,
    this.network,
    this.message,
    this.customerReceipt,
    this.merchantReceipt,
    this.confirmationToken,
  });

  final PaymentStatus status;
  final String orderId;
  final String? providerTxnId;
  final String? nsu;
  final String? authCode;

  /// Bandeira (ex.: VISA).
  final String? brand;

  /// Rede autorizadora.
  final String? network;

  /// Mensagem para a tela — NUNCA dado de cartão.
  final String? message;

  /// Via do cliente (texto pronto p/ escpos).
  final String? customerReceipt;

  /// Via do estabelecimento.
  final String? merchantReceipt;

  /// Token para confirmar a transação (COMP_DADOS_CONF ou equivalente).
  final String? confirmationToken;

  bool get aprovado => status == PaymentStatus.approved;
}

/// Eventos emitidos durante a transação (a UI do totem mostra a mensagem grande).
/// Abstrato (não sealed) para que providers em `src/<provider>/` definam eventos
/// próprios — ex.: o PIX emite o desafio do QR (PixChallenge).
abstract class PaymentEvent {
  const PaymentEvent();
}

/// Instrução para o cliente (ex.: "Aproxime, insira ou passe o cartão").
class PaymentPrompt extends PaymentEvent {
  const PaymentPrompt(this.message);
  final String message;
}

/// Etapa técnica da transação (ex.: "processing", "connecting").
class PaymentStage extends PaymentEvent {
  const PaymentStage(this.stage);
  final String stage;
}

/// O que o provider suporta (a UI adapta as opções ao que existe).
class ProviderCapabilities {
  const ProviderCapabilities({
    required this.pix,
    required this.cancelamento,
    required this.reimpressao,
    required this.parcelado,
  });

  final bool pix;
  final bool cancelamento;
  final bool reimpressao;
  final bool parcelado;
}
