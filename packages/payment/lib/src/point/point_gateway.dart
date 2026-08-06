import '../models.dart';
import 'point_models.dart';

/// Ponte para o backend do GoGeM (que fala com o Point do MP). Mantém o pacote
/// puro: o app injeta a impl HTTP (POST /pagamentos/point, GET :id, cancelar); os
/// testes injetam um fake. NENHUMA credencial passa por aqui.
abstract interface class PointGateway {
  /// Cria a cobrança na maquininha (a Point acende pedindo o cartão).
  Future<PointCharge> criar(PaymentRequest req);

  /// Consulta o status atual da cobrança.
  Future<PointCharge> status(String chargeId);

  /// Cancela a cobrança (a maquininha para de pedir o cartão).
  Future<void> cancelar(String chargeId);
}
