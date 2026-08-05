import '../models.dart';

/// Cobrança PIX (espelha o que o backend do GoGeM devolve). Valor em centavos.
class PixCharge {
  const PixCharge({
    required this.id,
    required this.status,
    required this.amountCents,
    this.copiaECola,
    this.qrImage,
    this.expiresAt,
  });

  final String id;

  /// pending | approved | expired | cancelled | error.
  final String status;
  final int amountCents;

  /// EMV "copia e cola".
  final String? copiaECola;

  /// Data URI (base64) do QR — opcional (o app pode desenhar do copia-e-cola).
  final String? qrImage;
  final DateTime? expiresAt;

  bool get aprovado => status == 'approved';
  bool get pendente => status == 'pending';
}

/// Evento de desafio do PIX: a tela mostra o QR (copia-e-cola + imagem) enquanto
/// o provider faz o polling. Emitido logo após criar a cobrança.
class PixChallenge extends PaymentEvent {
  const PixChallenge({
    required this.chargeId,
    required this.copiaECola,
    this.qrImage,
    this.expiresAt,
  });

  final String chargeId;
  final String copiaECola;
  final String? qrImage;
  final DateTime? expiresAt;
}
