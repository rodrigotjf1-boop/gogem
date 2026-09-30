import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/pagamento_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Pagamento do Vitrine (docs/templates/02 §6.7 e 00 §4.7). VIEW PURA, como a GoGen: cobre
/// escolha, PIX, maquininha, processando, erro e bloqueado a partir do estado recebido.
/// Formas mostradas = as da `GogenPagamentoView` (Pix, Cartão e Dinheiro, sempre) e com as
/// mesmas chaves de teste (`forma-pix`, `forma-cartao`, `forma-dinheiro`…). Nada de
/// cobrança aqui: write-ahead, portões, Point e PIX ficam na `PagamentoScreen`.
class VitrinePagamentoView extends StatelessWidget {
  const VitrinePagamentoView({super.key, required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final Widget corpo;
    // Durante a cobrança não há "Voltar" no topo: sair dali só pelo botão que cancela.
    VoidCallback? voltar;
    if (p.bloqueado) {
      corpo = _Bloqueado(p: p);
    } else if (p.processando) {
      if (p.pixCopiaECola != null) {
        corpo = _Pix(p: p);
      } else if (p.pointAtivo) {
        corpo = _Point(p: p);
      } else {
        corpo = _Processando(p: p);
      }
    } else {
      corpo = _Escolha(p: p);
      voltar = p.onVoltar;
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: EntradaVitrine(
        mov: p.mov,
        child: SafeArea(
          child: Column(children: [
            TopoVitrine(etapa: 3, onVoltar: voltar, mov: p.mov),
            Expanded(child: corpo),
          ]),
        ),
      ),
    );
  }
}

/// Kicker em CAIXA ALTA no acento, com ícone opcional.
class _Kicker extends StatelessWidget {
  const _Kicker({required this.texto, this.icone, this.centro = false});
  final String texto;
  final IconData? icone;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Row(
      mainAxisSize: centro ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: centro ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (icone != null) ...[
          Icon(icone, size: context.dz(32), color: t.accent),
          SizedBox(width: context.dz(10)),
        ],
        Flexible(
          child: Text(texto.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.vKicker(26)),
        ),
      ],
    );
  }
}

/// Rodapé com um botão (borda superior `line`, padding 22/48/48).
class _Rodape extends StatelessWidget {
  const _Rodape({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: context.dz(2)))),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------- escolha

class _Escolha extends StatelessWidget {
  const _Escolha({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final nome = p.cliente.trim();
    final formas = <Widget>[
      _Forma(
        key: const ValueKey('forma-pix'),
        indice: 0,
        icone: Icons.pix,
        nome: 'Pix',
        selo: 'Mais rápido',
        descricao: 'Aprovação na hora pelo app do banco',
        destaque: true,
        mov: p.mov,
        onTap: p.onPagarPix,
      ),
      _Forma(
        key: const ValueKey('forma-cartao'),
        indice: 1,
        icone: Icons.credit_card_rounded,
        nome: 'Cartão',
        descricao: 'Crédito, débito ou vale: você escolhe na maquininha',
        mov: p.mov,
        onTap: p.onPagarCartao,
      ),
      _Forma(
        key: const ValueKey('forma-dinheiro'),
        indice: 2,
        icone: Icons.payments_outlined,
        nome: 'Dinheiro',
        descricao: 'Seu pedido vai para o caixa e você paga lá',
        mov: p.mov,
        onTap: p.onPagarDinheiro,
      ),
    ];
    return ColunaQueRola(
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(40)),
      children: [
        _Kicker(texto: nome.isEmpty ? 'Último passo' : 'Último passo, $nome'),
        SizedBox(height: context.dz(22)),
        Text('Como você quer pagar?', key: const ValueKey('pagamento-titulo'), style: context.vDisplay(84, altura: 1)),
        if (p.erro != null) ...[
          SizedBox(height: context.dz(26)),
          _Erro(p: p),
        ],
        SizedBox(height: context.dz(30)),
        for (var i = 0; i < formas.length; i++) ...[
          if (i > 0) SizedBox(height: context.dz(20)),
          formas[i],
        ],
        SizedBox(height: context.dz(30)),
        const Spacer(),
        Container(
          key: const ValueKey('pagamento-resumo'),
          padding: EdgeInsets.symmetric(horizontal: context.dz(36), vertical: context.dz(32)),
          decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(context.dz(t.raio))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('RESUMO DO PEDIDO', style: context.vTexto(23, peso: FontWeight.w800, cor: t.muted, espacoEm: .1)),
            SizedBox(height: context.dz(14)),
            Container(height: context.dz(2), color: t.line2),
            SizedBox(height: context.dz(14)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('Total', style: context.vTexto(40, peso: FontWeight.w800)),
              const Spacer(),
              Text(formatCentavos(p.totalCentavos),
                  key: const ValueKey('pagamento-total'),
                  style: context.vTexto(44, peso: FontWeight.w800)),
            ]),
          ]),
        ),
      ],
    );
  }
}

