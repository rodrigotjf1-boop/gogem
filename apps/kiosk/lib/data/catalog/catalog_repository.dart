import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'catalog_models.dart';

/// Persistência do catálogo. Mantém as 3 últimas versões (auditoria/rollback
/// local) e o ponteiro `versao_corrente` no kv.
class CatalogRepository {
  CatalogRepository(this._db);
  final Database _db;

  Future<int?> versaoCorrente() async {
    final r = await _db.query('kv', where: 'chave = ?', whereArgs: ['versao_corrente']);
    if (r.isEmpty) return null;
    return int.tryParse(r.first['valor'] as String);
  }

  /// Aparência do totem (por loja) — persistida no kv p/ aplicar offline no boot.
  Future<void> salvarAparencia(Object? aparencia) async {
    if (aparencia == null) return;
    await _db.insert(
      'kv',
      {'chave': 'aparencia', 'valor': jsonEncode(aparencia)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Object?> carregarAparencia() async {
    final r = await _db.query('kv', where: 'chave = ?', whereArgs: ['aparencia']);
    if (r.isEmpty) return null;
    return jsonDecode(r.first['valor'] as String);
  }

  Future<void> salvarSnapshot(Map<String, dynamic> corpo) async {
    final versao = (corpo['versao'] as num).toInt();
    await _db.transaction((tx) async {
      await tx.insert(
        'menu_snapshot',
        {
          'versao': versao,
          'corpo_json': jsonEncode(corpo),
          'salvo_em': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await tx.insert('kv', {'chave': 'versao_corrente', 'valor': '$versao'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      // retenção: mantém as 3 mais recentes
      await tx.delete('menu_snapshot',
          where:
              'versao NOT IN (SELECT versao FROM menu_snapshot ORDER BY versao DESC LIMIT 3)');
    });
  }

  Future<MenuSnapshot?> carregarCorrente() async {
    final v = await versaoCorrente();
    if (v == null) return null;
    final r = await _db
        .query('menu_snapshot', where: 'versao = ?', whereArgs: [v], limit: 1);
    if (r.isEmpty) return null;
    final corpo = jsonDecode(r.first['corpo_json'] as String) as Map;
    return MenuSnapshot.fromPublicadoJson(corpo);
  }
}
