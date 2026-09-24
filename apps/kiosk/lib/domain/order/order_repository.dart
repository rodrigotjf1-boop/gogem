import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/catalog/catalog_sync.dart' show databaseProvider;
import '../../core/tempo/relogio_servidor.dart';
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

  /// F10 write-ahead: grava o pedido (com senha) ANTES de cobrar, em
  /// 'aguardando_pagamento'. Se o totem cair entre pagar e salvar, o pedido não
  /// se perde — o boot reconcilia por uuid (resolvePendings). Idempotente:
  /// re-salvar o mesmo uuid não duplica.
  Future<String> salvarPreCobranca(PedidoLocal pedido) async {
    final senha = await proximaSenha();
    await _db.insert(
      'pedidos_locais',
      {
        'uuid': pedido.uuid,
        'senha': senha,
        'corpo_json':
            jsonEncode(pedido.toJson(senhaLocal: int.tryParse(senha))),
        'status': 'aguardando_pagamento',
        'criado_em': pedido.criadoEm.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final r = await _db.query('pedidos_locais',
        columns: ['senha'], where: 'uuid = ?', whereArgs: [pedido.uuid]);
    return r.isNotEmpty ? r.first['senha'] as String : senha;
  }

  /// Pagamento confirmado → libera o pedido para envio ao Regem.
  Future<void> marcarPago(String uuid) => _db.update(
      'pedidos_locais', {'status': 'pendente_envio'},
      where: 'uuid = ? AND status = ?',
      whereArgs: [uuid, 'aguardando_pagamento']);

  /// Pagamento NÃO concluído → descarta (não vai pro Regem).
  Future<void> marcarCancelado(String uuid) => _db.update(
      'pedidos_locais', {'status': 'cancelado'},
      where: 'uuid = ? AND status = ?',
      whereArgs: [uuid, 'aguardando_pagamento']);

  /// Pedidos travados em 'aguardando_pagamento' (recuperação no boot).
  Future<List<Map<String, Object?>>> listarAguardandoPagamento() => _db.query(
      'pedidos_locais',
      where: "status = 'aguardando_pagamento'",
      orderBy: 'criado_em');

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

  /// Servidor da loja: guarda o id do pedido RETIDO. Se a liberação não concluir agora,
  /// a fila reenvia por ela (mesma senha, mesma nota), não como venda nova.
  Future<void> marcarRetido(String uuid, String retidoId) => _db.update(
      'pedidos_locais', {'retido_id': retidoId},
      where: 'uuid = ?', whereArgs: [uuid]);

  /// A venda NÃO se concluiu (nota não emitida, venda recusada, cupom fiscal que não
  /// imprimiu) e o estorno já foi resolvido — feito, ou impossível pelo totem. Sai da fila
  /// de vez; `detalheJson` guarda o motivo e o resultado do estorno.
  Future<void> marcarNaoConcluido(String uuid, String detalheJson) => _db.update(
      'pedidos_locais',
      {
        'status': 'nao_concluido',
        'enviado_em': DateTime.now().toIso8601String(),
        'resposta_json': detalheJson,
      },
      where: 'uuid = ?',
      whereArgs: [uuid]);

  /// A venda não se concluiu e o ESTORNO ainda não saiu (sem rede agora). A fila tenta de
  /// novo a cada ciclo — dinheiro do cliente não pode ficar esquecido numa tela.
  Future<void> marcarEstornoPendente(String uuid, String detalheJson) =>
      _db.update(
          'pedidos_locais',
          {'status': 'estorno_pendente', 'resposta_json': detalheJson},
          where: 'uuid = ?',
          whereArgs: [uuid]);

  /// Estornos que ainda não saíram (a fila os reenvia).
  Future<List<Map<String, Object?>>> listarEstornosPendentes() => _db.query(
      'pedidos_locais',
      where: "status = 'estorno_pendente'",
      orderBy: 'criado_em');

  /// O que ainda depende da fila: venda a enviar OU estorno a fazer.
  Future<int> pendentes() async {
    final r = await _db.rawQuery("SELECT COUNT(*) c FROM pedidos_locais "
        "WHERE status IN ('pendente_envio', 'estorno_pendente')");
    return (r.first['c'] as int?) ?? 0;
  }
}

final orderRepositoryProvider = FutureProvider<OrderRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  // K3 — a senha zera no DIA DA LOJA, medido pelo relógio do servidor. Com o relógio do
  // aparelho, um Android que voltou de queda de energia com data errada reiniciava o
  // contador fora de hora e dois clientes saíam com o mesmo número.
  final relogio = ref.watch(relogioServidorProvider.notifier);
  return OrderRepository(db, clock: relogio.agora);
});
