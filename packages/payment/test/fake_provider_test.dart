import 'package:gogem_payment/payment.dart';
import 'package:test/test.dart';

PaymentRequest _req() => const PaymentRequest(
      orderId: 'order-123',
      amountCents: 8360,
      method: PaymentMethod.credito,
    );

void main() {
  group('FakePaymentProvider', () {
    test('aprovado: status approved + NSU + vias + token de confirmação', () async {
      final p = FakePaymentProvider(delay: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.approved);
      expect(r.aprovado, isTrue);
      expect(r.orderId, 'order-123');
      expect(r.nsu, isNotNull);
      expect(r.confirmationToken, isNotNull);
      expect(r.customerReceipt, contains('VIA CLIENTE'));
      expect(r.merchantReceipt, contains('VIA ESTABELECIMENTO'));
      p.dispose();
    });

    test('negado: status denied, sem token de confirmação', () async {
      final p = FakePaymentProvider(
          outcome: FakeOutcome.denied, delay: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.denied);
      expect(r.aprovado, isFalse);
      expect(r.confirmationToken, isNull);
      p.dispose();
    });

    test('timeout: status timeout', () async {
      final p = FakePaymentProvider(
          outcome: FakeOutcome.timeout, delay: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.timeout);
      expect(r.aprovado, isFalse);
      p.dispose();
    });

    test('erro de comunicação: start lança PaymentCommunicationException', () async {
      final p = FakePaymentProvider(
          outcome: FakeOutcome.communicationError, delay: Duration.zero);
      expect(
        () => p.start(_req()),
        throwsA(isA<PaymentCommunicationException>()),
      );
      expect(await p.healthCheck(), isFalse);
      p.dispose();
    });

    test('emite prompt e stage durante a transação', () async {
      final p = FakePaymentProvider(delay: Duration.zero);
      final eventos = <PaymentEvent>[];
      final sub = p.events.listen(eventos.add);
      await p.start(_req());
      await Future<void>.delayed(Duration.zero);
      expect(eventos.whereType<PaymentPrompt>(), isNotEmpty);
      expect(eventos.whereType<PaymentStage>(), isNotEmpty);
      await sub.cancel();
      p.dispose();
    });

    test('capabilities do fake: pix e cancelamento', () {
      final p = FakePaymentProvider();
      expect(p.capabilities.pix, isTrue);
      expect(p.capabilities.cancelamento, isTrue);
      p.dispose();
    });
  });
}
