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
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Sacola do Vitrine (docs/templates/02 §6.4 e 00 §4.4): lista em `surface` (raio 40),
/// o bloco "Combina com seu pedido" em `surface2`, o seletor de consumo e o total em
/// Syne 800 78. Mesma regra da `CarrinhoScreen` (via `AcoesPedido`).
class VitrineCarrinhoScreen extends ConsumerWidget {
  const VitrineCarrinhoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const t = vitrineTokens;
    final cart = ref.watch(cartProvider);
    final consumo = ref.watch(checkoutProvider.select((c) => c.consumo));
    final mov = ref.watch(movimentoProvider);
    final snap = ref.watch(menuProvider).valueOrNull;
    final sugestoes = snap == null ? const <Produto>[] : sugestoesUpsell(cart.itens, snap).take(3).toList();
    final acoes = AcoesPedido(ref);
    final n = cart.totalItens;

    return Scaffold(
      backgroundColor: t.bg,
      body: EntradaVitrine(
        mov: mov,
        child: SafeArea(
          child: Column(children: [
            TopoVitrine(
              etapa: 1,
              mov: mov,
              onVoltar: () => acoes.adicionarMais(context),
              onCancelar: () => acoes.cancelarPedido(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text('Sua sacola', style: context.vDisplay(84, altura: 1))),
                      Text(n == 1 ? '1 item' : '$n itens',
                          key: const ValueKey('sacola-itens'),
                          style: context.vTexto(30, peso: FontWeight.w400, cor: t.muted)),
                    ],
                  ),
                  SizedBox(height: context.dz(26)),
                  if (cart.vazio)
                    _SacolaVazia(mov: mov, onAdicionarMais: () => acoes.adicionarMais(context))
                  else
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: context.dz(32), vertical: context.dz(6)),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(context.dz(t.raio)),
                      ),
                      child: Column(children: [
                        for (var i = 0; i < cart.itens.length; i++)
                          _LinhaSacola(
                            key: ValueKey('linha-${cart.itens[i].linhaId}'),
                            item: cart.itens[i],
                            primeira: i == 0,
                            mov: mov,
                            acoes: acoes,
                          ),
                      ]),
                    ),
                  if (!cart.vazio && sugestoes.isNotEmpty) ...[
                    SizedBox(height: context.dz(26)),
                    _Combina(sugestoes: sugestoes, acoes: acoes, mov: mov),
                  ],
                ]),
              ),
            ),
            _Rodape(
              totalCentavos: cart.totalCentavos,
              vazio: cart.vazio,
              consumo: consumo,
              mov: mov,
              onConsumo: acoes.setConsumo,
              onAdicionarMais: () => acoes.adicionarMais(context),
              onFinalizar: () => acoes.finalizar(context),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Uma linha da sacola: foto, nome, complementos, total da linha, lixeira e quantidade.
/// Ao remover, desliza para a esquerda e some (320 ms); sem animação, sai na hora.
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

class _LinhaSacolaState extends State<_LinhaSacola> with SingleTickerProviderStateMixin {
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

  Future<void> _remover() async {
    if (_saindo) return;
    final id = widget.item.linhaId;
    if (widget.mov.anima) {
      _saindo = true;
      await _saida.forward();
      if (!mounted) return;
    }
    widget.acoes.remover(id);
  }

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final item = widget.item;
    final extras = descricaoSelecoes(item);
    final linha = Container(
      padding: EdgeInsets.symmetric(vertical: context.dz(26)),
      decoration: BoxDecoration(
        border: widget.primeira ? null : Border(top: BorderSide(color: t.line, width: context.dz(2))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: context.dz(150),
          height: context.dz(150),
          child: ProdutoArte(
            url: item.produto.imagemUrl,
            tokens: t,
            raio: context.dz(t.raio - 8),
            escalaRecorte: .9,
          ),
        ),
        SizedBox(width: context.dz(26)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(item.produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.vTexto(36, peso: FontWeight.w800, altura: 1.15)),
              ),
              SizedBox(width: context.dz(16)),
              Text(formatCentavos(item.totalCentavos),
                  key: ValueKey('linha-total-${item.linhaId}'),
                  style: context.vTexto(34, peso: FontWeight.w800, altura: 1.15)),
            ]),
            if (extras.isNotEmpty) ...[
              SizedBox(height: context.dz(4)),
              Text(extras.join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.vTexto(24, peso: FontWeight.w400, cor: t.muted, altura: 1.35)),
            ],
            SizedBox(height: context.dz(12)),
            Row(children: [
              Semantics(
                button: true,
                label: 'Remover',
                child: GestureDetector(
                  key: ValueKey('remover-${item.linhaId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _remover,
                  child: Container(
                    width: context.dz(72),
                    height: context.dz(72),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.line2, width: context.dz(2)),
                    ),
                    child: Icon(Icons.delete_outline_rounded, size: context.dz(32), color: t.muted),
                  ),
                ),
              ),
              const Spacer(),
              Quantidade(
                n: item.quantidade,
                tokens: t,
                chave: 'qtd-${item.linhaId}',
                onMenos: () {
                  // Na última unidade o "−" tira a linha — com a mesma saída da lixeira.
                  if (item.quantidade <= 1) {
                    _remover();
                  } else {
                    widget.acoes.alterarQuantidade(item.linhaId, item.quantidade - 1);
                  }
                },
                onMais: () => widget.acoes.alterarQuantidade(item.linhaId, item.quantidade + 1),
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
        // A linha encolhe na altura (de baixo para cima), apaga e desliza 120 para a esquerda.
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

class _SacolaVazia extends StatelessWidget {
  const _SacolaVazia({required this.mov, required this.onAdicionarMais});
  final Movimento mov;
  final VoidCallback onAdicionarMais;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.dz(120)),
      child: Column(children: [
        Icon(Icons.shopping_bag_outlined, size: context.dz(90), color: t.muted),
        SizedBox(height: context.dz(22)),
        Text('Sua sacola está vazia',
            key: const ValueKey('sacola-vazia'),
            textAlign: TextAlign.center,
            style: context.vTexto(34, peso: FontWeight.w800, cor: t.muted)),
        SizedBox(height: context.dz(22)),
        BotaoVitrine(rotulo: 'Adicionar mais', mov: mov, onTap: onAdicionarMais),
      ]),
    );
  }
}

/// "Combina com seu pedido": até 3 sugestões de `sugestoesUpsell`, com foto, nome, preço e
/// "+" (o "+" segue a regra da peça-também: sem etapa obrigatória entra direto).
class _Combina extends StatelessWidget {
  const _Combina({required this.sugestoes, required this.acoes, required this.mov});
  final List<Produto> sugestoes;
  final AcoesPedido acoes;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      key: const ValueKey('vitrine-sugestoes'),
      padding: EdgeInsets.all(context.dz(32)),
      decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(context.dz(t.raio))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(top: context.dz(4)),
            child: Icon(Icons.auto_awesome_outlined, size: context.dz(38), color: t.accent),
          ),
          SizedBox(width: context.dz(18)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Combina com seu pedido', style: context.vDisplay(42, altura: 1.05, espacoEm: -.02)),
              SizedBox(height: context.dz(6)),
              Text('Sugestões pensadas para o que você escolheu',
                  style: context.vTexto(24, peso: FontWeight.w400, cor: t.muted)),
            ]),
          ),
        ]),
        SizedBox(height: context.dz(22)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: context.dz(16)),
            Expanded(
              child: i < sugestoes.length
                  ? _CartaoSugestao(
                      p: sugestoes[i],
                      onAdicionar: () => acoes.adicionarOuAbrir(context, sugestoes[i]),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _CartaoSugestao extends StatelessWidget {
  const _CartaoSugestao({required this.p, required this.onAdicionar});
  final Produto p;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      key: ValueKey('sugestao-${p.id}'),
      padding: EdgeInsets.all(context.dz(14)),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(context.dz(t.raio - 8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: context.dz(180),
          width: double.infinity,
          child: ProdutoArte(url: p.imagemUrl, tokens: t, raio: context.dz(t.raio - 14), escalaRecorte: .88),
        ),
        SizedBox(height: context.dz(10)),
        SizedBox(
          height: context.dz(62),
          child: Text(p.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.vTexto(26, peso: FontWeight.w800, altura: 1.15)),
        ),
        SizedBox(height: context.dz(8)),
        Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatCentavos(p.precoCentavos),
                    style: context.vTexto(28, peso: FontWeight.w800, cor: t.price)),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Adicionar ${p.nome}',
            child: GestureDetector(
              key: ValueKey('sugestao-mais-${p.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onAdicionar,
              child: Container(
                width: context.dz(64),
                height: context.dz(64),
                decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: context.dz(38), color: t.onAccent),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Rodapé: seletor de consumo (já marcado com a escolha do descanso), total grande e os
/// botões "Adicionar mais" e "Finalizar pedido".
class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.totalCentavos,
    required this.vazio,
    required this.consumo,
    required this.mov,
    required this.onConsumo,
    required this.onAdicionarMais,
    required this.onFinalizar,
  });

  final int totalCentavos;
  final bool vazio;
  final String consumo;
  final Movimento mov;
  final void Function(String) onConsumo;
  final VoidCallback onAdicionarMais;
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: context.dz(2)))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: _OpcaoConsumo(
              key: const ValueKey('consumo-local'),
              rotulo: 'Comer aqui',
              icone: Icons.restaurant_rounded,
              ativo: consumo == 'local',
              mov: mov,
              onTap: () => onConsumo('local'),
            ),
          ),
          SizedBox(width: context.dz(16)),
          Expanded(
            child: _OpcaoConsumo(
              key: const ValueKey('consumo-viagem'),
              rotulo: 'Para levar',
              icone: Icons.shopping_bag_outlined,
              ativo: consumo == 'viagem',
              mov: mov,
              onTap: () => onConsumo('viagem'),
            ),
          ),
        ]),
        SizedBox(height: context.dz(18)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Padding(
            padding: EdgeInsets.only(bottom: context.dz(6)),
            child: Text('Total', style: context.vTexto(36, peso: FontWeight.w800, altura: 1)),
          ),
          SizedBox(width: context.dz(20)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatCentavos(totalCentavos),
                    key: const ValueKey('total'), style: context.vDisplay(78, altura: 1, espacoEm: -.03)),
              ),
            ),
          ),
        ]),
        SizedBox(height: context.dz(18)),
        Row(children: [
          BotaoVitrine(
            key: const ValueKey('adicionar-mais'),
            rotulo: 'Adicionar mais',
            estilo: EstiloBotaoVitrine.fantasma,
            mov: mov,
            onTap: onAdicionarMais,
          ),
          SizedBox(width: context.dz(20)),
          Expanded(
            child: BotaoVitrine(
              key: const ValueKey('continuar'),
              rotulo: 'Finalizar pedido',
              iconeFim: Icons.arrow_forward_rounded,
              mov: mov,
              onTap: vazio ? null : onFinalizar,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _OpcaoConsumo extends StatelessWidget {
  const _OpcaoConsumo({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.ativo,
    required this.mov,
    required this.onTap,
  });
  final String rotulo;
  final IconData icone;
  final bool ativo;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final tinta = ativo ? vitrineTinta111 : t.text;
    return Semantics(
      button: true,
      selected: ativo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: mov.anima ? mov.d(300) : Duration.zero,
          height: context.dz(88),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativo ? t.text : const Color(0x00000000),
            borderRadius: BorderRadius.circular(context.dz(44)),
            border: Border.all(color: ativo ? t.text : t.line2, width: context.dz(2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, size: context.dz(34), color: tinta),
            SizedBox(width: context.dz(12)),
            Text(rotulo, style: context.vTexto(28, peso: FontWeight.w800, cor: tinta, altura: 1)),
          ]),
        ),
      ),
    );
  }
}
