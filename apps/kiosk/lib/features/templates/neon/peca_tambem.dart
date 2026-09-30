import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../comum/produto_arte.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// "Peça também" do Neon 2.0 (docs/templates/04-neon-2.md §6.5 e 00 §4.5): o cartão
/// central do protótipo — fundo `0xFF0C0C14`, raio 34, título em Unbounded 52 CAIXA ALTA
/// e até 3 sugestões `surface` com o "+" num quadrado `accent`. O botão diz "Seguir sem
/// sugestão" até algo ser adicionado e "Continuar" depois.
///
/// O item adicionado sai de `sugeridos` (a tela recalcula o upsell sem ele), então a View
/// guarda a lista que mostrou e marca com ✓ o que o cliente já pôs na sacola.
class NeonPecaTambemView extends StatefulWidget {
  const NeonPecaTambemView({super.key, required this.p});
  final PecaTambemProps p;

  @override
  State<NeonPecaTambemView> createState() => _NeonPecaTambemViewState();
}

class _NeonPecaTambemViewState extends State<NeonPecaTambemView> {
  final _mostrados = <Produto>[];
  final _adicionados = <String>{};

  @override
  void initState() {
    super.initState();
    _juntar();
  }

  @override
  void didUpdateWidget(covariant NeonPecaTambemView old) {
    super.didUpdateWidget(old);
    _juntar();
  }

  /// Mantém a ordem do que já apareceu, tira o que sumiu sem ter sido adicionado aqui e
  /// completa com sugestões novas, até 3.
  void _juntar() {
    final ids = {for (final s in widget.p.sugeridos) s.id};
    _mostrados.removeWhere((m) => !ids.contains(m.id) && !_adicionados.contains(m.id));
    for (final s in widget.p.sugeridos) {
      if (_mostrados.length >= 3) break;
      if (!_mostrados.any((m) => m.id == s.id)) _mostrados.add(s);
    }
  }

  void _adicionar(Produto prod) {
    if (_adicionados.contains(prod.id)) return;
    setState(() => _adicionados.add(prod.id));
    widget.p.onAdicionar(prod);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final algum = _adicionados.isNotEmpty;
    return Scaffold(
      backgroundColor: _t.bg,
      body: SafeArea(
        child: NeonEntrada(
          mov: p.mov,
          child: Column(children: [
            NeonTopo(mov: p.mov, etapa: 1, onVoltar: p.onVoltar),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: context.dz(64), vertical: context.dz(24)),
                  child: Container(
                    key: const ValueKey('peca-tambem-cartao'),
                    padding: EdgeInsets.fromLTRB(context.dz(50), context.dz(56), context.dz(50), context.dz(50)),
                    decoration: BoxDecoration(
                      color: neonFolha,
                      borderRadius: BorderRadius.circular(context.dz(34)),
                      border: Border.all(color: _t.line, width: context.dz(2)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _t.caixa('Que tal turbinar o pedido?'),
                        textAlign: TextAlign.center,
                        style: neonDisplay(context.dz(52), espaco: -.03, altura: 1.05),
                      ),
                      SizedBox(height: context.dz(20)),
                      Text(
                        'Toque para adicionar. Dá pra tirar depois.',
                        textAlign: TextAlign.center,
                        style: neonTexto(context.dz(30), cor: _t.muted, altura: 1.4),
                      ),
                      SizedBox(height: context.dz(30)),
                      if (_mostrados.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: context.dz(20)),
                          child: Column(children: [
                            Container(
                              width: context.dz(110),
                              height: context.dz(110),
                              decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
                              child: Icon(Icons.check_rounded, size: context.dz(64), color: _t.onAccent),
                            ),
                            SizedBox(height: context.dz(18)),
                            Text('Tudo certo! Adicionado ao pedido.',
                                textAlign: TextAlign.center, style: neonTexto(context.dz(30), peso: FontWeight.w700)),
                          ]),
                        )
                      else
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) SizedBox(width: context.dz(18)),
                            Expanded(
                              child: i < _mostrados.length
                                  ? _Sugestao(
                                      produto: _mostrados[i],
                                      feito: _adicionados.contains(_mostrados[i].id),
                                      onTap: () => _adicionar(_mostrados[i]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ]),
                      SizedBox(height: context.dz(34)),
                      SizedBox(
                        width: double.infinity,
                        child: NeonBotao(
                          key: const ValueKey('peca-tambem-continuar'),
                          rotulo: algum || _mostrados.isEmpty ? 'Continuar' : 'Seguir sem sugestão',
                          iconeFim: Icons.arrow_forward_rounded,
                          fonte: 32,
                          onTap: p.onContinuar,
                        ),
                      ),
                    ]),
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

class _Sugestao extends StatelessWidget {
  const _Sugestao({required this.produto, required this.feito, required this.onTap});
  final Produto produto;
  final bool feito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    final raio = BorderRadius.circular(context.dz(18));
    return GestureDetector(
      key: ValueKey('sugestao-${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(context.dz(14), context.dz(14), context.dz(14), context.dz(20)),
        decoration: BoxDecoration(
          color: feito ? _t.hi : _t.surface,
          borderRadius: raio,
          border: Border.all(color: feito ? _t.accent : _t.line, width: context.dz(3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: context.dz(210),
            width: double.infinity,
            child: Stack(children: [
              Positioned.fill(child: ProdutoArte(url: p.imagemUrl, tokens: _t, raio: context.dz(10))),
              Positioned(
                top: context.dz(10),
                right: context.dz(10),
                child: NeonBotaoMais(
                  key: ValueKey('sugestao-add-${p.id}'),
                  tamanho: 62,
                  feito: feito,
                  onTap: onTap,
                ),
              ),
            ]),
          ),
          SizedBox(height: context.dz(10)),
          Text(p.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: neonTexto(context.dz(26), peso: FontWeight.w700, altura: 1.15)),
          SizedBox(height: context.dz(6)),
          Text(formatCentavos(p.precoCentavos), style: neonTexto(context.dz(26), peso: FontWeight.w700, cor: _t.price)),
        ]),
      ),
    );
  }
}
