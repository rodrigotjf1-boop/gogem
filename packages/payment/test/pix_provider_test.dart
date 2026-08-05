import 'package:gogem_payment/payment.dart';
import 'package:test/test.dart';

/// Gateway PIX fake: devolve uma sequência de status ('throw' = erro de rede).
class _FakePixGateway implements PixGateway {
  _FakePixGateway(this._statuses, {this.criarThrows = false, this.onStatus});
  final List<String> _statuses;
  final bool criarThrows;
  final void Function()? onStatus;
  int _i = 0;

  @override
  Future<PixCharge> criar(PaymentRequest req) async {
    if (criarThrows) throw Exception('psp down');
    return PixCharge(
      id: 'chg1',
      status: 'pending',
      amountCents: req.amountCents,
      copiaECola: '00020126BR.GOV.BCB.PIX...6304ABCD',
    );
  }

  @override
  Future<PixCharge> status(String chargeId) async {
    onStatus?.call();
    final s = _i < _statuses.length ? _statuses[_i++] : 'pending';
    if (s == 'throw') throw Exception('net');
    return PixCharge(id: chargeId, status: s, amountCents: 100);
  }
}

PaymentRequest _req() => const PaymentRequest(
      orderId: 'order-9',
      amountCents: 8360,
      method: PaymentMethod.pix,
    );

void main() {
  group('PixProvider', () {
    test('emite o QR e aprova após alguns polls', () async {
      final gw = _FakePixGateway(['pending', 'pending', 'approved']);
      final p = PixProvider(gw, pollInterval: Duration.zero);
      final eventos = <PaymentEvent>[];
      final sub = p.events.listen(eventos.add);

      final r = await p.start(_req());
      await Future<void>.delayed(Duration.zero);

      expect(r.status, PaymentStatus.approved);
      expect(r.providerTxnId, 'chg1');
      expect(eventos.whereType<PixChallenge>(), isNotEmpty);
      final desafio = eventos.whereType<PixChallenge>().first;
      expect(desafio.copiaECola, contains('BR.GOV.BCB.PIX'));
      await sub.cancel();
      p.dispose();
    });

    test('erro de rede no polling NÃO derruba: tenta de novo e aprova', () async {
      final gw = _FakePixGateway(['throw', 'throw', 'approved']);
      final p = PixProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.approved);
      p.dispose();
    });

    test('expirado no PSP => timeout', () async {
      final gw = _FakePixGateway(['pending', 'expired']);
      final p = PixProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.timeout);
      p.dispose();
    });

    test('timeout de exibição (relógio injetado) => timeout', () async {
      // Relógio que avança 60s por chamada; displayTimeout 180s => ~3 voltas.
      var t = DateTime(2026, 1, 1);
      DateTime clock() {
        final atual = t;
        t = t.add(const Duration(seconds: 60));
        return atual;
      }

      final gw = _FakePixGateway(const []); // sempre pending
      final p = PixProvider(
        gw,
        pollInterval: Duration.zero,
        displayTimeout: const Duration(seconds: 180),
        clock: clock,
      );
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.timeout);
      p.dispose();
    });

    test('falha ao gerar o PIX => PaymentCommunicationException', () async {
      final gw = _FakePixGateway(const [], criarThrows: true);
      final p = PixProvider(gw, pollInterval: Duration.zero);
      expect(() => p.start(_req()),
          throwsA(isA<PaymentCommunicationException>()));
      p.dispose();
    });

    test('cancelar() no meio do polling => cancelled', () async {
      late PixProvider p;
      final gw = _FakePixGateway(['pending', 'pending'],
          onStatus: () => p.cancelar());
      p = PixProvider(gw, pollInterval: Duration.zero);
      final r = await p.start(_req());
      expect(r.status, PaymentStatus.cancelled);
      p.dispose();
    });
  });
}
