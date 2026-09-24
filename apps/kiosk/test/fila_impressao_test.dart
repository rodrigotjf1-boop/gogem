import 'package:flutter_test/flutter_test.dart';
import 'db_helper.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';

void main() {
  test('enfileirar/listar/remover, idempotente por uuid', () async {
    final db = await novaDbMemoria();
    final f = FilaImpressao(db);
    await f.enfileirar('u1', '007', [1, 2, 3]);
    await f.enfileirar('u1', '007', [1, 2, 3]); // repetido: ignorado
    expect(await f.pendentes(), 1);
    final row = (await f.listar()).single;
    expect(row['senha'], '007');
    await f.remover('u1');
    expect(await f.pendentes(), 0);
  });

  // ERR-020 — com a mesma chave (o uuid do pedido) para o cupom e para o DANFE, o DANFE
  // que não saía era IGNORADO pela fila: o cliente ficava sem a nota e ninguém sabia.
  test('cupom, DANFE e via do estabelecimento do MESMO pedido ficam os três na fila',
      () async {
    final db = await novaDbMemoria();
    final f = FilaImpressao(db);
    await f.enfileirar('u1', '007', [1]); // cupom (senha)
    await f.enfileirar(chaveDanfe('u1'), '007', [2]);
    await f.enfileirar(chaveDanfe('u1', viaEstabelecimento: true), '007', [3]);
    await f.enfileirar(chaveDanfe('u1'), '007', [2]); // repetido: ignorado
    expect(await f.pendentes(), 3);
    final docs = (await f.listar()).map((r) => r['cupom']).toList();
    expect(docs, containsAll([
      [1],
      [2],
      [3]
    ]));
  });
}
