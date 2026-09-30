import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart' show menuProvider;
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Título e rótulo de "pular" da peça-também: "Uma sobremesa pra fechar?" quando todas as
/// sugestões vêm de UMA categoria de doces; categorias mistas (ou outra), "Que tal
/// completar?" (docs/templates/01 §6.5).
({String titulo, String pular}) textosPecaTambem(List<Produto> sugeridos, List<Categoria> categorias) {
  final ids = {for (final p in sugeridos) p.categoriaId};
  if (ids.length == 1) {
    final nome = categorias
        .where((c) => c.id == ids.first)
        .map((c) => c.nome.toLowerCase())
        .firstOrNull;
    if (nome != null && (nome.contains('sobremesa') || nome.contains('doce'))) {
      return (titulo: 'Uma sobremesa pra fechar?', pular: 'Seguir sem sobremesa');
    }
  }
  return (titulo: 'Que tal completar?', pular: 'Seguir sem sugestão');
}

/// Peça também do **Brasa 2.0** (docs/templates/01 §6.5): cartão central sobre véu com até
/// 3 sugestões; o item adicionado mostra ✓ e o botão vira "Continuar". VIEW PURA: adicionar
/// e seguir são do `PecaTambemScreen`.
class Brasa2PecaTambem extends StatefulWidget {
  const Brasa2PecaTambem(this.p, {super.key});
  final PecaTambemProps p;

  @override
  State<Brasa2PecaTambem> createState() => _Brasa2PecaTambemState();
}

class _Brasa2PecaTambemState extends State<Brasa2PecaTambem> {
  /// As sugestões de quando o cartão abriu: o produto adicionado sai da lista da tela
  /// (já está na sacola), mas aqui continua, com o ✓.
  late List<Produto> _vitrine = widget.p.sugeridos.take(3).toList();
  final _adicionados = <String>{};

  @override
  void didUpdateWidget(covariant Brasa2PecaTambem old) {
    super.didUpdateWidget(old);
    if (_vitrine.isEmpty) _vitrine = widget.p.sugeridos.take(3).toList();
  }

  void _adicionar(Produto p) {
    if (_adicionados.contains(p.id)) return;
    setState(() => _adicionados.add(p.id));
    widget.p.onAdicionar(p);
  }

  @override
  Widget build(BuildContext context) {
    final temEscopo = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    return Brasa2Tela(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: brasa2Veu),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.dz(64), vertical: context.dz(40)),
            child: Brasa2Entrada(
              mov: widget.p.mov,
              duracaoMs: 500,
              escalaInicial: .9,
              curva: brasa2CurvaPop,
              // O título depende da categoria das sugestões: vem do cardápio quando há escopo.
              child: temEscopo
                  ? Consumer(
                      builder: (context, ref, _) =>
                          _cartao(context, ref.watch(menuProvider).valueOrNull?.categorias ?? const []),
                    )
                  : _cartao(context, const []),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cartao(BuildContext context, List<Categoria> categorias) {
    final textos = textosPecaTambem(_vitrine, categorias);
    final algum = _adicionados.isNotEmpty;
    return Container(
      key: const ValueKey('peca-tambem'),
      padding: EdgeInsets.fromLTRB(context.dz(50), context.dz(56), context.dz(50), context.dz(50)),
      decoration: BoxDecoration(
        color: brasa2FundoModal,
        borderRadius: BorderRadius.circular(context.dz(_t.raio + 10)),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 60, offset: Offset(0, 30))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(textos.titulo,
            key: const ValueKey('peca-tambem-titulo'),
            textAlign: TextAlign.center,
            style: brasaTitulo(context, 68, altura: 1.02)),
        SizedBox(height: context.dz(26)),
        Text('Toque para adicionar. Dá pra tirar depois.',
            textAlign: TextAlign.center, style: brasaTexto(context, 30, cor: _t.muted, altura: 1.4)),
        SizedBox(height: context.dz(26)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: context.dz(18)),
            Expanded(child: i < _vitrine.length ? _sugestao(context, _vitrine[i]) : const SizedBox.shrink()),
          ],
        ]),
        SizedBox(height: context.dz(26)),
        Brasa2Botao(
          key: const ValueKey('peca-tambem-continuar'),
          rotulo: algum ? 'Continuar' : textos.pular,
          iconeDepois: BrasaIcone.seta,
          mov: widget.p.mov,
          onTap: widget.p.onContinuar,
        ),
        SizedBox(height: context.dz(10)),
        Center(
          child: Semantics(
            button: true,
            child: GestureDetector(
              key: const ValueKey('peca-tambem-voltar'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.p.onVoltar,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.dz(24), vertical: context.dz(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconeBrasa(BrasaIcone.voltar, tamanho: context.dz(28), cor: _t.muted, traco: 2.6),
                  SizedBox(width: context.dz(8)),
                  Text('Voltar à sacola', style: brasaTexto(context, 26, peso: FontWeight.w700, cor: _t.muted)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sugestao(BuildContext context, Produto p) {
    final on = _adicionados.contains(p.id);
    return Semantics(
      button: true,
      selected: on,
      label: p.nome,
      child: GestureDetector(
        key: ValueKey('sugestao-${p.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _adicionar(p),
        child: AnimatedContainer(
          duration: widget.p.mov.anima ? widget.p.mov.d(250) : Duration.zero,
          padding: EdgeInsets.fromLTRB(context.dz(14), context.dz(14), context.dz(14), context.dz(20)),
          decoration: BoxDecoration(
            color: on ? _t.hi : _t.surface,
            borderRadius: BorderRadius.circular(context.dz(_t.raio - 6)),
            border: Border.all(color: on ? _t.accent : _t.line, width: context.dz(3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: context.dz(210),
              child: Stack(fit: StackFit.expand, children: [
                ProdutoArte(url: p.imagemUrl, tokens: _t, raio: _t.raio - 14, escalaRecorte: .88),
                Positioned(
                  top: context.dz(10),
                  right: context.dz(10),
                  child: Brasa2BotaoMais(tamanho: 62, adicionado: on, onTap: () => _adicionar(p)),
                ),
              ]),
            ),
            SizedBox(height: context.dz(8)),
            SizedBox(
              height: context.dz(60),
              child: Text(p.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: brasaTexto(context, 26, peso: FontWeight.w800, altura: 1.15)),
            ),
            SizedBox(height: context.dz(8)),
            Text(formatCentavos(p.precoCentavos),
                maxLines: 1, style: brasaTexto(context, 26, peso: FontWeight.w800, cor: _t.price)),
          ]),
        ),
      ),
    );
  }
}
