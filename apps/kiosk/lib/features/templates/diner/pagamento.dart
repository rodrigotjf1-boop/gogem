import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/cart.dart';
import '../comum/pagamento_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';

const _t = dinerTokens;

/// Pagamento do **Diner 58** (docs/templates/05 §6.7 e 00 §4.7). VIEW: cobre os estados do
/// `PagamentoScreen` — escolha (com o erro da última tentativa), PIX, maquininha,
/// processando e bloqueado — só com estado + callbacks. Cobrança, write-ahead, portões,
/// Point/PIX e impressão ficam na tela.
///
/// Formas e condições são as da GoGen (as três sempre à vista; Cartão é UM botão, a
/// maquininha pergunta crédito, débito ou vale); as chaves de teste também.
class DinerPagamento extends ConsumerWidget {
  const DinerPagamento({super.key, required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final escolhendo = !p.bloqueado && !p.processando;
    return DinerTema(
      child: Scaffold(
        backgroundColor: _t.bg,
        body: SafeArea(
          child: DinerEntrada(
            mov: p.mov,
            child: Column(children: [
              DinerTopo(
                etapa: 3,
                mov: p.mov,
                nomeLoja: ap.nomeLoja,
                logoUrl: ap.logoUrl,
                // Durante a cobrança não há "voltar": sai-se pelo cancelar do PIX/maquininha.
                onVoltar: escolhendo ? p.onVoltar : null,
              ),
              Expanded(child: _corpo(context)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _corpo(BuildContext context) {
    if (p.bloqueado) return _Bloqueado(p: p);
    if (p.processando) {
      if (p.pixCopiaECola != null) return _Pix(p: p);
      if (p.pointAtivo) return _Maquininha(p: p);
      return _Processando(mensagem: p.mensagemProcessando);
    }
    return _Escolha(p: p);
  }
}

/// Corpo rolável + rodapé fixo com borda em cima (o `.body` + `.foot` do protótipo).
/// [preencher]: o corpo ocupa a altura toda (um `Spacer` empurra o resumo para baixo) — só
/// para conteúdo que mede a própria altura (sem `LayoutBuilder`/grade dentro).
class _Tela extends StatelessWidget {
  const _Tela({required this.corpo, this.rodape, this.centro = false, this.preencher = false});
  final List<Widget> corpo;
  final Widget? rodape;
  final bool centro;
  final bool preencher;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30));
    final coluna = Column(
      crossAxisAlignment: centro ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: corpo,
    );
    return Column(children: [
      Expanded(
        child: preencher
            ? CustomScrollView(slivers: [
                SliverFillRemaining(hasScrollBody: false, child: Padding(padding: padding, child: coluna)),
              ])
            : SingleChildScrollView(
                padding: padding,
                child: SizedBox(width: double.infinity, child: coluna),
              ),
      ),
      if (rodape != null)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
          padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
          child: rodape,
        ),
    ]);
  }
}

// ---- escolha da forma (e o erro da última tentativa) ----
class _Escolha extends ConsumerWidget {
  const _Escolha({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);
    final nome = p.cliente.trim();
    final kicker = nome.isEmpty ? 'Último passo' : 'Último passo, $nome';
    final opcoes = [
      _Opcao(
        chave: 'forma-pix',
        icone: Icons.pix_rounded,
        nome: 'Pix',
        detalhe: 'Aprovação na hora pelo app do banco',
        destaque: 'Mais rápido',
        onTap: p.onPagarPix,
      ),
      _Opcao(
        chave: 'forma-cartao',
        icone: Icons.credit_card_rounded,
        nome: 'Cartão',
        detalhe: 'Crédito, débito ou vale: você escolhe na maquininha',
        onTap: p.onPagarCartao,
      ),
      _Opcao(
        chave: 'forma-dinheiro',
        icone: Icons.payments_outlined,
        nome: 'Dinheiro',
        detalhe: 'Seu pedido vai para o caixa e você paga lá',
        onTap: p.onPagarDinheiro,
      ),
    ];
    return _Tela(preencher: true, corpo: [
      Text(kicker.toUpperCase(), style: dinerKicker(context)),
      SizedBox(height: context.dz(14)),
      Text('Como você quer pagar?', style: _t.display(context.dz(62), altura: 1.05)),
      if (p.erro != null) ...[
        SizedBox(height: context.dz(24)),
        Container(
          key: const ValueKey('pagamento-erro'),
          padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(22)),
          decoration: BoxDecoration(
            color: _t.hi,
            borderRadius: BorderRadius.circular(context.dz(24)),
            border: Border.all(color: _t.err, width: context.dz(3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_rounded, size: context.dz(40), color: _t.err),
            SizedBox(width: context.dz(16)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.erro!, style: _t.texto(context.dz(28), peso: FontWeight.w900, cor: _t.err)),
                SizedBox(height: context.dz(6)),
                // Tentar de novo é tocar numa forma abaixo (o pedido retido segue com a senha).
                Text('Para tentar novamente, escolha uma forma de pagamento.',
                    style: _t.texto(context.dz(24), cor: _t.muted)),
              ]),
            ),
          ]),
        ),
      ],
      SizedBox(height: context.dz(30)),
      for (var i = 0; i < opcoes.length; i++) ...[
        if (i > 0) SizedBox(height: context.dz(20)),
        _Cascata(mov: p.mov, atraso: i * 70, child: opcoes[i]),
      ],
      const Spacer(),
      SizedBox(height: context.dz(30)),
      _Resumo(
        linhas: [for (final i in cart.itens) ('${i.quantidade}× ${i.produto.nome}', i.totalCentavos)],
        totalCentavos: p.totalCentavos,
        consumo: checkout.consumo,
        cpf: checkout.cpf,
      ),
    ]);
  }
}

/// Entrada em cascata das opções (70 ms entre cada uma), só com movimento.
class _Cascata extends StatelessWidget {
  const _Cascata({required this.mov, required this.atraso, required this.child});
  final Movimento mov;
  final int atraso;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!mov.anima || !mov.particulas) return child;
    final total = 500 + atraso;
    final inicio = atraso / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(total),
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, filho) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * context.dz(24)), child: filho),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.chave,
    required this.icone,
    required this.nome,
    required this.detalhe,
    required this.onTap,
    this.destaque,
  });

  final String chave;
  final IconData icone;
  final String nome;
  final String detalhe;
  final String? destaque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hi = destaque != null;
    return DinerToque(
      key: ValueKey(chave),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.dz(40), vertical: context.dz(30)),
        decoration: BoxDecoration(
          color: hi ? _t.hi : _t.surface,
          borderRadius: BorderRadius.circular(context.dz(_t.raio)),
          border: Border.all(color: hi ? _t.accent : _t.line, width: context.dz(3)),
        ),
        child: Row(children: [
          Container(
            width: context.dz(124),
            height: context.dz(124),
            decoration: BoxDecoration(
              color: hi ? _t.accent : _t.surface2,
              borderRadius: BorderRadius.circular(context.dz(24)),
            ),
            child: Icon(icone, size: context.dz(66), color: hi ? _t.onAccent : _t.text),
          ),
          SizedBox(width: context.dz(32)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: context.dz(16),
                runSpacing: context.dz(8),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(nome, style: _t.display(context.dz(40), altura: 1.1)),
                  if (destaque != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(8)),
                      decoration: BoxDecoration(color: _t.accent2, borderRadius: BorderRadius.circular(context.dz(20))),
                      child: Text(destaque!.toUpperCase(),
                          style: _t
                              .texto(context.dz(20), peso: FontWeight.w900, cor: _t.onAccent2)
                              .copyWith(letterSpacing: context.dz(20) * .08)),
                    ),
                ],
              ),
              SizedBox(height: context.dz(8)),
              Text(detalhe, style: _t.texto(context.dz(26), cor: _t.muted, altura: 1.3)),
            ]),
          ),
          SizedBox(width: context.dz(16)),
          Icon(Icons.chevron_right_rounded, size: context.dz(44), color: _t.muted),
        ]),
      ),
    );
  }
}

