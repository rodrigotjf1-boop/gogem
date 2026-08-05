import '../models.dart';
import 'pix_models.dart';

/// Ponte para o backend do GoGeM (que fala com o PSP). Mantém o pacote puro: o
/// app injeta a implementação HTTP (chama POST /pagamentos/pix e GET :id); os
/// testes injetam um fake. NENHUMA credencial de PSP passa por aqui.
abstract interface class PixGateway {
  /// Cria a cobrança e devolve o QR (copia-e-cola + imagem).
  Future<PixCharge> criar(PaymentRequest req);

  /// Consulta o status atual da cobrança.
  Future<PixCharge> status(String chargeId);
}
