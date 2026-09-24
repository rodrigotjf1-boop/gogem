import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/core/tempo/relogio_servidor.dart';
import 'package:gogem_kiosk/data/catalog/catalog_sync.dart' show databaseProvider;
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'db_helper.dart';

/// K3 — a hora do totem vem do servidor.
///
/// O que está em jogo não é o relógio bonito na tela: é o DIA que zera a senha. Um
/// Android de sala sem internet deriva, e depois de queda de energia pode voltar com
/// data errada — aí o contador reinicia fora de hora e dois clientes carregam o mesmo
/// número. Datas FIXAS nos testes, nunca "agora" (LIC-006).
void main() {
  group('leitura do cabeçalho Date', () {
    test('converte o formato de HTTP (GMT) para hora local', () {
      final d = parseDataHttp('Wed, 23 Sep 2026 03:20:00 GMT');
      expect(d, isNotNull);
      expect(d!.toUtc(), DateTime.utc(2026, 9, 23, 3, 20));
      expect(d.isUtc, isFalse, reason: 'o dia da loja é o dia LOCAL');
    });

    test('ausente ou ilegível não vira hora (servidor sem Date não desregula o totem)', () {
      for (final v in [null, '', '   ', 'ontem', '2026-09-23T03:20:00Z']) {
        expect(parseDataHttp(v), isNull);
      }
    });
  });

  group('desvio aplicado', () {
    test('desvio grande é adotado e guardado; pequeno é ruído e ignorado', () async {
      final db = await novaDbMemoria();
      final c = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) async => db)]);
      final r = c.read(relogioServidorProvider.notifier);

      // 2 segundos = ruído de rede (o cabeçalho tem precisão de segundos).
      final perto = DateTime.now().toUtc().add(const Duration(seconds: 2));
      await r.sincronizar(_http(perto));
      expect(c.read(relogioServidorProvider), Duration.zero);
      expect((await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveDesvio])).isEmpty,
          isTrue);

      // 3 horas à frente = relógio do aparelho errado de verdade.
      final longe = DateTime.now().toUtc().add(const Duration(hours: 3));
      await r.sincronizar(_http(longe));
      final desvio = c.read(relogioServidorProvider);
      expect(desvio.inMinutes, closeTo(180, 1));
      // Guardado: o próximo boot sem rede começa já corrigido.
      final salvo = (await db.query('kv', where: 'chave = ?', whereArgs: [kvChaveDesvio]))
          .single['valor'] as String;
      expect(int.parse(salvo), desvio.inMilliseconds);

      // E `agora()` anda com o desvio.
      expect(r.agora().difference(DateTime.now()).inMinutes, closeTo(180, 1));
    });

    test('o desvio guardado volta no boot seguinte', () async {
      final db = await novaDbMemoria();
      await db.insert('kv', {
        'chave': kvChaveDesvio,
        'valor': const Duration(hours: -2).inMilliseconds.toString(),
      });
      final c = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) async => db)]);
      await c.read(relogioServidorProvider.notifier).carregar();
      expect(c.read(relogioServidorProvider).inHours, -2);
    });
  });

  test('a senha do dia segue o relógio do SERVIDOR, não o do aparelho', () async {
    final db = await novaDbMemoria();
    // Relógio fixo: dia 23 às 23h50 (LIC-006 — data fixa, nunca "agora").
    var agora = DateTime(2026, 9, 23, 23, 50);
    final repo = OrderRepository(db, clock: () => agora);

    expect(await repo.proximaSenha(), '001');
    expect(await repo.proximaSenha(), '002');

    // Passou da meia-noite PELO RELÓGIO DO SERVIDOR → novo dia, contador zera.
    agora = DateTime(2026, 9, 24, 0, 10);
    expect(await repo.proximaSenha(), '001');

    // De volta ao mesmo dia: continua de onde parou (não reinicia a cada pedido).
    expect(await repo.proximaSenha(), '002');
  });
}

/// Formata como o cabeçalho `Date` do HTTP (RFC 7231, sempre GMT).
String _http(DateTime utc) {
  const dias = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const meses = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${dias[utc.weekday - 1]}, ${d2(utc.day)} ${meses[utc.month - 1]} ${utc.year} '
      '${d2(utc.hour)}:${d2(utc.minute)}:${d2(utc.second)} GMT';
}
