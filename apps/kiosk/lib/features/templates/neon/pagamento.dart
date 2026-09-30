import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/pagamento_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Pagamento do Neon 2.0 (docs/templates/04-neon-2.md §6.7 e 00 §4.7). Cobre os mesmos
/// sub-estados da `GogenPagamentoView` (bloqueado, escolha, processando, PIX, maquininha),
/// com as MESMAS formas e as mesmas chaves de teste (`forma-pix`, `forma-cartao`,
/// `forma-dinheiro`, `pix-cancelar`, `point-cancelar`, `tentar-novamente`…). Nada de lógica
/// de cobrança aqui: write-ahead, portões, Point/PIX e impressão ficam na tela.
class NeonPagamentoView extends StatelessWidget {
  const NeonPagamentoView({super.key, required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _t.bg,
      body: SafeArea(child: NeonEntrada(mov: p.mov, child: _corpo(context))),
    );
  }

  Widget _corpo(BuildContext context) {
    if (p.bloqueado) return _Bloqueado(p: p);
    if (p.processando) {
      if (p.pixCopiaECola != null) return _Pix(p: p);
      if (p.pointAtivo) return _Point(p: p);
      return _Processando(p: p);
    }
    return _Escolha(p: p);
  }
}

/// Coluna padrão das telas de pagamento: topo, corpo rolável e rodapé opcional.
class _Moldura extends StatelessWidget {
  const _Moldura({required this.mov, required this.corpo, this.onVoltar, this.rodape});
  final Movimento mov;
  final Widget corpo;
  final VoidCallback? onVoltar;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      NeonTopo(mov: mov, etapa: 3, onVoltar: onVoltar),
      Expanded(
        child: CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
              child: corpo,
            ),
          ),
        ]),
      ),
      if (rodape != null)
        Container(
          padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(44)),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
          child: rodape,
        ),
    ]);
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.texto, {this.icone});
  final String texto;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[
          Icon(icone, size: context.dz(32), color: _t.accent),
          SizedBox(width: context.dz(10)),
        ],
        Flexible(
          child: Text(texto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: neonTexto(context.dz(26), peso: FontWeight.w700, cor: _t.accent, espaco: .12)),
        ),
      ]);
}

class _Escolha extends StatelessWidget {
  const _Escolha({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final nome = p.cliente.trim();
    final opcoes = [
      (
        'forma-pix',
        Icons.pix,
        'Pix',
        'Aprovação na hora pelo app do banco',
        true,
        p.onPagarPix,
      ),
      (
        'forma-cartao',
        Icons.credit_card_rounded,
        'Cartão',
        'Crédito, débito ou vale: você escolhe na maquininha',
        false,
        p.onPagarCartao,
      ),
      (
        'forma-dinheiro',
        Icons.payments_outlined,
        'Dinheiro',
        'Seu pedido vai para o caixa e você paga lá',
        false,
        p.onPagarDinheiro,
      ),
    ];
    return _Moldura(
      mov: p.mov,
      onVoltar: p.onVoltar,
      corpo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Kicker(nome.isEmpty ? 'Último passo' : 'Último passo, $nome'),
        ),
        SizedBox(height: context.dz(18)),
        Text(_t.caixa('Como você quer pagar?'), style: neonDisplay(context.dz(66), altura: 1.02)),
        if (p.erro != null) ...[
          SizedBox(height: context.dz(24)),
          Container(
            key: const ValueKey('pagamento-erro'),
            padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(22)),
            decoration: BoxDecoration(
              color: const Color(0x1FFF5577),
              borderRadius: BorderRadius.circular(context.dz(20)),
              border: Border.all(color: _t.err, width: context.dz(3)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: context.dz(44), color: _t.err),
              SizedBox(width: context.dz(18)),
              Expanded(
                child: Text(p.erro!, style: neonTexto(context.dz(28), peso: FontWeight.w700, altura: 1.3)),
              ),
            ]),
          ),
        ],
        SizedBox(height: context.dz(30)),
        for (var i = 0; i < opcoes.length; i++) ...[
          if (i > 0) SizedBox(height: context.dz(20)),
          _Cascata(
            mov: p.mov,
            atraso: 70 * i,
            child: _Forma(
              chave: opcoes[i].$1,
              icone: opcoes[i].$2,
              nome: opcoes[i].$3,
              descricao: opcoes[i].$4,
              destaque: opcoes[i].$5,
              onTap: opcoes[i].$6,
            ),
          ),
        ],
        const Spacer(),
        SizedBox(height: context.dz(30)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.dz(36), vertical: context.dz(30)),
          decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('RESUMO DO PEDIDO',
                style: neonTexto(context.dz(23), peso: FontWeight.w700, cor: _t.muted, espaco: .1)),
            SizedBox(height: context.dz(14)),
            Row(children: [
              Text('Total', style: neonTexto(context.dz(40), peso: FontWeight.w700)),
              SizedBox(width: context.dz(20)),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(formatCentavos(p.totalCentavos),
                      key: const ValueKey('pagamento-total'), style: neonDisplay(context.dz(48), cor: _t.accent)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Entrada em cascata das formas (70 ms entre cada uma) — só com animação.
class _Cascata extends StatelessWidget {
  const _Cascata({required this.mov, required this.atraso, required this.child});
  final Movimento mov;
  final int atraso;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!mov.anima) return child;
    final total = 500 + atraso;
    final inicio = atraso / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(total),
      child: child,
      builder: (context, v, child) {
        final t = Curves.easeOut.transform(((v - inicio) / (1 - inicio)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, context.dz(24) * (1 - t)), child: child),
        );
      },
    );
  }
}

