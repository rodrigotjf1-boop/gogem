import 'dart:async';
import 'dart:convert';
import '../../data/api/gogem_api.dart';
import 'order_repository.dart';

/// Como ficou o dinheiro do cliente numa venda que não se concluiu — é o que a tela diz.
enum SituacaoEstorno {
  /// O estorno foi pedido ao Mercado Pago (ou já tinha sido): o valor volta ao cartão/conta.
  feito,

  /// Sem conexão agora: a fila do totem tenta de novo sozinha.
  pendente,

  /// O totem não consegue devolver (pagamento fora do GoGeM, prazo vencido, recusa do
  /// Mercado Pago): quem devolve é o atendente.
  manual,

  /// Dinheiro: nada foi cobrado no totem.
  semCobranca,
}

/// A venda foi paga, mas NÃO se concluiu: a NFC-e não foi emitida, o sistema da loja
/// recusou a venda, ou o cupom fiscal não imprimiu (e a nota foi cancelada). Aqui o
/// dinheiro volta ao cliente, o pedido sai da fila com o motivo e o gestor é avisado.
///
/// Usado pela tela de pagamento (cliente na frente do totem) e pela fila de envio (a venda
/// que só se resolveu depois) — as duas têm de terminar do mesmo jeito.
class ConclusaoVenda {
  ConclusaoVenda({required this.api, required this.repo});
  final GogemApi api;
  final OrderRepository repo;

  /// Desfaz, do lado do totem, uma venda que não se concluiu.
  ///
  /// `corpo` é o `PedidoLocal.toJson` (o mesmo que foi à venda). `estornoFeito` é o estorno
  /// que a nuvem já fez (venda pela nuvem com nota não emitida) — aí não se pede de novo.
  Future<SituacaoEstorno> naoConcluida({
    required String uuid,
    required Map<String, dynamic> corpo,
    required String motivo,
    required String etapa,
    int? senha,
    bool repete = false,
    Map<String, dynamic>? estornoFeito,
  }) async {
    SituacaoEstorno situacao;
    Map<String, dynamic>? estorno = estornoFeito;
    if (!_eletronico(corpo)) {
      situacao = SituacaoEstorno.semCobranca;
    } else if (estornoFeito?['feito'] == true) {
      situacao = SituacaoEstorno.feito;
    } else {
      final r = await _estornar(uuid, corpo, motivo, etapa, senha);
      situacao = r.situacao;
      estorno = r.estorno;
    }

    final detalhe = jsonEncode({
      'motivo': motivo,
      'etapa': etapa,
      'repete': repete,
      if (senha != null) 'senha': senha,
      'estorno': estorno,
      'situacao': situacao.name,
    });
    if (situacao == SituacaoEstorno.pendente) {
      await repo.marcarEstornoPendente(uuid, detalhe);
    } else {
      await repo.marcarNaoConcluido(uuid, detalhe);
    }

    // O gestor precisa saber: nota que não sai costuma ser configuração (certificado, NCM,
    // cadastro) — e dinheiro que o totem não conseguiu devolver é trabalho do balcão.
    unawaited(api.reportarErro(
      mensagem: 'Venda não concluída no totem ($etapa) — estorno: ${situacao.name}',
      detalhe: detalhe,
      nivel: repete || situacao == SituacaoEstorno.manual ? 'erro' : 'aviso',
    ));
    return situacao;
  }

  /// A fila tenta de novo o estorno que ficou pendente (sem rede na hora).
  Future<SituacaoEstorno> retentarEstorno(Map<String, Object?> row) async {
    final uuid = row['uuid'] as String;
    final corpo =
        jsonDecode(row['corpo_json'] as String) as Map<String, dynamic>;
    final antes = _mapa(row['resposta_json']);
    final motivo = '${antes['motivo'] ?? 'venda não concluída no totem'}';
    final etapa = '${antes['etapa'] ?? 'desconhecida'}';
    final senha = antes['senha'] is num ? (antes['senha'] as num).toInt() : null;
    final r = await _estornar(uuid, corpo, motivo, etapa, senha);
    if (r.situacao == SituacaoEstorno.pendente) {
      await repo.registrarFalhaEnvio(uuid);
      return r.situacao;
    }
    await repo.marcarNaoConcluido(
        uuid,
        jsonEncode({
          ...antes,
          'estorno': r.estorno,
          'situacao': r.situacao.name,
        }));
    if (r.situacao == SituacaoEstorno.manual) {
      unawaited(api.reportarErro(
        mensagem: 'Estorno do totem não saiu — devolver no balcão ($etapa)',
        detalhe: jsonEncode({'orderId': uuid, 'motivo': motivo, 'estorno': r.estorno}),
      ));
    }
    return r.situacao;
  }

  Future<({SituacaoEstorno situacao, Map<String, dynamic>? estorno})> _estornar(
      String uuid,
      Map<String, dynamic> corpo,
      String motivo,
      String etapa,
      int? senha) async {
    try {
      final e = await api.estornarPagamento(
        orderId: uuid,
        motivo: motivo,
        etapa: etapa,
        senha: senha ?? (corpo['senhaLocal'] as num?)?.toInt(),
        itens: corpo['itens'] as List<dynamic>?,
      );
      return (
        situacao:
            e['feito'] == true ? SituacaoEstorno.feito : SituacaoEstorno.manual,
        estorno: e,
      );
    } on GogemApiException catch (e) {
      // 4xx de validação/prazo: pedir de novo não muda nada — é com o atendente. O resto
      // (401, 404 do servidor antigo, 5xx) pode passar depois: fica pendente.
      if (recusaDefinitiva(e.status)) {
        return (
          situacao: SituacaoEstorno.manual,
          estorno: {'feito': false, 'mensagem': e.motivo},
        );
      }
      return (situacao: SituacaoEstorno.pendente, estorno: null);
    } catch (_) {
      return (situacao: SituacaoEstorno.pendente, estorno: null);
    }
  }

  static bool _eletronico(Map<String, dynamic> corpo) {
    final pags = corpo['pagamentos'];
    if (pags is! List || pags.isEmpty) return false;
    return pags.any((p) => p is Map && '${p['forma']}' != 'dinheiro');
  }

  static Map<String, dynamic> _mapa(Object? json) {
    if (json is! String || json.isEmpty) return {};
    try {
      final m = jsonDecode(json);
      return m is Map<String, dynamic> ? m : {};
    } catch (_) {
      return {};
    }
  }
}
