import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../comum/catalogo_dados.dart';
import '../comum/teclados.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';

const _t = dinerTokens;

/// Teclas de "máquina antiga" (docs/templates/05 §6.6): fundo branco, borda e sombra dura
/// marrons; a tecla desce 4 px ao toque. As de função ficam em `surface2`.
final _tecla = TeclaEstilo(
  fundo: _t.surface,
  tinta: _t.text,
  muted: _t.muted,
  sombra: _t.text,
  raio: _t.raioTecla,
  borda: _t.text,
  secundariaOverride: TeclaEstilo(
    fundo: _t.surface2,
    tinta: _t.text,
    muted: _t.muted,
    sombra: _t.text,
    raio: _t.raioTecla,
    borda: _t.text,
  ),
);

final _teclaNome = TeclaEstilo(
  fundo: _t.surface,
  tinta: _t.text,
  muted: _t.muted,
  sombra: _t.text,
  raio: _t.raioTecla - 6,
  borda: _t.text,
  secundariaOverride: TeclaEstilo(
    fundo: _t.surface2,
    tinta: _t.text,
    muted: _t.muted,
    sombra: _t.text,
    raio: _t.raioTecla - 6,
    borda: _t.text,
  ),
);

/// Identificação do **Diner 58** em DUAS etapas internas (docs/templates/00 §4.6):
/// 1. "CPF na nota?" — teclado numérico; Pular e Continuar só guardam a escolha;
/// 2. "Como podemos te chamar?" — teclado de letras no `nomeController` do fluxo;
///    Continuar chama `onConfirmar` (com CPF) ou `onPular` (sem CPF).
/// Com o CPF obrigatório (limite da UF), "Pular" fica desabilitado e o CPF vazio não passa.
class DinerIdentificacao extends ConsumerStatefulWidget {
  const DinerIdentificacao({super.key, required this.p});
  final IdentificacaoProps p;

  @override
  ConsumerState<DinerIdentificacao> createState() => _DinerIdentificacaoState();
}

class _DinerIdentificacaoState extends ConsumerState<DinerIdentificacao> {
  /// 1 = CPF, 2 = nome.
  int _etapa = 1;

  /// Escolha da etapa 1: seguir COM o CPF digitado.
  bool _comCpf = false;

  IdentificacaoProps get p => widget.p;
  bool get _obrigatorio => p.avisoCpfObrigatorio != null;

  /// Continuar da etapa 1: CPF vazio (se não for obrigatório) ou completo e válido.
  bool get _podeContinuar => (p.cpf.isEmpty && !_obrigatorio) || (p.completo && p.valido);

  void _limpar() {
    for (var i = p.cpf.length; i > 0; i--) {
      p.onApagar();
    }
  }

  void _irParaNome({required bool comCpf}) => setState(() {
        _comCpf = comCpf;
        _etapa = 2;
      });

  void _finalizar() => _comCpf ? p.onConfirmar() : p.onPular();

