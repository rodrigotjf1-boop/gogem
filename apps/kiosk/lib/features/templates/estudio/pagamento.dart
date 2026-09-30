import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/pagamento_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Pagamento do Estúdio (docs/03 §6.7 + 00 §4.7). VIEW PURA com os mesmos estados e
/// condições da GoGen: bloqueado (PORTÃO 2), escolha, PIX, maquininha (Point), processando
/// e erro. Nada de cobrança aqui — write-ahead, Point/PIX e impressão ficam na
/// `PagamentoScreen`. As chaves de teste são as da GoGen (`forma-pix`, `forma-cartao`,
/// `forma-dinheiro`, `pix-cancelar`, `point-cancelar`, `tentar-novamente`…).
class EstudioPagamento extends StatefulWidget {
  const EstudioPagamento({super.key, required this.p});
  final PagamentoProps p;

  @override
  State<EstudioPagamento> createState() => _EstudioPagamentoState();
}

class _EstudioPagamentoState extends State<EstudioPagamento> {
  /// Erro que o cliente já viu e dispensou com "Tentar novamente" (volta à escolha).
  String? _erroVisto;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final mov = p.mov;
    final Widget corpo;
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
    } else if (p.erro != null && p.erro != _erroVisto) {
      voltar = p.onVoltar;
      corpo = _Erro(p: p, onTentar: () => setState(() => _erroVisto = p.erro));
    } else {
      voltar = p.onVoltar;
      corpo = _Escolha(p: p);
    }
    return TelaEstudio(
      mov: mov,
      child: Column(children: [
        TopoEstudio(etapa: 3, onVoltar: voltar, mov: mov),
        Expanded(child: corpo),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────── escolha

class _Escolha extends StatefulWidget {
  const _Escolha({required this.p});
  final PagamentoProps p;

  @override
  State<_Escolha> createState() => _EscolhaState();
}

class _EscolhaState extends State<_Escolha> with SingleTickerProviderStateMixin {
  /// Cascata das opções: 500 ms cada, 70 ms entre uma e outra.
  late final AnimationController _cascata;
  late final List<CurvedAnimation> _passos;

  @override
  void initState() {
    super.initState();
    _cascata = AnimationController(vsync: this, duration: widget.p.mov.d(640));
    _passos = [
      for (var i = 0; i < 3; i++)
        CurvedAnimation(
          parent: _cascata,
          curve: Interval(i * 70 / 640, (i * 70 + 500) / 640, curve: Curves.easeOut),
        ),
    ];
    if (widget.p.mov.anima) {
      _cascata.forward();
    } else {
      _cascata.value = 1;
    }
  }

  @override
  void dispose() {
    for (final a in _passos) {
      a.dispose();
    }
    _cascata.dispose();
    super.dispose();
  }

  Widget _cascateia(int i, Widget filho) {
    final a = _passos[i];
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, context.dz(24) * (1 - a.value)), child: child),
        child: filho,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final k = context.k;
    final nome = p.cliente.trim();
    final opcoes = [
      _OpcaoPagamento(
        chave: 'forma-pix',
        icone: Icons.pix,
        nome: 'Pix',
        descricao: 'Aprovação na hora pelo app do banco',
        destaque: true,
        mov: p.mov,
        onTap: p.onPagarPix,
      ),
      _OpcaoPagamento(
        chave: 'forma-cartao',
        icone: Icons.credit_card_rounded,
        nome: 'Cartão',
        descricao: 'Crédito, débito ou vale: você escolhe na maquininha',
        mov: p.mov,
        onTap: p.onPagarCartao,
      ),
      _OpcaoPagamento(
        chave: 'forma-dinheiro',
        icone: Icons.payments_outlined,
        nome: 'Dinheiro',
        descricao: 'Seu pedido vai para o caixa e você paga lá',
        mov: p.mov,
        onTap: p.onPagarDinheiro,
      ),
    ];
    return CorpoEstudio(
      inicio: [
        Kicker(nome.isEmpty ? 'Último passo' : 'Último passo, $nome'),
        SizedBox(height: 26 * k),
        const TituloTela('Como você quer pagar?'),
        SizedBox(height: 26 * k),
        for (var i = 0; i < opcoes.length; i++) ...[
          if (i > 0) SizedBox(height: 20 * k),
          _cascateia(i, opcoes[i]),
        ],
      ],
      fim: Container(
        key: const ValueKey('pagamento-resumo'),
        padding: EdgeInsets.fromLTRB(36 * k, 32 * k, 36 * k, 32 * k),
        decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(_t.raio * k)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('RESUMO DO PEDIDO',
              style: _t.texto(23 * k, peso: FontWeight.w800, cor: _t.muted, espaco: 23 * .1 * k)),
          SizedBox(height: 14 * k),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line2, width: 2 * k))),
            child: Padding(
              padding: EdgeInsets.only(top: 14 * k),
              child: Row(children: [
                Text('Total', style: _t.texto(40 * k, peso: FontWeight.w800)),
                const Spacer(),
                Text(formatCentavos(p.totalCentavos),
                    key: const ValueKey('pagamento-total'),
                    style: _t.texto(44 * k, peso: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Uma forma de pagamento (`.po`): branca com borda `line`; no toque desliza 8 px para a
/// direita com a borda no acento. O Pix vem em destaque (fundo `hi`, selo "Mais rápido").
class _OpcaoPagamento extends StatefulWidget {
  const _OpcaoPagamento({
    required this.chave,
    required this.icone,
    required this.nome,
    required this.descricao,
    required this.mov,
    required this.onTap,
    this.destaque = false,
  });

  final String chave;
  final IconData icone;
  final String nome;
  final String descricao;
  final Movimento mov;
  final VoidCallback onTap;
  final bool destaque;

  @override
  State<_OpcaoPagamento> createState() => _OpcaoPagamentoState();
}

class _OpcaoPagamentoState extends State<_OpcaoPagamento> {
  bool _premido = false;

  void _marcar(bool v) {
    if (_premido != v) setState(() => _premido = v);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final w = widget;
    final raio = BorderRadius.circular(_t.raio * k);
    final dur = duracao(w.mov, 200);
    return AnimatedSlide(
      offset: Offset(_premido ? 8 / 968 : 0, 0),
      duration: dur,
      child: GestureDetector(
        key: ValueKey(w.chave),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _marcar(true),
        onTapCancel: () => _marcar(false),
        onTapUp: (_) => _marcar(false),
        onTap: w.onTap,
        child: AnimatedContainer(
          duration: dur,
          padding: EdgeInsets.fromLTRB(40 * k, 30 * k, 40 * k, 30 * k),
          decoration: BoxDecoration(
            color: w.destaque ? _t.hi : _t.surface,
            borderRadius: raio,
            border: Border.all(color: w.destaque || _premido ? _t.accent : _t.line, width: 3 * k),
          ),
          child: Row(children: [
            Container(
              width: 124 * k,
              height: 124 * k,
              decoration: BoxDecoration(
                color: w.destaque ? _t.accent : _t.surface2,
                borderRadius: BorderRadius.circular((_t.raio - 6) * k),
              ),
              child: Icon(w.icone, size: 66 * k, color: w.destaque ? _t.onAccent : _t.text),
            ),
            SizedBox(width: 32 * k),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(w.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t.display(46 * k, altura: 1).copyWith(letterSpacing: -46 * .02 * k)),
                  ),
                  if (w.destaque) ...[
                    SizedBox(width: 16 * k),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16 * k, vertical: 8 * k),
                      decoration: BoxDecoration(color: _t.accent2, borderRadius: BorderRadius.circular(20 * k)),
                      child: Text('MAIS RÁPIDO',
                          style: _t.texto(20 * k, peso: FontWeight.w800, cor: _t.onAccent2, espaco: 20 * .08 * k)),
                    ),
                  ],
                ]),
                SizedBox(height: 8 * k),
                Text(w.descricao, style: _t.texto(26 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.3)),
              ]),
            ),
            SizedBox(width: 12 * k),
            Icon(Icons.chevron_right_rounded, size: 48 * k, color: _t.muted),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── PIX

class _Pix extends StatelessWidget {
  const _Pix({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(children: [
      Expanded(
        child: CorpoEstudio(
          centro: true,
          inicio: [
            const Kicker('Pix', icone: Icons.pix),
            SizedBox(height: 26 * k),
            const TituloTela('Escaneie com o app do seu banco', centro: true),
            SizedBox(height: 26 * k),
            const Subtitulo('Abra o app, escolha Pix › Pagar com QR Code', centro: true),
            SizedBox(height: 26 * k),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40 * k),
                boxShadow: [BoxShadow(color: const Color(0x400E1A2B), blurRadius: 60 * k, offset: Offset(0, 30 * k))],
              ),
              child: QrPix(copiaECola: p.pixCopiaECola!, tokens: _t, mov: p.mov, lado: 520),
            ),
            SizedBox(height: 26 * k),
            Text('Total', style: _t.texto(28 * k, peso: FontWeight.w400, cor: _t.muted)),
            Text(formatCentavos(p.totalCentavos),
                key: const ValueKey('pix-total'),
                style: _t.display(92 * k, altura: 1.05).copyWith(letterSpacing: -92 * .03 * k)),
            SizedBox(height: 26 * k),
            Container(
              height: 76 * k,
              padding: EdgeInsets.symmetric(horizontal: 30 * k),
              decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(38 * k)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, size: 32 * k, color: _t.text),
                SizedBox(width: 12 * k),
                Text('Expira em ${p.pixContador}',
                    key: const ValueKey('pix-contador'),
                    style: _t.texto(28 * k, peso: FontWeight.w700)),
              ]),
            ),
            SizedBox(height: 18 * k),
            PontosAguardando(tokens: _t, mov: p.mov),
          ],
        ),
      ),
      RodapeEstudio(
        child: SizedBox(
          width: double.infinity,
          child: BotaoEstudio(
            chave: 'pix-cancelar',
            rotulo: 'Trocar forma de pagamento',
            tipo: TipoBotao.contorno,
            onTap: p.onCancelarPix,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────── maquininha

class _Point extends StatelessWidget {
  const _Point({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(children: [
      Expanded(
        child: CorpoEstudio(
          centro: true,
          inicio: [
            const Kicker('Cartão', icone: Icons.credit_card_rounded),
            SizedBox(height: 26 * k),
            const TituloTela('Use a maquininha abaixo', centro: true),
            SizedBox(height: 26 * k),
            const Subtitulo('Aproxime o cartão ou celular, ou insira o cartão', centro: true),
            SizedBox(height: 34 * k),
            MaquininhaAnimada(
              totalCentavos: p.totalCentavos,
              tokens: _t,
              mov: p.mov,
              corCartao: _t.accent,
              corTela: EstudioCores.telaMaquininha,
              corCorpo: EstudioCores.corpoMaquininha,
            ),
            SizedBox(height: 30 * k),
            // Instrução da Point em modo PDV (a mesma das telas padrão e GoGen).
            const _PassoPoint(n: '1', texto: 'Na maquininha, toque em'),
            SizedBox(height: 12 * k),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 40 * k, vertical: 14 * k),
              decoration: BoxDecoration(
                color: EstudioCores.atualizarPoint,
                borderRadius: BorderRadius.circular(14 * k),
              ),
              child: Text('Atualizar',
                  style: _t.texto(28 * k, peso: FontWeight.w700, cor: EstudioCores.branco)),
            ),
            SizedBox(height: 20 * k),
            const _PassoPoint(n: '2', texto: 'Escolha a forma (crédito, débito ou vale) e pague'),
            SizedBox(height: 26 * k),
            _Seta(mov: p.mov),
          ],
        ),
      ),
      RodapeEstudio(
        child: SizedBox(
          width: double.infinity,
          child: BotaoEstudio(
            chave: 'point-cancelar',
            rotulo: 'Cancelar',
            tipo: TipoBotao.contorno,
            onTap: p.onCancelarPoint,
          ),
        ),
      ),
    ]);
  }
}

class _PassoPoint extends StatelessWidget {
  const _PassoPoint({required this.n, required this.texto});
  final String n;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44 * k,
        height: 44 * k,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
        child: Text(n, style: _t.texto(24 * k, peso: FontWeight.w800, cor: _t.onAccent)),
      ),
      SizedBox(width: 14 * k),
      Flexible(child: Text(texto, textAlign: TextAlign.center, style: _t.texto(30 * k, peso: FontWeight.w600))),
    ]);
  }
}

/// Seta para baixo apontando a maquininha de verdade (vai e volta 20 px em 1,2 s).
class _Seta extends StatefulWidget {
  const _Seta({required this.mov});
  final Movimento mov;

  @override
  State<_Seta> createState() => _SetaState();
}

class _SetaState extends State<_Seta> with SingleTickerProviderStateMixin {
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
    final k = context.k;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 20 * k * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: Icon(Icons.arrow_downward_rounded, key: const ValueKey('seta-maquininha'), size: 60 * k, color: _t.accent),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── processando / erro / bloqueado

class _Processando extends StatelessWidget {
  const _Processando({required this.p});
  final PagamentoProps p;

  /// "EMITINDO O CUPOM FISCAL…" vira "Emitindo o cupom fiscal…" (como a GoGen).
  static String _texto(String? m) {
    if (m == null || m.trim().isEmpty) return 'Processando…';
    final baixo = m.trim().toLowerCase();
    return baixo[0].toUpperCase() + baixo.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final d = 120 * k;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(56 * k),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: d,
            height: d,
            child: p.mov.anima
                ? CircularProgressIndicator(color: _t.accent, strokeWidth: 10 * k)
                : Icon(Icons.hourglass_top_rounded, size: d * .8, color: _t.accent),
          ),
          SizedBox(height: 36 * k),
          Text(_texto(p.mensagemProcessando),
              key: const ValueKey('pagamento-espera'),
              textAlign: TextAlign.center,
              style: _t.display(52 * k, altura: 1.1).copyWith(letterSpacing: -52 * .03 * k)),
        ]),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.p, required this.onTentar});
  final PagamentoProps p;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return _Aviso(
      icone: Icons.error_outline_rounded,
      titulo: p.erro!,
      tituloChave: 'pagamento-erro',
      botoes: [
        BotaoEstudio(chave: 'erro-voltar', rotulo: 'Voltar', tipo: TipoBotao.contorno, onTap: p.onVoltar),
        SizedBox(width: 20 * k),
        BotaoEstudio(chave: 'erro-tentar-novamente', rotulo: 'Tentar novamente', onTap: onTentar),
      ],
    );
  }
}

