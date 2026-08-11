import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/gogem_api.dart';
import '../../data/catalog/catalog_sync.dart' show gogemApiProvider;
import 'order_repository.dart';

class VendaSyncState {
  const VendaSyncState({this.pendentes = 0, this.enviando = false, this.msg});
  final int pendentes;
  final bool enviando;
  final String? msg;
}

/// F6 — drena `pedidos_locais` para o backend.
/// Regras: Idempotency-Key = uuid (reenvio jamais duplica); **409 = já
/// processado ⇒ sucesso**; falha de rede interrompe a drenagem e mantém a
/// fila intacta (offline-first); agendador 45s com backoff simples.
class VendaSyncNotifier extends Notifier<VendaSyncState> {
  Timer? _timer;
  int _falhas = 0;

  @override
  VendaSyncState build() {
    ref.onDispose(() => _timer?.cancel());
    return const VendaSyncState();
  }

  void iniciarAgendador() {
    if (_timer != null) return;
    // No boot: primeiro reconcilia pagamentos presos (write-ahead F10), depois
    // começa a drenar a fila. Assim um pedido pago-mas-não-salvo (queda entre
    // pagar e gravar) volta pro fluxo antes de qualquer envio.
    unawaited(resolverPendencias());
    _agendar(const Duration(seconds: 5));
  }

  /// F10 — recuperação no boot. Pedidos presos em 'aguardando_pagamento' (o
  /// totem caiu entre a aprovação e o salvamento) são reconciliados pelo status
  /// REAL no backend: aprovado → libera pro envio; recusado/cancelado/expirado/
  /// inexistente → descarta; ainda pendente ou offline → deixa preso (o próximo
  /// boot tenta de novo). Nunca perde dinheiro capturado, nunca envia não-pago.
  Future<void> resolverPendencias() async {
    final repo = await ref.read(orderRepositoryProvider.future);
    final api = ref.read(gogemApiProvider);
    final presos = await repo.listarAguardandoPagamento();
    for (final row in presos) {
      final uuid = row['uuid'] as String;
      try {
        final st = await api.statusPorOrder(uuid);
        switch (st.status) {
          case 'approved':
            await repo.marcarPago(uuid);
          case 'nenhum':
          case 'rejected':
          case 'cancelled':
          case 'expired':
          case 'error':
            await repo.marcarCancelado(uuid);
          // 'pending' → deixa preso; a cobrança ainda pode fechar
        }
      } catch (_) {
        // sem rede: deixa preso, tenta no próximo boot
      }
    }
    await atualizarContagem();
  }

  void _agendar(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, () async {
      await drenar();
      final prox = _falhas == 0
          ? const Duration(seconds: 45)
          : Duration(seconds: (45 * (1 << _falhas.clamp(0, 3))).clamp(45, 480));
      _agendar(prox);
    });
  }

  Future<void> atualizarContagem() async {
    final repo = await ref.read(orderRepositoryProvider.future);
    state = VendaSyncState(pendentes: await repo.pendentes(), msg: state.msg);
  }

  Future<void> drenar() async {
    final repo = await ref.read(orderRepositoryProvider.future);
    final api = ref.read(gogemApiProvider);
    final fila = await repo.listarPendentes();
    state = VendaSyncState(pendentes: fila.length, enviando: true);
    var ok = 0;
    for (final row in fila) {
      final uuid = row['uuid'] as String;
      final corpo = jsonDecode(row['corpo_json'] as String) as Map<String, dynamic>;
      try {
        final resp = await api.enviarVenda(corpo);
        await repo.marcarEnviado(uuid, jsonEncode(resp));
        ok++;
      } on GogemApiException catch (e) {
        if (e.status == 409) {
          // idempotência: backend já processou este uuid — sucesso
          await repo.marcarEnviado(uuid, '{"idempotente":true}');
          ok++;
        } else {
          await repo.registrarFalhaEnvio(uuid);
          _falhas++;
          state = VendaSyncState(
              pendentes: await repo.pendentes(),
              msg: 'API ${e.status} — mantido na fila');
          return; // erro de API: para a drenagem, tenta no próximo ciclo
        }
      } catch (_) {
        // sem rede: interrompe, fila intacta
        _falhas++;
        state = VendaSyncState(
            pendentes: await repo.pendentes(), msg: 'offline — fila preservada');
        return;
      }
    }
    _falhas = 0;
    state = VendaSyncState(
        pendentes: await repo.pendentes(),
        msg: ok > 0 ? '$ok pedido(s) enviados' : null);
  }
}

final vendaSyncProvider =
    NotifierProvider<VendaSyncNotifier, VendaSyncState>(VendaSyncNotifier.new);
