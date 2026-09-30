import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../data/catalog/catalog_sync.dart' show menuProvider;
import '../../../domain/order/cart.dart';
import '../../../domain/order/order_models.dart';
import '../../../domain/order/sugestoes.dart';
import '../comum/catalogo_dados.dart';
import '../comum/produto_arte.dart';
import '../comum/quantidade.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Sacola do **Brasa 2.0** (docs/templates/01 §6.4): lista dos itens, seletor de consumo,
/// "Combina com seu pedido" (upsell dos itens, `sugestoesUpsell`) e o rodapé com o total e
/// "Finalizar pedido". Tela inteira: lê a sacola, o checkout e o cardápio como a GoGen.
class Brasa2Carrinho extends ConsumerStatefulWidget {
  const Brasa2Carrinho({super.key});

  @override
  ConsumerState<Brasa2Carrinho> createState() => _Brasa2CarrinhoState();
}

class _Brasa2CarrinhoState extends ConsumerState<Brasa2Carrinho> {
  /// Linhas deslizando para fora (320 ms) antes de sair da sacola.
  final _saindo = <String>{};

  void _remover(String linhaId, Movimento mov) {
    if (!mov.anima) {
      AcoesPedido(ref).remover(linhaId);
      return;
    }
    setState(() => _saindo.add(linhaId));
  }

  void _saiu(String linhaId) {
    if (!mounted) return;
    AcoesPedido(ref).remover(linhaId);
    setState(() => _saindo.remove(linhaId));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    final snap = ref.watch(menuProvider).valueOrNull;
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);
    final sugestoes = snap == null ? const <Produto>[] : sugestoesUpsell(cart.itens, snap).take(3).toList();
    final n = cart.totalItens;

