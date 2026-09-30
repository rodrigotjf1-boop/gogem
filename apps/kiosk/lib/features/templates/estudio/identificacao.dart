import 'package:flutter/material.dart';
import '../comum/teclados.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Visual das teclas (§6.6): brancas, raio 26, "degrau" `line` embaixo; as de função
/// (Limpar, Apagar) em `surface2`.
final _teclas = TeclaEstilo(
  fundo: _t.surface,
  tinta: _t.text,
  muted: _t.muted,
  sombra: _t.line,
  raio: _t.raioTecla,
  secundariaOverride: TeclaEstilo(
    fundo: _t.surface2,
    tinta: _t.text,
    muted: _t.muted,
    sombra: _t.line,
    raio: _t.raioTecla,
  ),
);

/// Identificação do Estúdio (docs/03 §6.6 + 00 §4.6) em DUAS etapas internas:
/// 1. "CPF na nota?" (opcional, ou obrigatório com o aviso da UF);
/// 2. "Como podemos te chamar?" com o teclado de letras.
/// Sair da etapa 1 só guarda a escolha; "Continuar para pagamento" (etapa 2) chama
/// `onConfirmar` (com CPF) ou `onPular` (sem CPF). VIEW PURA: validação e navegação
/// continuam na `IdentificacaoScreen`.
class EstudioIdentificacao extends StatefulWidget {
  const EstudioIdentificacao({super.key, required this.p});
  final IdentificacaoProps p;

  @override
  State<EstudioIdentificacao> createState() => _EstudioIdentificacaoState();
}

class _EstudioIdentificacaoState extends State<EstudioIdentificacao> {
  int _etapa = 0;

  /// Escolha da etapa 1: seguir COM o CPF digitado (válido) ou sem ele.
  bool _comCpf = false;

  IdentificacaoProps get p => widget.p;
  bool get _obrigatorio => p.avisoCpfObrigatorio != null;
  bool get _cpfOk => p.completo && p.valido;

  /// "Continuar" da etapa 1: CPF vazio ou válido (com o aviso da UF, só válido).
  bool get _podeContinuar => _obrigatorio ? _cpfOk : (p.cpf.isEmpty || _cpfOk);

  void _continuarCpf() => setState(() {
        _comCpf = _cpfOk;
        _etapa = 1;
      });

  void _pularCpf() => setState(() {
        _comCpf = false;
        _etapa = 1;
      });

  void _limpar() {
    for (var i = p.cpf.length; i > 0; i--) {
      p.onApagar();
    }
  }

  void _finalizar() => _comCpf ? p.onConfirmar() : p.onPular();

