import 'package:flutter/material.dart';
import '../comum/teclados.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Teclas do Brasa: fundo `surface`, degrau `line`; Limpar/Apagar em `surface2`.
final _tecla = TeclaEstilo(
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

/// Identificação do **Brasa 2.0** (docs/templates/01 §6.6, 00 §4.6) em duas etapas
/// internas: (1) CPF na nota? e (2) Como podemos te chamar?. Sair da etapa 1 só guarda a
/// escolha; quem segue é "Continuar para pagamento", que chama `onConfirmar` (com CPF) ou
/// `onPular` (sem). O nome é escrito direto no `nomeController` do fluxo.
class Brasa2Identificacao extends StatefulWidget {
  const Brasa2Identificacao(this.p, {super.key});
  final IdentificacaoProps p;

  @override
  State<Brasa2Identificacao> createState() => _Brasa2IdentificacaoState();
}

class _Brasa2IdentificacaoState extends State<Brasa2Identificacao> {
  int _etapa = 1;
  bool _comCpf = false;

  IdentificacaoProps get p => widget.p;
  Movimento get mov => p.mov;
  bool get _obrigatorio => p.avisoCpfObrigatorio != null;

  /// Continuar da etapa 1: CPF vazio (opcional) ou completo e válido; obrigatório, só válido.
  bool get _podeContinuar => (p.completo && p.valido) || (p.cpf.isEmpty && !_obrigatorio);

  void _limpar() {
    for (var i = 0; i < p.cpf.length; i++) {
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
    return Brasa2Tela(
      child: Column(children: [
        Brasa2Topo(
          onVoltar: _etapa == 1 ? p.onVoltar : () => setState(() => _etapa = 1),
          etapa: 2,
          mov: mov,
        ),
        Expanded(
          child: Brasa2Entrada(
            key: ValueKey('etapa-$_etapa'),
            mov: mov,
            child: _etapa == 1 ? _cpf(context) : _nome(context),
          ),
        ),
      ]),
    );
  }

  // ---- etapa 1: CPF na nota? ----
  Widget _cpf(BuildContext context) {
    final aviso = p.avisoCpfObrigatorio;
    final String dica;
    final Color corDica;
    if (p.completo) {
      dica = p.valido ? 'CPF válido' : 'CPF inválido, confira os números';
      corDica = p.valido ? _t.ok : _t.err;
    } else {
      dica = 'Ex.: 529.982.247-25';
      corDica = _t.muted;
    }
    return Column(children: [
      Expanded(
        child: Brasa2CorpoRolavel(children: [
          Row(children: [
            const Brasa2IconeRedondo(BrasaIcone.documento),
            if (aviso == null) ...[
              SizedBox(width: context.dz(20)),
              Container(
                key: const ValueKey('cpf-opcional'),
                height: context.dz(52),
                padding: EdgeInsets.symmetric(horizontal: context.dz(22)),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(context.dz(26))),
                child: Text('Opcional', style: brasaTexto(context, 24, peso: FontWeight.w700)),
              ),
            ],
          ]),
          Text('CPF na nota?', style: brasaTitulo(context, 92)),
          if (aviso == null)
            Text('Opcional. Informe se quiser a nota fiscal no seu nome.',
                style: brasaTexto(context, 32, cor: _t.muted, altura: 1.4))
          else
            Container(
              key: const ValueKey('aviso-cpf-obrigatorio'),
              padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(20)),
              decoration: BoxDecoration(
                color: _t.hi,
                borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
                border: Border.all(color: _t.accent, width: context.dz(3)),
              ),
              child: Text(aviso, style: brasaTexto(context, 30, peso: FontWeight.w800, cor: _t.accent, altura: 1.35)),
            ),
          CampoCpf(cpf: p.cpf, completo: p.completo, valido: p.valido, tokens: _t, mov: mov),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (p.completo && p.valido) ...[
              IconeBrasa(BrasaIcone.check, tamanho: context.dz(30), cor: _t.ok, traco: 3),
              SizedBox(width: context.dz(10)),
            ],
            Flexible(
              child: Text(dica,
                  key: const ValueKey('cpf-dica'),
                  textAlign: TextAlign.center,
                  style: brasaTexto(context, 26, peso: p.completo ? FontWeight.w800 : FontWeight.w600, cor: corDica)),
            ),
          ]),
          const Spacer(),
          TecladoCpf(
            onDigito: p.onDigito,
            onApagar: p.onApagar,
            onLimpar: _limpar,
            tokens: _t,
            estilo: _tecla,
          ),
        ]),
      ),
      Brasa2Rodape(children: [
        Row(children: [
          Brasa2Botao(
            key: const ValueKey('pular'),
            rotulo: 'Pular',
            variante: Brasa2Variante.fantasma,
            mov: mov,
            onTap: _obrigatorio ? null : () => _irParaNome(comCpf: false),
          ),
          SizedBox(width: context.dz(20)),
          Expanded(
            child: Brasa2Botao(
              key: const ValueKey('cpf-continuar'),
              rotulo: 'Continuar',
              iconeDepois: BrasaIcone.seta,
              mov: mov,
              onTap: _podeContinuar ? () => _irParaNome(comCpf: p.cpf.isNotEmpty) : null,
            ),
          ),
        ]),
      ]),
    ]);
  }

  // ---- etapa 2: Como podemos te chamar? ----
  Widget _nome(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Brasa2CorpoRolavel(children: [
          const Row(children: [Brasa2IconeRedondo(BrasaIcone.usuario)]),
          // Quebra equilibrada como no desenho (`text-wrap: balance`).
          Text('Como podemos\nte chamar?', style: brasaTitulo(context, 92)),
          Text('Seu nome aparece no painel e é chamado quando o pedido ficar pronto.',
              style: brasaTexto(context, 32, cor: _t.muted, altura: 1.4)),
          _CampoNome(controller: p.nomeController, mov: mov),
          const Spacer(),
          TecladoNome(
            controller: p.nomeController,
            tokens: _t,
            alturaTecla: 116,
            espaco: 12,
            estilo: _tecla,
          ),
        ]),
      ),
      Brasa2Rodape(children: [
        Brasa2Botao(
          key: const ValueKey('nome-continuar'),
          rotulo: 'Continuar para pagamento',
          iconeDepois: BrasaIcone.seta,
          mov: mov,
          largura: double.infinity,
          onTap: _finalizar,
        ),
      ]),
    ]);
  }
}

