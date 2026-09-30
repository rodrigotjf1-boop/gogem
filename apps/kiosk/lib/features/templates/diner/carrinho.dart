import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../../../domain/order/cart.dart';
import '../../../domain/order/order_models.dart';
import '../../../domain/order/sugestoes.dart';
import '../comum/catalogo_dados.dart';
import '../comum/quantidade.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';

const _t = dinerTokens;

/// Sacola do **Diner 58** (docs/templates/05 §6.4 e 00 §4.4): título em Bungee, itens num
/// cartão branco, o seletor Comer aqui / Para levar, "Combina com seu pedido" em caixa
/// tracejada e o total em Bungee vermelho. Tela inteira (lê os providers como a GoGen); as
/// ações são as do `AcoesPedido` comum.
class DinerCarrinho extends ConsumerWidget {
  const DinerCarrinho({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final snap = ref.watch(menuProvider).valueOrNull;
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);
    final sugestoes = snap == null ? const <Produto>[] : sugestoesUpsell(cart.itens, snap).take(3).toList();
    final n = cart.totalItens;

    return DinerTema(
      child: Scaffold(
        backgroundColor: _t.bg,
        body: SafeArea(
          child: DinerEntrada(
            mov: mov,
            child: Column(children: [
              DinerTopo(
                etapa: 1,
                mov: mov,
                nomeLoja: ap.nomeLoja,
                logoUrl: ap.logoUrl,
                onVoltar: () => acoes.adicionarMais(context),
                onCancelar: () => acoes.cancelarPedido(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Text('Sua sacola', style: _t.display(context.dz(62), altura: 1.05))),
                      Text(n == 1 ? '1 item' : '$n itens',
                          key: const ValueKey('sacola-itens'), style: _t.texto(context.dz(30), cor: _t.muted)),
                    ]),
                    SizedBox(height: context.dz(26)),
                    if (cart.vazio)
                      _Vazia(onAdicionarMais: () => acoes.adicionarMais(context))
                    else ...[
                      _Lista(itens: cart.itens, mov: mov, acoes: acoes),
                      SizedBox(height: context.dz(26)),
                      _Consumo(consumo: consumo, onEscolher: acoes.setConsumo),
                      if (sugestoes.isNotEmpty) ...[
                        SizedBox(height: context.dz(26)),
                        _Combina(
                          sugestoes: sugestoes,
                          onAdicionar: (p) => acoes.adicionarOuAbrir(context, p),
                        ),
                      ],
                    ],
                  ]),
                ),
              ),
              if (!cart.vazio)
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
                  padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Total', style: _t.texto(context.dz(36), peso: FontWeight.w900)),
                      SizedBox(width: context.dz(20)),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(formatCentavos(cart.totalCentavos),
                                key: const ValueKey('total'),
                                style: _t.display(context.dz(60), cor: _t.accent, altura: 1.1)),
                          ),
                        ),
                      ),
                    ]),
                    SizedBox(height: context.dz(18)),
                    Row(children: [
                      DinerBotao(
                        key: const ValueKey('adicionar-mais'),
                        rotulo: 'Adicionar mais',
                        estilo: DinerEstilo.contorno,
                        onTap: () => acoes.adicionarMais(context),
                      ),
                      SizedBox(width: context.dz(20)),
                      Expanded(
                        child: DinerBotao(
                          key: const ValueKey('finalizar'),
                          rotulo: 'Finalizar pedido',
                          iconeDepois: Icons.arrow_forward_rounded,
                          expandir: true,
                          onTap: () => acoes.finalizar(context),
                        ),
                      ),
                    ]),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Vazia extends StatelessWidget {
  const _Vazia({required this.onAdicionarMais});
  final VoidCallback onAdicionarMais;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.dz(120)),
      child: Column(key: const ValueKey('sacola-vazia'), children: [
        Icon(Icons.shopping_bag_outlined, size: context.dz(90), color: _t.muted),
        SizedBox(height: context.dz(22)),
        Text('Sua sacola está vazia', style: _t.texto(context.dz(34), peso: FontWeight.w800, cor: _t.muted)),
        SizedBox(height: context.dz(22)),
        DinerBotao(rotulo: 'Adicionar mais', onTap: onAdicionarMais),
      ]),
    );
  }
}

