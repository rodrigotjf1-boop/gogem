import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../escala.dart';
import '../movimento.dart';
import '../template_tokens.dart';

/// Máscara `000.000.000-00` do que já foi digitado: a parte com dígitos e a que falta
/// (mostrada apagada). Ex.: "123" → ("123", ".___.___-__").
(String, String) mascaraCpf(String digitos) {
  const molde = '___.___.___-__';
  final d = digitos.replaceAll(RegExp(r'\D'), '');
  final out = StringBuffer();
  var i = 0;
  var pos = 0;
  for (; pos < molde.length && i < d.length; pos++) {
    if (molde[pos] == '_') {
      out.write(d[i++]);
    } else {
      out.write(molde[pos]);
    }
  }
  return (out.toString(), molde.substring(pos));
}

/// Campo do CPF: dígitos em [tokens.text], o que falta em `muted` a 45%. Borda verde com
/// CPF válido; vermelha, com uma tremida de 400 ms, quando os 11 dígitos não fecham.
class CampoCpf extends StatefulWidget {
  const CampoCpf({
    super.key,
    required this.cpf,
    required this.completo,
    required this.valido,
    required this.tokens,
    this.mov = Movimento.parado,
    this.altura = 160,
    this.fonte = 74,
    this.fundo,
  });

  final String cpf;
  final bool completo;
  final bool valido;
  final TemplateTokens tokens;
  final Movimento mov;

  /// Altura e tamanho da fonte em px de desenho.
  final double altura;
  final double fonte;
  final Color? fundo;

  @override
  State<CampoCpf> createState() => _CampoCpfState();
}

class _CampoCpfState extends State<CampoCpf> with SingleTickerProviderStateMixin {
  late final AnimationController _tremida;

