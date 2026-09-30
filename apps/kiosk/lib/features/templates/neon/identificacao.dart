import 'package:flutter/material.dart';
import '../comum/teclados.dart' show CampoCpf;
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';
import 'teclados_neon.dart';

const _t = neonTokens;

/// Identificação do Neon 2.0 (docs/templates/04-neon-2.md §6.6 e 00 §4.6). Uma View, duas
/// etapas internas:
/// 1. **CPF na nota?** — "Opcional", teclado numérico, Pular e Continuar (este só com CPF
///    vazio ou válido). Com CPF obrigatório: sem "Opcional", aviso em destaque, Pular
///    desabilitado. Sair daqui NÃO chama `onPular`/`onConfirmar`: guarda a escolha.
/// 2. **Como podemos te chamar?** — nome no `nomeController` (teclado próprio, 12 letras).
///    Continuar chama `onConfirmar` (com CPF) ou `onPular` (sem CPF). Voltar volta à 1.
class NeonIdentificacaoView extends StatefulWidget {
  const NeonIdentificacaoView({super.key, required this.p});
  final IdentificacaoProps p;

  @override
  State<NeonIdentificacaoView> createState() => _NeonIdentificacaoViewState();
}

class _NeonIdentificacaoViewState extends State<NeonIdentificacaoView> {
  int _etapa = 1;
  bool _comCpf = false;

  bool get _obrigatorio => widget.p.avisoCpfObrigatorio != null;

  /// Continuar da etapa 1: CPF válido, ou vazio quando ele é opcional.
  bool get _podeContinuar {
    final p = widget.p;
    if (p.completo && p.valido) return true;
    return p.cpf.isEmpty && !_obrigatorio;
  }

  void _continuarCpf() => setState(() {
        _comCpf = widget.p.cpf.isNotEmpty;
        _etapa = 2;
      });

  void _pularCpf() => setState(() {
        _comCpf = false;
        _etapa = 2;
      });

  void _limpar() {
    for (var i = widget.p.cpf.length; i > 0; i--) {
      widget.p.onApagar();
    }
  }