/// Opção de pagamento (`.po`): raio 40; Pix em destaque (borda `accent`, fundo `hi`,
/// ícone no quadrado `accent`); nome em Syne 800 46. Entram em cascata (70 ms entre elas).
class _Forma extends StatefulWidget {
  const _Forma({
    super.key,
    required this.indice,
    required this.icone,
    required this.nome,
    required this.descricao,
    required this.mov,
    required this.onTap,
    this.selo,
    this.destaque = false,
  });

  final int indice;
  final IconData icone;
  final String nome;
  final String descricao;
  final String? selo;
  final bool destaque;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  State<_Forma> createState() => _FormaState();
}

class _FormaState extends State<_Forma> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curva;

  @override
  void initState() {
    super.initState();
    final mov = widget.mov;
    final atraso = 70 * widget.indice;
    _c = AnimationController(vsync: this, duration: mov.d(500 + atraso));
    _curva = CurvedAnimation(
      parent: _c,
      curve: Interval(atraso / (500 + atraso), 1, curve: const Cubic(.2, .8, .2, 1)),
    );
    if (mov.anima) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final w = widget;
    final raioIcone = BorderRadius.circular(context.dz(t.raio - 6));
    final cartao = Container(
      padding: EdgeInsets.symmetric(horizontal: context.dz(40), vertical: context.dz(30)),
      decoration: BoxDecoration(
        color: w.destaque ? t.hi : t.surface,
        borderRadius: BorderRadius.circular(context.dz(t.raio)),
        border: Border.all(color: w.destaque ? t.accent : t.line, width: context.dz(3)),
      ),
      child: Row(children: [
        Container(
          width: context.dz(124),
          height: context.dz(124),
          decoration: BoxDecoration(color: w.destaque ? t.accent : t.surface2, borderRadius: raioIcone),
          child: Icon(w.icone, size: context.dz(66), color: w.destaque ? t.onAccent : t.text),
        ),
        SizedBox(width: context.dz(32)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(w.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.vDisplay(46, altura: 1.05, espacoEm: -.02)),
              ),
              if (w.selo != null) ...[
                SizedBox(width: context.dz(16)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(8)),
                  decoration: BoxDecoration(color: t.accent2, borderRadius: BorderRadius.circular(context.dz(20))),
                  child: Text(w.selo!.toUpperCase(),
                      style: context.vTexto(20, peso: FontWeight.w800, cor: t.onAccent2, altura: 1, espacoEm: .08)),
                ),
              ],
            ]),
            SizedBox(height: context.dz(8)),
            Text(w.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.vTexto(26, peso: FontWeight.w400, cor: t.muted, altura: 1.3)),
          ]),
        ),
        SizedBox(width: context.dz(16)),
        Icon(Icons.chevron_right_rounded, size: context.dz(52), color: t.muted),
      ]),
    );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: w.onTap,
        child: FadeTransition(
          opacity: _curva,
          child: AnimatedBuilder(
            animation: _curva,
            builder: (_, child) =>
                Transform.translate(offset: Offset(0, context.dz(24) * (1 - _curva.value)), child: child),
            child: cartao,
          ),
        ),
      ),
    );
  }
}

