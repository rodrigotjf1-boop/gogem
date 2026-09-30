import 'dart:async';
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
import '../comum/produto_arte.dart';
import '../comum/quantidade.dart';
import '../escala.dart';
import '../movimento.dart';
import '../providers.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Sacola do Neon 2.0 (docs/templates/04-neon-2.md §6.4): título + contagem em 2 dígitos
/// (`accent2`, Unbounded 88), lista com borda TRACEJADA `line2`, seletor de consumo, bloco
/// "Combina com seu pedido" com borda e brilho magenta, e o total em Unbounded 66 `accent`
/// num cartão `surface`. Tela inteira: mesma lógica da GoGen (providers + `AcoesPedido`).
class NeonCarrinhoScreen extends ConsumerStatefulWidget {
  const NeonCarrinhoScreen({super.key});

  @override
  ConsumerState<NeonCarrinhoScreen> createState() => _NeonCarrinhoScreenState();
}

class _NeonCarrinhoScreenState extends ConsumerState<NeonCarrinhoScreen> {
  /// Linhas saindo (deslizam para a esquerda e somem em 320 ms antes de sair da sacola).
  final _saindo = <String>{};
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _remover(AcoesPedido acoes, String linhaId, Movimento mov) {
    if (!mov.anima) {
      acoes.remover(linhaId);
      return;
    }
    setState(() => _saindo.add(linhaId));
    _timers.add(Timer(mov.d(320), () {
      if (!mounted) return;
      _saindo.remove(linhaId);
      acoes.remover(linhaId);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final snap = ref.watch(menuProvider).valueOrNull;
    final mov = ref.watch(movimentoProvider);
    final acoes = AcoesPedido(ref);
    final sugestoes = snap == null ? const <Produto>[] : sugestoesUpsell(cart.itens, snap).take(3).toList();

    return Scaffold(
      backgroundColor: _t.bg,
      body: SafeArea(
        child: NeonEntrada(
          mov: mov,
          child: Column(children: [
            NeonTopo(
              mov: mov,
              etapa: 1,
              nomeLoja: ap.nomeLoja,
              logoUrl: ap.logoUrl,
              onVoltar: () => acoes.adicionarMais(context),
              onCancelar: () => acoes.cancelarPedido(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Cabecalho(itens: cart.totalItens),
                  SizedBox(height: context.dz(26)),
                  if (cart.vazio)
                    _Vazia(onAdicionar: () => acoes.adicionarMais(context))
                  else ...[
                    CustomPaint(
                      painter: BordaTracejada(cor: _t.line2, espessura: context.dz(2), raio: context.dz(24)),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(6)),
                        decoration: BoxDecoration(
                          color: _t.surface,
                          borderRadius: BorderRadius.circular(context.dz(24)),
                        ),
                        child: Column(children: [
                          for (var i = 0; i < cart.itens.length; i++)
                            _Linha(
                              key: ValueKey('linha-${cart.itens[i].linhaId}'),
                              item: cart.itens[i],
                              primeira: i == 0,
                              saindo: _saindo.contains(cart.itens[i].linhaId),
                              mov: mov,
                              onRemover: () => _remover(acoes, cart.itens[i].linhaId, mov),
                              onQuantidade: (q) => acoes.alterarQuantidade(cart.itens[i].linhaId, q),
                            ),
                        ]),
                      ),
                    ),
                    SizedBox(height: context.dz(26)),
                    _Consumo(consumo: consumo, mov: mov, onTrocar: acoes.setConsumo),
                    if (sugestoes.isNotEmpty) ...[
                      SizedBox(height: context.dz(26)),
                      _Sugestoes(
                        produtos: sugestoes,
                        mov: mov,
                        onAbrir: (p) => acoes.abrirProduto(context, p),
                        onMais: (p) => acoes.adicionarOuAbrir(context, p),
                      ),
                    ],
                  ],
                ]),
              ),
            ),
            _Rodape(
              totalCentavos: cart.totalCentavos,
              vazio: cart.vazio,
              onAdicionarMais: () => acoes.adicionarMais(context),
              onFinalizar: () => acoes.finalizar(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.itens});
  final int itens;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Text(_t.caixa('Sua sacola'), style: neonDisplay(context.dz(66))),
      ),
      SizedBox(width: context.dz(16)),
      Text(itens.toString().padLeft(2, '0'),
          key: const ValueKey('sacola-contagem'), style: neonDisplay(context.dz(88), cor: _t.accent2, altura: 1)),
      SizedBox(width: context.dz(10)),
      Text(itens == 1 ? 'ITEM' : 'ITENS',
          style: neonTexto(context.dz(22), peso: FontWeight.w700, cor: _t.muted, espaco: .1)),
    ]);
  }
}

class _Vazia extends StatelessWidget {
  const _Vazia({required this.onAdicionar});
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.dz(100)),
      child: Column(children: [
        Icon(Icons.shopping_bag_outlined, size: context.dz(96), color: _t.muted),
        SizedBox(height: context.dz(22)),
        Text('Sua sacola está vazia',
            key: const ValueKey('sacola-vazia'), style: neonTexto(context.dz(34), cor: _t.muted)),
        SizedBox(height: context.dz(30)),
        SizedBox(
          width: context.dz(520),
          child: NeonBotao(key: const ValueKey('vazia-adicionar'), rotulo: 'Adicionar mais', onTap: onAdicionar),
        ),
      ]),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    super.key,
    required this.item,
    required this.primeira,
    required this.saindo,
    required this.mov,
    required this.onRemover,
    required this.onQuantidade,
  });

  final ItemCarrinho item;
  final bool primeira;
  final bool saindo;
  final Movimento mov;
  final VoidCallback onRemover;
  final void Function(int) onQuantidade;

  @override
  Widget build(BuildContext context) {
    final dur = mov.anima ? mov.d(320) : Duration.zero;
    final complementos = descricaoSelecoes(item);
    final linha = Container(
      padding: EdgeInsets.symmetric(vertical: context.dz(26)),
      decoration: BoxDecoration(
        border: primeira ? null : Border(top: BorderSide(color: _t.line, width: context.dz(2))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: context.dz(150),
          height: context.dz(150),
          child: ProdutoArte(url: item.produto.imagemUrl, tokens: _t, raio: context.dz(16)),
        ),
        SizedBox(width: context.dz(26)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: neonTexto(context.dz(36), peso: FontWeight.w700, altura: 1.15)),
              ),
              SizedBox(width: context.dz(16)),
              Text(formatCentavos(item.totalCentavos), style: neonTexto(context.dz(34), peso: FontWeight.w700)),
            ]),
            for (final c in complementos)
              Padding(
                padding: EdgeInsets.only(top: context.dz(4)),
                child: Text(c, style: neonTexto(context.dz(24), cor: _t.muted)),
              ),
            SizedBox(height: context.dz(12)),
            Row(children: [
              Material(
                color: const Color(0x00000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.dz(16)),
                  side: BorderSide(color: _t.line, width: context.dz(2)),
                ),
                child: InkWell(
                  key: ValueKey('remover-${item.linhaId}'),
                  borderRadius: BorderRadius.circular(context.dz(16)),
                  onTap: onRemover,
                  child: SizedBox(
                    width: context.dz(64),
                    height: context.dz(64),
                    child: Icon(Icons.delete_outline_rounded, size: context.dz(30), color: _t.muted),
                  ),
                ),
              ),
              const Spacer(),
              Quantidade(
                n: item.quantidade,
                onMenos: () => onQuantidade(item.quantidade - 1),
                onMais: () => onQuantidade(item.quantidade + 1),
                tokens: _t,
                corMenos: _t.surface2,
                chave: 'qtd-${item.linhaId}',
              ),
            ]),
          ]),
        ),
      ]),
    );
    return AnimatedSlide(
      duration: dur,
      curve: Curves.easeIn,
      offset: saindo ? const Offset(-.12, 0) : Offset.zero,
      child: AnimatedOpacity(duration: dur, opacity: saindo ? 0 : 1, child: linha),
    );
  }
}

