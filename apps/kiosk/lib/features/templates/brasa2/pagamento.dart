import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../comum/pagamento_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Estados da tela, na MESMA precedência da `GogenPagamentoView`: bloqueado → cobrando
/// (PIX, maquininha ou espera) → erro → escolha.
enum _Estado { bloqueado, pix, point, processando, erro, escolha }

/// Pagamento do **Brasa 2.0** (docs/templates/01 §6.7, 00 §4.7). VIEW PURA: write-ahead,
/// portão da impressora, Point/PIX, fiscal e impressão ficam no `PagamentoScreen`. As formas
/// mostradas e as chaves de teste são as da GoGen (`forma-pix`, `forma-cartao`,
/// `forma-dinheiro`, `pix-contador`, `pix-cancelar`, `point-cancelar`, …).
class Brasa2Pagamento extends StatefulWidget {
  const Brasa2Pagamento(this.p, {super.key});
  final PagamentoProps p;

  @override
  State<Brasa2Pagamento> createState() => _Brasa2PagamentoState();
}

class _Brasa2PagamentoState extends State<Brasa2Pagamento> {
  /// O cliente já leu o erro e tocou em "Tentar novamente": volta às formas de pagamento
  /// (é assim que se tenta de novo — como na GoGen, escolhendo a forma outra vez).
  bool _erroVisto = false;

  PagamentoProps get p => widget.p;
  Movimento get mov => p.mov;

  @override
  void didUpdateWidget(covariant Brasa2Pagamento old) {
    super.didUpdateWidget(old);
    // Erro novo (ou o mesmo, depois de outra tentativa): mostra de novo.
    if (p.erro != old.p.erro || (old.p.processando && !p.processando)) _erroVisto = false;
  }

  _Estado get _estado {
    if (p.bloqueado) return _Estado.bloqueado;
    if (p.processando) {
      if (p.pixCopiaECola != null) return _Estado.pix;
      if (p.pointAtivo) return _Estado.point;
      return _Estado.processando;
    }
    if (p.erro != null && !_erroVisto) return _Estado.erro;
    return _Estado.escolha;
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    return Brasa2Tela(
      child: Column(children: [
        Brasa2Topo(
          // Voltar só na escolha: cobrando, quem sai é o botão do rodapé (cancela a cobrança).
          onVoltar: estado == _Estado.escolha || estado == _Estado.erro ? p.onVoltar : null,
          etapa: 3,
          mov: mov,
        ),
        Expanded(
          child: Brasa2Entrada(
            key: ValueKey('estado-${estado.name}'),
            mov: mov,
            child: switch (estado) {
              _Estado.bloqueado => _bloqueado(context),
              _Estado.pix => _pix(context),
              _Estado.point => _point(context),
              _Estado.processando => _processando(context),
              _Estado.erro => _erro(context),
              _Estado.escolha => _escolha(context),
            },
          ),
        ),
      ]),
    );
  }

