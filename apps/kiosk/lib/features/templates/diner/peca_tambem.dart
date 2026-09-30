import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/sugestoes.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';

const _t = dinerTokens;

/// "Peça também" do **Diner 58** (docs/templates/05 §6.5 e 00 §4.5): cartão central creme
/// com borda marrom de 6 e sombra dura, título em Bungee, até 3 sugestões com foto, nome,
/// preço e "+", e o botão "Seguir sem…" que vira "Continuar" depois de adicionar.
/// A lista chega sem os itens que já entraram na sacola; a View guarda os que mostrou para
/// o adicionado ficar na tela com ✓.
class DinerPecaTambem extends ConsumerStatefulWidget {
  const DinerPecaTambem({super.key, required this.p});
  final PecaTambemProps p;

  @override
  ConsumerState<DinerPecaTambem> createState() => _DinerPecaTambemState();
}

class _DinerPecaTambemState extends ConsumerState<DinerPecaTambem> {
  final List<Produto> _mostrados = [];
  final Set<String> _adicionados = {};

  @override
  void initState() {
    super.initState();
    _acrescenta(widget.p.sugeridos);
  }

  @override
  void didUpdateWidget(covariant DinerPecaTambem old) {
    super.didUpdateWidget(old);
    _acrescenta(widget.p.sugeridos);
  }

  void _acrescenta(List<Produto> novos) {
    for (final s in novos) {
      if (_mostrados.length >= 3) break;
      if (_mostrados.every((m) => m.id != s.id)) _mostrados.add(s);
    }
  }

  void _adicionar(Produto p) {
    if (_adicionados.contains(p.id)) return;
    widget.p.onAdicionar(p);
    // Com etapa obrigatória a tela abre o produto; sem ela, já entrou na sacola.
    if (!temEtapaObrigatoria(p) && mounted) setState(() => _adicionados.add(p.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final snap = ref.watch(menuProvider).valueOrNull;
    final nomes = {for (final c in snap?.categorias ?? const <Categoria>[]) c.id: c.nome.toLowerCase()};
    final soSobremesa =
        _mostrados.isNotEmpty && _mostrados.every((m) => (nomes[m.categoriaId] ?? '').contains('sobremesa'));
    final titulo = soSobremesa ? 'Uma sobremesa pra fechar?' : 'Que tal completar?';
    final pular = soSobremesa ? 'Seguir sem sobremesa' : 'Seguir sem sugestão';
    final continuar = _adicionados.isNotEmpty;

    final cartao = Container(
      key: const ValueKey('peca-tambem-cartao'),
      padding: EdgeInsets.fromLTRB(context.dz(50), context.dz(56), context.dz(50), context.dz(50)),
      decoration: BoxDecoration(
        color: dinerModal,
        borderRadius: BorderRadius.circular(context.dz(40)),
        border: Border.all(color: _t.text, width: context.dz(6)),
        boxShadow: [sombraDura(context.dz(14))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(titulo, textAlign: TextAlign.center, style: _t.display(context.dz(50), altura: 1.1)),
        SizedBox(height: context.dz(20)),
        Text('Toque para adicionar. Dá pra tirar depois.',
            textAlign: TextAlign.center, style: _t.texto(context.dz(30), cor: _t.muted, altura: 1.4)),
        SizedBox(height: context.dz(26)),
        LayoutBuilder(builder: (context, c) {
          final vao = context.dz(18);
          final largura = (c.maxWidth - vao * 2) / 3;
          return Row(
            mainAxisAlignment: _mostrados.length < 3 ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _mostrados.length; i++) ...[
                if (i > 0) SizedBox(width: vao),
                SizedBox(
                  width: largura,
                  child: _Card(
                    produto: _mostrados[i],
                    feito: _adicionados.contains(_mostrados[i].id),
                    onTap: () => _adicionar(_mostrados[i]),
                  ),
                ),
              ],
            ],
          );
        }),
        SizedBox(height: context.dz(30)),
        SizedBox(
          width: double.infinity,
          child: DinerBotao(
            key: const ValueKey('peca-tambem-continuar'),
            rotulo: continuar ? 'Continuar' : pular,
            iconeDepois: Icons.arrow_forward_rounded,
            expandir: true,
            onTap: p.onContinuar,
          ),
        ),
      ]),
    );

    return DinerTema(
      child: Scaffold(
        backgroundColor: dinerVeu,
        body: SafeArea(
          child: Stack(children: [
            Positioned.fill(child: DinerVeu(onTap: p.onVoltar)),
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: context.dz(64), vertical: context.dz(40)),
                  child: _Pop(mov: p.mov, child: cartao),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Entrada do cartão: cresce de 0,9 com um leve "quique" (500 ms); reduzido, só fade.
class _Pop extends StatelessWidget {
  const _Pop({required this.mov, required this.child});
  final Movimento mov;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!mov.anima) return child;
    final cheio = mov.particulas;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mov.d(cheio ? 500 : 300),
      curve: cheio ? const Cubic(.2, 1.2, .4, 1) : Curves.easeOut,
      child: child,
      builder: (_, v, filho) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: cheio ? Transform.scale(scale: .9 + .1 * v, child: filho) : filho,
      ),
    );
  }
}

/// Sugestão: foto, nome, preço e o "+" vermelho no canto (✓ depois de adicionada).
class _Card extends StatelessWidget {
  const _Card({required this.produto, required this.feito, required this.onTap});
  final Produto produto;
  final bool feito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DinerToque(
      key: ValueKey('sugestao-${produto.id}'),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(context.dz(14), context.dz(14), context.dz(14), context.dz(20)),
        decoration: BoxDecoration(
          color: feito ? _t.hi : _t.surface,
          borderRadius: BorderRadius.circular(context.dz(24)),
          border: Border.all(color: feito ? _t.accent : _t.line, width: context.dz(3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            SizedBox(
              height: context.dz(210),
              width: double.infinity,
              child: DinerArte(url: produto.imagemUrl, raio: context.dz(16)),
            ),
            Positioned(
              top: context.dz(10),
              right: context.dz(10),
              child: Container(
                width: context.dz(62),
                height: context.dz(62),
                decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
                child: Icon(feito ? Icons.check_rounded : Icons.add_rounded, size: context.dz(34), color: _t.onAccent),
              ),
            ),
          ]),
          SizedBox(height: context.dz(10)),
          Text(produto.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _t.texto(context.dz(26), peso: FontWeight.w900, altura: 1.15)),
          SizedBox(height: context.dz(6)),
          Text(formatCentavos(produto.precoCentavos),
              style: _t.texto(context.dz(26), peso: FontWeight.w900, cor: _t.price)),
        ]),
      ),
    );
  }
}
