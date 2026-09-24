import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../data/catalog/catalog_sync.dart' show databaseProvider;

/// Chave do DANFE de um pedido na fila de reimpressão.
///
/// A chave da fila é PRIMARY KEY e o repetido é ignorado — é o que torna o `enfileirar`
/// idempotente. Mas um pedido tem DOIS documentos (o cupom da senha e o DANFE; na
/// contingência, ainda a via do estabelecimento): com o uuid do pedido para todos, o DANFE
/// que não saía era descartado calado quando o cupom já estava na fila (ERR-020).
String chaveDanfe(String uuid, {bool viaEstabelecimento = false}) =>
    viaEstabelecimento ? '$uuid#danfe-estabelecimento' : '$uuid#danfe';

/// Fila de REIMPRESSÃO: quando o cupom não sai (sem papel/desconectada),
/// o pedido NÃO se perde — a senha fica na tela e o cupom entra aqui.
/// O painel admin (F5) e a telemetria (S5) drenam/alertam. Cada documento tem a sua
/// chave: o cupom usa o uuid do pedido; o DANFE, [chaveDanfe].
class FilaImpressao {
  FilaImpressao(this._db);
  final Database _db;

  Future<void> enfileirar(String uuid, String senha, List<int> cupom) =>
      _db.insert(
          'fila_impressao',
          {
            'uuid': uuid,
            'senha': senha,
            // Coluna BLOB: o sqflite só binda bytes como Uint8List — um
            // List<int> cru estoura "Invalid sql argument type". A leitura
            // (admin_panel) já espera Uint8List (que É List<int>).
            'cupom': Uint8List.fromList(cupom),
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
