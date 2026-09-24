import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/domain/fiscal/bloqueio_fiscal.dart';
import 'package:gogem_kiosk/domain/fiscal/resultado_fiscal.dart';

/// O contrato do Regem (#574) lido pelo totem, e a trava de cartão/PIX.
void main() {
  group('ResultadoFiscal.de', () {
    test('null → sem nota (loja sem fiscal ou totem desmarcado)', () {
      expect(ResultadoFiscal.de(null), isA<SemNota>());
    });

    test('autorizada com DANFE → nota emitida, sem 2ª via', () {
      final r = ResultadoFiscal.de(
          {'status': 'autorizada', 'danfe': 'DANFE', 'viaEstabelecimento': true});
      expect(r, isA<NotaEmitida>());
      // A 2ª via só existe na contingência — mesmo que o campo venha por engano.
      expect((r as NotaEmitida).viaEstabelecimento, isFalse);
    });

    test('contingência com a 2ª via ligada', () {
      final r = ResultadoFiscal.de({
        'status': 'contingencia',
        'danfe': 'DANFE',
        'viaEstabelecimento': true,
      }) as NotaEmitida;
      expect(r.contingencia, isTrue);
      expect(r.viaEstabelecimento, isTrue);
    });

    test('nao_emitida → etapa, código, motivo e repete; motivo no formato do Regem',
        () {
      final r = ResultadoFiscal.de({
        'status': 'nao_emitida',
        'danfe': null,
        'erro': {
          'etapa': 'rejeitada',
          'codigo': '778',
          'motivo': 'NCM inexistente',
          'repete': true
        },
      }) as NotaNaoEmitida;
      expect(r.etapa, 'rejeitada');
      expect(r.codigo, '778');
      expect(r.repete, isTrue);
      expect(r.motivoRelatorio, 'NFC-e não emitida (rejeitada 778): NCM inexistente');
    });

    test('nao_emitida sem código → motivo sem o espaço do código', () {
      final r = ResultadoFiscal.de({
        'status': 'nao_emitida',
        'erro': {'etapa': 'configuracao', 'codigo': null, 'motivo': 'certificado vencido'},
      }) as NotaNaoEmitida;
      expect(r.motivoRelatorio, 'NFC-e não emitida (configuracao): certificado vencido');
      expect(r.repete, isFalse); // ausente = não afirma que repete
    });

    test('status desconhecido SEM DANFE → sem nota (nunca desfaz a venda por palpite)',
        () {
      expect(ResultadoFiscal.de({'status': 'pendente'}), isA<SemNota>());
    });
  });

  group('BloqueioFiscal', () {
    late DateTime agora;
    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        bloqueioFiscalProvider.overrideWith(
            () => BloqueioFiscalNotifier(relogio: () => agora)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => agora = DateTime(2026, 9, 24, 12));

    test('UMA falha que repete não trava (pode ser um produto só)', () {
      final c = container();
      c.read(bloqueioFiscalProvider.notifier)
          .registrarNaoEmitida(repete: true, motivo: 'm');
      expect(c.read(bloqueioFiscalProvider.notifier).travado, isFalse);
    });

    test('DUAS seguidas travam por 10 min; depois destrava sozinho', () {
      final c = container();
      final b = c.read(bloqueioFiscalProvider.notifier);
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      expect(b.travado, isTrue);
      agora = agora.add(const Duration(minutes: 11));
      expect(b.travado, isFalse);
    });

    test('nota emitida no meio zera a contagem', () {
      final c = container();
      final b = c.read(bloqueioFiscalProvider.notifier);
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      b.registrarEmitida();
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      expect(b.travado, isFalse);
    });

    test('falha que NÃO repete (passageira) não conta', () {
      final c = container();
      final b = c.read(bloqueioFiscalProvider.notifier);
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      b.registrarNaoEmitida(repete: false, motivo: 'm');
      b.registrarNaoEmitida(repete: true, motivo: 'm');
      expect(b.travado, isFalse);
    });
  });
}