class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.p});
  final PagamentoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return _Aviso(
      chave: 'pagamento-bloqueado',
      icone: Icons.print_disabled_rounded,
      titulo: 'Não é possível pagar agora',
      detalhes: ['Motivo: ${p.motivo}', 'Chame um atendente, seu carrinho está salvo'],
      botoes: [
        BotaoEstudio(
          chave: 'voltar-carrinho',
          rotulo: 'Voltar ao carrinho',
          tipo: TipoBotao.contorno,
          onTap: p.onVoltarCarrinho,
        ),
        SizedBox(width: 20 * k),
        BotaoEstudio(chave: 'tentar-novamente', rotulo: 'Tentar novamente', onTap: p.onTentarNovamente),
      ],
    );
  }
}

/// Tela de aviso (erro, bloqueio): ícone num círculo, título, detalhes e botões.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.titulo,
    required this.botoes,
    this.detalhes = const [],
    this.chave,
    this.tituloChave,
  });

  final IconData icone;
  final String titulo;
  final List<String> detalhes;
  final List<Widget> botoes;
  final String? chave;
  final String? tituloChave;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final d = 170 * k;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(56 * k),
        child: Column(
          key: chave == null ? null : ValueKey<String>(chave!),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(color: _t.err.withAlpha(28), shape: BoxShape.circle),
              child: Icon(icone, size: d * .5, color: _t.err),
            ),
            SizedBox(height: 34 * k),
            Text(titulo,
                key: tituloChave == null ? null : ValueKey<String>(tituloChave!),
                textAlign: TextAlign.center,
                style: _t.display(56 * k, altura: 1.1).copyWith(letterSpacing: -56 * .03 * k)),
            for (final d in detalhes) ...[
              SizedBox(height: 12 * k),
              Text(d,
                  textAlign: TextAlign.center,
                  style: _t.texto(30 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.35)),
            ],
            SizedBox(height: 40 * k),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: botoes),
            ),
          ],
        ),
      ),
    );
  }
}