/// Itens da sacola num cartão branco com sombra suave.
class _Lista extends StatelessWidget {
  const _Lista({required this.itens, required this.mov, required this.acoes});
  final List<ItemCarrinho> itens;
  final Movimento mov;
  final AcoesPedido acoes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(6)),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(context.dz(30)),
        boxShadow: [
          BoxShadow(color: const Color(0x0F2A1512), blurRadius: context.dz(30), offset: Offset(0, context.dz(12)))
        ],
      ),
      child: Column(children: [
        for (var i = 0; i < itens.length; i++)
          _LinhaSacola(
            key: ValueKey('linha-${itens[i].linhaId}'),
            item: itens[i],
            primeira: i == 0,
            mov: mov,
            acoes: acoes,
          ),
      ]),
    );
  }
}

/// Uma linha: foto, nome, complementos, total da linha, lixeira e quantidade. Ao remover,
/// desliza para a esquerda e some (320 ms).
class _LinhaSacola extends StatefulWidget {
  const _LinhaSacola({
    super.key,
    required this.item,
    required this.primeira,
    required this.mov,
    required this.acoes,
  });

  final ItemCarrinho item;
  final bool primeira;
  final Movimento mov;
  final AcoesPedido acoes;

  @override
  State<_LinhaSacola> createState() => _LinhaSacolaState();
}

class _LinhaSacolaState extends State<_LinhaSacola> {
  bool _saindo = false;

  void _remover() {
    if (_saindo) return;
    if (!widget.mov.anima) {
      widget.acoes.remover(widget.item.linhaId);
      return;
    }
    setState(() => _saindo = true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final linhas = [
      for (final o in item.todasOpcoes) o.precoCentavosDelta > 0 ? '+ ${o.nome}' : o.nome,
    ];
    final corpo = Container(
      padding: EdgeInsets.symmetric(vertical: context.dz(26)),
      decoration: BoxDecoration(
        border: widget.primeira ? null : Border(top: BorderSide(color: _t.line, width: context.dz(2))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: context.dz(150),
          height: context.dz(150),
          child: DinerArte(url: item.produto.imagemUrl, raio: context.dz(22)),
        ),
        SizedBox(width: context.dz(26)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(context.dz(36), peso: FontWeight.w900, altura: 1.15)),
              ),
              SizedBox(width: context.dz(16)),
              Text(formatCentavos(item.totalCentavos),
                  key: ValueKey('linha-total-${item.linhaId}'),
                  style: _t.texto(context.dz(34), peso: FontWeight.w900, altura: 1.2)),
            ]),
            for (final l in linhas)
              Text(l,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t.texto(context.dz(24), cor: _t.muted, altura: 1.4)),
            SizedBox(height: context.dz(12)),
            Row(children: [
              DinerToque(
                key: ValueKey('remover-${item.linhaId}'),
                onTap: _remover,
                child: Container(
                  width: context.dz(64),
                  height: context.dz(64),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _t.line, width: context.dz(2)),
                  ),
                  child: Icon(Icons.delete_outline_rounded, size: context.dz(30), color: _t.muted),
                ),
              ),
              const Spacer(),
              Quantidade(
                n: item.quantidade,
                onMenos: () => widget.acoes.alterarQuantidade(item.linhaId, item.quantidade - 1),
                onMais: () => widget.acoes.alterarQuantidade(item.linhaId, item.quantidade + 1),
                tokens: _t,
                tamanho: 60,
                corMais: _t.accent,
                chave: 'qtd-${item.linhaId}',
              ),
            ]),
          ]),
        ),
      ]),
    );
    if (!_saindo) return corpo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: widget.mov.d(320),
      curve: Curves.easeIn,
      onEnd: () => widget.acoes.remover(item.linhaId),
      child: corpo,
      builder: (context, v, filho) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1 - v,
          child: Opacity(
            opacity: 1 - v,
            child: Transform.translate(offset: Offset(-context.dz(120) * v, 0), child: filho),
          ),
        ),
      ),
    );
  }
}