  void _voltar() {
    if (_etapa == 1) {
      setState(() => _etapa = 0);
    } else {
      p.onVoltar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mov = p.mov;
    final corpo = _etapa == 0 ? _etapaCpf(context) : _etapaNome(context);
    return TelaEstudio(
      mov: mov,
      child: Column(children: [
        TopoEstudio(etapa: 2, onVoltar: _voltar, mov: mov),
        Expanded(
          child: mov.anima
              ? AnimatedSwitcher(
                  duration: mov.d(550),
                  switchInCurve: curvaTela,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: AnimatedBuilder(
                      animation: a,
                      builder: (_, filho) =>
                          Transform.translate(offset: Offset(context.dz(90) * (1 - a.value), 0), child: filho),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey('id-etapa-$_etapa'), child: corpo),
                )
              : KeyedSubtree(key: ValueKey('id-etapa-$_etapa'), child: corpo),
        ),
      ]),
    );
  }

  Widget _etapaCpf(BuildContext context) {
    final k = context.k;
    final aviso = p.avisoCpfObrigatorio;
    return Column(children: [
      Expanded(
        child: CorpoEstudio(
          inicio: [
            Row(children: [
              const _IconeForm(icone: Icons.badge_outlined),
              if (aviso == null) ...[
                SizedBox(width: 20 * k),
                Container(
                  key: const ValueKey('cpf-opcional'),
                  height: 52 * k,
                  padding: EdgeInsets.symmetric(horizontal: 22 * k),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(26 * k)),
                  child: Text('Opcional', style: _t.texto(24 * k, peso: FontWeight.w700)),
                ),
              ],
            ]),
            SizedBox(height: 26 * k),
            const TituloTela('CPF na nota?'),
            SizedBox(height: 26 * k),
            if (aviso == null)
              const Subtitulo('Opcional. Informe se quiser a nota fiscal no seu nome.')
            else
              Container(
                key: const ValueKey('aviso-cpf-obrigatorio'),
                padding: EdgeInsets.symmetric(horizontal: 28 * k, vertical: 20 * k),
                decoration: BoxDecoration(
                  color: _t.hi,
                  borderRadius: BorderRadius.circular((_t.raio - 14) * k),
                  border: Border.all(color: _t.accent, width: 3 * k),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 38 * k, color: _t.accent),
                  SizedBox(width: 16 * k),
                  Expanded(
                    child: Text(aviso, style: _t.texto(28 * k, peso: FontWeight.w800, altura: 1.3)),
                  ),
                ]),
              ),
            SizedBox(height: 26 * k),
            CampoCpf(cpf: p.cpf, completo: p.completo, valido: p.valido, tokens: _t, mov: p.mov),
            SizedBox(height: 18 * k),
            _MensagemCpf(completo: p.completo, valido: p.valido),
          ],
          fim: TecladoCpf(
            onDigito: p.onDigito,
            onApagar: p.onApagar,
            onLimpar: _limpar,
            tokens: _t,
            estilo: _teclas,
          ),
        ),
      ),
      RodapeEstudio(
        child: Row(children: [
          BotaoEstudio(
            chave: 'pular',
            rotulo: 'Pular',
            tipo: TipoBotao.contorno,
            onTap: _obrigatorio ? null : _pularCpf,
          ),
          SizedBox(width: 20 * k),
          Expanded(
            child: BotaoEstudio(
              chave: 'continuar-cpf',
              rotulo: 'Continuar',
              iconeDepois: Icons.arrow_forward_rounded,
              onTap: _podeContinuar ? _continuarCpf : null,
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _etapaNome(BuildContext context) {
    final k = context.k;
    return Column(children: [
      Expanded(
        child: CorpoEstudio(
          inicio: [
            const Align(alignment: Alignment.centerLeft, child: _IconeForm(icone: Icons.person_outline_rounded)),
            SizedBox(height: 26 * k),
            const TituloTela('Como podemos te chamar?'),
            SizedBox(height: 26 * k),
            const Subtitulo('Seu nome aparece no painel e é chamado quando o pedido ficar pronto.'),
            SizedBox(height: 26 * k),
            _CampoNome(controller: p.nomeController, mov: p.mov),
          ],
          fim: TecladoNome(
            controller: p.nomeController,
            tokens: _t,
            alturaTecla: 116,
            espaco: 10,
            estilo: _teclas,
          ),
        ),
      ),
      RodapeEstudio(
        child: SizedBox(
          width: double.infinity,
          child: BotaoEstudio(
            chave: 'continuar-pagamento',
            rotulo: 'Continuar para pagamento',
            iconeDepois: Icons.arrow_forward_rounded,
            onTap: _finalizar,
          ),
        ),
      ),
    ]);
  }
}

/// Ícone da etapa num círculo `surface2` de 124.
class _IconeForm extends StatelessWidget {
  const _IconeForm({required this.icone});
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(124);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(color: _t.surface2, shape: BoxShape.circle),
      child: Icon(icone, size: context.dz(64), color: _t.accent),
    );
  }
}

class _MensagemCpf extends StatelessWidget {
  const _MensagemCpf({required this.completo, required this.valido});
  final bool completo;
  final bool valido;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    if (!completo) {
      return Text('Ex.: 529.982.247-25',
          textAlign: TextAlign.center,
          style: _t.texto(26 * k, peso: FontWeight.w400, cor: _t.muted));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (valido) ...[
        Icon(Icons.check_rounded, size: 30 * k, color: _t.ok),
        SizedBox(width: 10 * k),
      ],
      Flexible(
        child: Text(valido ? 'CPF válido' : 'CPF inválido, confira os números',
            key: const ValueKey('cpf-mensagem'),
            textAlign: TextAlign.center,
            style: _t.texto(26 * k, peso: FontWeight.w800, cor: valido ? _t.ok : _t.err)),
      ),
    ]);
  }
}

/// Campo do nome: o que foi digitado em caixa alta (ou o placeholder), o cursor no acento
/// piscando e o contador "0/12". Só mostra — quem escreve é o `TecladoNome` no
/// `nomeController` do fluxo; nada de teclado do sistema.
class _CampoNome extends StatefulWidget {
  const _CampoNome({required this.controller, required this.mov});
  final TextEditingController controller;
  final Movimento mov;

  @override
  State<_CampoNome> createState() => _CampoNomeState();
}

class _CampoNomeState extends State<_CampoNome> with SingleTickerProviderStateMixin {
  late final AnimationController _pisca;

  @override
  void initState() {
    super.initState();
    _pisca = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    if (widget.mov.anima) _pisca.repeat();
  }

  @override
  void dispose() {
    _pisca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        final texto = v.text;
        return Container(
          key: const ValueKey('nome-campo'),
          height: 160 * k,
          padding: EdgeInsets.symmetric(horizontal: 44 * k),
          decoration: BoxDecoration(
            color: _t.surface,
            borderRadius: BorderRadius.circular(_t.raio * k),
            border: Border.all(color: _t.line, width: 3 * k),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    texto.isEmpty ? 'Digite seu nome' : texto.toUpperCase(),
                    key: const ValueKey('nome-texto'),
                    style: texto.isEmpty
                        ? _t.texto(52 * k, peso: FontWeight.w600, cor: _t.muted.withAlpha(153))
                        : _t.texto(74 * k, peso: FontWeight.w700, espaco: 74 * .05 * k),
                  ),
                  SizedBox(width: 6 * k),
                  AnimatedBuilder(
                    animation: _pisca,
                    builder: (_, __) => Opacity(
                      opacity: !widget.mov.anima || _pisca.value < .5 ? 1 : 0,
                      child: Container(
                        width: 6 * k,
                        height: 88 * k,
                        decoration: BoxDecoration(color: _t.accent, borderRadius: BorderRadius.circular(3 * k)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Positioned(
              right: -14 * k,
              bottom: 16 * k,
              child: Text('${texto.length}/12',
                  key: const ValueKey('nome-contador'),
                  style: _t.texto(22 * k, peso: FontWeight.w600, cor: _t.muted)),
            ),
          ]),
        );
      },
    );
  }
}