/// Comer aqui / Para levar — já marcado com o que foi escolhido no descanso.
class _Consumo extends StatelessWidget {
  const _Consumo({required this.consumo, required this.mov, required this.onTrocar});
  final String consumo;
  final Movimento mov;
  final void Function(String) onTrocar;

  @override
  Widget build(BuildContext context) {
    Widget opcao(String valor, String rotulo, IconData icone) {
      final ativo = consumo == valor;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('consumo-$valor'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTrocar(valor),
          child: AnimatedContainer(
            duration: mov.anima ? const Duration(milliseconds: 250) : Duration.zero,
            height: context.dz(78),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ativo ? _t.accent : const Color(0x00000000),
              borderRadius: BorderRadius.circular(context.dz(14)),
              boxShadow: ativo && mov.brilho ? [BoxShadow(color: neonBrilho, blurRadius: context.dz(26))] : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icone, size: context.dz(30), color: ativo ? _t.onAccent : _t.text),
                SizedBox(width: context.dz(12)),
                Text(rotulo.toUpperCase(),
                    style: neonTexto(context.dz(23),
                        peso: FontWeight.w600, cor: ativo ? _t.onAccent : _t.text, espaco: .05)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.dz(8)),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(context.dz(22)),
        border: Border.all(color: _t.line, width: context.dz(2)),
      ),
      child: Row(children: [
        opcao('local', 'Comer aqui', Icons.restaurant_rounded),
        SizedBox(width: context.dz(8)),
        opcao('viagem', 'Para levar', Icons.shopping_bag_outlined),
      ]),
    );
  }
}

