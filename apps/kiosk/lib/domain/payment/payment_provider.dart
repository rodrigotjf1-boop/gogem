import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogem_payment/payment.dart';

import '../../data/api/gogem_api.dart';
import '../../data/catalog/catalog_sync.dart';
import '../order/order_models.dart';

/// Liga o PixProvider (pacote) ao backend do GoGeM: cria a cobrança e faz o
/// polling do status via API do totem (X-Device-Token). Credencial do PSP fica
/// no backend — o app nunca a vê.
class HttpPixGateway implements PixGateway {
  HttpPixGateway(this._api);
  final GogemApi _api;

  @override
  Future<PixCharge> criar(PaymentRequest req) => _api.criarPix(
        amountCents: req.amountCents,
        orderId: req.orderId,
        cpfCnpj: req.cpfCnpj,
      );

  @override
  Future<PixCharge> status(String chargeId) => _api.pixStatus(chargeId);
}

/// PixProvider ligado ao backend. A tela de PIX usa este (o QR + polling).
final pixProviderProvider = Provider<PixProvider>((ref) {
  final p = PixProvider(HttpPixGateway(ref.watch(gogemApiProvider)));
  ref.onDispose(p.dispose);
  return p;
});

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