  void _concluir() => _comCpf ? widget.p.onConfirmar() : widget.p.onPular();

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Scaffold(
      backgroundColor: _t.bg,
      body: SafeArea(
        child: NeonEntrada(
          mov: p.mov,
          child: Column(children: [
            NeonTopo(
              mov: p.mov,
              etapa: 2,
              onVoltar: _etapa == 1 ? p.onVoltar : () => setState(() => _etapa = 1),
            ),
            Expanded(
              child: CustomScrollView(slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                    child: _etapa == 1 ? _etapaCpf(context) : _etapaNome(context),
                  ),
                ),
              ]),
            ),
            _Rodape(
              children: _etapa == 1
                  ? [
                      SizedBox(
                        width: context.dz(260),
                        child: NeonBotao(
                          key: const ValueKey('pular'),
                          rotulo: 'Pular',
                          tipo: NeonBotaoTipo.fantasma,
                          fonte: 30,
                          onTap: _obrigatorio ? null : _pularCpf,
                        ),
                      ),
                      SizedBox(width: context.dz(20)),
                      Expanded(
                        child: NeonBotao(
                          key: const ValueKey('cpf-continuar'),
                          rotulo: 'Continuar',
                          iconeFim: Icons.arrow_forward_rounded,
                          fonte: 30,
                          onTap: _podeContinuar ? _continuarCpf : null,
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: NeonBotao(
                          key: const ValueKey('nome-continuar'),
                          rotulo: 'Continuar',
                          iconeFim: Icons.arrow_forward_rounded,
                          fonte: 30,
                          onTap: _concluir,
                        ),
                      ),
                    ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _etapaCpf(BuildContext context) {
    final p = widget.p;
    final valido = p.completo && p.valido;
    final aviso = p.avisoCpfObrigatorio;
    return Column(
      key: const ValueKey('etapa-cpf'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const _Icone(Icons.badge_outlined),
          if (aviso == null) ...[
            SizedBox(width: context.dz(20)),
            Container(
              key: const ValueKey('pilula-opcional'),
              height: context.dz(52),
              padding: EdgeInsets.symmetric(horizontal: context.dz(22)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _t.surface2,
                borderRadius: BorderRadius.circular(context.dz(26)),
              ),
              child: Text('Opcional', style: neonTexto(context.dz(24), peso: FontWeight.w700)),
            ),
          ],
        ]),
        SizedBox(height: context.dz(26)),
        Text(_t.caixa('CPF na nota?'), style: neonDisplay(context.dz(66))),
        SizedBox(height: context.dz(20)),
        if (aviso == null)
          Text('Opcional. Informe se quiser a nota fiscal no seu nome.',
              style: neonTexto(context.dz(32), cor: _t.muted, altura: 1.4))
        else
          Container(
            key: const ValueKey('aviso-cpf-obrigatorio'),
            padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(22)),
            decoration: BoxDecoration(
              color: const Color(0x1FFF3EA5),
              borderRadius: BorderRadius.circular(context.dz(20)),
              border: Border.all(color: _t.accent2, width: context.dz(3)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: context.dz(44), color: _t.accent2),
              SizedBox(width: context.dz(18)),
              Expanded(
                child: Text(aviso, style: neonTexto(context.dz(30), peso: FontWeight.w700, altura: 1.3)),
              ),
            ]),
          ),
        SizedBox(height: context.dz(26)),
        CampoCpf(
          cpf: p.cpf,
          completo: p.completo,
          valido: p.valido,
          tokens: valido ? neonComTexto(_t.accent) : _t,
          mov: p.mov,
        ),
        SizedBox(height: context.dz(18)),
        Center(
          child: Row(
            key: const ValueKey('cpf-msg'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.completo && p.valido) ...[
                Icon(Icons.check_rounded, size: context.dz(30), color: _t.ok),
                SizedBox(width: context.dz(8)),
              ],
              Flexible(
                child: Text(
                  !p.completo ? 'Ex.: 529.982.247-25' : (p.valido ? 'CPF válido' : 'CPF inválido, confira os números'),
                  style: neonTexto(context.dz(26),
                      peso: p.completo ? FontWeight.w700 : FontWeight.w400,
                      cor: !p.completo ? _t.muted : (p.valido ? _t.ok : _t.err)),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(height: context.dz(30)),
        TecladoCpfNeon(onDigito: p.onDigito, onApagar: p.onApagar, onLimpar: _limpar),
      ],
    );
  }

  Widget _etapaNome(BuildContext context) {
    final p = widget.p;
    return Column(
      key: const ValueKey('etapa-nome'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [_Icone(Icons.person_outline_rounded)]),
        SizedBox(height: context.dz(26)),
        Text(_t.caixa('Como podemos te chamar?'), style: neonDisplay(context.dz(66), altura: 1.02)),
        SizedBox(height: context.dz(20)),
        Text('Seu nome aparece no painel e é chamado quando o pedido ficar pronto.',
            style: neonTexto(context.dz(32), cor: _t.muted, altura: 1.4)),
        SizedBox(height: context.dz(26)),
        _CampoNome(controller: p.nomeController, mov: p.mov),
        const Spacer(),
        SizedBox(height: context.dz(30)),
        TecladoNomeNeon(controller: p.nomeController),
      ],
    );
  }
}

class _Icone extends StatelessWidget {
  const _Icone(this.icone);
  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
        width: context.dz(124),
        height: context.dz(124),
        decoration: BoxDecoration(color: _t.surface2, shape: BoxShape.circle),
        child: Icon(icone, size: context.dz(64), color: _t.accent),
      );
}

/// Campo do nome (`.field.name`): o que foi digitado em CAIXA ALTA, o cursor `accent`
/// piscando (só com loops) e o contador n/12. Não é um `TextField`: o teclado do sistema
/// nunca abre — quem escreve no `nomeController` é o teclado da tela.
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
    if (widget.mov.loops) _pisca.repeat();
  }

  @override
  void dispose() {
    _pisca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        final nome = v.text;
        return Container(
          key: const ValueKey('nome-campo'),
          height: context.dz(160),
          padding: EdgeInsets.symmetric(horizontal: context.dz(44)),
          decoration: BoxDecoration(
            color: _t.surface,
            borderRadius: BorderRadius.circular(context.dz(_t.raio)),
            border: Border.all(color: _t.line, width: context.dz(3)),
          ),
          child: Stack(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nome.isEmpty ? 'Digite seu nome' : nome.toUpperCase(),
                      key: const ValueKey('nome-texto'),
                      maxLines: 1,
                      style: nome.isEmpty
                          ? neonTexto(context.dz(52), peso: FontWeight.w600, cor: const Color(0x99A4A4BC))
                          : neonTexto(context.dz(66), peso: FontWeight.w700, espaco: .05),
                    ),
                  ),
                ),
                SizedBox(width: context.dz(6)),
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _pisca,
                    builder: (_, __) => Opacity(
                      opacity: _pisca.value < .5 ? 1 : 0,
                      child: Container(
                        width: context.dz(6),
                        height: context.dz(88),
                        decoration: BoxDecoration(
                          color: _t.accent,
                          borderRadius: BorderRadius.circular(context.dz(3)),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Positioned(
              right: 0,
              bottom: context.dz(14),
              child: Text('${nome.length}/12',
                  key: const ValueKey('nome-contador'),
                  style: neonTexto(context.dz(22), peso: FontWeight.w600, cor: _t.muted)),
            ),
          ]),
        );
      },
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(44)),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
        child: Row(children: children),
      );
}