/// Resumo do pedido: itens, total e o consumo (com o CPF mascarado, se informado).
class _Resumo extends StatelessWidget {
  const _Resumo({required this.linhas, required this.totalCentavos, required this.consumo, required this.cpf});
  final List<(String, int)> linhas;
  final int totalCentavos;
  final String consumo;
  final String cpf;

  @override
  Widget build(BuildContext context) {
    final linha = _t.texto(context.dz(26), cor: _t.muted);
    final cpfMascara = cpf.length == 11 ? 'CPF na nota: ${cpf.substring(0, 3)}.***.***-${cpf.substring(9)} · ' : '';
    return Container(
      key: const ValueKey('pagamento-resumo'),
      padding: EdgeInsets.symmetric(horizontal: context.dz(36), vertical: context.dz(32)),
      decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('RESUMO DO PEDIDO', style: dinerRotulo(context)),
        for (final (nome, valor) in linhas)
          Padding(
            padding: EdgeInsets.only(top: context.dz(10)),
            child: Row(children: [
              Expanded(child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: linha)),
              SizedBox(width: context.dz(16)),
              Text(formatCentavos(valor), style: linha),
            ]),
          ),
        Container(
          margin: EdgeInsets.only(top: context.dz(16)),
          padding: EdgeInsets.only(top: context.dz(14)),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line2, width: context.dz(2)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text('Total', style: _t.texto(context.dz(40), peso: FontWeight.w900))),
            Text(formatCentavos(totalCentavos),
                key: const ValueKey('pagamento-total'),
                style: _t.texto(context.dz(44), peso: FontWeight.w900, cor: _t.accent)),
          ]),
        ),
        SizedBox(height: context.dz(10)),
        Row(children: [
          Icon(Icons.receipt_long_outlined, size: context.dz(26), color: _t.muted),
          SizedBox(width: context.dz(10)),
          Flexible(
            child: Text('$cpfMascara${consumo == 'viagem' ? 'Para levar' : 'Comer aqui'}',
                style: _t.texto(context.dz(22), cor: _t.muted)),
          ),
        ]),
      ]),
    );
  }
}