/// Campo do nome: altura 160, texto em CAIXA ALTA, "Digite seu nome" apagado, cursor no
/// acento (pisca só com animação) e o contador 0/12. Só leitura: quem escreve é o teclado.
class _CampoNome extends StatefulWidget {
  const _CampoNome({required this.controller, required this.mov});
  final TextEditingController controller;
  final Movimento mov;

  @override
  State<_CampoNome> createState() => _CampoNomeState();
}

class _CampoNomeState extends State<_CampoNome> with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    if (widget.mov.anima) _cursor.repeat();
  }

  @override
  void dispose() {
    _cursor.dispose();
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
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        final nome = v.text;
        return Container(
          key: const ValueKey('nome-cliente'),
          height: context.dz(160),
          padding: EdgeInsets.symmetric(horizontal: context.dz(44)),
          decoration: BoxDecoration(
            color: _t.surface,
            borderRadius: BorderRadius.circular(context.dz(_t.raio)),
            border: Border.all(color: _t.line, width: context.dz(3)),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    nome.isEmpty ? 'Digite seu nome' : nome.toUpperCase(),
                    key: const ValueKey('nome-texto'),
                    style: nome.isEmpty
                        ? brasaTexto(context, 52, cor: _t.muted.withAlpha(153))
                        : brasaTexto(context, 74, peso: FontWeight.w700, espacoEm: .05),
                  ),
                  if (widget.mov.anima)
                    FadeTransition(
                      opacity: _cursor.drive(TweenSequence([
                        TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
                        TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
                      ])),
                      child: cursor,
                    )
                  else
                    cursor,
                ]),
              ),
            ),
            Positioned(
              right: context.dz(-14),
              bottom: context.dz(16),
              child: Text('${nome.length}/12',
                  key: const ValueKey('nome-contador'),
                  style: brasaTexto(context, 22, cor: _t.muted)),
            ),
          ]),
        );
      },
    );
  }
}