class _Forma extends StatelessWidget {
  const _Forma({
    required this.chave,
    required this.icone,
    required this.nome,
    required this.descricao,
    required this.destaque,
    required this.onTap,
  });
  final String chave;
  final IconData icone;
  final String nome;
  final String descricao;
  final bool destaque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(context.dz(_t.raio));
    return Material(
      color: destaque ? _t.hi : _t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: BorderSide(color: destaque ? _t.accent : _t.line, width: context.dz(destaque ? 3 : 2)),
      ),
      child: InkWell(
        key: ValueKey(chave),
        borderRadius: raio,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.dz(40), vertical: context.dz(30)),
          child: Row(children: [
            Container(
              width: context.dz(124),
              height: context.dz(124),
              decoration: BoxDecoration(
                color: destaque ? _t.accent : _t.surface2,
                borderRadius: BorderRadius.circular(context.dz(18)),
              ),
              child: Icon(icone, size: context.dz(64), color: destaque ? _t.onAccent : _t.text),
            ),
            SizedBox(width: context.dz(32)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.dz(16),
                  runSpacing: context.dz(8),
                  children: [
                    Text(_t.caixa(nome), style: neonDisplay(context.dz(46))),
                    if (destaque)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(8)),
                        decoration: BoxDecoration(
                          color: _t.accent2,
                          borderRadius: BorderRadius.circular(context.dz(20)),
                        ),
                        child: Text('MAIS RÁPIDO',
                            style: neonTexto(context.dz(20), peso: FontWeight.w700, cor: _t.onAccent2, espaco: .08)),
                      ),
                  ],
                ),
                SizedBox(height: context.dz(8)),
                Text(descricao, style: neonTexto(context.dz(26), cor: _t.muted, altura: 1.3)),
              ]),
            ),
            SizedBox(width: context.dz(12)),
            Icon(Icons.chevron_right_rounded, size: context.dz(48), color: _t.muted),
          ]),
        ),
      ),
    );
  }
}

class _Pix extends StatelessWidget {
  const _Pix({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      mov: p.mov,
      rodape: NeonBotao(
        key: const ValueKey('pix-cancelar'),
        rotulo: 'Trocar forma de pagamento',
        tipo: NeonBotaoTipo.fantasma,
        fonte: 30,
        onTap: p.onCancelarPix,
      ),
      corpo: Column(children: [
        const _Kicker('Pix', icone: Icons.pix),
        SizedBox(height: context.dz(18)),
        Text(_t.caixa('Escaneie com o app do seu banco'),
            textAlign: TextAlign.center, style: neonDisplay(context.dz(66), altura: 1.02)),
        SizedBox(height: context.dz(18)),
        Text('Abra o app, escolha Pix › Pagar com QR Code',
            textAlign: TextAlign.center, style: neonTexto(context.dz(32), cor: _t.muted, altura: 1.3)),
        SizedBox(height: context.dz(30)),
        QrPix(copiaECola: p.pixCopiaECola!, tokens: _t, mov: p.mov, lado: 520),
        SizedBox(height: context.dz(28)),
        Text('Total', style: neonTexto(context.dz(28), cor: _t.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(formatCentavos(p.totalCentavos),
              key: const ValueKey('pix-total'), style: neonDisplay(context.dz(92))),
        ),
        SizedBox(height: context.dz(22)),
        Container(
          height: context.dz(76),
          padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
          decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(38))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: context.dz(34), color: _t.text),
            SizedBox(width: context.dz(12)),
            Text('Expira em ${p.pixContador}',
                key: const ValueKey('pix-contador'), style: neonTexto(context.dz(28), peso: FontWeight.w700)),
          ]),
        ),
        SizedBox(height: context.dz(18)),
        PontosAguardando(tokens: _t, mov: p.mov),
      ]),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      mov: p.mov,
      rodape: NeonBotao(
        key: const ValueKey('point-cancelar'),
        rotulo: 'Cancelar',
        tipo: NeonBotaoTipo.fantasma,
        fonte: 30,
        onTap: p.onCancelarPoint,
      ),
      corpo: Column(children: [
        const _Kicker('Cartão', icone: Icons.credit_card_rounded),
        SizedBox(height: context.dz(18)),
        Text(_t.caixa('Use a maquininha abaixo'),
            key: const ValueKey('point-titulo'),
            textAlign: TextAlign.center,
            style: neonDisplay(context.dz(66), altura: 1.02)),
        SizedBox(height: context.dz(18)),
        Text('Aproxime o cartão ou celular, ou insira o cartão',
            textAlign: TextAlign.center, style: neonTexto(context.dz(32), cor: _t.muted, altura: 1.3)),
        SizedBox(height: context.dz(60)),
        MaquininhaAnimada(totalCentavos: p.totalCentavos, tokens: _t, mov: p.mov, corCartao: _t.accent),
        SizedBox(height: context.dz(40)),
        _SetaBaixo(mov: p.mov),
      ]),
    );
  }
}

