import 'dart:async';

import '../errors.dart';
import '../models.dart';
import '../provider.dart';

/// Desfecho que o [FakePaymentProvider] vai produzir (bancada + testes).
enum FakeOutcome { approved, denied, timeout, communicationError, cancelled }

/// Provider de pagamento FAKE — substitui o pagamento mock da Fatia 3.
///
/// Determinístico: o desfecho é injetado (default aprovado), então dá para
/// exercitar toda a tela sem hardware. Emite eventos como um provider real.
/// NENHUMA integradora — só bancada, dev e testes.
class FakePaymentProvider implements PaymentProvider {
  FakePaymentProvider({
    this.outcome = FakeOutcome.approved,
    this.delay = const Duration(milliseconds: 300),
  });

  /// Desfecho a produzir no [start].
  final FakeOutcome outcome;

  /// Atraso simulado da "conversa com o pinpad".
  final Duration delay;

  final StreamController<PaymentEvent> _events =
      StreamController<PaymentEvent>.broadcast();

  @override
  Stream<PaymentEvent> get events => _events.stream;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        pix: true,
        cancelamento: true,
        reimpressao: true,
        parcelado: true,
      );

  @override
  Future<PaymentResult> start(PaymentRequest req) async {
    _emit(const PaymentPrompt('Aproxime, insira ou passe o cartão'));
    await Future<void>.delayed(delay);
    _emit(const PaymentStage('processing'));

    switch (outcome) {
      case FakeOutcome.communicationError:
        throw const PaymentCommunicationException();
      case FakeOutcome.timeout:
        return _res(req, PaymentStatus.timeout, message: 'Tempo esgotado');
      case FakeOutcome.denied:
        return _res(req, PaymentStatus.denied, message: 'Pagamento negado');
      case FakeOutcome.cancelled:
        return _res(req, PaymentStatus.cancelled, message: 'Cancelado');
      case FakeOutcome.approved:
        return _res(
          req,
          PaymentStatus.approved,
          message: 'Pagamento aprovado',
          providerTxnId: 'FAKE-${req.orderId}',
          nsu: _nsu(req.orderId),
          authCode: '123456',
          brand: 'VISA',
          network: 'FAKE',
          confirmationToken: 'FAKE-CONF-${req.orderId}',
          customerReceipt: _recibo(req, 'VIA CLIENTE'),
          merchantReceipt: _recibo(req, 'VIA ESTABELECIMENTO'),
        );
    }
  }

  @override
  Future<void> confirm(String confirmationToken) async {
    _emit(const PaymentStage('confirmed'));
  }

  @override
  Future<void> undo(String confirmationToken) async {
    _emit(const PaymentStage('undone'));
  }

  @override
  Future<PaymentResult> cancelTransaction(String originalRef) async =>
      PaymentResult(
        status: PaymentStatus.cancelled,
        orderId: originalRef,
        message: 'Estorno simulado',
      );

  @override
  Future<List<String>> reprint() async => const <String>[];

  @override
  Future<void> resolvePendings() async {}

  @override
  Future<void> closeBatch() async {}

  @override
  Future<bool> healthCheck() async =>
      outcome != FakeOutcome.communicationError;

  /// Fecha o stream de eventos (chamar ao descartar).
  void dispose() {
    if (!_events.isClosed) _events.close();
  }

  PaymentResult _res(
    PaymentRequest req,
    PaymentStatus status, {
    String? message,
    String? providerTxnId,
    String? nsu,
    String? authCode,
    String? brand,
    String? network,
    String? confirmationToken,
    String? customerReceipt,
    String? merchantReceipt,
  }) =>
      PaymentResult(
        status: status,
        orderId: req.orderId,
        message: message,
        providerTxnId: providerTxnId,
        nsu: nsu,
        authCode: authCode,
        brand: brand,
        network: network,
        confirmationToken: confirmationToken,
        customerReceipt: customerReceipt,
        merchantReceipt: merchantReceipt,
      );

  String _nsu(String orderId) {
    // NSU fake determinístico a partir do orderId (6 dígitos).
    final n = orderId.codeUnits.fold<int>(0, (a, c) => (a + c) % 1000000);
    return n.toString().padLeft(6, '0');
  }

  String _recibo(PaymentRequest req, String titulo) {
    final reais = (req.amountCents / 100).toStringAsFixed(2);
    return '$titulo\nGoGeM (bancada)\nPedido ${req.orderId}\n'
        'Valor R\$ $reais\nNSU ${_nsu(req.orderId)}\n** PAGAMENTO SIMULADO **';
  }

  void _emit(PaymentEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
