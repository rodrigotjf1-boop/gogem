import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
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
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Sacola do Estúdio (docs/03 §6.4 + 00 §4.4): lista num cartão branco, o seletor de
/// consumo (já marcado com o que foi escolhido no descanso), "Combina com seu pedido" com
/// até 3 sugestões e o total em Sora 800 78. Tela inteira: lê os providers e usa
/// `AcoesPedido` (mesma regra da `CarrinhoScreen`).
class EstudioCarrinho extends ConsumerWidget {
  const EstudioCarrinho({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    final snap = ref.watch(menuProvider).valueOrNull;
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);
    final sugestoes =
        snap == null ? const <Produto>[] : sugestoesUpsell(cart.itens, snap).take(3).toList();
    final k = context.k;

    return TelaEstudio(
      mov: mov,
      child: Column(children: [
        TopoEstudio(
          etapa: 1,
          onVoltar: () => acoes.adicionarMais(context),
          onCancelar: () => acoes.cancelarPedido(context),
          mov: mov,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(56 * k, 24 * k, 56 * k, 30 * k),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Expanded(child: TituloTela('Sua sacola')),
                  Text(cart.totalItens == 1 ? '1 item' : '${cart.totalItens} itens',
                      key: const ValueKey('sacola-contagem'),
                      style: _t.texto(30 * k, peso: FontWeight.w400, cor: _t.muted)),
                ],
              ),
              SizedBox(height: 26 * k),
              if (cart.vazio)
                _Vazia(onMais: () => acoes.adicionarMais(context))
              else ...[
                _Lista(itens: cart.itens, acoes: acoes, mov: mov),
                SizedBox(height: 26 * k),
                _Consumo(consumo: consumo, onEscolher: acoes.setConsumo),
                if (sugestoes.isNotEmpty) ...[
                  SizedBox(height: 26 * k),
                  _Combina(
                    sugestoes: sugestoes,
                    mov: mov,
                    onAdicionar: (p) => acoes.adicionarOuAbrir(context, p),
                  ),
                ],
              ],
            ]),
          ),
        ),
        if (!cart.vazio)
          RodapeEstudio(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Total', style: _t.texto(36 * k, peso: FontWeight.w800)),
                  SizedBox(width: 20 * k),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatCentavos(cart.totalCentavos),
                            key: const ValueKey('total'),
                            style: _t.display(78 * k, altura: 1).copyWith(letterSpacing: -78 * .03 * k)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18 * k),
              Row(children: [
                BotaoEstudio(
                  chave: 'adicionar-mais',
                  rotulo: 'Adicionar mais',
                  tipo: TipoBotao.contorno,
                  onTap: () => acoes.adicionarMais(context),
                ),
                SizedBox(width: 20 * k),
                Expanded(
                  child: BotaoEstudio(
                    chave: 'finalizar-pedido',
                    rotulo: 'Finalizar pedido',
                    iconeDepois: Icons.arrow_forward_rounded,
                    onTap: () => acoes.finalizar(context),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _Vazia extends StatelessWidget {
  const _Vazia({required this.onMais});
  final VoidCallback onMais;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 120 * k),
      child: Column(children: [
        Icon(Icons.shopping_bag_outlined, size: 90 * k, color: _t.muted),
        SizedBox(height: 22 * k),
        Text('Sua sacola está vazia', style: _t.texto(34 * k, peso: FontWeight.w700, cor: _t.muted)),
        SizedBox(height: 22 * k),
        BotaoEstudio(chave: 'adicionar-mais', rotulo: 'Adicionar mais', onTap: onMais),
      ]),
    );
  }
}

/// A lista num cartão branco (raio 38, sombra suave), com uma linha por item.
class _Lista extends StatelessWidget {
  const _Lista({required this.itens, required this.acoes, required this.mov});
  final List<ItemCarrinho> itens;
  final AcoesPedido acoes;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32 * k, vertical: 6 * k),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(_t.raio * k),
        boxShadow: [BoxShadow(color: const Color(0x0F2A1512), blurRadius: 30 * k, offset: Offset(0, 12 * k))],
      ),
      child: Column(children: [
        for (var i = 0; i < itens.length; i++)
          _Linha(
            key: ValueKey('linha-${itens[i].linhaId}'),
            item: itens[i],
            primeira: i == 0,
            mov: mov,
            onRemover: () => acoes.remover(itens[i].linhaId),
            onQuantidade: (q) => acoes.alterarQuantidade(itens[i].linhaId, q),
          ),
      ]),
    );
  }
}