    return Brasa2Tela(
      child: Brasa2Entrada(
        mov: mov,
        child: Column(children: [
          Brasa2Topo(
            onVoltar: () => acoes.adicionarMais(context),
            onCancelar: () => acoes.cancelarPedido(context),
            etapa: 1,
            mov: mov,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text('Sua sacola', style: brasaTitulo(context, 92))),
                    Text('$n ${n == 1 ? 'item' : 'itens'}',
                        key: const ValueKey('sacola-itens'), style: brasaTexto(context, 30, cor: _t.muted)),
                  ],
                ),
                SizedBox(height: context.dz(26)),
                if (cart.vazio)
                  _Vazia(onAdicionarMais: () => acoes.adicionarMais(context), mov: mov)
                else ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(6)),
                    decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
                    child: Column(children: [
                      for (var i = 0; i < cart.itens.length; i++)
                        _Linha(
                          key: ValueKey('linha-${cart.itens[i].linhaId}'),
                          item: cart.itens[i],
                          primeira: i == 0,
                          saindo: _saindo.contains(cart.itens[i].linhaId),
                          mov: mov,
                          onRemover: () => _remover(cart.itens[i].linhaId, mov),
                          onSaiu: () => _saiu(cart.itens[i].linhaId),
                          onQuantidade: (q) => acoes.alterarQuantidade(cart.itens[i].linhaId, q),
                        ),
                    ]),
                  ),
                  SizedBox(height: context.dz(26)),
                  _Consumo(consumo: consumo, onEscolher: acoes.setConsumo, mov: mov),
                  if (sugestoes.isNotEmpty) ...[
                    SizedBox(height: context.dz(26)),
                    Brasa2Entrada(
                      mov: mov,
                      atraso: const Duration(milliseconds: 150),
                      duracaoMs: 500,
                      subida: 24,
                      child: _Sugestoes(
                        itens: sugestoes,
                        onMais: (p) => acoes.adicionarOuAbrir(context, p),
                      ),
                    ),
                  ],
                ],
              ]),
            ),
          ),
          Brasa2Rodape(children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Total', style: brasaTexto(context, 36, peso: FontWeight.w800)),
                SizedBox(width: context.dz(20)),
                Expanded(
                  child: Text(formatCentavos(cart.totalCentavos),
                      key: const ValueKey('total'),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: brasaTitulo(context, 78)),
                ),
              ],
            ),
            Row(children: [
              Expanded(
                flex: 10,
                child: Brasa2Botao(
                  key: const ValueKey('adicionar-mais'),
                  rotulo: 'Adicionar mais',
                  variante: Brasa2Variante.fantasma,
                  mov: mov,
                  onTap: () => acoes.adicionarMais(context),
                ),
              ),
              SizedBox(width: context.dz(20)),
              Expanded(
                flex: 16,
                child: Brasa2Botao(
                  key: const ValueKey('continuar'),
                  rotulo: 'Finalizar pedido',
                  iconeDepois: BrasaIcone.seta,
                  mov: mov,
                  onTap: cart.vazio ? null : () => acoes.finalizar(context),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

/// Uma linha da sacola: miniatura de 150, nome e total, complementos em linhas pequenas,
/// lixeira e quantidade. Ao sair, desliza para a esquerda e some (320 ms).
class _Linha extends StatefulWidget {
  const _Linha({
    super.key,
    required this.item,
    required this.primeira,
    required this.saindo,
    required this.mov,
    required this.onRemover,
    required this.onSaiu,
    required this.onQuantidade,
  });

  final ItemCarrinho item;
  final bool primeira;
  final bool saindo;
  final Movimento mov;
  final VoidCallback onRemover;
  final VoidCallback onSaiu;
  final ValueChanged<int> onQuantidade;

  @override
  State<_Linha> createState() => _LinhaState();
}

class _LinhaState extends State<_Linha> with SingleTickerProviderStateMixin {
  late final AnimationController _saida;

  @override
  void initState() {
    super.initState();
    _saida = AnimationController(vsync: this, duration: widget.mov.d(320));
    if (widget.saindo) _sair();
  }

  @override
  void didUpdateWidget(covariant _Linha old) {
    super.didUpdateWidget(old);
    if (widget.saindo && !old.saindo) _sair();
  }

  void _sair() => _saida.forward().whenComplete(() {
        if (mounted) widget.onSaiu();
      });

  @override
  void dispose() {
    _saida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final id = item.linhaId;
    final linha = Container(
      padding: EdgeInsets.symmetric(vertical: context.dz(26)),
      decoration: BoxDecoration(
        border: widget.primeira ? null : Border(top: BorderSide(color: _t.line, width: context.dz(2))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: context.dz(150),
          height: context.dz(150),
          child: ProdutoArte(url: item.produto.imagemUrl, tokens: _t, raio: _t.raio - 8, escalaRecorte: .9),
        ),
        SizedBox(width: context.dz(26)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: brasaTexto(context, 36, peso: FontWeight.w800, altura: 1.15)),
              ),
              SizedBox(width: context.dz(16)),
              Text(formatCentavos(item.totalCentavos),
                  style: brasaTexto(context, 34, peso: FontWeight.w800, altura: 1.25)),
            ]),
            for (final o in item.todasOpcoes)
              Padding(
                padding: EdgeInsets.only(top: context.dz(4)),
                child: Text('${o.precoCentavosDelta > 0 ? '+ ' : ''}${o.nome}',
                    style: brasaTexto(context, 24, cor: _t.muted, altura: 1.3)),
              ),
            SizedBox(height: context.dz(12)),
            Row(children: [
              Semantics(
                button: true,
                label: 'Remover ${item.produto.nome}',
                child: GestureDetector(
                  key: ValueKey('remover-$id'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.saindo ? null : widget.onRemover,
                  child: Container(
                    width: context.dz(64),
                    height: context.dz(64),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
                      border: Border.all(color: _t.line, width: context.dz(2)),
                    ),
                    child: IconeBrasa(BrasaIcone.lixeira, tamanho: context.dz(26), cor: _t.muted),
                  ),
                ),
              ),
              const Spacer(),
              Quantidade(
                n: item.quantidade,
                tokens: _t,
                chave: 'linha-$id',
                corMenos: _t.surface2,
                onMenos: () => item.quantidade <= 1 ? widget.onRemover() : widget.onQuantidade(item.quantidade - 1),
                onMais: () => widget.onQuantidade(item.quantidade + 1),
              ),
            ]),
          ]),
        ),
      ]),
    );
    if (!widget.mov.anima) return linha;
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
              child: Transform.translate(offset: Offset(-context.dz(120) * v, 0), child: child),
            ),
          ),
        );
      },
      child: linha,
    );
  }
}

class _Vazia extends StatelessWidget {
  const _Vazia({required this.onAdicionarMais, required this.mov});
  final VoidCallback onAdicionarMais;
  final Movimento mov;

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('sacola-vazia'),
        padding: EdgeInsets.symmetric(vertical: context.dz(90)),
        child: Column(children: [
          IconeBrasa(BrasaIcone.sacola, tamanho: context.dz(90), cor: _t.muted, traco: 1.6),
          SizedBox(height: context.dz(22)),
          Text('Sua sacola está vazia', style: brasaTexto(context, 34, peso: FontWeight.w800, cor: _t.muted)),
          SizedBox(height: context.dz(22)),
          Brasa2Botao(rotulo: 'Adicionar mais', mov: mov, onTap: onAdicionarMais),
        ]),
      );
}

