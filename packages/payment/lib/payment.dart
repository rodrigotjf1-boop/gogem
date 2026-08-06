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
export 'src/pix/pix_models.dart';
export 'src/pix/pix_gateway.dart';
export 'src/pix/pix_provider.dart';
export 'src/elgin/elgin_transport.dart';
export 'src/elgin/elgin_provider.dart';
export 'src/point/point_models.dart';
export 'src/point/point_gateway.dart';
export 'src/point/point_provider.dart';