  @override
  void initState() {
    super.initState();
    _tremida = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void didUpdateWidget(covariant CampoCpf old) {
    super.didUpdateWidget(old);
    final ficouInvalido = widget.completo && !widget.valido && old.cpf != widget.cpf;
    if (ficouInvalido && widget.mov.anima) _tremida.forward(from: 0);
  }

  @override
  void dispose() {
    _tremida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final (feito, falta) = mascaraCpf(widget.cpf);
    final borda = widget.completo ? (widget.valido ? t.ok : t.err) : t.line;
    final fs = context.dz(widget.fonte);
    return AnimatedBuilder(
      animation: _tremida,
      builder: (_, child) => Transform.translate(
        offset: Offset(math.sin(_tremida.value * math.pi * 6) * context.dz(14) * (1 - _tremida.value), 0),
        child: child,
      ),
      child: Container(
        key: const ValueKey('cpf-campo'),
        height: context.dz(widget.altura),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.fundo ?? t.surface,
          borderRadius: BorderRadius.circular(context.dz(t.raio)),
          border: Border.all(color: borda, width: context.dz(3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            key: const ValueKey('cpf-display'),
            TextSpan(children: [
              TextSpan(text: feito, style: t.texto(fs, peso: FontWeight.w800)),
              TextSpan(text: falta, style: t.texto(fs, peso: FontWeight.w800, cor: t.muted.withAlpha(115))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Teclado numérico 3×4: 1–9, Limpar, 0, Apagar (docs/templates/00 §3.5).
class TecladoCpf extends StatelessWidget {
  const TecladoCpf({
    super.key,
    required this.onDigito,
    required this.onApagar,
    required this.onLimpar,
    required this.tokens,
    this.alturaTecla = 134,
    this.espaco = 18,
    this.estilo,
  });

  final void Function(String) onDigito;
  final VoidCallback onApagar;
  final VoidCallback onLimpar;
  final TemplateTokens tokens;
  final double alturaTecla;
  final double espaco;

  /// Visual da tecla (padrão: [TeclaEstilo.de]).
  final TeclaEstilo? estilo;

  @override
  Widget build(BuildContext context) {
    final e = estilo ?? TeclaEstilo.de(tokens);
    Widget linha(List<Widget> teclas) => Row(children: [
          for (var i = 0; i < teclas.length; i++) ...[
            if (i > 0) SizedBox(width: context.dz(espaco)),
            Expanded(child: teclas[i]),
          ],
        ]);
    Tecla num(String d) => Tecla(
          key: ValueKey('cpf-tecla-$d'),
          altura: alturaTecla,
          estilo: e,
          tokens: tokens,
          onTap: () => onDigito(d),
          child: Text(d, style: tokens.texto(context.dz(44), peso: FontWeight.w800, cor: e.tinta)),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      linha([num('1'), num('2'), num('3')]),
      SizedBox(height: context.dz(espaco)),
      linha([num('4'), num('5'), num('6')]),
      SizedBox(height: context.dz(espaco)),
      linha([num('7'), num('8'), num('9')]),
      SizedBox(height: context.dz(espaco)),
      linha([
        Tecla(
          key: const ValueKey('cpf-limpar'),
          altura: alturaTecla,
          estilo: e.secundaria,
          tokens: tokens,
          onTap: onLimpar,
          child: Text('Limpar',
              style: tokens.texto(context.dz(28), peso: FontWeight.w800, cor: e.secundaria.tinta)),
        ),
        num('0'),
        Tecla(
          key: const ValueKey('cpf-apagar'),
          altura: alturaTecla,
          estilo: e.secundaria,
          tokens: tokens,
          onTap: onApagar,
          child: Icon(Icons.backspace_outlined, size: context.dz(40), color: e.secundaria.tinta),
        ),
      ]),
    ]);
  }
}

/// Aplica uma tecla ao nome: letras, "espaço" e "apagar". No máximo [maximo] caracteres,
/// sem espaço no começo nem dois seguidos.
String aplicarTeclaNome(String atual, String tecla, {int maximo = 12}) {
  if (tecla == 'apagar') return atual.isEmpty ? atual : atual.substring(0, atual.length - 1);
  if (tecla == 'espaco') {
    if (atual.isEmpty || atual.endsWith(' ') || atual.length >= maximo) return atual;
    return '$atual ';
  }
  if (atual.length >= maximo) return atual;
  return atual + tecla;
}

/// Teclado QWERTY com Ç, apagar e espaço, escrevendo no `nomeController` (o do fluxo).
/// O campo do nome fica `readOnly` — o teclado do sistema não abre.
class TecladoNome extends StatelessWidget {
  const TecladoNome({
    super.key,
    required this.controller,
    required this.tokens,
    this.maximo = 12,
    this.alturaTecla = 96,
    this.espaco = 10,
    this.estilo,
  });

  final TextEditingController controller;
  final TemplateTokens tokens;
  final int maximo;
  final double alturaTecla;
  final double espaco;
  final TeclaEstilo? estilo;

  static const linhas = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ç'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  void _tecla(String t) {
    final novo = aplicarTeclaNome(controller.text, t, maximo: maximo);
    if (novo == controller.text) return;
    controller.value = TextEditingValue(
      text: novo,
      selection: TextSelection.collapsed(offset: novo.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = estilo ?? TeclaEstilo.de(tokens);
    final fs = context.dz(34);
    Widget linha(List<Widget> teclas, {double recuo = 0}) => Padding(
          padding: EdgeInsets.symmetric(horizontal: context.dz(recuo)),
          child: Row(children: [
            for (var i = 0; i < teclas.length; i++) ...[
              if (i > 0) SizedBox(width: context.dz(espaco)),
              Expanded(child: teclas[i]),
            ],
          ]),
        );
    Tecla letra(String l) => Tecla(
          key: ValueKey('nome-tecla-$l'),
          altura: alturaTecla,
          estilo: e,
          tokens: tokens,
          onTap: () => _tecla(l),
          child: Text(l, style: tokens.texto(fs, peso: FontWeight.w700, cor: e.tinta)),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      linha([for (final l in linhas[0]) letra(l)]),
      SizedBox(height: context.dz(espaco)),
      linha([for (final l in linhas[1]) letra(l)]),
      SizedBox(height: context.dz(espaco)),
      linha([
        for (final l in linhas[2]) letra(l),
        Tecla(
          key: const ValueKey('nome-apagar'),
          altura: alturaTecla,
          estilo: e.secundaria,
          tokens: tokens,
          onTap: () => _tecla('apagar'),
          child: Icon(Icons.backspace_outlined, size: fs, color: e.secundaria.tinta),
        ),
      ], recuo: 0),
      SizedBox(height: context.dz(espaco)),
      linha([
        Tecla(
          key: const ValueKey('nome-espaco'),
          altura: alturaTecla,
          estilo: e,
          tokens: tokens,
          onTap: () => _tecla('espaco'),
          child: Text('espaço', style: tokens.texto(context.dz(26), peso: FontWeight.w700, cor: e.muted)),
        ),
      ], recuo: 220),
    ]);
  }
}

/// Visual de uma tecla: fundo, borda, sombra inferior ("degrau") e tinta.
class TeclaEstilo {
  const TeclaEstilo({
    required this.fundo,
    required this.tinta,
    required this.muted,
    required this.sombra,
    required this.raio,
    this.borda,
    this.secundariaOverride,
  });

  factory TeclaEstilo.de(TemplateTokens t) => TeclaEstilo(
        fundo: t.surface,
        tinta: t.text,
        muted: t.muted,
        sombra: t.line,
        raio: t.raioTecla,
      );

  final Color fundo;
  final Color tinta;
  final Color muted;
  final Color sombra;
  final double raio;
  final Color? borda;
  final TeclaEstilo? secundariaOverride;

  /// Estilo das teclas de ação (Limpar, Apagar).
  TeclaEstilo get secundaria => secundariaOverride ?? this;
}

/// Tecla que "afunda" 4 px de desenho ao toque, sobre a sombra inferior do estilo.
class Tecla extends StatefulWidget {
  const Tecla({
    super.key,
    required this.altura,
    required this.estilo,
    required this.tokens,
    required this.onTap,
    required this.child,
  });

  final double altura;
  final TeclaEstilo estilo;
  final TemplateTokens tokens;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<Tecla> createState() => _TeclaState();
}

class _TeclaState extends State<Tecla> {
  bool _baixo = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.estilo;
    final degrau = context.dz(5);
    final raio = BorderRadius.circular(context.dz(e.raio));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _baixo = true),
      onTapCancel: () => setState(() => _baixo = false),
      onTapUp: (_) => setState(() => _baixo = false),
      onTap: widget.onTap,
      child: SizedBox(
        height: context.dz(widget.altura),
        child: Stack(children: [
          Positioned.fill(
            top: degrau,
            child: DecoratedBox(decoration: BoxDecoration(color: e.sombra, borderRadius: raio)),
          ),
          Positioned.fill(
            bottom: _baixo ? 0 : degrau,
            top: _baixo ? context.dz(4) : 0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: e.fundo,
                borderRadius: raio,
                border: e.borda == null ? null : Border.all(color: e.borda!, width: context.dz(2)),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
            ),
          ),
        ]),
      ),
    );
  }
}
