import 'package:flutter/material.dart';
import '../comum/teclados.dart' show aplicarTeclaNome;
import '../escala.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Tecla do Neon (docs/templates/04-neon-2.md §6.6): borda 2 `line`, SEM sombra, raio 14;
/// ao tocar, a borda acende em `accent`. Variante local: a `Tecla` comum tem o "degrau"
/// de sombra e não troca a borda no toque.
class TeclaNeon extends StatefulWidget {
  const TeclaNeon({
    super.key,
    required this.altura,
    required this.onTap,
    required this.child,
    this.funcao = false,
    this.raio = 14,
  });

  /// Altura em px de desenho.
  final double altura;
  final VoidCallback onTap;
  final Widget child;

  /// Tecla de ação (Limpar, Apagar): fundo `surface2`.
  final bool funcao;
  final double raio;

  @override
  State<TeclaNeon> createState() => _TeclaNeonState();
}

class _TeclaNeonState extends State<TeclaNeon> {
  bool _baixo = false;

  void _set(bool v) {
    if (_baixo != v) setState(() => _baixo = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: Container(
        height: context.dz(widget.altura),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.funcao ? _t.surface2 : _t.surface,
          borderRadius: BorderRadius.circular(context.dz(widget.raio)),
          border: Border.all(color: _baixo ? _t.accent : _t.line, width: context.dz(2)),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
      ),
    );
  }
}

/// Teclado numérico 3×4 do CPF (1–9, Limpar, 0, Apagar) com as mesmas chaves de teste do
/// `TecladoCpf` comum (`cpf-tecla-N`, `cpf-limpar`, `cpf-apagar`).
class TecladoCpfNeon extends StatelessWidget {
  const TecladoCpfNeon({super.key, required this.onDigito, required this.onApagar, required this.onLimpar});
  final void Function(String) onDigito;
  final VoidCallback onApagar;
  final VoidCallback onLimpar;

  static const _alto = 134.0;
  static const _vao = 18.0;

  @override
  Widget build(BuildContext context) {
    Widget linha(List<Widget> teclas) => Row(children: [
          for (var i = 0; i < teclas.length; i++) ...[
            if (i > 0) SizedBox(width: context.dz(_vao)),
            Expanded(child: teclas[i]),
          ],
        ]);
    Widget num(String d) => TeclaNeon(
          key: ValueKey('cpf-tecla-$d'),
          altura: _alto,
          onTap: () => onDigito(d),
          child: Text(d, style: neonTexto(context.dz(52), peso: FontWeight.w400)),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      linha([num('1'), num('2'), num('3')]),
      SizedBox(height: context.dz(_vao)),
      linha([num('4'), num('5'), num('6')]),
      SizedBox(height: context.dz(_vao)),
      linha([num('7'), num('8'), num('9')]),
      SizedBox(height: context.dz(_vao)),
      linha([
        TeclaNeon(
          key: const ValueKey('cpf-limpar'),
          altura: _alto,
          funcao: true,
          onTap: onLimpar,
          child: Text('Limpar', style: neonTexto(context.dz(30), peso: FontWeight.w400)),
        ),
        num('0'),
        TeclaNeon(
          key: const ValueKey('cpf-apagar'),
          altura: _alto,
          funcao: true,
          onTap: onApagar,
          child: Icon(Icons.backspace_outlined, size: context.dz(46), color: _t.text),
        ),
      ]),
    ]);
  }
}

/// Teclado QWERTY com Ç, apagar e espaço (prototipo `.kb-keys`), escrevendo no
/// `nomeController` do fluxo pela mesma regra do comum (`aplicarTeclaNome`: 12 letras,
/// sem dois espaços). Mesmas chaves de teste do `TecladoNome` comum.
class TecladoNomeNeon extends StatelessWidget {
  const TecladoNomeNeon({super.key, required this.controller, this.maximo = 12, this.largura = 968});
  final TextEditingController controller;
  final int maximo;

  /// Largura útil em px de desenho (a coluna do corpo).
  final double largura;

  static const _linhas = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ç'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  void _tecla(String t) {
    final novo = aplicarTeclaNome(controller.text, t, maximo: maximo);
    if (novo == controller.text) return;
    controller.value = TextEditingValue(text: novo, selection: TextSelection.collapsed(offset: novo.length));
  }

  @override
  Widget build(BuildContext context) {
    const vao = 8.0;
    // 10 teclas por linha, com vãos de 8 — a largura de uma tecla em px de desenho.
    final k = (largura - 9 * vao) / 10;
    Widget tecla(String rotulo,
            {required Key key, required VoidCallback onTap, double unidades = 1, Widget? filho, bool funcao = false}) =>
        SizedBox(
          width: context.dz(k * unidades + vao * (unidades - 1)),
          child: TeclaNeon(
            key: key,
            altura: 116,
            raio: 8,
            funcao: funcao,
            onTap: onTap,
            child: filho ?? Text(rotulo, style: neonTexto(context.dz(44))),
          ),
        );
    Widget linha(List<Widget> teclas) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < teclas.length; i++) ...[
            if (i > 0) SizedBox(width: context.dz(vao)),
            teclas[i],
          ],
        ]);
    Widget letra(String l) => tecla(l, key: ValueKey('nome-tecla-$l'), onTap: () => _tecla(l));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      linha([for (final l in _linhas[0]) letra(l)]),
      SizedBox(height: context.dz(12)),
      linha([for (final l in _linhas[1]) letra(l)]),
      SizedBox(height: context.dz(12)),
      linha([
        for (final l in _linhas[2]) letra(l),
        tecla('',
            key: const ValueKey('nome-apagar'),
            unidades: 2,
            funcao: true,
            onTap: () => _tecla('apagar'),
            filho: Icon(Icons.backspace_outlined, size: context.dz(42), color: _t.text)),
      ]),
      SizedBox(height: context.dz(12)),
      linha([
        tecla('espaço',
            key: const ValueKey('nome-espaco'),
            unidades: 6,
            onTap: () => _tecla('espaco'),
            filho: Text('espaço', style: neonTexto(context.dz(30), cor: _t.muted))),
      ]),
    ]);
  }
}
