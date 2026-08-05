/// GoGeM — contrato de pagamento agnóstico de integradora.
///
/// A UI do totem fala SÓ com [PaymentProvider]. Cada integradora (PIX, Elgin TEF
/// Web, Destaxa, PayGo, m-SiTef) entra como uma implementação em `src/<provider>/`
/// sem tocar na tela. O [FakePaymentProvider] cobre bancada, dev e testes.
library;

export 'src/models.dart';
export 'src/errors.dart';
export 'src/provider.dart';
export 'src/fake/fake_provider.dart';
