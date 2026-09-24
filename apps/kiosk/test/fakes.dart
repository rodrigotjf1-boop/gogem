import 'dart:convert';
import 'package:gogem_kiosk/domain/order/order_models.dart';
import 'package:gogem_kiosk/domain/order/order_repository.dart';
import 'package:gogem_kiosk/printing/fila_impressao.dart';

/// Fakes em MEMÓRIA (Dart puro) dos repositórios de banco.
///
/// Widget tests NÃO devem tocar sqflite real: uma query disparada de dentro de
/// um widget, sob o relógio-falso do `TestWidgetsFlutterBinding`, não completa e
/// CONGELA o teste (timeout de 10 min). Overridar só o `databaseProvider` não
/// basta — o repositório ainda roda sqflite. A solução é trocar o repositório
/// inteiro por um fake em memória nos `overrides`.
///
/// Estes fakes implementam a API pública completa (sem `noSuchMethod`), então
/// nenhuma chamada inesperada estoura.

class FakeOrderRepository implements OrderRepository {
  final List<Map<String, Object?>> pedidos = [];
  int _seq = 0;

  @override
  Future<String> proximaSenha() async {
    _seq = _seq >= 999 ? 1 : _seq + 1;
    return _seq.toString().padLeft(3, '0');
  }

  @override
  Future<String> salvarPedido(PedidoLocal pedido) async {
    final senha = await proximaSenha();
    pedidos.add({
      'uuid': pedido.uuid,
      'senha': senha,
      'corpo_json': jsonEncode(pedido.toJson()),
      'status': 'pendente_envio',
      'criado_em': pedido.criadoEm.toIso8601String(),
      'tentativas': 0,
    });
    return senha;
  }

  @override
  Future<String> salvarPreCobranca(PedidoLocal pedido) async {
    final existente = pedidos.where((p) => p['uuid'] == pedido.uuid);
    if (existente.isNotEmpty) return existente.first['senha'] as String;
    final senha = await proximaSenha();
    pedidos.add({
      'uuid': pedido.uuid,
      'senha': senha,
      'corpo_json': jsonEncode(pedido.toJson()),
      'status': 'aguardando_pagamento',
      'criado_em': pedido.criadoEm.toIso8601String(),
      'tentativas': 0,
    });
    return senha;
  }

  @override
  Future<void> marcarPago(String uuid) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid && p['status'] == 'aguardando_pagamento') {
        p['status'] = 'pendente_envio';
      }
    }
  }

  @override
  Future<void> marcarCancelado(String uuid) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid && p['status'] == 'aguardando_pagamento') {
        p['status'] = 'cancelado';
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> listarAguardandoPagamento() async => [
        for (final p in pedidos)
          if (p['status'] == 'aguardando_pagamento') Map.of(p),
      ];

  @override
  Future<List<Map<String, Object?>>> listarPendentes() async => [
        for (final p in pedidos)
          if (p['status'] == 'pendente_envio') Map.of(p),
      ];

  @override
  Future<void> marcarEnviado(String uuid, String respostaJson) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) {
        p['status'] = 'enviado';
        p['resposta_json'] = respostaJson;
      }
    }
  }

  @override
  Future<void> registrarFalhaEnvio(String uuid) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) {
        p['tentativas'] = (p['tentativas'] as int) + 1;
      }
    }
  }

  @override
  Future<void> marcarRetido(String uuid, String retidoId) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) p['retido_id'] = retidoId;
    }
  }

  @override
  Future<void> marcarNaoConcluido(String uuid, String detalheJson) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) {
        p['status'] = 'nao_concluido';
        p['resposta_json'] = detalheJson;
      }
    }
  }

  @override
  Future<void> marcarEstornoPendente(String uuid, String detalheJson) async {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) {
        p['status'] = 'estorno_pendente';
        p['resposta_json'] = detalheJson;
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> listarEstornosPendentes() async => [
        for (final p in pedidos)
          if (p['status'] == 'estorno_pendente') Map.of(p),
      ];

  @override
  Future<int> pendentes() async => pedidos
      .where((p) =>
          p['status'] == 'pendente_envio' || p['status'] == 'estorno_pendente')
      .length;

  /// Status atual de um pedido (atalho dos testes).
  String? statusDe(String uuid) {
    for (final p in pedidos) {
      if (p['uuid'] == uuid) return p['status'] as String?;
    }
    return null;
  }
}

class FakeFilaImpressao implements FilaImpressao {
  final List<Map<String, Object?>> rows = [];

  /// Igual à fila real: a chave é PRIMARY KEY e o repetido é IGNORADO. Um fake que
  /// aceitava duplicata escondeu que o DANFE, enfileirado com a mesma chave do cupom,
  /// sumia na fila real (ERR-020).
  @override
  Future<void> enfileirar(String uuid, String senha, List<int> cupom) async {
    if (rows.any((r) => r['uuid'] == uuid)) return;
    rows.add({'uuid': uuid, 'senha': senha, 'cupom': cupom, 'tentativas': 0});
  }

  @override
  Future<int> pendentes() async => rows.length;

  @override
  Future<List<Map<String, Object?>>> listar() async => List.of(rows);

  @override
  Future<void> remover(String uuid) async =>
      rows.removeWhere((r) => r['uuid'] == uuid);
}
