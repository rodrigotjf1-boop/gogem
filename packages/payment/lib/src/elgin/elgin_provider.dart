import 'dart:async';
import 'dart:convert';

import '../errors.dart';
import '../models.dart';
import '../provider.dart';
import 'elgin_transport.dart';

/// Provider TEF do Elgin (IDH via Intent Android). `start()` dispara a função
/// (crédito/débito) no pinpad e parseia o `retorno` do Protocolo Elgin:
/// `{funcao, mensagem, resultado:{...}}` — `mensagem == 'Sucesso'` = aprovado; as
/// vias (`viaCliente`/`viaEstabelecimento`) já vêm prontas para o escpos.
///
/// O IDH confirma a transação internamente (CliSiTef), então `confirm`/`undo`
/// são no-ops aqui; o desfazimento/estorno é a função `cancelar` (F10 amarra o
/// journal). Resiliente: timeout no pinpad e falha de comunicação não travam.
class ElginTefProvider implements PaymentProvider {
  ElginTefProvider(
    this._transport, {
    this.timeout = const Duration(seconds: 120),
  });

  final ElginTefTransport _transport;
  final Duration timeout;

  final StreamController<PaymentEvent> _events =
      StreamController<PaymentEvent>.broadcast();

  @override
  Stream<PaymentEvent> get events => _events.stream;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        pix: true,
        cancelamento: true,
        reimpressao: true,
        parcelado: true,
      );

  @override
  Future<PaymentResult> start(PaymentRequest req) async {
    _emit(const PaymentPrompt('Siga as instruções no pinpad'));
    final String retorno;
    try {
      retorno = await _transport.executar(_extrasDe(req)).timeout(timeout);
    } on TimeoutException {
      return _res(req, PaymentStatus.timeout, 'Tempo do pagamento esgotado');
    } catch (_) {
      throw const PaymentCommunicationException('falha ao falar com o pinpad');
    }
    return _parse(req, retorno);
  }

  @override
  Future<void> confirm(String confirmationToken) async {
    // O IDH confirma a transação internamente — nada a fazer aqui.
  }

  @override
  Future<void> undo(String confirmationToken) async {
    // Desfazimento no fluxo IDH é via `cancelar` (precisa de nsu/valor/data).
  }

  @override
  Future<PaymentResult> cancelTransaction(String originalRef) async {
    // originalRef = "nsu|valorCentavos|dd/MM/aa" (o app monta a partir da venda).
    final p = originalRef.split('|');
    final extras = <String, String>{
      'funcao': 'cancelar',
      if (p.isNotEmpty) 'nsu': p[0],
      if (p.length > 1) 'valor': _reais(int.tryParse(p[1]) ?? 0),
      if (p.length > 2) 'data': p[2],
    };
    final retorno = await _transport.executar(extras);
    return _parse(
      PaymentRequest(
        orderId: originalRef,
        amountCents: 0,
        method: PaymentMethod.credito,
      ),
      retorno,
      statusFalha: PaymentStatus.error,
    );
  }

  @override
  Future<List<String>> reprint() async {
    final retorno = await _transport.executar({'funcao': 'reimprimir'});
    final r = _resultado(retorno);
    return [
      if (r['viaCliente'] is String) r['viaCliente'] as String,
      if (r['viaEstabelecimento'] is String) r['viaEstabelecimento'] as String,
    ];
  }

  @override
  Future<void> resolvePendings() async {}

  @override
  Future<void> closeBatch() async {}

  @override
  Future<bool> healthCheck() => _transport.disponivel();

  void dispose() {
    if (!_events.isClosed) _events.close();
  }

  // ── internos ──────────────────────────────────────────────────────────────

  /// Monta os putExtra do Intent conforme a função. Quirk do IDH: crédito/débito
  /// levam o valor em CENTAVOS (ex.: "1500"); pix/cancelar em REAIS ("15.00").
  Map<String, String> _extrasDe(PaymentRequest req) {
    if (req.method == PaymentMethod.pix) {
      return {'funcao': 'pix', 'valor': _reais(req.amountCents)};
    }
    if (req.method == PaymentMethod.debito) {
      return {'funcao': 'debito', 'valor': '${req.amountCents}'};
    }
    // crédito (à vista ou parcelado). financiamento: 1=à vista, 3=parcelado loja.
    final parcelado = req.installments > 1;
    return {
      'funcao': 'credito',
      'valor': '${req.amountCents}',
      'parcelas': '${req.installments}',
      'financiamento': parcelado ? '3' : '1',
    };
  }

  PaymentResult _parse(
    PaymentRequest req,
    String retorno, {
    PaymentStatus statusFalha = PaymentStatus.denied,
  }) {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(retorno) as Map<String, dynamic>;
    } catch (_) {
      return _res(req, PaymentStatus.error, 'Retorno inválido do TEF');
    }
    final mensagem = '${j['mensagem'] ?? ''}';
    final resultado =
        (j['resultado'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sucesso = mensagem.trim().toLowerCase() == 'sucesso';
    if (!sucesso) {
      final cancelado = mensagem.toLowerCase().contains('cancel');
      return _res(
        req,
        cancelado ? PaymentStatus.cancelled : statusFalha,
        mensagem.isEmpty ? 'Pagamento não concluído' : mensagem,
      );
    }
    String? s(String k) => resultado[k] is String ? resultado[k] as String : null;
    return PaymentResult(
      status: PaymentStatus.approved,
      orderId: req.orderId,
      providerTxnId: s('nsu'),
      nsu: s('nsu') ?? s('nsuRede'),
      authCode: s('autorizacao'),
      brand: s('rede') ?? s('administradora'),
      network: s('rede'),
      message: s('mensagem') ?? 'Pagamento aprovado',
      customerReceipt: s('viaCliente'),
      merchantReceipt: s('viaEstabelecimento'),
    );
  }

  Map<String, dynamic> _resultado(String retorno) {
    try {
      final j = jsonDecode(retorno) as Map<String, dynamic>;
      return (j['resultado'] as Map?)?.cast<String, dynamic>() ?? const {};
    } catch (_) {
      return const {};
    }
  }

  String _reais(int centavos) => (centavos / 100).toStringAsFixed(2);

  PaymentResult _res(PaymentRequest req, PaymentStatus status, String msg) =>
      PaymentResult(status: status, orderId: req.orderId, message: msg);

  void _emit(PaymentEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
