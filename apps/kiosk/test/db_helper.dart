import 'package:gogem_kiosk/data/db/kiosk_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Banco SQLite em memória ISOLADO por teste.
///
/// `:memory:` com `singleInstance: true` (o default) COMPARTILHA a mesma base
/// entre todos os testes do arquivo — o factory faz cache por caminho, então o
/// estado vaza e contagens acumulam (ex.: pendentes 2 vira 3).
///
/// Com `singleInstance: false`, cada chamada abre uma base in-memory NOVA e
/// independente (bases `:memory:` são privadas por conexão) ⇒ isolamento entre
/// testes; e como o repositório reusa a MESMA conexão, os writes persistem
/// dentro de um teste (o sync offline-first grava e relê o snapshot local).
Future<Database> novaDbMemoria() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await KioskDatabase.ensureSchema(db);
  return db;
}