/// Comer aqui / Para levar: dois botões segmentados de 96 (já vem marcado o do descanso).
class _Consumo extends StatelessWidget {
  const _Consumo({required this.consumo, required this.onEscolher, required this.mov});
  final String consumo;
  final ValueChanged<String> onEscolher;
  final Movimento mov;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _opcao(context, 'local', 'Comer aqui', BrasaIcone.comerAqui)),
        SizedBox(width: context.dz(18)),
        Expanded(child: _opcao(context, 'viagem', 'Para levar', BrasaIcone.paraLevar)),
      ]);

  Widget _opcao(BuildContext context, String valor, String rotulo, BrasaIcone icone) {
    final on = consumo == valor;
    final tinta = on ? _t.onAccent : _t.text;
    return Semantics(
      button: true,
      selected: on,
      label: rotulo,
      child: GestureDetector(
        key: ValueKey('consumo-$valor'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onEscolher(valor),
        child: AnimatedContainer(
          duration: mov.anima ? mov.d(250) : Duration.zero,
          height: context.dz(96),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _t.accent : const Color(0x00000000),
            borderRadius: BorderRadius.circular(context.dz(_t.raioBotao)),
            border: Border.all(color: on ? _t.accent : _t.line2, width: context.dz(3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconeBrasa(icone, tamanho: context.dz(36), cor: tinta),
            SizedBox(width: context.dz(14)),
            Text(rotulo, style: brasaTexto(context, 30, peso: FontWeight.w800, cor: tinta)),
          ]),
        ),
      ),
    );
  }
}

/// "Combina com seu pedido": caixa tracejada com até 3 sugestões (foto, nome, preço e +).
class _Sugestoes extends StatelessWidget {
  const _Sugestoes({required this.itens, required this.onMais});
  final List<Produto> itens;
  final ValueChanged<Produto> onMais;

  @override
  Widget build(BuildContext context) {
    final espaco = context.dz(16);
    return CustomPaint(
      key: const ValueKey('combina'),
      painter: _Tracejado(cor: _t.line2, largura: context.dz(3), raio: context.dz(_t.raio), traco: context.dz(12), vao: context.dz(9)),
      child: Padding(
        padding: EdgeInsets.all(context.dz(32)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.only(top: context.dz(4)),
              child: IconeBrasa(BrasaIcone.brilho, tamanho: context.dz(38), cor: _t.accent, traco: 2),
            ),
            SizedBox(width: context.dz(18)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Combina com seu pedido', style: brasaTitulo(context, 48, altura: 1.05)),
                SizedBox(height: context.dz(6)),
                Text('Sugestões pensadas para o que você escolheu',
                    style: brasaTexto(context, 24, cor: _t.muted)),
              ]),
            ),
          ]),
          SizedBox(height: context.dz(22)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: espaco),
              Expanded(child: i < itens.length ? _cartao(context, itens[i]) : const SizedBox.shrink()),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _cartao(BuildContext context, Produto p) => Container(
        key: ValueKey('sugestao-${p.id}'),
        padding: EdgeInsets.all(context.dz(14)),
        decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(_t.raio - 8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: context.dz(180),
            child: ProdutoArte(url: p.imagemUrl, tokens: _t, raio: _t.raio - 14, escalaRecorte: .88),
          ),
          SizedBox(height: context.dz(10)),
          SizedBox(
            height: context.dz(60),
            child: Text(p.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: brasaTexto(context, 26, peso: FontWeight.w800, altura: 1.15)),
          ),
          SizedBox(height: context.dz(10)),
          Row(children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatCentavos(p.precoCentavos),
                    style: brasaTexto(context, 28, peso: FontWeight.w800, cor: _t.price)),
              ),
            ),
            SizedBox(width: context.dz(8)),
            Brasa2BotaoMais(key: ValueKey('sugestao-add-${p.id}'), tamanho: 64, onTap: () => onMais(p)),
          ]),
        ]),
      );
}

/// Borda tracejada arredondada (o `border: 3px dashed` do protótipo).
class _Tracejado extends CustomPainter {
  _Tracejado({required this.cor, required this.largura, required this.raio, required this.traco, required this.vao});
  final Color cor;
  final double largura;
  final double raio;
  final double traco;
  final double vao;

  @override
  void paint(Canvas canvas, Size size) {
    final m = largura / 2;
    final caminho = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(m, m, size.width - largura, size.height - largura), Radius.circular(raio)));
    final p = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..strokeCap = StrokeCap.round;
    for (final metrica in caminho.computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + traco), p);
        d += traco + vao;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Tracejado o) =>
      o.cor != cor || o.largura != largura || o.raio != raio || o.traco != traco || o.vao != vao;
}