  // ---- escolha da forma ----
  Widget _escolha(BuildContext context) {
    final nome = p.cliente.trim();
    final formas = [
      (
        chave: 'forma-pix',
        icone: BrasaIcone.pix,
        nome: 'Pix',
        texto: 'Aprovação na hora pelo app do banco',
        destaque: true,
        onTap: p.onPagarPix,
      ),
      (
        chave: 'forma-cartao',
        icone: BrasaIcone.cartao,
        nome: 'Cartão',
        texto: 'Crédito, débito ou vale: você escolhe na maquininha',
        destaque: false,
        onTap: p.onPagarCartao,
      ),
      (
        chave: 'forma-dinheiro',
        icone: BrasaIcone.dinheiro,
        nome: 'Dinheiro',
        texto: 'Seu pedido vai para o caixa e você paga lá',
        destaque: false,
        onTap: p.onPagarDinheiro,
      ),
    ];
    return Brasa2CorpoRolavel(children: [
      Brasa2Kicker(nome.isEmpty ? 'Último passo' : 'Último passo, $nome', espacoEm: .12),
      Text('Como você quer pagar?', style: brasaTitulo(context, 92)),
      for (var i = 0; i < formas.length; i++)
        Brasa2Entrada(
          mov: mov,
          atraso: Duration(milliseconds: 70 * i),
          duracaoMs: 500,
          subida: 24,
          child: _Forma(
            chave: formas[i].chave,
            icone: formas[i].icone,
            nome: formas[i].nome,
            texto: formas[i].texto,
            destaque: formas[i].destaque,
            onTap: formas[i].onTap,
          ),
        ),
      const Spacer(),
      Container(
        key: const ValueKey('pagamento-resumo'),
        padding: EdgeInsets.symmetric(horizontal: context.dz(36), vertical: context.dz(32)),
        decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('RESUMO DO PEDIDO',
              style: brasaTexto(context, 23, peso: FontWeight.w800, cor: _t.muted, espacoEm: .1)),
          SizedBox(height: context.dz(14)),
          Container(height: context.dz(2), color: _t.line2),
          SizedBox(height: context.dz(14)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Total', style: brasaTexto(context, 40, peso: FontWeight.w800)),
              SizedBox(width: context.dz(20)),
              Expanded(
                child: Text(formatCentavos(p.totalCentavos),
                    key: const ValueKey('pagamento-total'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: brasaTexto(context, 44, peso: FontWeight.w800)),
              ),
            ],
          ),
        ]),
      ),
    ]);
  }

  // ---- erro: a mensagem, "Tentar novamente" (volta às formas) e "Voltar" ----
  Widget _erro(BuildContext context) => Column(children: [
        Expanded(
          child: Brasa2Estado(
            key: const ValueKey('pagamento-erro'),
            titulo: 'Pagamento não concluído',
            detalhe: p.erro,
            icone: BrasaIcone.cartao,
          ),
        ),
        Brasa2Rodape(children: [
          Row(children: [
            Expanded(
              flex: 10,
              child: Brasa2Botao(
                key: const ValueKey('erro-voltar'),
                rotulo: 'Voltar',
                variante: Brasa2Variante.fantasma,
                mov: mov,
                onTap: p.onVoltar,
              ),
            ),
            SizedBox(width: context.dz(20)),
            Expanded(
              flex: 16,
              child: Brasa2Botao(
                key: const ValueKey('erro-tentar-novamente'),
                rotulo: 'Tentar novamente',
                mov: mov,
                onTap: () => setState(() => _erroVisto = true),
              ),
            ),
          ]),
        ]),
      ]);

  // ---- bloqueado (PORTÃO 2: sem papel/tampa/offline) ----
  Widget _bloqueado(BuildContext context) => Column(children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.dz(56)),
              child: Column(key: const ValueKey('pagamento-bloqueado'), mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: context.dz(190),
                  height: context.dz(190),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _t.hi, shape: BoxShape.circle),
                  child: IconeBrasa(BrasaIcone.impressora, tamanho: context.dz(100), cor: _t.accent, traco: 1.8),
                ),
                SizedBox(height: context.dz(36)),
                Text('Não é possível pagar agora',
                    textAlign: TextAlign.center, style: brasaTitulo(context, 72, altura: 1.05)),
                SizedBox(height: context.dz(20)),
                Text(p.motivo,
                    key: const ValueKey('pagamento-motivo'),
                    textAlign: TextAlign.center,
                    style: brasaTexto(context, 32, peso: FontWeight.w800, cor: _t.accent)),
                SizedBox(height: context.dz(12)),
                Text('Chame um atendente, seu carrinho está salvo',
                    textAlign: TextAlign.center, style: brasaTexto(context, 30, cor: _t.muted, altura: 1.4)),
              ]),
            ),
          ),
        ),
        Brasa2Rodape(children: [
          Row(children: [
            Expanded(
              flex: 10,
              child: Brasa2Botao(
                key: const ValueKey('voltar-carrinho'),
                rotulo: 'Voltar ao carrinho',
                variante: Brasa2Variante.fantasma,
                mov: mov,
                onTap: p.onVoltarCarrinho,
              ),
            ),
            SizedBox(width: context.dz(20)),
            Expanded(
              flex: 12,
              child: Brasa2Botao(
                key: const ValueKey('tentar-novamente'),
                rotulo: 'Tentar novamente',
                mov: mov,
                onTap: p.onTentarNovamente,
              ),
            ),
          ]),
        ]),
      ]);

  // ---- processando (e a confirmação da venda: "Emitindo o cupom fiscal…") ----
  Widget _processando(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.dz(56)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: context.dz(120),
              height: context.dz(120),
              child: CircularProgressIndicator(color: _t.accent, strokeWidth: context.dz(9)),
            ),
            SizedBox(height: context.dz(40)),
            Text(textoEsperaBrasa(p.mensagemProcessando),
                key: const ValueKey('pagamento-espera'),
                textAlign: TextAlign.center,
                style: brasaTitulo(context, 64, altura: 1.1)),
          ]),
        ),
      );

  // ---- PIX: QR, total, contador e "Trocar forma de pagamento" ----
  Widget _pix(BuildContext context) => Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
            child: Column(children: [
              const Brasa2Kicker('Pix', icone: BrasaIcone.pix),
              SizedBox(height: context.dz(26)),
              // Quebra equilibrada como no desenho (`text-wrap: balance`).
              Text('Escaneie com o\napp do seu banco', textAlign: TextAlign.center, style: brasaTitulo(context, 92)),
              SizedBox(height: context.dz(26)),
              Text('Abra o app, escolha Pix › Pagar com QR Code',
                  textAlign: TextAlign.center, style: brasaTexto(context, 32, cor: _t.muted, altura: 1.4)),
              SizedBox(height: context.dz(26)),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.dz(40)),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 60, offset: Offset(0, 30))],
                ),
                child: QrPix(copiaECola: p.pixCopiaECola!, tokens: _t, mov: mov, lado: 520),
              ),
              SizedBox(height: context.dz(26)),
              Text('Total', style: brasaTexto(context, 28, cor: _t.muted)),
              SizedBox(height: context.dz(4)),
              Text(formatCentavos(p.totalCentavos), style: brasaTitulo(context, 92)),
              SizedBox(height: context.dz(26)),
              Container(
                key: const ValueKey('pix-contador'),
                height: context.dz(76),
                padding: EdgeInsets.symmetric(horizontal: context.dz(30)),
                decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(38))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconeBrasa(BrasaIcone.relogio, tamanho: context.dz(32), cor: _t.text),
                  SizedBox(width: context.dz(12)),
                  Text('Expira em ${p.pixContador}', style: brasaTexto(context, 28, peso: FontWeight.w800)),
                ]),
              ),
              SizedBox(height: context.dz(18)),
              PontosAguardando(tokens: _t, mov: mov),
            ]),
          ),
        ),
        Brasa2Rodape(children: [
          Brasa2Botao(
            key: const ValueKey('pix-cancelar'),
            rotulo: 'Trocar forma de pagamento',
            variante: Brasa2Variante.fantasma,
            mov: mov,
            largura: double.infinity,
            onTap: p.onCancelarPix,
          ),
        ]),
      ]);

  // ---- maquininha (Point) ----
  Widget _point(BuildContext context) => Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
            child: Column(children: [
              const Brasa2Kicker('Cartão', icone: BrasaIcone.cartao),
              SizedBox(height: context.dz(26)),
              // Uma linha só, como no desenho (encolhe um pouco se não couber).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Use a maquininha abaixo', maxLines: 1, style: brasaTitulo(context, 92)),
              ),
              SizedBox(height: context.dz(26)),
              Text('Aproxime o cartão ou celular, ou insira o cartão',
                  textAlign: TextAlign.center, style: brasaTexto(context, 32, cor: _t.muted, altura: 1.4)),
              SizedBox(height: context.dz(60)),
              MaquininhaAnimada(
                totalCentavos: p.totalCentavos,
                tokens: _t,
                mov: mov,
                corTela: const Color(0xFFCFE8D8),
                corCorpo: const Color(0xFF1C1E23),
              ),
              SizedBox(height: context.dz(40)),
              _SetaParaBaixo(mov: mov),
            ]),
          ),
        ),
        Brasa2Rodape(children: [
          Brasa2Botao(
            key: const ValueKey('point-cancelar'),
            rotulo: 'Trocar forma de pagamento',
            variante: Brasa2Variante.fantasma,
            mov: mov,
            largura: double.infinity,
            onTap: p.onCancelarPoint,
          ),
        ]),
      ]);
}