/// Seta para baixo, balançando (1,2 s) — só com loops.
class _SetaBaixo extends StatefulWidget {
  const _SetaBaixo({required this.mov});
  final Movimento mov;

  @override
  State<_SetaBaixo> createState() => _SetaBaixoState();
}

class _SetaBaixoState extends State<_SetaBaixo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.mov.d(1200));
    if (widget.mov.loops) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seta = Icon(Icons.arrow_downward_rounded, size: context.dz(64), color: _t.accent);
    if (!widget.mov.loops) return seta;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: seta,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, context.dz(20) * (1 - math.cos(_c.value * 2 * math.pi)) / 2),
          child: child,
        ),
      ),
    );
  }
}

class _Processando extends StatelessWidget {
  const _Processando({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final msg =
        (p.mensagemProcessando == null || p.mensagemProcessando!.isEmpty) ? 'Processando…' : p.mensagemProcessando!;
    return Column(children: [
      NeonTopo(mov: p.mov, etapa: 3),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.dz(56)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: context.dz(120),
                height: context.dz(120),
                child: CircularProgressIndicator(
                  color: _t.accent,
                  strokeWidth: context.dz(10),
                  value: p.mov.anima ? null : .7,
                ),
              ),
              SizedBox(height: context.dz(40)),
              Text(_t.caixa(msg),
                  key: const ValueKey('pagamento-espera'),
                  textAlign: TextAlign.center,
                  style: neonDisplay(context.dz(52), altura: 1.1)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      NeonTopo(mov: p.mov, etapa: 3),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.dz(56)),
            child: Column(
              key: const ValueKey('pagamento-bloqueado'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: context.dz(170),
                  height: context.dz(170),
                  decoration: BoxDecoration(
                    color: _t.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: _t.err, width: context.dz(4)),
                  ),
                  child: Icon(Icons.print_disabled_rounded, size: context.dz(86), color: _t.err),
                ),
                SizedBox(height: context.dz(34)),
                Text(_t.caixa('Não é possível pagar agora'),
                    textAlign: TextAlign.center, style: neonDisplay(context.dz(56), altura: 1.05)),
                SizedBox(height: context.dz(18)),
                Text(p.motivo,
                    key: const ValueKey('pagamento-motivo'),
                    textAlign: TextAlign.center,
                    style: neonTexto(context.dz(32), peso: FontWeight.w700, cor: _t.err)),
                SizedBox(height: context.dz(10)),
                Text('Chame um atendente, seu carrinho está salvo',
                    textAlign: TextAlign.center, style: neonTexto(context.dz(30), cor: _t.muted, altura: 1.3)),
                SizedBox(height: context.dz(44)),
                Row(children: [
                  Expanded(
                    child: NeonBotao(
                      key: const ValueKey('voltar-carrinho'),
                      rotulo: 'Voltar ao carrinho',
                      tipo: NeonBotaoTipo.fantasma,
                      fonte: 28,
                      onTap: p.onVoltarCarrinho,
                    ),
                  ),
                  SizedBox(width: context.dz(20)),
                  Expanded(
                    child: NeonBotao(
                      key: const ValueKey('tentar-novamente'),
                      rotulo: 'Tentar novamente',
                      fonte: 28,
                      onTap: p.onTentarNovamente,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}
