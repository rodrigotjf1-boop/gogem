import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/db/kiosk_database.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());
  test('enfileirar/listar/remover, idempotente por uuid', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await KioskDatabase.ensureSchema(db);
    final f = FilaImpressao(db);
    await f.enfileirar('u1', '007', [1, 2, 3]);
    await f.enfileirar('u1', '007', [1, 2, 3]); // repetido: ignorado
    expect(await f.pendentes(), 1);
    final row = (await f.listar()).single;
    expect(row['senha'], '007');
    await f.remover('u1');
    expect(await f.pendentes(), 0);
  });
}
