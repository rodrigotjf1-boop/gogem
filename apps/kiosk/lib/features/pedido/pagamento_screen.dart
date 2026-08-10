import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gogem_payment/payment.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../domain/order/cart.dart';
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
  PixChallenge? _pixDesafio;
  bool _pointAtivo = false;
  Timer? _pixTimer;
  int _pixSegundos = 300; // contagem regressiva do PIX (5 min)

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
    });

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
    if (!mounted) return;
    setState(() {
      _processando = false;
      _pixDesafio = null;
      _pointAtivo = false;
      _erroPagamento = msg;
    });
  }

  /// Pós-aprovação (comum a todas as formas): persiste, imprime (com fila de
  /// reimpressão na janela residual), dispara o envio ao Regem e confirma.
  Future<void> _finalizar(PedidoLocal pedido) async {
    final repo = await ref.read(orderRepositoryProvider.future);
    final senha = await repo.salvarPedido(pedido);

    var impresso = true;
    final cupom = montarCupom(pedido, senha);
    try {
      final s = await ref.read(printerDriverProvider).imprimir(cupom);
      impresso = !s.semPapel && s.online && !s.tampaAberta;
    } catch (_) {
      impresso = false;
    }
    if (!impresso) {
      try {
        final fila = await ref.read(filaImpressaoProvider.future);
        await fila.enfileirar(pedido.uuid, senha, cupom);
      } catch (_) {}
    }

    unawaited(ref.read(vendaSyncProvider.notifier).drenar());
    ref.read(cartProvider.notifier).limpar();
    ref.read(checkoutProvider.notifier).limpar();
    if (mounted) {
      context.go('/confirmacao?senha=$senha&impresso=${impresso ? 1 : 0}');
    }
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
                        Text('PROCESSANDO PAGAMENTO…', style: t.titleLarge),
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                  child: Text(
                      'No cartão você escolhe crédito, débito ou vale na maquininha.',
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
