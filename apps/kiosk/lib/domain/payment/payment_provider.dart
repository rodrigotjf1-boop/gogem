import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogem_payment/payment.dart';

import '../order/order_models.dart';

/// Provider de pagamento ativo do totem.
///
/// Default: FAKE (bancada/dev) — substitui o pagamento mock da Fatia 3. As
/// integradoras reais (PIX/Elgin/Destaxa/PayGo/SiTef) entram aqui conforme o
/// roadmap-tef, selecionáveis por `--dart-define=GOGEM_PAYMENT_PROVIDER` na
/// bancada; em produção o provider vem da config do dispositivo (pareamento).
const String _kProvider =
    String.fromEnvironment('GOGEM_PAYMENT_PROVIDER', defaultValue: 'fake');

final paymentProviderProvider = Provider<PaymentProvider>((ref) {
  switch (_kProvider) {
    case 'fake':
    default:
      final p = FakePaymentProvider();
      ref.onDispose(p.dispose);
      return p;
  }
});

/// De-para da forma escolhida na tela → método do contrato de pagamento.
PaymentMethod metodoDePagamento(FormaPagamento forma) => switch (forma) {
      FormaPagamento.credito => PaymentMethod.credito,
      FormaPagamento.debito => PaymentMethod.debito,
      FormaPagamento.pix => PaymentMethod.pix,
      FormaPagamento.vr => PaymentMethod.voucher,
    };