/// A cobrança não passou: a mensagem, "Tentar novamente" e "Voltar". As formas continuam
/// abaixo — escolher de novo é tentar de novo (regra da `PagamentoScreen`).
class _Erro extends StatelessWidget {
  const _Erro({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      key: const ValueKey('pagamento-erro'),
      padding: EdgeInsets.all(context.dz(28)),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B5B),
        borderRadius: BorderRadius.circular(context.dz(t.raio - 8)),
        border: Border.all(color: t.err, width: context.dz(2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline_rounded, size: context.dz(44), color: t.err),
          SizedBox(width: context.dz(18)),
          Expanded(
            child: Text(p.erro ?? '',
                style: context.vTexto(28, peso: FontWeight.w800, cor: t.text, altura: 1.35)),
          ),
        ]),
        SizedBox(height: context.dz(22)),
        Row(children: [
          BotaoVitrine(
            key: const ValueKey('erro-voltar'),
            rotulo: 'Voltar',
            estilo: EstiloBotaoVitrine.fantasma,
            altura: 96,
            fonte: 28,
            padH: 34,
            mov: p.mov,
            onTap: p.onVoltar,
          ),
          SizedBox(width: context.dz(16)),
          Expanded(
            child: BotaoVitrine(
              key: const ValueKey('tentar-novamente'),
              rotulo: 'Tentar novamente',
              estilo: EstiloBotaoVitrine.suave,
              altura: 96,
              fonte: 28,
              padH: 34,
              mov: p.mov,
              onTap: p.onTentarNovamente,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------- PIX

class _Pix extends StatelessWidget {
  const _Pix({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          // O QR ocupa 600 de desenho; em tela baixa, encolhe para caber sem rolar demais.
          final lado = math.min(520.0, math.max(260.0, c.maxHeight / context.k * .38));
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
            child: Column(children: [
              const _Kicker(texto: 'Pix', icone: Icons.pix, centro: true),
              SizedBox(height: context.dz(22)),
              Text('Escaneie com o app do seu banco',
                  textAlign: TextAlign.center, style: context.vDisplay(84, altura: 1)),
              SizedBox(height: context.dz(22)),
              Text('Abra o app, escolha Pix › Pagar com QR Code',
                  textAlign: TextAlign.center,
                  style: context.vTexto(32, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
              SizedBox(height: context.dz(30)),
              RepaintBoundary(child: QrPix(copiaECola: p.pixCopiaECola!, tokens: t, mov: p.mov, lado: lado)),
              SizedBox(height: context.dz(30)),
              Text('Total', style: context.vTexto(28, peso: FontWeight.w400, cor: t.muted)),
              Text(formatCentavos(p.totalCentavos),
                  key: const ValueKey('pix-total'), style: context.vDisplay(92, altura: 1.05, espacoEm: -.02)),
              SizedBox(height: context.dz(22)),
              Container(
                key: const ValueKey('pix-contador'),
                height: context.dz(76),
                padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
                decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(context.dz(38))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_rounded, size: context.dz(32), color: t.text),
                  SizedBox(width: context.dz(12)),
                  Text('Expira em ', style: context.vTexto(28, peso: FontWeight.w800)),
                  Text(p.pixContador, style: context.vTexto(28, peso: FontWeight.w800)),
                ]),
              ),
              SizedBox(height: context.dz(18)),
              PontosAguardando(tokens: t, mov: p.mov),
            ]),
          );
        }),
      ),
      _Rodape(
        child: BotaoVitrine(
          key: const ValueKey('pix-cancelar'),
          rotulo: 'Trocar forma de pagamento',
          estilo: EstiloBotaoVitrine.fantasma,
          mov: p.mov,
          onTap: p.onCancelarPix,
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------- maquininha

class _Point extends StatelessWidget {
  const _Point({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
          child: Column(children: [
            const _Kicker(texto: 'Cartão', icone: Icons.credit_card_rounded, centro: true),
            SizedBox(height: context.dz(22)),
            Text('Use a maquininha abaixo', textAlign: TextAlign.center, style: context.vDisplay(84, altura: 1)),
            SizedBox(height: context.dz(22)),
            Text('Aproxime o cartão ou celular, ou insira o cartão',
                textAlign: TextAlign.center,
                style: context.vTexto(32, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
            SizedBox(height: context.dz(60)),
            RepaintBoundary(
              child: MaquininhaAnimada(totalCentavos: p.totalCentavos, tokens: t, mov: p.mov, corCartao: t.accent),
            ),
            SizedBox(height: context.dz(40)),
            _SetaAbaixo(mov: p.mov),
          ]),
        ),
      ),
      _Rodape(
        child: BotaoVitrine(
          key: const ValueKey('point-cancelar'),
          rotulo: 'Cancelar',
          estilo: EstiloBotaoVitrine.fantasma,
          mov: p.mov,
          onTap: p.onCancelarPoint,
        ),
      ),
    ]);
  }
}

/// Seta `accent` que "aponta" para a maquininha de verdade, embaixo (1,2 s, só com animação).
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
    _c = AnimationController(vsync: this, duration: widget.mov.d(600));
    if (widget.mov.anima) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, context.dz(20) * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: Icon(Icons.arrow_downward_rounded,
            key: const ValueKey('seta-maquininha'), size: context.dz(60), color: vitrineTokens.accent),
      ),
    );
  }
}

