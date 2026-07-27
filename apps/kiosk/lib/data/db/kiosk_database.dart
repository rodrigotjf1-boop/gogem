import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SQLite local — a FONTE DA VERDADE do totem (offline-first, CLAUDE.md).
/// O snapshot publicado é imutável: guardamos o corpo bruto por versão e um
/// ponteiro para a versão corrente.
abstract final class KioskDatabase {
  static const _file = 'gogem_kiosk.db';

  static Future<Database> open() async {
    final dir = await getApplicationSupportDirectory();
    final db = await openDatabase(p.join(dir.path, _file), version: 1,
        onCreate: (db, _) => ensureSchema(db));
    await ensureSchema(db); // idempotente (CREATE IF NOT EXISTS)
    return db;
  }

  /// Extraído para os testes abrirem bancos ffi em memória com o mesmo schema.
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_snapshot (
        versao INTEGER PRIMARY KEY,
        corpo_json TEXT NOT NULL,
        salvo_em TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedidos_locais (
        uuid TEXT PRIMARY KEY,
        senha TEXT NOT NULL,
        corpo_json TEXT NOT NULL,
        status TEXT NOT NULL,
        criado_em TEXT NOT NULL,
        tentativas INTEGER NOT NULL DEFAULT 0,
        enviado_em TEXT,
        resposta_json TEXT
      )''');
    // bancos de dev antigos: colunas novas via ALTER tolerante
    for (final alter in const [
      "ALTER TABLE pedidos_locais ADD COLUMN tentativas INTEGER NOT NULL DEFAULT 0",
      "ALTER TABLE pedidos_locais ADD COLUMN enviado_em TEXT",
      "ALTER TABLE pedidos_locais ADD COLUMN resposta_json TEXT",
    ]) {
      try {
        await db.execute(alter);
      } catch (_) {/* coluna já existe */}
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fila_impressao (
        uuid TEXT PRIMARY KEY,
        senha TEXT NOT NULL,
        cupom BLOB NOT NULL,
        tentativas INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )''');
  }
}