  @override
  Widget build(BuildContext context) {
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final mov = p.mov;
    final etapa1 = _etapa == 1;
    return DinerTema(
      child: Scaffold(
        backgroundColor: _t.bg,
        body: SafeArea(
          child: DinerEntrada(
            mov: mov,
            child: Column(children: [
              DinerTopo(
                etapa: 2,
                mov: mov,
                nomeLoja: ap.nomeLoja,
                logoUrl: ap.logoUrl,
                onVoltar: etapa1 ? p.onVoltar : () => setState(() => _etapa = 1),
                onCancelar: () => AcoesPedido(ref).cancelarPedido(context),
              ),
              Expanded(
                child: CustomScrollView(slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                      child: etapa1 ? _cpf(context, mov) : _nome(context, mov),
                    ),
                  ),
                ]),
              ),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
                padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
                child: etapa1
                    ? Row(children: [
                        DinerBotao(
                          key: const ValueKey('pular'),
                          rotulo: 'Pular',
                          estilo: DinerEstilo.contorno,
                          onTap: _obrigatorio ? null : () => _irParaNome(comCpf: false),
                        ),
                        SizedBox(width: context.dz(20)),
                        Expanded(
                          child: DinerBotao(
                            key: const ValueKey('cpf-continuar'),
                            rotulo: 'Continuar',
                            iconeDepois: Icons.arrow_forward_rounded,
                            expandir: true,
                            onTap: _podeContinuar ? () => _irParaNome(comCpf: p.cpf.isNotEmpty) : null,
                          ),
                        ),
                      ])
                    : SizedBox(
                        width: double.infinity,
                        child: DinerBotao(
                          key: const ValueKey('nome-continuar'),
                          rotulo: 'Continuar',
                          iconeDepois: Icons.arrow_forward_rounded,
                          expandir: true,
                          onTap: _finalizar,
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _icone(BuildContext context, IconData icone) => Container(
        width: context.dz(124),
        height: context.dz(124),
        decoration: BoxDecoration(color: _t.surface2, shape: BoxShape.circle),
        child: Icon(icone, size: context.dz(64), color: _t.accent),
      );

  Widget _cpf(BuildContext context, Movimento mov) {
    final aviso = p.avisoCpfObrigatorio;
    final msg = p.completo ? (p.valido ? 'CPF válido' : 'CPF inválido, confira os números') : 'Ex.: 529.982.247-25';
    final corMsg = p.completo ? (p.valido ? _t.ok : _t.err) : _t.muted;
    return Column(key: const ValueKey('identificacao-cpf'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _icone(context, Icons.badge_outlined),
        if (aviso == null) ...[
          SizedBox(width: context.dz(20)),
          Container(
            height: context.dz(52),
            padding: EdgeInsets.symmetric(horizontal: context.dz(22)),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(26))),
            child: Text('Opcional', style: _t.texto(context.dz(24), peso: FontWeight.w900)),
          ),
        ],
      ]),
      SizedBox(height: context.dz(26)),
      Text('CPF na nota?', style: _t.display(context.dz(62), altura: 1.05)),
      SizedBox(height: context.dz(18)),
      if (aviso == null)
        Text('Opcional. Informe se quiser a nota fiscal no seu nome.',
            style: _t.texto(context.dz(32), cor: _t.muted, altura: 1.4))
      else
        Container(
          key: const ValueKey('aviso-cpf-obrigatorio'),
          padding: EdgeInsets.symmetric(horizontal: context.dz(26), vertical: context.dz(20)),
          decoration: BoxDecoration(
            color: _t.hi,
            borderRadius: BorderRadius.circular(context.dz(24)),
            border: Border.all(color: _t.accent, width: context.dz(3)),
          ),
          child: Row(children: [
            Icon(Icons.error_outline_rounded, size: context.dz(40), color: _t.accent),
            SizedBox(width: context.dz(16)),
            Expanded(
              child: Text(aviso, style: _t.texto(context.dz(28), peso: FontWeight.w900, cor: _t.accent)),
            ),
          ]),
        ),
      SizedBox(height: context.dz(26)),
      CampoCpf(cpf: p.cpf, completo: p.completo, valido: p.valido, tokens: _t, mov: mov),
      SizedBox(height: context.dz(18)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (p.completo && p.valido) ...[
          Icon(Icons.check_rounded, size: context.dz(30), color: corMsg),
          SizedBox(width: context.dz(8)),
        ],
        Flexible(
          child: Text(msg,
              key: const ValueKey('cpf-mensagem'),
              textAlign: TextAlign.center,
              style: _t.texto(context.dz(26), peso: p.completo ? FontWeight.w900 : FontWeight.w600, cor: corMsg)),
        ),
      ]),
      const Spacer(),
      SizedBox(height: context.dz(26)),
      TecladoCpf(
        onDigito: p.onDigito,
        onApagar: p.onApagar,
        onLimpar: _limpar,
        tokens: _t,
        estilo: _tecla,
        alturaTecla: 134,
        espaco: 18,
      ),
    ]);
  }

  Widget _nome(BuildContext context, Movimento mov) {
    return Column(key: const ValueKey('identificacao-nome'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft, child: _icone(context, Icons.person_outline_rounded)),
      SizedBox(height: context.dz(26)),
      Text('Como podemos te chamar?', style: _t.display(context.dz(62), altura: 1.05)),
      SizedBox(height: context.dz(18)),
      Text('Seu nome aparece no painel e é chamado quando o pedido ficar pronto.',
          style: _t.texto(context.dz(32), cor: _t.muted, altura: 1.4)),
      SizedBox(height: context.dz(26)),
      _CampoNome(controller: p.nomeController, mov: mov),
      const Spacer(),
      SizedBox(height: context.dz(26)),
      TecladoNome(
        controller: p.nomeController,
        tokens: _t,
        estilo: _teclaNome,
        alturaTecla: 116,
        espaco: 10,
      ),
    ]);
  }
}

/// Campo do nome (só leitura — quem escreve é o teclado do template): caixa branca de
/// borda 3 `line`, texto em caixa alta, cursor vermelho piscando e o contador "n/12".
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
    final cursor = Container(
      width: context.dz(6),
      height: context.dz(88),
      margin: EdgeInsets.only(left: context.dz(6)),
      decoration: BoxDecoration(color: _t.accent, borderRadius: BorderRadius.circular(context.dz(3))),
    );
    return Container(
      key: const ValueKey('nome-cliente'),
      height: context.dz(160),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(context.dz(_t.raio)),
        border: Border.all(color: _t.line, width: context.dz(3)),
      ),
      child: Stack(children: [
        Padding(
            padding: EdgeInsets.symmetric(horizontal: context.dz(44)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (_, v, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: v.text.isEmpty
                          ? Text('Digite seu nome', style: _t.texto(context.dz(52), cor: _t.muted.withAlpha(150)))
                          : Text(v.text.toUpperCase(),
                              key: const ValueKey('nome-valor'),
                              style: _t
                                  .texto(context.dz(74), peso: FontWeight.w800)
                                  .copyWith(letterSpacing: context.dz(74) * .05)),
                    ),
                  ),
                  if (widget.mov.anima) FadeTransition(opacity: _Degrau(_pisca), child: cursor) else cursor,
                ]),
              ),
            )),
        Positioned(
          right: context.dz(30),
          bottom: context.dz(14),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (_, v, __) => Text('${v.text.length}/12',
                key: const ValueKey('nome-contador'),
                style: _t.texto(context.dz(22), peso: FontWeight.w800, cor: _t.muted)),
          ),
        ),
      ]),
    );
  }
}

/// Pisca em degrau (aceso na 1ª metade do ciclo, apagado na 2ª), como o `steps(2)` do CSS.
class _Degrau extends Animation<double> with AnimationWithParentMixin<double> {
  _Degrau(this.parent);
  @override
  final Animation<double> parent;
  @override
  double get value => parent.value < .5 ? 1 : 0;
}
