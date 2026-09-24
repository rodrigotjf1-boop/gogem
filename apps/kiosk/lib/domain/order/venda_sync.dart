import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/gogem_api.dart';
import '../../data/catalog/catalog_sync.dart' show gogemApiProvider;
import '../../printing/fila_impressao.dart';
import '../../printing/recibo.dart';
import '../fiscal/bloqueio_fiscal.dart';
import '../fiscal/resultado_fiscal.dart';
import 'conclusao_venda.dart';
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
///
/// Recusa DEFINITIVA (400/422: código PDV que não existe, soma que não fecha) NÃO para a
/// fila: a venda sai com o motivo, o pagamento é estornado e as de trás seguem. Antes uma
/// venda recusada ficava na frente para sempre e nenhuma outra saía (ERR-008).
///
/// A resposta que chega aqui é de uma venda cujo cliente JÁ SAIU do totem (a tela não
/// recebeu resposta a tempo), então o resultado fiscal é tratado sem ele: nota não emitida
/// → estorno; nota emitida → o DANFE vai para a fila de reimpressão (a tela mandou o
/// cliente buscá-lo no balcão).
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
    final conclusao = ConclusaoVenda(api: api, repo: repo);

    // Primeiro o dinheiro do cliente: estornos que não saíram por falta de rede.
    for (final row in await repo.listarEstornosPendentes()) {
      await conclusao.retentarEstorno(row);
    }

    final fila = await repo.listarPendentes();
    state = VendaSyncState(pendentes: fila.length, enviando: true);
    var ok = 0;
    var recusadas = 0;
    for (final row in fila) {
      final uuid = row['uuid'] as String;
      final corpo = jsonDecode(row['corpo_json'] as String) as Map<String, dynamic>;
      final retidoId = row['retido_id'] as String?;
      try {
        // Servidor da loja: o pedido já está RETIDO lá, com a senha que o cliente levou.
        // Reenvia pela liberação — a repetição devolve a mesma venda e a mesma nota.
        final resp = retidoId == null
            ? await api.enviarVenda(corpo)
            : await api.liberarPedidoRetido(
                retidoId, corpo['pagamentos'] as List<dynamic>);
        await _concluir(repo, conclusao, uuid, corpo, resp);
        ok++;
      } on GogemApiException catch (e) {
        if (e.status == 409) {
          // idempotência: backend já processou este uuid — sucesso
          await repo.marcarEnviado(uuid, '{"idempotente":true}');
          ok++;
        } else if (recusaDefinitiva(e.status)) {
          await conclusao.naoConcluida(
            uuid: uuid,
            corpo: corpo,
            motivo: 'Venda recusada pelo sistema da loja: ${e.motivo}',
            etapa: 'recusada',
          );
          recusadas++;
        } else {
          await repo.registrarFalhaEnvio(uuid);
          _falhas++;
          state = VendaSyncState(
              pendentes: await repo.pendentes(),
              msg: 'API ${e.status} — mantido na fila');
          return; // erro passageiro: para a drenagem, tenta no próximo ciclo
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
        msg: ok > 0 || recusadas > 0
            ? '$ok pedido(s) enviados'
                '${recusadas > 0 ? ', $recusadas recusado(s) e estornado(s)' : ''}'
            : null);
  }

  /// A venda voltou do servidor: trata o resultado fiscal sem o cliente na frente.
  Future<void> _concluir(OrderRepository repo, ConclusaoVenda conclusao,
      String uuid, Map<String, dynamic> corpo, Map<String, dynamic> resp) async {
    final fiscal = ResultadoFiscal.de(resp['nfce']);
    if (fiscal is NotaNaoEmitida) {
      final estorno = resp['estorno'];
      await conclusao.naoConcluida(
        uuid: uuid,
        corpo: corpo,
        motivo: fiscal.motivoRelatorio,
        etapa: fiscal.etapa,
        repete: fiscal.repete,
        estornoFeito: estorno is Map ? estorno.cast<String, dynamic>() : null,
      );
      ref.read(bloqueioFiscalProvider.notifier).registrarNaoEmitida(
          repete: fiscal.repete, motivo: fiscal.motivoRelatorio);
      return;
    }
    if (resp['cancelado'] == true) {
      // Cancelado pelo painel ou pelo Regem enquanto estava na fila: quem cancelou já
      // cuidou do dinheiro. Só sai da fila.
      await repo.marcarNaoConcluido(
          uuid, jsonEncode({'motivo': 'pedido cancelado', 'resposta': resp}));
      return;
    }
    await repo.marcarEnviado(uuid, jsonEncode(resp));
    if (fiscal is NotaEmitida) {
      ref.read(bloqueioFiscalProvider.notifier).registrarEmitida();
      // O cliente já saiu com o aviso "retire o cupom fiscal no balcão": o DANFE fica na
      // fila de reimpressão (painel do totem) — nunca é impresso sozinho, na frente do
      // próximo cliente.
      try {
        final fila = await ref.read(filaImpressaoProvider.future);
        final senha = '${resp['senha'] ?? corpo['senhaLocal'] ?? ''}';
        await fila.enfileirar(chaveDanfe(uuid), senha, montarDanfe(fiscal.danfe));
        if (fiscal.viaEstabelecimento) {
          await fila.enfileirar(chaveDanfe(uuid, viaEstabelecimento: true), senha,
              montarDanfe(fiscal.danfe, viaEstabelecimento: true));
        }
      } catch (_) {/* a nota existe no Regem; a reimpressão sai pela liberação */}
    }
  }
}

final vendaSyncProvider =
    NotifierProvider<VendaSyncNotifier, VendaSyncState>(VendaSyncNotifier.new);
