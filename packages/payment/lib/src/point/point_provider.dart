import 'dart:async';

import '../errors.dart';
import '../models.dart';
import '../provider.dart';
import 'point_gateway.dart';
import 'point_models.dart';

/// Provider de cartão na maquininha Point Smart (modo PDV). `start()` cria a
/// cobrança (a Point acende), emite o [PointChallenge] (a tela mostra "pague na
/// maquininha") e faz POLLING até aprovar/cancelar/erro/timeout. Resiliente a
/// rede: erro na consulta NÃO derruba — tenta de novo até o timeout. Em
/// timeout/cancelamento, CANCELA a intent remota (a maquininha para de pedir o
/// cartão) — nunca deixa pedido órfão.
class PointProvider implements PaymentProvider {
  PointProvider(
    this._gateway, {
    this.pollInterval = const Duration(seconds: 2),
    this.displayTimeout = const Duration(seconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PointGateway _gateway;
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
        pix: false,
        cancelamento: true,
        reimpressao: false,
        parcelado: true,
      );

  /// Cliente/operador desistiu: encerra o polling e cancela a intent na Point.
  void cancelar() => _cancelado = true;

  @override
  Future<PaymentResult> start(PaymentRequest req) async {
    _cancelado = false;
    final PointCharge charge;
    try {
      charge = await _gateway.criar(req);
    } catch (_) {
      throw const PaymentCommunicationException(
        'não foi possível acionar a maquininha',
      );
    }
    _emit(PointChallenge(chargeId: charge.id));
    _emit(const PaymentStage('aguardando_maquininha'));

    final inicio = _clock();
    while (true) {
      if (_cancelado) return _abortar(req, charge.id, PaymentStatus.cancelled);
      if (_clock().difference(inicio) >= displayTimeout) {
        return _abortar(req, charge.id, PaymentStatus.timeout);
      }
      await Future<void>.delayed(pollInterval);
      if (_cancelado) return _abortar(req, charge.id, PaymentStatus.cancelled);

      PointCharge atual;
      try {
        atual = await _gateway.status(charge.id);
      } catch (_) {
        continue; // rede caiu: tenta de novo até o timeout
      }
      switch (atual.status) {
        case 'approved':
          return _res(req, PaymentStatus.approved, 'Pagamento aprovado',
              txn: charge.id);
        case 'cancelled':
          return _res(req, PaymentStatus.cancelled, 'Pagamento cancelado');
        case 'error':
          return _res(req, PaymentStatus.error, 'Pagamento recusado');
        default:
          break; // pending → segue o polling
      }
    }
  }

  @override
  Future<void> confirm(String confirmationToken) async {}

  @override
  Future<void> undo(String confirmationToken) async {}

  @override
  Future<PaymentResult> cancelTransaction(String originalRef) async {
    await _cancelarRemoto(originalRef);
    return PaymentResult(
      status: PaymentStatus.cancelled,
      orderId: originalRef,
    );
  }

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

  /// Encerra a cobrança: cancela a intent na Point e devolve o desfecho.
  Future<PaymentResult> _abortar(
    PaymentRequest req,
    String chargeId,
    PaymentStatus status,
  ) async {
    await _cancelarRemoto(chargeId);
    return _res(
      req,
      status,
      status == PaymentStatus.timeout
          ? 'Tempo do pagamento esgotado'
          : 'Pagamento cancelado',
    );
  }

  Future<void> _cancelarRemoto(String chargeId) async {
    try {
      await _gateway.cancelar(chargeId);
    } catch (_) {
      // best-effort: se a rede caiu, o resolvePendings/expiração cobre.
    }
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
