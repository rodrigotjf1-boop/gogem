import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/util/moeda.dart';
import 'gogen_tokens.dart';

/// Pagamento no visual **GoGen** (claro/flame). VIEW PURA: cobre os 5
/// sub-estados do `PagamentoScreen` (bloqueado, idle, processando, PIX,
/// maquininha) recebendo estado + callbacks. NADA de lógica de cobrança aqui —
/// write-ahead, PORTÃO 2, Point/PIX e impressão ficam no PagamentoScreen.
class GogenPagamentoView extends StatelessWidget {
  const GogenPagamentoView({
    super.key,
    required this.totalCentavos,
    required this.bloqueado,
    required this.motivo,
    required this.processando,
    required this.erro,
    required this.pointAtivo,
    required this.pixCopiaECola,
    required this.pixContador,
    required this.onVoltar,
    required this.onVoltarCarrinho,
    required this.onTentarNovamente,
    required this.onPagarPix,
    required this.onPagarCartao,
    required this.onPagarDinheiro,
    required this.onCancelarPix,
    required this.onCancelarPoint,
  });

  final int totalCentavos;
  final bool bloqueado;
  final String motivo;
  final bool processando;
  final String? erro;
  final bool pointAtivo;
  final String? pixCopiaECola; // não-nulo = tela do PIX
  final String pixContador; // mm:ss
  final VoidCallback onVoltar; // idle → identificação
  final VoidCallback onVoltarCarrinho; // bloqueado → carrinho
  final VoidCallback onTentarNovamente;
  final VoidCallback onPagarPix;
  final VoidCallback onPagarCartao;
  final VoidCallback onPagarDinheiro;
  final VoidCallback onCancelarPix;
  final VoidCallback onCancelarPoint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(child: _corpo()),
    );
  }

  Widget _corpo() {
    if (bloqueado) return _bloqueadoView();
    if (processando) {
      if (pixCopiaECola != null) return _pixView();
      if (pointAtivo) return _pointView();
      return _processandoView();
    }
    return _idleView();
  }

  // ---- bloqueado (PORTÃO 2) ----
  Widget _bloqueadoView() => Center(
        child: Column(
          key: const ValueKey('pagamento-bloqueado'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_disabled_rounded, color: GogenColors.flame1, size: 76),
            const SizedBox(height: 18),
            const Text('Não dá pra pagar agora',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: GogenColors.ink)),
            const SizedBox(height: 8),
            Text('motivo: $motivo', style: const TextStyle(fontSize: 17, color: GogenColors.ink2)),
            const SizedBox(height: 4),
            const Text('chame um atendente — seu carrinho está salvo',
                style: TextStyle(fontSize: 15, color: GogenColors.ink2)),
            const SizedBox(height: 28),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _BtnSecundario(rotulo: 'Voltar', onTap: onVoltarCarrinho),
              const SizedBox(width: 16),
              _BtnFlame(chave: 'tentar-novamente', rotulo: 'Tentar de novo', onTap: onTentarNovamente),
            ]),
          ],
        ),
      );

  // ---- processando genérico ----
  Widget _processandoView() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: GogenColors.flame1),
          SizedBox(height: 24),
          Text('Processando pagamento…',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: GogenColors.ink)),
        ]),
      );

  // ---- PIX (QR + contador) ----
  Widget _pixView() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(children: [
          _TotalHeader(rotulo: 'Pague com PIX', totalCentavos: totalCentavos),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: QrImageView(data: pixCopiaECola!, size: 260, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('Abra o app do banco e escaneie o QR',
              style: TextStyle(fontSize: 17, color: GogenColors.ink), textAlign: TextAlign.center),
          const SizedBox(height: 26),
          const CircularProgressIndicator(color: GogenColors.flame1),
          const SizedBox(height: 12),
          Text('Aguardando pagamento · $pixContador',
              key: const ValueKey('pix-contador'),
              style: const TextStyle(fontSize: 17, color: GogenColors.ink2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          _BtnSecundario(chave: 'pix-cancelar', rotulo: 'Cancelar pagamento', onTap: onCancelarPix),
        ]),
      );

  // ---- maquininha (Point modo PDV) ----
  Widget _pointView() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.point_of_sale_rounded, color: GogenColors.flame1, size: 76),
            const SizedBox(height: 14),
            _TotalHeader(rotulo: 'Pague na maquininha', totalCentavos: totalCentavos),
            const SizedBox(height: 24),
            _passo('1', 'Na maquininha, toque em'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF2D7FF9), borderRadius: BorderRadius.circular(12)),
              child: const Text('Atualizar',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 18),
            _passo('2', 'Escolha a forma (crédito, débito ou vale) e pague'),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: GogenColors.flame1),
            const SizedBox(height: 12),
            const Text('Aguardando o pagamento…', style: TextStyle(fontSize: 15, color: GogenColors.ink2)),
            const SizedBox(height: 24),
            _BtnSecundario(chave: 'point-cancelar', rotulo: 'Cancelar pagamento', onTap: onCancelarPoint),
          ]),
        ),
      );

  Widget _passo(String n, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(gradient: GogenColors.grad, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Flexible(
              child: Text(texto,
                  style: const TextStyle(fontSize: 17, color: GogenColors.ink), textAlign: TextAlign.center)),
        ],
      );

  // ---- idle: escolher a forma ----
  Widget _idleView() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
          child: Row(children: [
            IconButton(
              onPressed: onVoltar,
              icon: const Icon(Icons.arrow_back_rounded, color: GogenColors.ink, size: 30),
            ),
            const SizedBox(width: 4),
            const Text('Pagamento',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(formatCentavos(totalCentavos),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40, color: GogenColors.flame1)),
        if (erro != null)
          Padding(
            key: const ValueKey('pagamento-erro'),
            padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
            child: Text(erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: GogenColors.flame1, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 28),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            children: [
              _FormaBtn(chave: 'forma-pix', icone: Icons.qr_code_2_rounded, rotulo: 'PIX', onTap: onPagarPix),
              const SizedBox(height: 16),
              _FormaBtn(chave: 'forma-cartao', icone: Icons.credit_card_rounded, rotulo: 'Cartão', onTap: onPagarCartao),
              const SizedBox(height: 16),
              _FormaBtn(chave: 'forma-dinheiro', icone: Icons.payments_rounded, rotulo: 'Dinheiro', onTap: onPagarDinheiro),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(40, 0, 40, 16),
          child: Text('No cartão você escolhe crédito, débito ou vale na maquininha. No dinheiro, o pagamento é feito no caixa.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: GogenColors.ink2)),
        ),
      ]);
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.rotulo, required this.totalCentavos});
  final String rotulo;
  final int totalCentavos;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(rotulo,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
        const SizedBox(height: 4),
        Text('Total ${formatCentavos(totalCentavos)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: GogenColors.flame1)),
      ]);
}

/// Botão grande de forma de pagamento: card branco, ícone flame.
class _FormaBtn extends StatelessWidget {
  const _FormaBtn({required this.chave, required this.icone, required this.rotulo, required this.onTap});
  final String chave;
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(chave),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              color: GogenColors.card,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Container(
              height: 92,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: GogenColors.grad,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icone, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Text(rotulo,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: GogenColors.ink)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: GogenColors.ink2, size: 30),
              ]),
            ),
          ),
        ),
      );
}

class _BtnFlame extends StatelessWidget {
  const _BtnFlame({required this.chave, required this.rotulo, required this.onTap});
  final String chave;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(chave),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(gradient: GogenColors.grad, borderRadius: BorderRadius.circular(999)),
            child: Container(
              constraints: const BoxConstraints(minWidth: 180),
              height: 64,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(rotulo,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
            ),
          ),
        ),
      );
}

class _BtnSecundario extends StatelessWidget {
  const _BtnSecundario({this.chave, required this.rotulo, required this.onTap});
  final String? chave;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        key: chave == null ? null : ValueKey<String>(chave!),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(180, 64),
          foregroundColor: GogenColors.ink,
          side: const BorderSide(color: Color(0x1A000000), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        child: Text(rotulo),
      );
}
