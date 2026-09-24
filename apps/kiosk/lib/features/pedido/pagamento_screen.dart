import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_payment/payment.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../data/api/gogem_api.dart';
import '../../data/catalog/aparencia.dart';
import '../../data/catalog/catalog_sync.dart'
    show gogemApiProvider, aparenciaProvider, fiscalProvider;
import '../gogen/gogen_pagamento.dart';
import '../../core/kiosk/inatividade_guard.dart';
import '../../domain/fiscal/bloqueio_fiscal.dart';
import '../../domain/fiscal/resultado_fiscal.dart';
import '../../domain/order/cart.dart';
import '../../core/config/host_servidor.dart';
import '../../domain/order/conclusao_venda.dart';
import '../../domain/order/order_models.dart';
import '../../domain/order/order_repository.dart';
import '../../domain/order/venda_sync.dart';
import '../../domain/payment/payment_provider.dart';
import '../../printing/fila_impressao.dart';
import '../../printing/printer_providers.dart';
import '../../printing/recibo.dart';

/// Pagamento (F7: consome o `PaymentProvider` — fake na bancada; integradoras
/// reais entram sem tocar nesta tela).
/// PORTÃO 2 (F4): checagem SÍNCRONA da impressora ao entrar E imediatamente
/// antes de cobrar — NUNCA cobrar sem poder concluir. Se o papel acabar na
/// janela residual pós-pagamento, o pedido não se perde: senha na tela +
/// fila de reimpressão.
///
/// Resultado fiscal (Regem #574): depois de aprovar, o totem espera a venda até 45 s
/// ("Emitindo o cupom fiscal…"). A compra só termina com o cupom fiscal na mão do
/// cliente — nota não emitida, venda recusada ou DANFE que não imprimiu (servidor da
/// loja) desfazem a venda e ESTORNAM o pagamento, com o motivo no relatório.
class PagamentoScreen extends ConsumerStatefulWidget {
  const PagamentoScreen({super.key});
  @override
  ConsumerState<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends ConsumerState<PagamentoScreen> {
  bool _processando = false;
  bool _bloqueado = false;
  String _motivo = '';
  String? _erroPagamento;

  /// K4 — esta loja tem servidor local? Só nele existe pedido retido; na nuvem o fluxo
  /// segue como sempre (paga e então lança a venda).
  bool get _modoServidor => ref.read(hostServidorProvider).temServidor;

  /// K4 — id do pedido RETIDO no servidor da loja (modo servidor). O pedido entra lá
  /// ANTES de cobrar, sem ir para a cozinha; vira venda no `liberar` e é encerrado com
  /// motivo no `cancelar`. Nulo = modo nuvem (fluxo de sempre: paga e então lança).
  String? _pedidoRetidoId;
  PixChallenge? _pixDesafio;
  bool _pointAtivo = false;
  Timer? _pixTimer;
  int _pixSegundos = 300; // contagem regressiva do PIX (5 min)
  PedidoLocal? _pedidoAtual; // pedido em cobrança (write-ahead F10)
  String? _senhaAtual; // senha local do pedido em cobrança

  /// Pagamento aprovado, venda sendo confirmada: o texto da espera ("EMITINDO O CUPOM
  /// FISCAL…"). Nulo = ainda cobrando.
  String? _confirmando;

  /// Plano da confirmação: a 1ª tentativa com folga para a nota (o Regem responde em até
  /// ~12 s; 25 s quando a repetição espera uma emissão em andamento); a 2ª é a REPETIÇÃO,
  /// idempotente — devolve a mesma venda e a mesma nota. 30 + 2 + 13 = 45 s, o combinado
  /// com o Regem. Plano fixo (e não relógio de parede) para caber no prazo mesmo quando a
  /// primeira falha no último segundo.
  static const _tentativas = [Duration(seconds: 30), Duration(seconds: 13)];
  static const _pausaEntreTentativas = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _portao());
  }

  @override
  void dispose() {
    _pixTimer?.cancel();
    super.dispose();
  }

  /// Contagem regressiva do PIX (5 min) — só visual; o provider tem o mesmo
  /// timeout e cancela sozinho ao esgotar.
  void _iniciarContagemPix() {
    _pixTimer?.cancel();
    _pixSegundos = 300;
    _pixTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _pixSegundos = _pixSegundos > 0 ? _pixSegundos - 1 : 0);
      if (_pixSegundos <= 0) t.cancel();
    });
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _portao() async {
    final h = await ref.read(printerHealthProvider.notifier).checarAgora();
    if (!mounted) return;
    setState(() {
      _bloqueado = !h.prontaParaVenda;
      _motivo = h.motivo;
    });
  }

  Future<void> _pagar(FormaPagamento forma) async {
    final cart = ref.read(cartProvider);
    if (cart.vazio || _processando) return;
    // A nota fiscal está falhando em SÉRIE (o Regem avisou que a próxima falha igual):
    // cartão e PIX ficam travados por alguns minutos — cobrar e estornar cliente após
    // cliente é pior do que mandar ao caixa. O dinheiro segue: a nota dele sai no caixa.
    if (forma != FormaPagamento.dinheiro &&
        ref.read(bloqueioFiscalProvider.notifier).travado) {
      setState(() => _erroPagamento =
          'Cartão e PIX indisponíveis agora: o cupom fiscal não está sendo emitido. '
          'Pague em dinheiro no caixa ou chame um atendente.');
      return;
    }
    // reconfere na hora de cobrar (o papel pode ter acabado AGORA)
    final h = await ref.read(printerHealthProvider.notifier).checarAgora();
    if (!h.prontaParaVenda) {
      if (!mounted) return;
      setState(() {
        _bloqueado = true;
        _motivo = h.motivo;
      });
      return;
    }

    final checkout = ref.read(checkoutProvider);
    final pedido = PedidoLocal(
      itens: cart.itens,
      forma: forma,
      cpf: checkout.cpf,
      cliente: checkout.cliente,
      consumo: checkout.consumo,
    );
    setState(() {
      _processando = true;
      _erroPagamento = null;
      _pixDesafio = null;
      _pointAtivo = false;
      _confirmando = null;
    });
    // Venda em andamento: o retorno por inatividade espera (o cliente paga no celular ou
    // na maquininha e não toca na tela) — ERR-021.
    ref.read(vendaEmAndamentoDesdeProvider.notifier).state = DateTime.now();

    // WRITE-AHEAD (F10): grava o pedido ANTES de cobrar. Se o totem cair entre a
    // aprovação e o salvamento, o pedido não se perde — o boot reconcilia por
    // uuid (resolvePendings). A senha é atribuída aqui.
    final repo = await ref.read(orderRepositoryProvider.future);
    _pedidoAtual = pedido;
    _senhaAtual = await repo.salvarPreCobranca(pedido);

    // K4 — modo servidor: o pedido entra RETIDO no Regem antes de cobrar, e a senha
    // que vem de lá é a que vai no cupom. Dinheiro fica fora: ele já nasce retido pelo
    // caminho de sempre (`/vendas` → hub de Retirada, "a pagar no balcão").
    // Reaproveita o retido em nova tentativa: o cliente não pode trocar de número só
    // porque o cartão foi recusado uma vez.
    if (_modoServidor && forma != FormaPagamento.dinheiro && _pedidoRetidoId == null) {
      try {
        final r = await ref
            .read(gogemApiProvider)
            .abrirPedidoRetido(pedido.toJson(senhaLocal: int.tryParse(_senhaAtual ?? '')));
        _pedidoRetidoId = r['pedidoId']?.toString();
        final senhaServidor = r['senha'];
        if (senhaServidor != null) _senhaAtual = '$senhaServidor';
      } catch (_) {
        // Servidor fora: não cobra. Cobrar sem conseguir registrar deixaria o cliente
        // pago e a cozinha sem pedido — o pior dos dois mundos.
        _falhaPagamento('Sem conexão com o servidor da loja. Tente de novo.');
        return;
      }
    }

    // DINHEIRO: pago no CAIXA. Não cobra aqui — finaliza direto. O cupom destaca
    // "PAGUE NO CAIXA PARA SER PRODUZIDO" e o Regem trata a pendência por forma=='dinheiro'.
    if (forma == FormaPagamento.dinheiro) {
      await _finalizar(pedido);
      return;
    }

    // PIX tem fluxo próprio (QR + polling); os demais vão pelo provider genérico.
    if (forma == FormaPagamento.pix) {
      await _pagarPix(pedido, cart.totalCentavos, checkout.cpf);
      return;
    }
    // Cartão E vale-refeição vão pela maquininha Point (modo PDV): crédito,
    // débito e voucher (VR/VA). PIX é o único que fica no QR da tela.
    final vaiPraMaquininha = forma == FormaPagamento.credito ||
        forma == FormaPagamento.debito ||
        forma == FormaPagamento.vr;
    if (vaiPraMaquininha && cartaoViaPoint) {
      await _pagarPoint(pedido, cart.totalCentavos);
      return;
    }

    // Cartão/voucher: PaymentProvider (fake na F7; TEF na F9). O orderId = uuid do
    // pedido é a chave de idempotência. Só segue (persiste/imprime) se APROVADO.
    final provider = ref.read(paymentProviderProvider);
    PaymentResult res;
    try {
      res = await provider.start(PaymentRequest(
        orderId: pedido.uuid,
        amountCents: cart.totalCentavos,
        method: metodoDePagamento(forma),
        cpfCnpj: checkout.cpf,
      ));
    } on PaymentException {
      _falhaPagamento('Falha na comunicação com a maquininha. Tente de novo.');
      return;
    }
    if (res.status != PaymentStatus.approved) {
      _falhaPagamento(res.message ?? 'Pagamento não aprovado. Tente outra forma.');
      return;
    }
    await _finalizar(pedido);
  }

  /// PIX (F8): cria a cobrança, mostra o QR (PixChallenge) e faz polling até
  /// aprovar/expirar/cancelar. Só finaliza se aprovado.
  Future<void> _pagarPix(
      PedidoLocal pedido, int totalCentavos, String? cpf) async {
    final pix = ref.read(pixProviderProvider);
    final sub = pix.events.listen((e) {
      if (e is PixChallenge && mounted) {
        setState(() => _pixDesafio = e);
        _iniciarContagemPix();
      }
    });
    PaymentResult res;
    try {
      res = await pix.start(PaymentRequest(
        orderId: pedido.uuid,
        amountCents: totalCentavos,
        method: PaymentMethod.pix,
        cpfCnpj: cpf,
      ));
    } on PaymentException {
      await sub.cancel();
      _falhaPagamento('Não foi possível gerar o PIX. Tente de novo.');
      return;
    }
    await sub.cancel();
    if (res.status != PaymentStatus.approved) {
      _falhaPagamento(res.message ?? 'PIX não concluído.');
      return;
    }
    await _finalizar(pedido);
  }

  /// Cartão na maquininha Point (modo PDV): aciona a maquininha, mostra "pague na
  /// maquininha" e faz polling até aprovar/cancelar/timeout. Só finaliza se OK.
  Future<void> _pagarPoint(PedidoLocal pedido, int totalCentavos) async {
    final point = ref.read(pointProviderProvider);
    final sub = point.events.listen((e) {
      if (e is PointChallenge && mounted) setState(() => _pointAtivo = true);
    });
    PaymentResult res;
    try {
      res = await point.start(PaymentRequest(
        orderId: pedido.uuid,
        amountCents: totalCentavos,
        method: metodoDePagamento(pedido.forma),
      ));
    } on PaymentException {
      await sub.cancel();
      _falhaPagamento('Não foi possível acionar a maquininha. Tente de novo.');
      return;
    }
    await sub.cancel();
    if (res.status != PaymentStatus.approved) {
      _falhaPagamento(res.message ?? 'Pagamento não concluído.');
      return;
    }
    await _finalizar(pedido);
  }

  void _falhaPagamento(String msg) {
    _pixTimer?.cancel();
    if (!mounted) return; // descartado: o boot reconcilia o órfão (não-approved)
    // Write-ahead (F10): o pedido foi gravado antes de cobrar; não pagou →
    // descarta (best-effort). Se esta marcação não rodar, o boot reconcilia o
    // 'aguardando_pagamento' órfão (o status remoto não estará approved).
    final p = _pedidoAtual;
    // K4 — com pedido RETIDO, a falha NÃO encerra nada: o pedido continua lá, com a
    // senha que o cliente já viu, e ele escolhe tentar de novo ou cancelar. Quem
    // encerra é o botão de cancelar (ou os 5 minutos do servidor).
    if (p != null && _pedidoRetidoId == null) {
      // Reporta ao Regem (via backend) o pedido que NÃO passou + o motivo —
      // best-effort (o backend lista o cupom "não passou"). Depois descarta local.
      final corpo = p.toJson(senhaLocal: int.tryParse(_senhaAtual ?? ''));
      unawaited(
          ref.read(gogemApiProvider).reportarFalha(corpo, motivo: msg));
      unawaited(ref
          .read(orderRepositoryProvider.future)
          .then((r) => r.marcarCancelado(p.uuid)));
      _pedidoAtual = null;
    }
    _encerrarVenda();
    setState(() {
      _processando = false;
      _pixDesafio = null;
      _pointAtivo = false;
      _confirmando = null;
      _erroPagamento = msg;
    });
  }

  /// A venda saiu de cena (concluída, recusada ou desistida): o retorno por inatividade
  /// volta a valer.
  void _encerrarVenda() =>
      ref.read(vendaEmAndamentoDesdeProvider.notifier).state = null;

  /// K4 — o cliente desistiu depois de uma recusa. Encerra o pedido retido no servidor
  /// COM MOTIVO (fica registrado no Regem e no admin do GoGeM), descarta o local e sai.
  Future<void> _cancelarCompra() async {
    final retidoId = _pedidoRetidoId;
    final p = _pedidoAtual;
    _pedidoRetidoId = null;
    _pedidoAtual = null;
    if (retidoId != null) {
      unawaited(ref
          .read(gogemApiProvider)
          .cancelarPedidoRetido(retidoId, 'cliente cancelou a compra no totem'));
    }
    if (p != null) {
      unawaited(ref
          .read(orderRepositoryProvider.future)
          .then((r) => r.marcarCancelado(p.uuid)));
    }
    ref.read(cartProvider.notifier).limpar();
    if (mounted) context.go('/');
  }

  /// Pós-aprovação (comum a todas as formas): confirma a venda com o servidor (até 45 s),
  /// trata o resultado fiscal e imprime.
  ///
  /// Os desfechos:
  ///  • nota emitida (ou loja sem nota) → DANFE primeiro, depois o cupom da senha;
  ///  • nota NÃO emitida, ou venda recusada → estorna, avisa o cliente, registra o motivo;
  ///  • DANFE que não saiu no papel, no servidor da loja → o Regem cancela a nota e desfaz
  ///    a venda, e o totem estorna — sem cupom fiscal na mão do cliente não há compra;
  ///  • sem resposta no prazo → a fila reenvia (pela liberação: mesma senha, mesma nota) e
  ///    o cliente leva a senha com o aviso de buscar o cupom fiscal no balcão.
  Future<void> _finalizar(PedidoLocal pedido) async {
    final repo = await ref.read(orderRepositoryProvider.future);
    final api = ref.read(gogemApiProvider);
    // Pago: 'aguardando_pagamento' → 'pendente_envio' (libera pro Regem).
    await repo.marcarPago(pedido.uuid);
    _pedidoAtual = null; // concluído: não é mais candidato a cancelamento
    // Guarda ANTES de limpar: é com ele que se libera o retido logo abaixo. Limpar
    // primeiro fazia a liberação virar venda direta (o servidor ficava com o retido
    // pendurado e a venda lançada duas vezes).
    final retidoId = _pedidoRetidoId;
    _pedidoRetidoId = null;
    // Se a liberação não concluir agora, a fila reenvia POR ELA (mesma senha, mesma nota).
    if (retidoId != null) await repo.marcarRetido(pedido.uuid, retidoId);
    final senhaLocal = _senhaAtual ?? '000';

    // Mostra a senha do REGEM (a que a cozinha/KDS chama), não a local do totem
    // — senão o cliente sai com um número (001) e a cozinha chama outro (107).
    var senha = senhaLocal;
    _pixTimer?.cancel();
    // A loja emite nota? (Vem do servidor da loja com o cardápio; na nuvem não se sabe, e
    // a espera diz só "confirmando".) Espera o carregamento — o valor em cache pode ainda
    // não ter sido lido nesta tela.
    final fiscalAtivo = await ref
        .read(fiscalProvider.future)
        .then((f) => f.ativo)
        .timeout(const Duration(seconds: 1), onTimeout: () => false)
        .catchError((_) => false);
    if (mounted) {
      setState(() {
        _pixDesafio = null;
        _pointAtivo = false;
        _confirmando =
            fiscalAtivo ? 'EMITINDO O CUPOM FISCAL…' : 'CONFIRMANDO O PEDIDO…';
      });
    }

    final corpo = pedido.toJson(senhaLocal: int.tryParse(senhaLocal));
    final envio = await _confirmarVenda(api, corpo, retidoId);
    NotaEmitida? nota;
    switch (envio) {
      case _Recusada(:final erro):
        await _naoConcluida(pedido, corpo, senha,
            motivo: 'Venda recusada pelo sistema da loja: ${erro.motivo}',
            etapa: 'recusada');
        return;
      case _JaProcessada():
        await repo.marcarEnviado(pedido.uuid, '{"idempotente":true}');
      case _SemResposta():
        unawaited(ref.read(vendaSyncProvider.notifier).drenar());
      case _Respondida(:final resposta):
        final regemSenha = resposta['senha'];
        if (regemSenha != null) senha = '$regemSenha';
        final fiscal = ResultadoFiscal.de(resposta['nfce']);
        if (fiscal is NotaNaoEmitida) {
          ref.read(bloqueioFiscalProvider.notifier).registrarNaoEmitida(
              repete: fiscal.repete, motivo: fiscal.motivoRelatorio);
          final e = resposta['estorno'];
          await _naoConcluida(pedido, corpo, senha,
              motivo: fiscal.motivoRelatorio,
              etapa: fiscal.etapa,
              repete: fiscal.repete,
              estornoFeito: e is Map ? e.cast<String, dynamic>() : null);
          return;
        }
        if (resposta['cancelado'] == true) {
          await _naoConcluida(pedido, corpo, senha,
              motivo: 'Pedido cancelado no sistema da loja', etapa: 'recusada');
          return;
        }
        await repo.marcarEnviado(pedido.uuid, jsonEncode(resposta));
        ref.read(bloqueioFiscalProvider.notifier).registrarEmitida();
        if (fiscal is NotaEmitida) nota = fiscal;
    }

    // O DANFE sai PRIMEIRO: se ele não sair (e a venda for desfeita), o cliente não fica com
    // um cupom de senha de um pedido que não existe mais.
    var fiscalOk = true;
    if (nota != null) {
      final danfe = await _imprimirDanfe(pedido.uuid, nota);
      if (!danfe.clienteRecebeu) {
        if (retidoId != null && mounted) {
          setState(() => _confirmando = 'O CUPOM FISCAL NÃO SAIU — CANCELANDO A NOTA…');
        }
        if (retidoId != null &&
            await _desfazerSemCupom(api, retidoId, danfe.motivo)) {
          await _naoConcluida(pedido, corpo, senha,
              motivo: 'Cupom fiscal não impresso no totem: ${danfe.motivo}',
              etapa: 'impressao');
          return;
        }
        // A venda vale (nuvem, onde não há como desfazê-la daqui; ou o servidor não
        // confirmou): o DANFE vai para a fila de reimpressão e a tela manda o cliente
        // buscá-lo no balcão com a senha.
        fiscalOk = false;
      }
      await _enfileirar(danfe.naoImpressas, senha);
    } else if (envio is _SemResposta &&
        fiscalAtivo &&
        pedido.forma != FormaPagamento.dinheiro) {
      // Sem resposta a tempo numa loja que emite nota: o DANFE vem quando a fila concluir
      // a venda, e fica na reimpressão. (No dinheiro a nota sai no caixa, na cobrança.)
      fiscalOk = false;
    }

    final cupom = montarCupom(pedido, senha);
    final impresso = await _imprimir(cupom) == null;
    if (!impresso) await _enfileirar([(pedido.uuid, cupom)], senha);

    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    _encerrarVenda();
    if (mounted) {
      final dinheiro = pedido.forma == FormaPagamento.dinheiro ? 1 : 0;
      context.go('/confirmacao?senha=$senha&impresso=${impresso ? 1 : 0}'
          '&dinheiro=$dinheiro&fiscal=${fiscalOk ? 1 : 0}');
    }
  }

  /// Confirma a venda (ou libera o retido) no plano de tentativas de [_tentativas].
  Future<_Confirmacao> _confirmarVenda(
      GogemApi api, Map<String, dynamic> corpo, String? retidoId) async {
    for (var i = 0; i < _tentativas.length; i++) {
      if (i > 0) await Future<void>.delayed(_pausaEntreTentativas);
      try {
        final r = retidoId == null
            ? await api.enviarVenda(corpo, timeout: _tentativas[i])
            : await api.liberarPedidoRetido(
                retidoId, corpo['pagamentos'] as List<dynamic>,
                timeout: _tentativas[i]);
        return _Respondida(r);
      } on GogemApiException catch (e) {
        if (e.status == 409) return const _JaProcessada();
        if (recusaDefinitiva(e.status)) return _Recusada(e);
        // Passageiro (5xx, 503 com a nota ainda em emissão…): a repetição resolve.
      } catch (_) {
        // Rede/tempo esgotado: se a venda chegou lá, a repetição devolve o resultado.
      }
    }
    return const _SemResposta();
  }

  /// A compra não se concluiu: estorna (se houve cobrança), registra e mostra ao cliente.
  Future<void> _naoConcluida(
    PedidoLocal pedido,
    Map<String, dynamic> corpo,
    String senha, {
    required String motivo,
    required String etapa,
    bool repete = false,
    Map<String, dynamic>? estornoFeito,
  }) async {
    if (mounted) {
      setState(() => _confirmando = pedido.forma == FormaPagamento.dinheiro
          ? 'CANCELANDO O PEDIDO…'
          : 'ESTORNANDO O PAGAMENTO…');
    }
    final repo = await ref.read(orderRepositoryProvider.future);
    final situacao =
        await ConclusaoVenda(api: ref.read(gogemApiProvider), repo: repo)
            .naoConcluida(
      uuid: pedido.uuid,
      corpo: corpo,
      motivo: motivo,
      etapa: etapa,
      senha: int.tryParse(senha),
      repete: repete,
      estornoFeito: estornoFeito,
    );
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    _encerrarVenda();
    if (!mounted) return;
    final q = Uri(queryParameters: {
      'etapa': etapa,
      'estorno': situacao.name,
      'motivo': motivo,
      'senha': senha,
    }).query;
    context.go('/nao-concluida?$q');
  }

  /// Servidor da loja (Regem #574): o DANFE não saiu no papel — o Regem cancela a nota (ou
  /// agenda o cancelamento, se está em contingência) e desfaz a venda. `true` só com a
  /// confirmação: sem ela a venda continua valendo, e estornar seria devolver o dinheiro de
  /// uma venda com nota válida.
  Future<bool> _desfazerSemCupom(
      GogemApi api, String retidoId, String motivo) async {
    try {
      final r = await api.falhaImpressao(retidoId, motivo);
      return r['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Imprime o DANFE devolvido pelo Regem (e a 2ª via, se a contingência pede e a loja
  /// ligou — mig 287). O que decide a compra é a VIA DO CLIENTE (`clienteRecebeu`); a via
  /// do estabelecimento que falhar só vai para a fila de reimpressão.
  Future<
      ({
        bool clienteRecebeu,
        String motivo,
        List<(String, Uint8List)> naoImpressas
      })> _imprimirDanfe(String uuid, NotaEmitida nota) async {
    // A mensagem da contingência já vem no texto do EMITENTE; o totem não a inventa.
    final vias = <(String, Uint8List)>[
      (chaveDanfe(uuid), montarDanfe(nota.danfe)),
      if (nota.viaEstabelecimento)
        (
          chaveDanfe(uuid, viaEstabelecimento: true),
          montarDanfe(nota.danfe, viaEstabelecimento: true)
        ),
    ];
    final falhas = <(String, Uint8List)>[];
    var motivo = '';
    for (final (chave, bytes) in vias) {
      final m = await _imprimir(bytes);
      if (m != null) {
        falhas.add((chave, bytes));
        if (motivo.isEmpty) motivo = m;
      }
    }
    return (
      clienteRecebeu: falhas.every((f) => f.$1 != chaveDanfe(uuid)),
      motivo: motivo,
      naoImpressas: falhas,
    );
  }

  /// Imprime e devolve o MOTIVO da falha (`null` = saiu no papel).
  Future<String?> _imprimir(Uint8List bytes) async {
    try {
      final s = await ref.read(printerDriverProvider).imprimir(bytes);
      if (s.semPapel) return 'sem papel';
      if (s.tampaAberta) return 'tampa aberta';
      if (!s.online) return 'impressora desconectada';
      return null;
    } catch (_) {
      return 'falha na impressora';
    }
  }

  /// Documentos que não saíram vão para a fila de reimpressão — cada um com a sua chave
  /// (ERR-020: com a mesma, o segundo sumia).
  Future<void> _enfileirar(List<(String, Uint8List)> docs, String senha) async {
    if (docs.isEmpty) return;
    try {
      final fila = await ref.read(filaImpressaoProvider.future);
      for (final (chave, bytes) in docs) {
        await fila.enfileirar(chave, senha, bytes);
      }
    } catch (_) {}
  }

  /// Passo numerado (bolinha + texto) da instrução da maquininha.
  Widget _passoPoint(TextTheme t, String n, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                color: GogemColors.cheese, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(n,
                style: const TextStyle(
                    color: Color(0xFF1A1206), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Flexible(
              child: Text(texto,
                  style: t.bodyLarge, textAlign: TextAlign.center)),
        ],
      );

  /// Tela do cartão na Point (modo PDV): instrui o cliente a tocar "Atualizar"
  /// na maquininha e escolher a forma lá; faz o polling e permite cancelar.
  Widget _pointView(TextTheme t, int totalCentavos) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.point_of_sale, color: GogemColors.cheese, size: 76),
          const SizedBox(height: 14),
          Text('PAGUE NA MAQUININHA',
              style: t.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Total ${formatCentavos(totalCentavos)}',
              style: t.titleLarge?.copyWith(color: GogemColors.cheese)),
          const SizedBox(height: 24),
          _passoPoint(t, '1', 'Na maquininha, toque em'),
          const SizedBox(height: 10),
          // Reproduz o botão azul "Atualizar" que aparece no terminal.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF2D7FF9),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Atualizar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 18),
          _passoPoint(
              t, '2', 'Escolha a forma (crédito, débito ou vale) e pague'),
          const SizedBox(height: 28),
          const CircularProgressIndicator(color: GogemColors.cheese),
          const SizedBox(height: 12),
          Text('Aguardando o pagamento…', style: t.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const ValueKey('point-cancelar'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 64),
                side: const BorderSide(color: GogemColors.line),
                foregroundColor: GogemColors.ink),
            onPressed: () => ref.read(pointProviderProvider).cancelar(),
            child: const Text('CANCELAR PAGAMENTO'),
          ),
        ]),
      ),
    );
  }

  /// Tela do PIX (F8): QR gerado do copia-e-cola, botão copiar, "aguardando" e
  /// cancelar (encerra o polling). Aparece durante o processamento do PIX.
  Widget _pixView(TextTheme t, int totalCentavos) {
    final d = _pixDesafio!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(children: [
        Text('PAGUE COM PIX', style: t.headlineMedium),
        const SizedBox(height: 8),
        Text('Total ${formatCentavos(totalCentavos)}',
            style: t.titleLarge?.copyWith(color: GogemColors.cheese)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(
              data: d.copiaECola, size: 260, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 16),
        Text('Abra o app do banco e escaneie o QR',
            style: t.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        const CircularProgressIndicator(color: GogemColors.cheese),
        const SizedBox(height: 12),
        Text('Aguardando pagamento · ${_mmss(_pixSegundos)}',
            key: const ValueKey('pix-contador'), style: t.bodyLarge),
        const SizedBox(height: 20),
        OutlinedButton(
          key: const ValueKey('pix-cancelar'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(220, 64),
              side: const BorderSide(color: GogemColors.line),
              foregroundColor: GogemColors.ink),
          onPressed: () => ref.read(pixProviderProvider).cancelar(),
          child: const Text('CANCELAR PAGAMENTO'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);

    // Template GoGen: mesmo comportamento (só PIX e Cartão; no cartão o cliente
    // escolhe crédito/débito/vale na maquininha Mercado Pago Point), visual flame.
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    if (ap.gogen) {
      return GogenPagamentoView(
        totalCentavos: cart.totalCentavos,
        bloqueado: _bloqueado,
        motivo: _motivo,
        processando: _processando,
        erro: _erroPagamento,
        pointAtivo: _pointAtivo,
        pixCopiaECola: _pixDesafio?.copiaECola,
        pixContador: _mmss(_pixSegundos),
        mensagemProcessando: _confirmando,
        onVoltar: () => context.go('/identificacao'),
        onVoltarCarrinho: () => context.go('/carrinho'),
        onTentarNovamente: _portao,
        onPagarPix: () => _pagar(FormaPagamento.pix),
        onPagarCartao: () => _pagar(FormaPagamento.credito),
        onPagarDinheiro: () => _pagar(FormaPagamento.dinheiro),
        onCancelarPix: () => ref.read(pixProviderProvider).cancelar(),
        onCancelarPoint: () => ref.read(pointProviderProvider).cancelar(),
      );
    }

    if (_bloqueado) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
                key: const ValueKey('pagamento-bloqueado'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.print_disabled,
                      color: GogemColors.heat, size: 72),
                  const SizedBox(height: 20),
                  Text('NÃO É POSSÍVEL PAGAR AGORA', style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text('motivo: $_motivo', style: t.bodyLarge),
                  const SizedBox(height: 4),
                  Text('chame um atendente — seu carrinho está salvo',
                      style: t.bodyMedium),
                  const SizedBox(height: 28),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(180, 64),
                          side: const BorderSide(color: GogemColors.line),
                          foregroundColor: GogemColors.ink),
                      onPressed: () => context.go('/carrinho'),
                      child: const Text('VOLTAR'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      key: const ValueKey('tentar-novamente'),
                      onPressed: _portao,
                      child: const Text('TENTAR NOVAMENTE'),
                    ),
                  ]),
                ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _processando
            ? (_pixDesafio != null
                ? _pixView(t, cart.totalCentavos)
                : _pointAtivo
                    ? _pointView(t, cart.totalCentavos)
                    : Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(
                            color: GogemColors.cheese),
                        const SizedBox(height: 24),
                        Text(_confirmando ?? 'PROCESSANDO PAGAMENTO…',
                            key: const ValueKey('pagamento-espera'),
                            style: t.titleLarge),
                      ])))
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => context.go('/identificacao'),
                      icon: const Icon(Icons.arrow_back,
                          color: GogemColors.ink, size: 32),
                    ),
                    const SizedBox(width: 8),
                    Text('PAGAMENTO', style: t.headlineMedium),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('Total ${formatCentavos(cart.totalCentavos)}',
                    style:
                        t.headlineMedium?.copyWith(color: GogemColors.cheese)),
                if (_erroPagamento != null)
                  Padding(
                    key: const ValueKey('pagamento-erro'),
                    padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
                    child: Text('$_erroPagamento',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge?.copyWith(color: GogemColors.heat)),
                  ),
                // K4 — recusou: o pedido segue RETIDO com a senha que o cliente já viu.
                // Ele escolhe. Tentar de novo é tocar numa forma de pagamento (os botões
                // continuam abaixo); desistir é este botão, que encerra com motivo.
                if (_erroPagamento != null && _pedidoRetidoId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
                    child: TextButton(
                      key: const ValueKey('cancelar-compra'),
                      onPressed: _processando ? null : _cancelarCompra,
                      child: Text('CANCELAR A COMPRA',
                          style: t.titleMedium?.copyWith(color: GogemColors.heat)),
                    ),
                  ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    children: [
                      _FormaBtn(
                          key: const ValueKey('forma-pix'),
                          icone: Icons.qr_code_2,
                          rotulo: 'PIX',
                          onTap: () => _pagar(FormaPagamento.pix)),
                      // Um botão só: crédito/débito/vale são escolhidos NA
                      // maquininha (o backend não força o tipo).
                      _FormaBtn(
                          key: const ValueKey('forma-cartao'),
                          icone: Icons.credit_card,
                          rotulo: 'CARTÃO',
                          onTap: () => _pagar(FormaPagamento.credito)),
                      _FormaBtn(
                          key: const ValueKey('forma-dinheiro'),
                          icone: Icons.payments,
                          rotulo: 'DINHEIRO',
                          onTap: () => _pagar(FormaPagamento.dinheiro)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                  child: Text(
                      'No cartão você escolhe crédito, débito ou vale na maquininha. '
                      'No dinheiro, o pagamento é feito no caixa.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(fontSize: 13)),
                ),
              ]),
      ),
    );
  }
}

class _FormaBtn extends StatelessWidget {
  const _FormaBtn(
      {super.key, required this.icone, required this.rotulo, required this.onTap});
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(88),
            backgroundColor: GogemColors.panel,
            foregroundColor: GogemColors.ink,
            side: const BorderSide(color: GogemColors.line),
          ),
          onPressed: onTap,
          icon: Icon(icone, size: 32, color: GogemColors.mint),
          label: Text(rotulo,
              style: const TextStyle(fontFamily: 'Tektur', fontSize: 24)),
        ),
      );
}

/// Como terminou a confirmação da venda com o servidor.
sealed class _Confirmacao {
  const _Confirmacao();
}

class _Respondida extends _Confirmacao {
  const _Respondida(this.resposta);
  final Map<String, dynamic> resposta;
}

/// 409: o servidor já tinha esta venda.
class _JaProcessada extends _Confirmacao {
  const _JaProcessada();
}

/// 400/422: o sistema da loja recusou a venda de forma definitiva.
class _Recusada extends _Confirmacao {
  const _Recusada(this.erro);
  final GogemApiException erro;
}

/// Sem resposta no prazo (rede, servidor fora): a fila reenvia.
class _SemResposta extends _Confirmacao {
  const _SemResposta();
}