/// Comer aqui / Para levar — já vem marcado com o que foi escolhido no descanso. Botões no
/// estilo jukebox (borda marrom, sombra dura; o escolhido fica menta e afunda).
class _Consumo extends StatelessWidget {
  const _Consumo({required this.consumo, required this.onEscolher});
  final String consumo;
  final void Function(String) onEscolher;

  @override
  Widget build(BuildContext context) {
    Widget opcao(String valor, String rotulo, IconData icone) {
      final ativo = consumo == valor;
      return Expanded(
        child: Semantics(
          button: true,
          selected: ativo,
          child: GestureDetector(
            key: ValueKey('consumo-$valor'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onEscolher(valor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: context.dz(96),
              transform: Matrix4.translationValues(0, ativo ? context.dz(4) : 0, 0),
              decoration: BoxDecoration(
                color: ativo ? _t.accent2 : _t.surface,
                borderRadius: BorderRadius.circular(context.dz(24)),
                border: Border.all(color: _t.text, width: context.dz(4)),
                boxShadow: [sombraDura(context.dz(ativo ? 2 : 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icone, size: context.dz(36), color: _t.text),
                SizedBox(width: context.dz(12)),
                Flexible(
                  child: Text(rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t.texto(context.dz(30), peso: FontWeight.w900)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      opcao('local', 'Comer aqui', Icons.restaurant_rounded),
      SizedBox(width: context.dz(18)),
      opcao('viagem', 'Para levar', Icons.shopping_bag_outlined),
    ]);
  }
}

/// "Combina com seu pedido": caixa branca de borda tracejada com até 3 sugestões.
class _Combina extends StatelessWidget {
  const _Combina({required this.sugestoes, required this.onAdicionar});
  final List<Produto> sugestoes;
  final void Function(Produto) onAdicionar;

  @override
  Widget build(BuildContext context) {
    return CaixaTracejada(
      key: const ValueKey('combina'),
      padding: EdgeInsets.all(context.dz(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_outlined, size: context.dz(38), color: _t.accent),
          SizedBox(width: context.dz(18)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Combina com seu pedido', style: _t.display(context.dz(36), altura: 1.1)),
              SizedBox(height: context.dz(6)),
              Text('Sugestões pensadas para o que você escolheu', style: _t.texto(context.dz(24), cor: _t.muted)),
            ]),
          ),
        ]),
        SizedBox(height: context.dz(22)),
        LayoutBuilder(builder: (context, c) {
          final vao = context.dz(16);
          final largura = (c.maxWidth - vao * 2) / 3;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < sugestoes.length; i++) ...[
              if (i > 0) SizedBox(width: vao),
              SizedBox(width: largura, child: _Sugestao(produto: sugestoes[i], onAdicionar: onAdicionar)),
            ],
          ]);
        }),
      ]),
    );
  }
}

class _Sugestao extends StatelessWidget {
  const _Sugestao({required this.produto, required this.onAdicionar});
  final Produto produto;
  final void Function(Produto) onAdicionar;

  @override
  Widget build(BuildContext context) {
    return Column(key: ValueKey('combina-${produto.id}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: context.dz(180),
        width: double.infinity,
        child: DinerArte(url: produto.imagemUrl, raio: context.dz(16)),
      ),
      SizedBox(height: context.dz(10)),
      SizedBox(
        height: context.dz(62),
        child: Text(produto.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _t.texto(context.dz(26), peso: FontWeight.w900, altura: 1.15)),
      ),
      SizedBox(height: context.dz(8)),
      Row(children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatCentavos(produto.precoCentavos),
                style: _t.texto(context.dz(28), peso: FontWeight.w900, cor: _t.price)),
          ),
        ),
        DinerMais(
          key: ValueKey('combina-mais-${produto.id}'),
          diametro: 64,
          onTap: () => onAdicionar(produto),
        ),
      ]),
    ]);
  }
}
