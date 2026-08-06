import '../models.dart';

/// Cobrança de cartão na Point Smart (espelha o que o backend devolve).
class PointCharge {
  const PointCharge({
    required this.id,
    required this.status,
    required this.amountCents,
    this.tipo,
  });

  final String id;

  /// pending | approved | cancelled | error.
  final String status;
  final int amountCents;

  /// credit | debit.
  final String? tipo;

  bool get aprovado => status == 'approved';
  bool get pendente => status == 'pending';
}

/// Evento: a maquininha acendeu e está pedindo o cartão. A tela mostra "pague na
/// maquininha — siga no visor" enquanto o provider faz o polling.
class PointChallenge extends PaymentEvent {
  const PointChallenge({required this.chargeId});
  final String chargeId;
}