/// Uma linha da sacola. Ao remover, desliza para a esquerda e some (320 ms) — só então o
/// item sai da sacola.
class _Linha extends StatefulWidget {
  const _Linha({
    super.key,
    required this.item,
    required this.primeira,
    required this.mov,
    required this.onRemover,
    required this.onQuantidade,
  });

  final ItemCarrinho item;
  final bool primeira;
  final Movimento mov;
  final VoidCallback onRemover;
  final void Function(int) onQuantidade;

  @override
  State<_Linha> createState() => _LinhaState();
}

class _LinhaState extends State<_Linha> with SingleTickerProviderStateMixin {
  late final AnimationController _saida;
  bool _saindo = false;

  @override
  void initState() {
    super.initState();
    _saida = AnimationController(vsync: this, duration: widget.mov.d(320));
  }

  @override
  void dispose() {
    _saida.dispose();
    super.dispose();
  }

  void _remover() {
    if (_saindo) return;
    if (!widget.mov.anima) {
      widget.onRemover();
      return;
    }
    _saindo = true;
    _saida.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onRemover();
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final item = widget.item;
    final extras = descricaoSelecoes(item);
    final conteudo = Container(
      padding: EdgeInsets.symmetric(vertical: 26 * k),
      decoration: BoxDecoration(
        border: widget.primeira ? null : Border(top: BorderSide(color: _t.line, width: 2 * k)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150 * k,
          height: 150 * k,
          child: ClipRRect(
            borderRadius: BorderRadius.circular((_t.raio - 8) * k),
            child: ColoredBox(
              color: _t.art,
              child: ArteEstudio(url: item.produto.imagemUrl, foto: .86, borda: 5, recorteLargura: .9, recorteAltura: .9),
            ),
          ),
        ),
        SizedBox(width: 26 * k),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(36 * k, peso: FontWeight.w800, altura: 1.15)),
              ),
              SizedBox(width: 16 * k),
              Text(formatCentavos(item.totalCentavos),
                  key: ValueKey('linha-total-${item.linhaId}'),
                  style: _t.texto(34 * k, peso: FontWeight.w800, altura: 1.2)),
            ]),
            if (extras.isNotEmpty) ...[
              SizedBox(height: 4 * k),
              Text(extras.join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _t.texto(24 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.35)),
            ],
            SizedBox(height: 12 * k),
            Row(children: [
              Material(
                color: const Color(0x00000000),
                shape: CircleBorder(side: BorderSide(color: _t.line, width: 2 * k)),
                child: InkWell(
                  key: ValueKey('remover-${item.linhaId}'),
                  customBorder: const CircleBorder(),
                  onTap: _remover,
                  child: SizedBox(
                    width: 72 * k,
                    height: 72 * k,
                    child: Icon(Icons.delete_outline_rounded, size: 30 * k, color: _t.muted),
                  ),
                ),
              ),
              const Spacer(),
              Quantidade(
                n: item.quantidade,
                onMenos: () => widget.onQuantidade(item.quantidade - 1),
                onMais: () => widget.onQuantidade(item.quantidade + 1),
                tokens: _t,
                chave: 'qtd-${item.linhaId}',
              ),
            ]),
          ]),
        ),
      ]),
    );
    return AnimatedBuilder(
      animation: _saida,
      builder: (_, child) {
        final v = Curves.easeIn.transform(_saida.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - v,
            child: Opacity(
              opacity: 1 - v,
              child: Transform.translate(offset: Offset(-120 * k * v, 0), child: child),
            ),
          ),
        );
      },
      child: conteudo,
    );
  }
}