// ---------------------------------------------------------------------- processando / bloqueado

/// O texto da espera em caixa de frase ("EMITINDO O CUPOM FISCAL…" → "Emitindo o cupom
/// fiscal…"), como a GoGen faz; nulo = "Processando…".
String _textoEspera(String? m) {
  if (m == null || m.trim().isEmpty) return 'Processando…';
  final baixo = m.trim().toLowerCase();
  return baixo[0].toUpperCase() + baixo.substring(1);
}

class _Processando extends StatelessWidget {
  const _Processando({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: context.dz(96),
            height: context.dz(96),
            child: CircularProgressIndicator(color: t.accent, strokeWidth: context.dz(8)),
          ),
          SizedBox(height: context.dz(36)),
          Text(_textoEspera(p.mensagemProcessando),
              key: const ValueKey('pagamento-espera'),
              textAlign: TextAlign.center,
              style: context.vDisplay(56, altura: 1.1, espacoEm: -.02)),
        ]),
      ),
    );
  }
}

class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final motivo = p.motivo.trim();
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.dz(56)),
        child: Column(key: const ValueKey('pagamento-bloqueado'), mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: context.dz(160),
            height: context.dz(160),
            decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
            child: Icon(Icons.print_disabled_rounded, size: context.dz(84), color: t.accent),
          ),
          SizedBox(height: context.dz(36)),
          Text('Não é possível pagar agora', textAlign: TextAlign.center, style: context.vDisplay(72, altura: 1.05)),
          if (motivo.isNotEmpty) ...[
            SizedBox(height: context.dz(20)),
            Text('Motivo: $motivo',
                key: const ValueKey('pagamento-motivo'),
                textAlign: TextAlign.center,
                style: context.vTexto(32, peso: FontWeight.w800, cor: t.accent)),
          ],
          SizedBox(height: context.dz(12)),
          Text('Chame um atendente, seu carrinho está salvo',
              textAlign: TextAlign.center,
              style: context.vTexto(30, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
          SizedBox(height: context.dz(48)),
          Row(children: [
            Expanded(
              child: BotaoVitrine(
                key: const ValueKey('voltar-carrinho'),
                rotulo: 'Voltar ao carrinho',
                estilo: EstiloBotaoVitrine.fantasma,
                altura: 110,
                fonte: 30,
                padH: 30,
                mov: p.mov,
                onTap: p.onVoltarCarrinho,
              ),
            ),
            SizedBox(width: context.dz(20)),
            Expanded(
              child: BotaoVitrine(
                key: const ValueKey('tentar-novamente'),
                rotulo: 'Tentar novamente',
                altura: 110,
                fonte: 30,
                padH: 30,
                mov: p.mov,
                onTap: p.onTentarNovamente,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
