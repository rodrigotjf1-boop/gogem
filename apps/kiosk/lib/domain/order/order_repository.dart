import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/catalog/catalog_sync.dart' show databaseProvider;
import 'order_models.dart';

/// Fila local de pedidos (offline-first): todo pedido finalizado entra como
/// `pendente_envio`; a Fatia 6 drena para o backend com o mesmo UUID
/// (reenvio jamais duplica). Senha de retirada: sequencial diário 3 dígitos.
class OrderRepository {
  OrderRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final Database _db;
  final DateTime Function() _clock;

  Future<String> proximaSenha() async {
    final hoje = _clock().toIso8601String().substring(0, 10);
    return _db.transaction((tx) async {
      final r = await tx.query('kv', where: 'chave = ?', whereArgs: ['senha_seq']);
      final dia = hoje;
      var seq = 0;
      if (r.isNotEmpty) {
        final parts = (r.first['valor'] as String).split('|');
        if (parts.length == 2 && parts[0] == hoje) seq = int.tryParse(parts[1]) ?? 0;
      }
      seq = seq >= 999 ? 1 : seq + 1;
      await tx.insert('kv', {'chave': 'senha_seq', 'valor': '$dia|$seq'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return seq.toString().padLeft(3, '0');
    });
  }

  Future<String> salvarPedido(PedidoLocal pedido) async {
    final senha = await proximaSenha();
    await _db.insert('pedidos_locais', {
      'uuid': pedido.uuid,
      'senha': senha,
      // A senha de retirada (sequencial diário) segue ao backend/Regem como
      // senhaLocal — só é conhecida aqui, após proximaSenha().
      'corpo_json': jsonEncode(pedido.toJson(senhaLocal: int.tryParse(senha))),
      'status': 'pendente_envio',
      'criado_em': pedido.criadoEm.toIso8601String(),
    });
    return senha;
  }

  /// Pedidos aguardando envio ao backend (F6 drena com Idempotency-Key=uuid).
  Future<List<Map<String, Object?>>> listarPendentes() => _db.query(
      'pedidos_locais',
      where: "status = 'pendente_envio'",
      orderBy: 'criado_em');

  Future<void> marcarEnviado(String uuid, String respostaJson) => _db.update(
      'pedidos_locais',
      {
        'status': 'enviado',
        'enviado_em': DateTime.now().toIso8601String(),
        'resposta_json': respostaJson,
      },
      where: 'uuid = ?',
      whereArgs: [uuid]);

  Future<void> registrarFalhaEnvio(String uuid) => _db.rawUpdate(
      'UPDATE pedidos_locais SET tentativas = tentativas + 1 WHERE uuid = ?',
      [uuid]);

  Future<int> pendentes() async {
    final r = await _db.rawQuery(
        "SELECT COUNT(*) c FROM pedidos_locais WHERE status = 'pendente_envio'");
    return (r.first['c'] as int?) ?? 0;
  }
}

final orderRepositoryProvider = FutureProvider<OrderRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return OrderRepository(db);
});
