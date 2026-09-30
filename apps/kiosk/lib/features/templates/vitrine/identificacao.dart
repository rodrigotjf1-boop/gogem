import 'package:flutter/material.dart';
import '../comum/teclados.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Identificação do Vitrine (docs/templates/02 §6.6 e 00 §4.6), em DUAS etapas internas:
/// 1. "CPF na nota?" — Pular / Continuar (só com CPF vazio ou válido). Sair daqui NÃO
///    chama `onPular` nem `onConfirmar`: a escolha fica guardada.
/// 2. "Como podemos te chamar?" — o nome vai no `nomeController` do fluxo; "Continuar"
///    chama `onConfirmar` (com CPF) ou `onPular` (sem CPF).
/// Com `avisoCpfObrigatorio`, o "Opcional" some, o aviso aparece e "Pular" desliga.
class VitrineIdentificacaoView extends StatefulWidget {
  const VitrineIdentificacaoView({super.key, required this.p});
  final IdentificacaoProps p;

  @override
  State<VitrineIdentificacaoView> createState() => _VitrineIdentificacaoViewState();
}

class _VitrineIdentificacaoViewState extends State<VitrineIdentificacaoView> {
  int _etapa = 0;

  /// Escolha da etapa 1: seguir SEM CPF (Pular, ou Continuar com o campo vazio).
  bool _semCpf = true;

  IdentificacaoProps get p => widget.p;

  bool get _podePular => p.avisoCpfObrigatorio == null;

  /// Continuar da etapa 1: CPF válido, ou vazio quando o CPF não é obrigatório.
  bool get _podeContinuarCpf => p.cpf.isEmpty ? _podePular : (p.completo && p.valido);

  void _irParaNome({required bool semCpf}) => setState(() {
        _semCpf = semCpf;
        _etapa = 1;
      });

  void _limpar() {
    for (var i = p.cpf.length; i > 0; i--) {
      p.onApagar();
    }
  }