/// Comer aqui / Para levar — já vem marcado com o que foi escolhido no descanso.
class _Consumo extends StatelessWidget {
  const _Consumo({required this.consumo, required this.onEscolher});
  final String consumo;
  final void Function(String) onEscolher;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget opcao(String chave, String valor, String rotulo, IconData icone) {
      final ativo = consumo == valor;
      final raio = BorderRadius.circular(_t.raioBotao * k);
      return Material(
        color: ativo ? _t.text : _t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: ativo ? BorderSide.none : BorderSide(color: _t.line, width: 3 * k),
        ),
        child: InkWell(
          key: ValueKey(chave),
          borderRadius: raio,
          onTap: () => onEscolher(valor),
          child: SizedBox(
            height: 96 * k,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icone, size: 36 * k, color: ativo ? EstudioCores.branco : _t.text),
              SizedBox(width: 14 * k),
              Flexible(
                child: Text(rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t.texto(30 * k, peso: FontWeight.w700, cor: ativo ? EstudioCores.branco : _t.text)),
              ),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      Expanded(child: opcao('consumo-local', 'local', 'Comer aqui', Icons.restaurant_rounded)),
      SizedBox(width: 16 * k),
      Expanded(child: opcao('consumo-viagem', 'viagem', 'Para levar', Icons.shopping_bag_outlined)),
    ]);
  }
}

/// "Combina com seu pedido": até 3 sugestões (disco + recorte ou foto em círculo).
class _Combina extends StatelessWidget {
  const _Combina({required this.sugestoes, required this.mov, required this.onAdicionar});
  final List<Produto> sugestoes;
  final Movimento mov;
  final void Function(Produto) onAdicionar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: const ValueKey('combina'),
      padding: EdgeInsets.all(32 * k),
      decoration: BoxDecoration(color: _t.surface2, borderRadius: BorderRadius.circular(_t.raio * k)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_outlined, size: 38 * k, color: _t.accent),
          SizedBox(width: 18 * k),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Combina com seu pedido',
                  style: _t.display(42 * k, altura: 1.05).copyWith(letterSpacing: -42 * .02 * k)),
              SizedBox(height: 6 * k),
              Text('Sugestões pensadas para o que você escolheu',
                  style: _t.texto(24 * k, peso: FontWeight.w400, cor: _t.muted)),
            ]),
          ),
        ]),
        SizedBox(height: 22 * k),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: 16 * k),
            Expanded(
              child: i < sugestoes.length
                  ? _Sugestao(p: sugestoes[i], cor: corDisco(i), mov: mov, onAdicionar: () => onAdicionar(sugestoes[i]))
                  : const SizedBox.shrink(),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Sugestao extends StatelessWidget {
  const _Sugestao({required this.p, required this.cor, required this.mov, required this.onAdicionar});
  final Produto p;
  final Color cor;
  final Movimento mov;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: ValueKey('sugestao-${p.id}'),
      padding: EdgeInsets.all(14 * k),
      decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular((_t.raio - 8) * k)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 180 * k,
          child: ClipRRect(
            borderRadius: BorderRadius.circular((_t.raio - 14) * k),
            child: ColoredBox(
              color: _t.art,
              child: ArteEstudio(url: p.imagemUrl, corDisco: cor, disco: .92, foto: .84, mov: mov),
            ),
          ),
        ),
        SizedBox(height: 10 * k),
        SizedBox(
          height: 60 * k,
          child: Text(p.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _t.texto(26 * k, peso: FontWeight.w700, altura: 1.15)),
        ),
        SizedBox(height: 10 * k),
        Row(children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatCentavos(p.precoCentavos),
                  style: _t.texto(28 * k, peso: FontWeight.w800, cor: _t.price)),
            ),
          ),
          BotaoMais(diametro: 64, chave: 'sugestao-mais-${p.id}', onTap: onAdicionar),
        ]),
      ]),
    );
  }
}
