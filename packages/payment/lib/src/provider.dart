import 'models.dart';

/// Contrato único de pagamento. A UI do totem fala SÓ com esta interface — cada
/// integradora (PIX/Elgin/Destaxa/PayGo/SiTef) é uma implementação em
/// `src/<provider>/`, sem tocar na tela.
///
/// Regras de ouro (ver roadmap-tef F10): confirmar só depois de persistir o
/// cupom; na dúvida, `undo`; resolver pendências no boot; timeout em toda etapa;
/// zero dado de cartão em log.
abstract interface class PaymentProvider {
  /// O que este provider suporta (PIX, cancelamento, reimpressão, parcelado).
  ProviderCapabilities get capabilities;

  /// Eventos para a UI durante a transação (mensagem/etapa).
  Stream<PaymentEvent> get events;

  /// Inicia a cobrança. Retorna o desfecho; lança [PaymentException] em falha
  /// de comunicação (a UI trata como "não cobrado").
  Future<PaymentResult> start(PaymentRequest req);

  /// Confirma a transação aprovada (só APÓS persistir o cupom).
  Future<void> confirm(String confirmationToken);

  /// Desfaz (undo) uma transação não confirmada — garantido em qualquer falha
  /// entre a aprovação e a persistência.
  Future<void> undo(String confirmationToken);

  /// Estorna/cancela uma transação já confirmada (referência original).
  Future<PaymentResult> cancelTransaction(String originalRef);

  /// Reimprime as últimas vias (texto pronto p/ escpos).
  Future<List<String>> reprint();

  /// Resolve transações pendentes — chamado no BOOT antes de liberar o totem.
  Future<void> resolvePendings();

  /// Fechamento de lote/dia.
  Future<void> closeBatch();

  /// Pinpad/serviço vivo? Alimenta a telemetria (heartbeat).
  Future<bool> healthCheck();
}