  void _concluir() {
    // O nome já está no controller do fluxo; a tela o grava ao seguir.
    if (_semCpf || p.cpf.isEmpty) {
      p.onPular();
    } else {
      p.onConfirmar();
    }
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final mov = p.mov;
    final cpfEtapa = _etapa == 0;
    return Scaffold(
      backgroundColor: t.bg,
      body: EntradaVitrine(
        mov: mov,
        child: SafeArea(
          child: Column(children: [
            TopoVitrine(
              etapa: 2,
              mov: mov,
              onVoltar: cpfEtapa ? p.onVoltar : () => setState(() => _etapa = 0),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: mov.anima ? mov.d(300) : Duration.zero,
                child: KeyedSubtree(
                  key: ValueKey('identificacao-etapa-$_etapa'),
                  child: cpfEtapa ? _EtapaCpf(p: p, onLimpar: _limpar) : _EtapaNome(p: p),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: context.dz(2)))),
              child: cpfEtapa
                  ? Row(children: [
                      BotaoVitrine(
                        key: const ValueKey('pular'),
                        rotulo: 'Pular',
                        estilo: EstiloBotaoVitrine.fantasma,
                        mov: mov,
                        onTap: _podePular ? () => _irParaNome(semCpf: true) : null,
                      ),
                      SizedBox(width: context.dz(20)),
                      Expanded(
                        child: BotaoVitrine(
                          key: const ValueKey('cpf-continuar'),
                          rotulo: 'Continuar',
                          iconeFim: Icons.arrow_forward_rounded,
                          mov: mov,
                          onTap: _podeContinuarCpf ? () => _irParaNome(semCpf: p.cpf.isEmpty) : null,
                        ),
                      ),
                    ])
                  : SizedBox(
                      width: double.infinity,
                      child: BotaoVitrine(
                        key: const ValueKey('nome-continuar'),
                        rotulo: 'Continuar',
                        iconeFim: Icons.arrow_forward_rounded,
                        mov: mov,
                        onTap: _concluir,
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Círculo `surface2` de 124 com o ícone da etapa em `accent`.
class _IconeEtapa extends StatelessWidget {
  const _IconeEtapa({required this.icone});
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      width: context.dz(124),
      height: context.dz(124),
      decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
      child: Icon(icone, size: context.dz(64), color: t.accent),
    );
  }
}

class _EtapaCpf extends StatelessWidget {
  const _EtapaCpf({required this.p, required this.onLimpar});
  final IdentificacaoProps p;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final aviso = p.avisoCpfObrigatorio;
    final (String msg, Color corMsg) = !p.completo
        ? ('Ex.: 529.982.247-25', t.muted)
        : p.valido
            ? ('CPF válido', t.ok)
            : ('CPF inválido, confira os números', t.err);
    return ColunaQueRola(
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
      children: [
        Row(children: [
          const _IconeEtapa(icone: Icons.badge_outlined),
          if (aviso == null) ...[
            SizedBox(width: context.dz(20)),
            Container(
              key: const ValueKey('cpf-opcional'),
              height: context.dz(52),
              padding: EdgeInsets.symmetric(horizontal: context.dz(22)),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(context.dz(26))),
              child: Text('Opcional', style: context.vTexto(24, peso: FontWeight.w800, altura: 1)),
            ),
          ],
        ]),
        SizedBox(height: context.dz(26)),
        Text('CPF na nota?', style: context.vDisplay(84, altura: 1)),
        SizedBox(height: context.dz(26)),
        if (aviso == null)
          Text('Opcional. Informe se quiser a nota fiscal no seu nome.',
              style: context.vTexto(32, peso: FontWeight.w400, cor: t.muted, altura: 1.4))
        else
          AvisoVitrine(
            key: const ValueKey('aviso-cpf-obrigatorio'),
            icone: Icons.info_outline_rounded,
            child: Text(aviso, style: context.vTexto(28, peso: FontWeight.w800, cor: t.text, altura: 1.35)),
          ),
        SizedBox(height: context.dz(26)),
        CampoCpf(cpf: p.cpf, completo: p.completo, valido: p.valido, tokens: t, mov: p.mov),
        SizedBox(height: context.dz(18)),
        Text(msg,
            key: const ValueKey('cpf-mensagem'),
            textAlign: TextAlign.center,
            style: context.vTexto(26, peso: p.completo ? FontWeight.w800 : FontWeight.w400, cor: corMsg)),
        SizedBox(height: context.dz(26)),
        const Spacer(),
        TecladoCpf(
          onDigito: p.onDigito,
          onApagar: p.onApagar,
          onLimpar: onLimpar,
          tokens: t,
          estilo: _estiloTecla,
        ),
      ],
    );
  }
}

/// Teclas do template (§6.6): raio 28, fundo `surface`, sombra inferior `line`; as de ação
/// (Limpar, Apagar) em `surface2`.
final _estiloTecla = TeclaEstilo(
  fundo: vitrineTokens.surface,
  tinta: vitrineTokens.text,
  muted: vitrineTokens.muted,
  sombra: vitrineTokens.line,
  raio: vitrineTokens.raioTecla,
  secundariaOverride: TeclaEstilo(
    fundo: vitrineTokens.surface2,
    tinta: vitrineTokens.text,
    muted: vitrineTokens.muted,
    sombra: vitrineTokens.line,
    raio: vitrineTokens.raioTecla,
  ),
);

class _EtapaNome extends StatelessWidget {
  const _EtapaNome({required this.p});
  final IdentificacaoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return ColunaQueRola(
      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
      children: [
        const Align(alignment: Alignment.centerLeft, child: _IconeEtapa(icone: Icons.person_outline_rounded)),
        SizedBox(height: context.dz(26)),
        Text('Como podemos te chamar?', style: context.vDisplay(84, altura: 1)),
        SizedBox(height: context.dz(26)),
        Text('Seu nome aparece no painel e é chamado quando o pedido ficar pronto.',
            style: context.vTexto(32, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
        SizedBox(height: context.dz(26)),
        _CampoNome(controller: p.nomeController, mov: p.mov),
        SizedBox(height: context.dz(26)),
        const Spacer(),
        TecladoNome(controller: p.nomeController, tokens: t, alturaTecla: 116, espaco: 10, estilo: _estiloTecla),
      ],
    );
  }
}

/// Campo do nome: só mostra (o teclado do sistema nunca abre — quem escreve é o
/// `TecladoNome`). Placeholder "Digite seu nome", cursor `accent` e contador n/12.
class _CampoNome extends StatelessWidget {
  const _CampoNome({required this.controller, required this.mov});
  final TextEditingController controller;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final nome = v.text;
        return Container(
          key: const ValueKey('nome-cliente'),
          height: context.dz(160),
          padding: EdgeInsets.symmetric(horizontal: context.dz(44)),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(context.dz(t.raio)),
            border: Border.all(color: t.line, width: context.dz(3)),
          ),
          child: Stack(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  nome.isEmpty
                      ? Text('Digite seu nome',
                          style: context.vTexto(52, cor: const Color(0x73FFFFFF), altura: 1))
                      : Text(nome.toUpperCase(),
                          key: const ValueKey('nome-texto'),
                          style: context.vTexto(74, peso: FontWeight.w800, altura: 1, espacoEm: .05)),
                  SizedBox(width: context.dz(6)),
                  _Cursor(mov: mov),
                ]),
              ),
            ),
            Positioned(
              right: 0,
              bottom: context.dz(14),
              child: Text('${nome.length}/12',
                  key: const ValueKey('nome-contador'),
                  style: context.vTexto(22, cor: t.muted)),
            ),
          ]),
        );
      },
    );
  }
}

/// Cursor `accent` (6 × 88) que pisca — só com animação; parado, fica aceso.
class _Cursor extends StatefulWidget {
  const _Cursor({required this.mov});
  final Movimento mov;

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    if (widget.mov.anima) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barra = Container(
      width: context.dz(6),
      height: context.dz(88),
      decoration: BoxDecoration(
        color: vitrineTokens.accent,
        borderRadius: BorderRadius.circular(context.dz(3)),
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        // `steps(2)` do protótipo: meio segundo aceso, meio apagado.
        builder: (_, child) => Opacity(opacity: _c.value < .5 ? 1 : 0, child: child),
        child: barra,
      ),
    );
  }
}
