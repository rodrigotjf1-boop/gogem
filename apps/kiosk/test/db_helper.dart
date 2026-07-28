import 'package:gogem_kiosk/data/db/kiosk_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;

/// Banco SQLite em memória ISOLADO por teste. `inMemoryDatabasePath` sozinho
/// compartilha a MESMA base entre testes do arquivo (estado vaza → contagens
/// acumulam, ex.: pendentes 2 vira 3). Usar sempre este helper nos testes.
///
/// URI `mode=memory&cache=private` + nome único por teste dá isolamento entre
/// testes; `singleInstance: false` evita o cache por caminho do factory.
Future<Database> novaDbMemoria() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    'file:testdb_${_seq++}?mode=memory&cache=private',
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await KioskDatabase.ensureSchema(db);
  return db;
}
