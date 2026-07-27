import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../data/catalog/catalog_sync.dart' show databaseProvider;

/// Fila de REIMPRESSÃO: quando o cupom não sai (sem papel/desconectada),
/// o pedido NÃO se perde — a senha fica na tela e o cupom entra aqui.
/// O painel admin (F5) e a telemetria (S5) drenam/alertam.
class FilaImpressao {
  FilaImpressao(this._db);
  final Database _db;

  Future<void> enfileirar(String uuid, String senha, List<int> cupom) =>
      _db.insert(
          'fila_impressao',
          {
            'uuid': uuid,
            'senha': senha,
            'cupom': cupom,
            'tentativas': 0,
            'criado_em': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<int> pendentes() async {
    final r = await _db.rawQuery('SELECT COUNT(*) c FROM fila_impressao');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> listar() =>
      _db.query('fila_impressao', orderBy: 'criado_em');

  Future<void> remover(String uuid) =>
      _db.delete('fila_impressao', where: 'uuid = ?', whereArgs: [uuid]);
}

final filaImpressaoProvider = FutureProvider<FilaImpressao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return FilaImpressao(db);
});
