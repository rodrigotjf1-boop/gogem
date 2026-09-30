import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Peça também do Vitrine (docs/templates/02 §6.5 e 00 §4.5): o cartão central do
/// protótipo (`surface2`, raio 50, título em Syne 800) com até 3 sugestões. O item
/// adicionado mostra ✓ e o botão troca de "Seguir sem sugestão" para "Continuar".
///
/// A tela tira da lista o que entrou na sacola; a View guarda os cartões que mostrou
/// para o ✓ continuar visível.
class VitrinePecaTambemView extends StatefulWidget {
  const VitrinePecaTambemView({super.key, required this.p});
  final PecaTambemProps p;

  @override
  State<VitrinePecaTambemView> createState() => _VitrinePecaTambemViewState();
}

class _VitrinePecaTambemViewState extends State<VitrinePecaTambemView> {
  final _mostrados = <Produto>[];
  final _adicionados = <String>{};

  void _lembrar(List<Produto> sugeridos) {
    for (final s in sugeridos) {
      if (_mostrados.length >= 3) break;
      if (!_mostrados.any((m) => m.id == s.id)) _mostrados.add(s);
    }
  }

  @override
  void initState() {
    super.initState();
    _lembrar(widget.p.sugeridos);
  }

  @override
  void didUpdateWidget(covariant VitrinePecaTambemView old) {
    super.didUpdateWidget(old);
    _lembrar(widget.p.sugeridos);
  }

  void _adicionar(Produto s) {
    if (_adicionados.contains(s.id)) return;
    setState(() => _adicionados.add(s.id));
    widget.p.onAdicionar(s);
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final p = widget.p;
    final mov = p.mov;
    final algum = _adicionados.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: EntradaVitrine(
        mov: mov,
        child: SafeArea(
          child: Column(children: [
            TopoVitrine(etapa: 1, onVoltar: p.onVoltar, mov: mov),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: context.dz(64), vertical: context.dz(30)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (c.maxHeight - context.dz(60)).clamp(0.0, double.infinity)),
                    child: Center(
                      child: Container(
                        key: const ValueKey('peca-tambem-cartao'),
                        padding: EdgeInsets.fromLTRB(context.dz(50), context.dz(56), context.dz(50), context.dz(50)),
                        decoration: BoxDecoration(
                          color: t.surface2,
                          borderRadius: BorderRadius.circular(context.dz(t.raio + 10)),
                          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 30))],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('Que tal turbinar o pedido?',
                              textAlign: TextAlign.center,
                              style: context.vDisplay(68, altura: 1.02, espacoEm: -.03)),
                          SizedBox(height: context.dz(20)),
                          Text('Toque para adicionar. Dá pra tirar depois.',
                              textAlign: TextAlign.center,
                              style: context.vTexto(30, peso: FontWeight.w400, cor: t.muted, altura: 1.4)),
                          SizedBox(height: context.dz(30)),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) SizedBox(width: context.dz(18)),
                              Expanded(
                                child: i < _mostrados.length
                                    ? _Sugestao(
                                        key: ValueKey('sugestao-${_mostrados[i].id}'),
                                        produto: _mostrados[i],
                                        adicionado: _adicionados.contains(_mostrados[i].id),
                                        mov: mov,
                                        onTap: () => _adicionar(_mostrados[i]),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ]),
                          SizedBox(height: context.dz(30)),
                          SizedBox(
                            width: double.infinity,
                            child: BotaoVitrine(
                              key: const ValueKey('peca-tambem-continuar'),
                              rotulo: algum ? 'Continuar' : 'Seguir sem sugestão',
                              iconeFim: Icons.arrow_forward_rounded,
                              mov: mov,
                              onTap: p.onContinuar,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Cartão de sugestão (`.upd`): foto, nome, preço e o "+" — que vira ✓ quando entra.
class _Sugestao extends StatelessWidget {
  const _Sugestao({
    super.key,
    required this.produto,
    required this.adicionado,
    required this.mov,
    required this.onTap,
  });
  final Produto produto;
  final bool adicionado;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final d = context.dz(62);
    return Semantics(
      button: true,
      selected: adicionado,
      label: 'Adicionar ${produto.nome}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: mov.anima ? mov.d(250) : Duration.zero,
          padding: EdgeInsets.fromLTRB(context.dz(14), context.dz(14), context.dz(14), context.dz(20)),
          decoration: BoxDecoration(
            color: adicionado ? t.hi : t.surface,
            borderRadius: BorderRadius.circular(context.dz(t.raio - 6)),
            border: Border.all(color: adicionado ? t.accent : t.line, width: context.dz(3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: context.dz(210),
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                ProdutoArte(url: produto.imagemUrl, tokens: t, raio: context.dz(t.raio - 14), escalaRecorte: .88),
                Positioned(
                  top: context.dz(10),
                  right: context.dz(10),
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                    child: Icon(adicionado ? Icons.check_rounded : Icons.add_rounded,
                        key: ValueKey(adicionado ? 'sugestao-ok-${produto.id}' : 'sugestao-mais-${produto.id}'),
                        size: d * .55,
                        color: t.onAccent),
                  ),
                ),
              ]),
            ),
            SizedBox(height: context.dz(10)),
            Text(produto.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.vTexto(26, peso: FontWeight.w800, altura: 1.15)),
            SizedBox(height: context.dz(6)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatCentavos(produto.precoCentavos),
                  style: context.vTexto(26, peso: FontWeight.w800, cor: t.price)),
            ),
          ]),
        ),
      ),
    );
  }
}