/// "Combina com seu pedido": borda 2 `accent2` com brilho magenta (só perfil forte).
class _Sugestoes extends StatelessWidget {
  const _Sugestoes({required this.produtos, required this.mov, required this.onAbrir, required this.onMais});
  final List<Produto> produtos;
  final Movimento mov;
  final void Function(Produto) onAbrir;
  final void Function(Produto) onMais;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('sugestoes'),
      padding: EdgeInsets.all(context.dz(32)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.dz(24)),
        border: Border.all(color: _t.accent2, width: context.dz(2)),
        color: _t.bg,
        boxShadow: mov.brilho ? [BoxShadow(color: const Color(0x33FF3EA5), blurRadius: context.dz(30))] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(top: context.dz(4)),
            child: Icon(Icons.auto_awesome, size: context.dz(38), color: _t.accent),
          ),
          SizedBox(width: context.dz(18)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Combina com seu pedido', style: neonDisplay(context.dz(42), altura: 1.05)),
              SizedBox(height: context.dz(6)),
              Text('Sugestões pensadas para o que você escolheu', style: neonTexto(context.dz(24), cor: _t.muted)),
            ]),
          ),
        ]),
        SizedBox(height: context.dz(22)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: context.dz(16)),
            Expanded(
              child: i < produtos.length
                  ? _CartaoSugestao(produto: produtos[i], onAbrir: onAbrir, onMais: onMais)
                  : const SizedBox.shrink(),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _CartaoSugestao extends StatelessWidget {
  const _CartaoSugestao({required this.produto, required this.onAbrir, required this.onMais});
  final Produto produto;
  final void Function(Produto) onAbrir;
  final void Function(Produto) onMais;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return GestureDetector(
      key: ValueKey('sugestao-${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onAbrir(p),
      child: Container(
        padding: EdgeInsets.all(context.dz(14)),
        decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(16))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: context.dz(180),
            width: double.infinity,
            child: ProdutoArte(url: p.imagemUrl, tokens: _t, raio: context.dz(10)),
          ),
          SizedBox(height: context.dz(10)),
          SizedBox(
            height: context.dz(62),
            child: Text(p.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: neonTexto(context.dz(26), peso: FontWeight.w700, altura: 1.15)),
          ),
          SizedBox(height: context.dz(10)),
          Row(children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatCentavos(p.precoCentavos),
                    style: neonTexto(context.dz(28), peso: FontWeight.w700, cor: _t.price)),
              ),
            ),
            NeonBotaoMais(
              key: ValueKey('sugestao-add-${p.id}'),
              tamanho: 64,
              onTap: () => onMais(p),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.totalCentavos,
    required this.vazio,
    required this.onAdicionarMais,
    required this.onFinalizar,
  });
  final int totalCentavos;
  final bool vazio;
  final VoidCallback onAdicionarMais;
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(44)),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _t.line, width: context.dz(2)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.dz(30), vertical: context.dz(16)),
          decoration: BoxDecoration(
            color: _t.surface,
            borderRadius: BorderRadius.circular(context.dz(24)),
            border: Border.all(color: _t.line, width: context.dz(2)),
          ),
          child: Row(children: [
            Text('Total', style: neonTexto(context.dz(36), peso: FontWeight.w700)),
            SizedBox(width: context.dz(20)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(formatCentavos(totalCentavos),
                    key: const ValueKey('total'), style: neonDisplay(context.dz(66), cor: _t.accent, espaco: -.03)),
              ),
            ),
          ]),
        ),
        SizedBox(height: context.dz(18)),
        Row(children: [
          Expanded(
            flex: 5,
            child: NeonBotao(
              key: const ValueKey('adicionar-mais'),
              rotulo: 'Adicionar mais',
              tipo: NeonBotaoTipo.fantasma,
              fonte: 30,
              onTap: onAdicionarMais,
            ),
          ),
          SizedBox(width: context.dz(20)),
          Expanded(
            flex: 7,
            child: NeonBotao(
              key: const ValueKey('continuar'),
              rotulo: 'Finalizar pedido',
              iconeFim: Icons.arrow_forward_rounded,
              fonte: 30,
              onTap: vazio ? null : onFinalizar,
            ),
          ),
        ]),
      ]),
    );
  }
}