// ---- PIX ----
class _Pix extends StatelessWidget {
  const _Pix({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return _Tela(
      centro: true,
      corpo: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.pix_rounded, size: context.dz(32), color: _t.accent),
          SizedBox(width: context.dz(10)),
          Text('PIX', style: dinerKicker(context)),
        ]),
        SizedBox(height: context.dz(14)),
        Text('Escaneie com o app do seu banco',
            textAlign: TextAlign.center, style: _t.display(context.dz(62), altura: 1.05)),
        SizedBox(height: context.dz(18)),
        Text('Abra o app, escolha Pix › Pagar com QR Code',
            textAlign: TextAlign.center, style: _t.texto(context.dz(32), cor: _t.muted)),
        SizedBox(height: context.dz(26)),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.dz(40)),
            boxShadow: [
              BoxShadow(color: const Color(0x33000000), blurRadius: context.dz(60), offset: Offset(0, context.dz(30))),
            ],
          ),
          child: QrPix(copiaECola: p.pixCopiaECola!, tokens: _t, mov: p.mov, lado: 520, cantos: _t.accent),
        ),
        SizedBox(height: context.dz(20)),
        Text('Total', style: _t.texto(context.dz(28), cor: _t.muted)),
        Text(formatCentavos(p.totalCentavos),
            key: const ValueKey('pix-total'), style: _t.display(context.dz(92), altura: 1.05)),
        SizedBox(height: context.dz(18)),
        Container(
          height: context.dz(76),
          padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
          decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(38))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: context.dz(32), color: _t.text),
            SizedBox(width: context.dz(12)),
            Text('Expira em ${p.pixContador}',
                key: const ValueKey('pix-contador'), style: _t.texto(context.dz(28), peso: FontWeight.w900)),
          ]),
        ),
        SizedBox(height: context.dz(18)),
        PontosAguardando(tokens: _t, mov: p.mov),
      ],
      rodape: DinerBotao(
        key: const ValueKey('pix-cancelar'),
        rotulo: 'Trocar forma de pagamento',
        estilo: DinerEstilo.contorno,
        expandir: true,
        onTap: p.onCancelarPix,
      ),
    );
  }
}

// ---- maquininha (Point modo PDV) ----
class _Maquininha extends StatelessWidget {
  const _Maquininha({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final passo = _t.texto(context.dz(30), cor: _t.muted, altura: 1.3);
    Widget numero(String n) => Container(
          width: context.dz(44),
          height: context.dz(44),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
          child: Text(n, style: _t.texto(context.dz(24), peso: FontWeight.w900, cor: _t.onAccent)),
        );
    return _Tela(
      centro: true,
      corpo: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.credit_card_rounded, size: context.dz(32), color: _t.accent),
          SizedBox(width: context.dz(10)),
          Text('CARTÃO', style: dinerKicker(context)),
        ]),
        SizedBox(height: context.dz(14)),
        Text('Use a maquininha abaixo', textAlign: TextAlign.center, style: _t.display(context.dz(62), altura: 1.05)),
        SizedBox(height: context.dz(22)),
        // Os passos do Point em modo PDV (os mesmos da GoGen e da tela padrão).
        Row(mainAxisSize: MainAxisSize.min, children: [
          numero('1'),
          SizedBox(width: context.dz(14)),
          Flexible(child: Text('Na maquininha, toque em', style: passo)),
          SizedBox(width: context.dz(12)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.dz(22), vertical: context.dz(8)),
            decoration:
                BoxDecoration(color: const Color(0xFF2D7FF9), borderRadius: BorderRadius.circular(context.dz(12))),
            child:
                Text('Atualizar', style: _t.texto(context.dz(26), peso: FontWeight.w900, cor: const Color(0xFFFFFFFF))),
          ),
        ]),
        SizedBox(height: context.dz(14)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          numero('2'),
          SizedBox(width: context.dz(14)),
          Flexible(child: Text('Escolha a forma (crédito, débito ou vale) e pague', style: passo)),
        ]),
        SizedBox(height: context.dz(40)),
        MaquininhaAnimada(totalCentavos: p.totalCentavos, tokens: _t, mov: p.mov, corCartao: _t.accent),
        SizedBox(height: context.dz(24)),
        _SetaAbaixo(mov: p.mov),
        SizedBox(height: context.dz(10)),
        Text('Aguardando o pagamento…', style: _t.texto(context.dz(26), cor: _t.muted)),
      ],
      rodape: DinerBotao(
        key: const ValueKey('point-cancelar'),
        rotulo: 'Cancelar',
        estilo: DinerEstilo.contorno,
        expandir: true,
        onTap: p.onCancelarPoint,
      ),
    );
  }
}

