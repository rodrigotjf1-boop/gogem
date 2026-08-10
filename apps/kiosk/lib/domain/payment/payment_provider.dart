import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogem_payment/payment.dart';

import '../../data/api/gogem_api.dart';
import '../../data/catalog/catalog_sync.dart';
import '../order/order_models.dart';

/// Liga o ElginTefProvider (pacote) ao IDH nativo: o canal `gogem/tef` dispara o
/// Intent `com.elgin.e1.digitalhub.TEF` e devolve o `retorno`. Sem canal nativo
/// (bancada desktop/teste) as chamadas caem no fake do transporte.
class MethodChannelElginTransport implements ElginTefTransport {
  static const MethodChannel _canal = MethodChannel('gogem/tef');

  @override
  Future<String> executar(Map<String, String> extras) async {
    final r = await _canal.invokeMethod<String>('executar', extras);
    return r ?? '{"mensagem":"Sem retorno do TEF"}';
  }

  @override
  Future<bool> disponivel() async {
    try {
      return await _canal.invokeMethod<bool>('disponivel') ?? false;
    } catch (_) {
      return false;
    }
  }
}

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

/// Liga o PointProvider (pacote) ao backend: cria a cobrança na maquininha Point,
/// faz o polling e cancela. Credencial (token + device) fica no backend.
class HttpPointGateway implements PointGateway {
  HttpPointGateway(this._api);
  final GogemApi _api;

  @override
  Future<PointCharge> criar(PaymentRequest req) => _api.criarPoint(
        amountCents: req.amountCents,
        orderId: req.orderId,
        tipo: switch (req.method) {
          PaymentMethod.debito => 'debit',
          PaymentMethod.voucher => 'voucher', // vale-refeição → voucher_card
          _ => 'credit',
        },
      );

  @override
  Future<PointCharge> status(String chargeId) => _api.pointStatus(chargeId);

  @override
  Future<void> cancelar(String chargeId) => _api.pointCancelar(chargeId);
}

/// PointProvider (cartão na maquininha). A tela usa quando cartão vai pro Point.
final pointProviderProvider = Provider<PointProvider>((ref) {
  final p = PointProvider(HttpPointGateway(ref.watch(gogemApiProvider)));
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

/// Cartão (crédito/débito) vai pra maquininha Point Smart (via nuvem)? Ligado por
/// `--dart-define=GOGEM_PAYMENT_PROVIDER=mppoint`. A tela roteia o cartão pro
/// fluxo do Point ("pague na maquininha"); o PIX segue no QR do totem.
const bool cartaoViaPoint = _kProvider == 'mppoint';

final paymentProviderProvider = Provider<PaymentProvider>((ref) {
  switch (_kProvider) {
    // Elgin TEF (cartão crédito/débito pelo pinpad, via IDH). PIX continua no
    // pixProviderProvider (PSP). Selecionável por GOGEM_PAYMENT_PROVIDER=elgin.
    case 'elgin':
      final p = ElginTefProvider(MethodChannelElginTransport());
      ref.onDispose(p.dispose);
      return p;
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