/// A mensagem de espera vem em CAIXA ALTA do fluxo ("EMITINDO O CUPOM FISCAL…"); aqui vai
/// em caixa de frase, como na GoGen. Nula = "Processando…".
String textoEsperaBrasa(String? m) {
  if (m == null || m.trim().isEmpty) return 'Processando…';
  final baixo = m.trim().toLowerCase();
  return baixo[0].toUpperCase() + baixo.substring(1);
}

/// Uma forma de pagamento: ícone num quadrado de 124, nome em DM Serif 52, texto e seta.
/// A destacada (Pix) tem borda no acento, fundo `hi`, ícone no acento e o selo "Mais rápido".
class _Forma extends StatelessWidget {
  const _Forma({
    required this.chave,
    required this.icone,
    required this.nome,
    required this.texto,
    required this.destaque,
    required this.onTap,
  });
  final String chave;
  final BrasaIcone icone;
  final String nome;
  final String texto;
  final bool destaque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: nome,
        child: GestureDetector(
          key: ValueKey(chave),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: context.dz(40), vertical: context.dz(30)),
            decoration: BoxDecoration(
              color: destaque ? _t.hi : _t.surface,
              borderRadius: BorderRadius.circular(context.dz(_t.raio)),
              border: Border.all(color: destaque ? _t.accent : _t.line, width: context.dz(3)),
            ),
            child: Row(children: [
              Container(
                width: context.dz(124),
                height: context.dz(124),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: destaque ? _t.accent : _t.surface2,
                  borderRadius: BorderRadius.circular(context.dz(_t.raio - 6)),
                ),
                child: IconeBrasa(icone, tamanho: context.dz(66), cor: destaque ? _t.onAccent : _t.text, traco: 1.9),
              ),
              SizedBox(width: context.dz(32)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.dz(16),
                    runSpacing: context.dz(6),
                    children: [
                      Text(nome, style: brasaTitulo(context, 52)),
                      if (destaque)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: context.dz(16), vertical: context.dz(8)),
                          decoration: BoxDecoration(color: _t.accent2, borderRadius: BorderRadius.circular(context.dz(20))),
                          child: Text('MAIS RÁPIDO',
                              style: brasaTexto(context, 20,
                                  peso: FontWeight.w800, cor: _t.onAccent2, altura: 1, espacoEm: .08)),
                        ),
                    ],
                  ),
                  SizedBox(height: context.dz(8)),
                  Text(texto, style: brasaTexto(context, 26, cor: _t.muted, altura: 1.3)),
                ]),
              ),
              SizedBox(width: context.dz(16)),
              IconeBrasa(BrasaIcone.chevron, tamanho: context.dz(44), cor: _t.muted, traco: 2.4),
            ]),
          ),
        ),
      );
}

/// Seta para baixo apontando a maquininha (1,2 s, vai e volta 20 px; parada sem animação).
class _SetaParaBaixo extends StatefulWidget {
  const _SetaParaBaixo({required this.mov});
  final Movimento mov;

  @override
  State<_SetaParaBaixo> createState() => _SetaParaBaixoState();
}

class _SetaParaBaixoState extends State<_SetaParaBaixo> with SingleTickerProviderStateMixin {
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
    final seta = RotatedBox(
      quarterTurns: 1,
      child: IconeBrasa(BrasaIcone.seta, tamanho: context.dz(60), cor: _t.accent, traco: 2.4),
    );
    if (!widget.mov.anima) return seta;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, context.dz(20) * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: seta,
    );
  }
}
