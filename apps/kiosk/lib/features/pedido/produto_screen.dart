import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/gogem_theme.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/catalog_models.dart';
import '../../data/catalog/catalog_sync.dart';
import '../catalogo/produto_imagem.dart';
import '../../domain/order/cart.dart';
import '../../domain/order/order_models.dart';

/// Configuração do produto: grupos de complementos com min/max/obrigatorio.
/// O botão ADICIONAR só habilita quando TODOS os grupos estão válidos e mostra
/// o total ao vivo (produto + deltas) × quantidade.
class ProdutoScreen extends ConsumerStatefulWidget {
  const ProdutoScreen({super.key, required this.produtoId});
  final String produtoId;
  @override
  ConsumerState<ProdutoScreen> createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends ConsumerState<ProdutoScreen> {
  final Map<String, List<OpcaoComplemento>> _sel = {};
  int _qtd = 1;

  void _toggle(GrupoComplemento g, OpcaoComplemento o) {
    setState(() {
      final atual = List<OpcaoComplemento>.from(_sel[g.id] ?? const []);
      final jaTem = atual.any((x) => x.id == o.id);
      if (jaTem) {
        atual.removeWhere((x) => x.id == o.id);
      } else if (g.max <= 1) {
        atual
          ..clear()
          ..add(o); // comportamento rádio quando max = 1
      } else if (atual.length < g.max) {
        atual.add(o);
      }
      _sel[g.id] = atual;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final menu = ref.watch(menuProvider).valueOrNull;
    final p = menu?.produtos.where((x) => x.id == widget.produtoId).firstOrNull;
    if (p == null) {
      return const Scaffold(body: Center(child: Text('Produto indisponível')));
    }
    final valido = p.grupos.every((g) => selecaoValida(g, _sel[g.id] ?? const []));
    final unit = p.precoCentavos +
        [for (final l in _sel.values) ...l]
            .fold<int>(0, (s, o) => s + o.precoCentavosDelta);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: GogemColors.ink, size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(p.nome, style: t.headlineMedium, maxLines: 1)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                if (p.imagemUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ProdutoImagem(
                        url: p.imagemUrl,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                if (p.descricao.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(p.descricao, style: t.bodyMedium),
                  ),
                for (final g in p.grupos) _GrupoCard(
                  grupo: g,
                  selecionadas: _sel[g.id] ?? const [],
                  onToggle: (o) => _toggle(g, o),
                ),
              ],
            ),
          ),
          _Rodape(
            qtd: _qtd,
            onMenos: () => setState(() => _qtd = _qtd > 1 ? _qtd - 1 : 1),
            onMais: () => setState(() => _qtd++),
            habilitado: valido,
            totalCentavos: unit * _qtd,
            onAdicionar: () {
              ref.read(cartProvider.notifier).adicionar(ItemCarrinho(
                    produto: p,
                    selecoes: Map.of(_sel),
                    quantidade: _qtd,
                  ));
              context.go('/carrinho');
            },
          ),
        ]),
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  const _GrupoCard(
      {required this.grupo, required this.selecionadas, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final void Function(OpcaoComplemento) onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final min = minEfetivo(grupo);
    final ok = selecaoValida(grupo, selecionadas);
    final regra = grupo.max <= 1
        ? (min > 0 ? 'escolha 1' : 'até 1')
        : (min > 0 ? 'escolha $min a ${grupo.max}' : 'até ${grupo.max}');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GogemColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ok ? GogemColors.line : GogemColors.cheese),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(grupo.nome.toUpperCase(), style: t.titleLarge)),
          Text(regra,
              key: ValueKey('regra-${grupo.id}'),
              style: TextStyle(
                  fontFamily: 'Tektur',
                  fontSize: 14,
                  color: ok ? GogemColors.mint : GogemColors.cheese)),
        ]),
        const SizedBox(height: 8),
        for (final o in grupo.opcoes)
          _OpcaoTile(
            opcao: o,
            marcada: selecionadas.any((x) => x.id == o.id),
            onTap: () => onToggle(o),
          ),
      ]),
    );
  }
}

class _OpcaoTile extends StatelessWidget {
  const _OpcaoTile({required this.opcao, required this.marcada, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('op-${opcao.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(marcada ? Icons.check_box : Icons.check_box_outline_blank,
              color: marcada ? GogemColors.mint : GogemColors.inkDim, size: 30),
          const SizedBox(width: 12),
          // Foto da opção (quando houver) — dá cara ao complemento.
          if (opcao.imagemUrl != null) ...[
            SizedBox(
              width: 44,
              height: 44,
              child: ProdutoImagem(
                url: opcao.imagemUrl,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(opcao.nome, style: t.bodyLarge)),
          if (opcao.precoCentavosDelta != 0)
            Text('+ ${formatCentavos(opcao.precoCentavosDelta)}',
                style: t.bodyLarge?.copyWith(color: GogemColors.cheese)),
        ]),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.qtd,
    required this.onMenos,
    required this.onMais,
    required this.habilitado,
    required this.totalCentavos,
    required this.onAdicionar,
  });
  final int qtd;
  final VoidCallback onMenos, onMais, onAdicionar;
  final bool habilitado;
  final int totalCentavos;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: GogemColors.line))),
        child: Row(children: [
          _QtdBtn(icon: Icons.remove, onTap: onMenos),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$qtd',
                key: const ValueKey('qtd'),
                style: const TextStyle(fontFamily: 'Tektur', fontSize: 28)),
          ),
          _QtdBtn(icon: Icons.add, onTap: onMais),
          const SizedBox(width: 20),
          Expanded(
            child: FilledButton(
              key: const ValueKey('adicionar'),
              onPressed: habilitado ? onAdicionar : null,
              child: Text('ADICIONAR · ${formatCentavos(totalCentavos)}'),
            ),
          ),
        ]),
      );
}

class _QtdBtn extends StatelessWidget {
  const _QtdBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: GogemColors.line),
            borderRadius: BorderRadius.circular(14),
            color: GogemColors.panel,
          ),
          child: Icon(icon, color: GogemColors.ink, size: 28),
        ),
      );
}
