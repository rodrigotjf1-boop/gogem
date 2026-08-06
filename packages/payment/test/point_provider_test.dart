import 'package:gogem_payment/payment.dart';
import 'package:test/test.dart';

/// Gateway Point fake: devolve uma sequência de status ('throw' = erro de rede)
/// e registra se `cancelar` foi chamado (para provar o cancelamento remoto).
class _FakePointGateway implements PointGateway {
  _FakePointGateway(this._statuses, {this.criarThrows = false, this.onStatus});
  final List<String> _statuses;
  final bool criarThrows;
  final void Function()? onStatus;
  int _i = 0;
  bool cancelou = false;

  @override
  Future<PointCharge> criar(PaymentRequest req) async {
    if (criarThrows) throw Exception('point down');
    return PointCharge(
      id: 'pt1',
      status: 'pending',
      amountCents: req.amountCents,
      tipo: 'credit',
    );
  }

  @override
  Future<PointCharge> status(String chargeId) async {
    onStatus?.call();
    final s = _i < _statuses.length ? _statuses[_i++] : 'pending';
    if (s == 'throw') throw Exception('net');
    return PointCharge(id: chargeId, status: s, amountCents: 100);
  }

  @override
  Future<void> cancelar(String chargeId) async {
    cancelou = true;
  }
}

PaymentRequest _req() => const PaymentRequest(
      orderId: 'order-7',
      amountCents: 8360,
      method: PaymentMethod.credito,
    );

void main() {
  group('PointProvider', () {
    test('emite o desafio e aprova após alguns polls', () async {
      final gw = _FakePointGateway(['pending', 'approved']);
      final p = PointProvider(gw, pollInterval: Duration.zero);
      final eventos = <PaymentEvent>[];
      final sub = p.events.listen(eventos.add);

      final r = await p.start(_req());
      await Future<void>.delayed(Duration.zero);

      expect(r.status, PaymentStatus.approved);
      expect(r.providerTxnId, 'pt1');
      expect(eventos.whereType<PointChallenge>(), isNotEmpty);
      await sub.cancel();
      p.dispose();
    });

    test('erro de rede no polling NÃO derruba: tenta de novo e aprova', () async {
      final gw = _FakePointGateway(['throw', 'throw', 'approved']);
      final p = PointProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.approved);
      p.dispose();
    });

    test('recusado na maquininha => error', () async {
      final gw = _FakePointGateway(['pending', 'error']);
      final p = PointProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.error);
      p.dispose();
    });

    test('timeout: aborta e CANCELA a intent remota', () async {
      var t = DateTime(2026, 1, 1);
      DateTime clock() {
        final atual = t;
        t = t.add(const Duration(seconds: 60));
        return atual;
      }

      final gw = _FakePointGateway(const []); // sempre pending
      final p = PointProvider(
        gw,
        pollInterval: Duration.zero,
        displayTimeout: const Duration(seconds: 120),
        clock: clock,
      );
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.timeout);
      expect(gw.cancelou, isTrue); // não deixou pedido órfão
      p.dispose();
    });

    test('cancelar() encerra e cancela a intent remota', () async {
      late PointProvider p;
      final gw = _FakePointGateway(['pending', 'pending'],
          onStatus: () => p.cancelar());
      p = PointProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.cancelled);
      expect(gw.cancelou, isTrue);
      p.dispose();
    });

    test('falha ao acionar a maquininha => PaymentCommunicationException', () async {
      final gw = _FakePointGateway(const [], criarThrows: true);
      final p = PointProvider(gw, pollInterval: Duration.zero);
      expect(() => p.start(_req()),
          throwsA(isA<PaymentCommunicationException>()));
      p.dispose();
    });

    test('capabilities: cancelamento e parcelado, sem pix', () {
      final p = PointProvider(_FakePointGateway(const []));
      expect(p.capabilities.cancelamento, isTrue);
      expect(p.capabilities.parcelado, isTrue);
      expect(p.capabilities.pix, isFalse);
      p.dispose();
    });
  });
}
