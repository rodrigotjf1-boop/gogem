import 'package:flutter/material.dart';
import '../escala.dart';
import '../template_tokens.dart';

/// − n + com alvos de toque de pelo menos 72 px de desenho (docs/templates/00 §3.5).
class Quantidade extends StatelessWidget {
  const Quantidade({
    super.key,
    required this.n,
    required this.onMenos,
    required this.onMais,
    required this.tokens,
    this.tamanho = 72,
    this.corMais,
    this.corMenos,
    this.chave = 'qtd',
  });

  final int n;
  final VoidCallback onMenos;
  final VoidCallback onMais;
  final TemplateTokens tokens;

  /// Diâmetro do botão em px de desenho (mínimo 72).
  final double tamanho;
  final Color? corMais;
  final Color? corMenos;

  /// Prefixo das chaves de teste (`$chave-menos`, `$chave-valor`, `$chave-mais`).
  final String chave;

  @override
  Widget build(BuildContext context) {
    final d = context.dz(tamanho < 72 ? 72 : tamanho);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Botao(
        key: ValueKey('$chave-menos'),
        d: d,
        icone: Icons.remove_rounded,
        fundo: corMenos ?? tokens.surface2,
        tinta: tokens.text,
        borda: tokens.line2,
        onTap: onMenos,
      ),
      SizedBox(
        width: d * .9,
        child: Text('$n',
            key: ValueKey('$chave-valor'),
            textAlign: TextAlign.center,
            style: tokens.texto(d * .42, peso: FontWeight.w800)),
      ),
      _Botao(
        key: ValueKey('$chave-mais'),
        d: d,
        icone: Icons.add_rounded,
        fundo: corMais ?? tokens.accent,
        tinta: tokens.onAccent,
        onTap: onMais,
      ),
    ]);
  }
}

class _Botao extends StatelessWidget {
  const _Botao({
    super.key,
    required this.d,
    required this.icone,
    required this.fundo,
    required this.tinta,
    required this.onTap,
    this.borda,
  });
  final double d;
  final IconData icone;
  final Color fundo;
  final Color tinta;
  final Color? borda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fundo,
      shape: CircleBorder(side: borda == null ? BorderSide.none : BorderSide(color: borda!, width: 2)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: d, height: d, child: Icon(icone, color: tinta, size: d * .5)),
      ),
    );
  }
}
