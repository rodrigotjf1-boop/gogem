import 'dart:async';

import '../errors.dart';
import '../models.dart';
import '../provider.dart';
import 'pix_gateway.dart';
import 'pix_models.dart';

/// Provider PIX via PSP (F8). `start()` cria a cobrança, emite o [PixChallenge]
/// (a tela mostra o QR) e faz POLLING do status até aprovar/expirar/timeout.
/// Resiliente a rede: erro na consulta NÃO derruba — tenta de novo até o timeout
/// de exibição (nunca deixa pedido órfão). O cliente pode desistir ([cancelar]).
class PixProvider implements PaymentProvider {
  PixProvider(
    this._gateway, {
    this.pollInterval = const Duration(seconds: 3),
    this.displayTimeout = const Duration(seconds: 180),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PixGateway _gateway;
  final Duration pollInterval;
  final Duration displayTimeout;
  final DateTime Function() _clock;

  final StreamController<PaymentEvent> _events =
      StreamController<PaymentEvent>.broadcast();
  bool _cancelado = false;

  @override
  Stream<PaymentEvent> get events => _events.stream;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        pix: true,
        cancelamento: false,
        reimpressao: false,
        parcelado: false,
      );

  /// Cliente desistiu: encerra o polling e devolve `cancelled` na próxima volta.
  void cancelar() => _cancelado = true;

  @override
  Future<PaymentResult> start(PaymentRequest req) async {
    _cancelado = false;
    final PixCharge charge;
    try {
      charge = await _gateway.criar(req);
    } catch (_) {
      throw const PaymentCommunicationException('não foi possível gerar o PIX');
    }
    final copia = charge.copiaECola;
    if (copia == null || copia.isEmpty) {
      return _res(req, PaymentStatus.error, 'PIX sem QR');
    }
    _emit(PixChallenge(
      chargeId: charge.id,
      copiaECola: copia,
      qrImage: charge.qrImage,
      expiresAt: charge.expiresAt,
    ));
    _emit(const PaymentStage('aguardando_pix'));

    final inicio = _clock();
    while (true) {
      if (_cancelado) {
        return _res(req, PaymentStatus.cancelled, 'Pagamento cancelado');
      }
      if (_clock().difference(inicio) >= displayTimeout) {
        return _res(req, PaymentStatus.timeout, 'Tempo do PIX esgotado');
      }
      await Future<void>.delayed(pollInterval);
      if (_cancelado) {
        return _res(req, PaymentStatus.cancelled, 'Pagamento cancelado');
      }
      PixCharge atual;
      try {
        atual = await _gateway.status(charge.id);
      } catch (_) {
        continue; // rede caiu: tenta de novo até o timeout
      }
      switch (atual.status) {
        case 'approved':
          return _res(req, PaymentStatus.approved, 'PIX aprovado',
              txn: charge.id);
        case 'expired':
          return _res(req, PaymentStatus.timeout, 'PIX expirou');
        case 'cancelled':
          return _res(req, PaymentStatus.cancelled, 'PIX cancelado');
        case 'error':
          return _res(req, PaymentStatus.error, 'Falha no PIX');
        default:
          break; // pending → continua o polling
      }
    }
  }

  @override
  Future<void> confirm(String confirmationToken) async {}

  @override
  Future<void> undo(String confirmationToken) async {}

  @override
  Future<PaymentResult> cancelTransaction(String originalRef) async =>
      PaymentResult(status: PaymentStatus.cancelled, orderId: originalRef);

  @override
  Future<List<String>> reprint() async => const <String>[];

  @override
  Future<void> resolvePendings() async {}

  @override
  Future<void> closeBatch() async {}

  @override
  Future<bool> healthCheck() async => true;

  void dispose() {
    if (!_events.isClosed) _events.close();
  }

  PaymentResult _res(
    PaymentRequest req,
    PaymentStatus status,
    String message, {
    String? txn,
  }) =>
      PaymentResult(
        status: status,
        orderId: req.orderId,
        message: message,
        providerTxnId: txn,
      );

  void _emit(PaymentEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