/// Seta para baixo que "aponta" a maquininha (1,2 s, só com movimento).
class _SetaAbaixo extends StatefulWidget {
  const _SetaAbaixo({required this.mov});
  final Movimento mov;

  @override
  State<_SetaAbaixo> createState() => _SetaAbaixoState();
}

class _SetaAbaixoState extends State<_SetaAbaixo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(1200));
    if (widget.mov.anima) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seta = Icon(Icons.arrow_downward_rounded, size: context.dz(60), color: _t.accent);
    if (!widget.mov.anima) return seta;
    return AnimatedBuilder(
      animation: _c,
      child: seta,
      builder: (_, filho) => Transform.translate(
        offset: Offset(0, Curves.easeInOut.transform(_c.value) * context.dz(20)),
        child: filho,
      ),
    );
  }
}

// ---- processando (e a confirmação da venda: "Emitindo o cupom fiscal…") ----
class _Processando extends StatelessWidget {
  const _Processando({required this.mensagem});
  final String? mensagem;

  /// Caixa de frase: "EMITINDO O CUPOM FISCAL…" vira "Emitindo o cupom fiscal…".
  static String _texto(String? m) {
    if (m == null || m.trim().isEmpty) return 'Processando…';
    final baixo = m.trim().toLowerCase();
    return baixo[0].toUpperCase() + baixo.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: context.dz(110),
            height: context.dz(110),
            child: CircularProgressIndicator(strokeWidth: context.dz(10), color: _t.accent),
          ),
          SizedBox(height: context.dz(36)),
          Text(_texto(mensagem),
              key: const ValueKey('pagamento-espera'),
              textAlign: TextAlign.center,
              style: _t.display(context.dz(44), altura: 1.15)),
        ]),
      ),
    );
  }
}

// ---- bloqueado (PORTÃO 2: impressora) ----
class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(key: const ValueKey('pagamento-bloqueado'), mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: context.dz(170),
            height: context.dz(170),
            decoration: BoxDecoration(
              color: _t.hi,
              shape: BoxShape.circle,
              border: Border.all(color: _t.accent, width: context.dz(4)),
            ),
            child: Icon(Icons.print_disabled_outlined, size: context.dz(86), color: _t.accent),
          ),
          SizedBox(height: context.dz(30)),
          Text('Não é possível pagar agora',
              textAlign: TextAlign.center, style: _t.display(context.dz(56), altura: 1.1)),
          SizedBox(height: context.dz(16)),
          Text('Motivo: ${p.motivo}',
              textAlign: TextAlign.center, style: _t.texto(context.dz(30), peso: FontWeight.w800)),
          SizedBox(height: context.dz(8)),
          Text('Chame um atendente, seu carrinho está salvo',
              textAlign: TextAlign.center, style: _t.texto(context.dz(28), cor: _t.muted)),
          SizedBox(height: context.dz(40)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.dz(20),
            runSpacing: context.dz(16),
            children: [
              DinerBotao(
                key: const ValueKey('voltar-carrinho'),
                rotulo: 'Voltar ao carrinho',
                estilo: DinerEstilo.contorno,
                onTap: p.onVoltarCarrinho,
              ),
              DinerBotao(
                key: const ValueKey('tentar-novamente'),
                rotulo: 'Tentar novamente',
                onTap: p.onTentarNovamente,
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
