import 'package:flutter/material.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/catalog_models.dart';
import '../../domain/order/order_models.dart';
import '../catalogo/produto_imagem.dart';
import 'gogen_tokens.dart';

/// Tela de produto no visual **GoGen** (claro/flame). VIEW PURA: recebe o estado
/// e os callbacks do `ProdutoScreen` (mesma lógica de seleção/validação/preço),
/// então nada de regra de negócio duplicada aqui.
class GogenProdutoView extends StatelessWidget {
  const GogenProdutoView({
    super.key,
    required this.produto,
    required this.selecoes,
    required this.qtd,
    required this.valido,
    required this.totalCentavos,
    required this.onToggle,
    required this.onMenos,
    required this.onMais,
    required this.onAdicionar,
    required this.onVoltar,
  });

  final Produto produto;
  final Map<String, List<OpcaoComplemento>> selecoes;
  final int qtd;
  final bool valido;
  final int totalCentavos;
  final void Function(GrupoComplemento, OpcaoComplemento) onToggle;
  final VoidCallback onMenos;
  final VoidCallback onMais;
  final VoidCallback onAdicionar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final p = produto;
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
            child: Row(children: [
              IconButton(
                onPressed: onVoltar,
                icon: const Icon(Icons.arrow_back_rounded, color: GogenColors.ink, size: 30),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                if (p.imagemUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ProdutoImagem(url: p.imagemUrl, borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                if (p.descricao.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(p.descricao,
                        style: const TextStyle(fontSize: 16, color: GogenColors.ink2)),
                  ),
                for (final g in p.grupos)
                  _GrupoCard(
                    grupo: g,
                    selecionadas: selecoes[g.id] ?? const [],
                    onToggle: (o) => onToggle(g, o),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _Rodape(
            qtd: qtd,
            onMenos: onMenos,
            onMais: onMais,
            habilitado: valido,
            totalCentavos: totalCentavos,
            onAdicionar: onAdicionar,
          ),
        ]),
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  const _GrupoCard({required this.grupo, required this.selecionadas, required this.onToggle});
  final GrupoComplemento grupo;
  final List<OpcaoComplemento> selecionadas;
  final void Function(OpcaoComplemento) onToggle;

  @override
  Widget build(BuildContext context) {
    final min = minEfetivo(grupo);
    final ok = selecaoValida(grupo, selecionadas);
    final regra = grupo.max <= 1
        ? (min > 0 ? 'escolha 1' : 'até 1')
        : (min > 0 ? 'escolha $min a ${grupo.max}' : 'até ${grupo.max}');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GogenColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ok ? const Color(0x11000000) : GogenColors.flame2,
          width: ok ? 1 : 2,
        ),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(grupo.nome,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: GogenColors.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: ok ? GogenColors.ok.withValues(alpha: 0.12) : GogenColors.flame1.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(regra,
                key: ValueKey('regra-${grupo.id}'),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ok ? GogenColors.ok : GogenColors.flame1)),
          ),
        ]),
        const SizedBox(height: 6),
        for (final o in grupo.opcoes)
          _OpcaoTile(
            opcao: o,
            marcada: selecionadas.any((x) => x.id == o.id),
            radio: grupo.max <= 1,
            onTap: () => onToggle(o),
          ),
      ]),
    );
  }
}

class _OpcaoTile extends StatelessWidget {
  const _OpcaoTile({required this.opcao, required this.marcada, required this.radio, required this.onTap});
  final OpcaoComplemento opcao;
  final bool marcada;
  final bool radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('op-${opcao.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          _Marca(marcada: marcada, radio: radio),
          const SizedBox(width: 12),
          if (opcao.imagemUrl != null) ...[
            SizedBox(
              width: 46,
              height: 46,
              child: ProdutoImagem(url: opcao.imagemUrl, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(opcao.nome,
                style: const TextStyle(fontSize: 17, color: GogenColors.ink, fontWeight: FontWeight.w600)),
          ),
          if (opcao.precoCentavosDelta != 0)
            Text('+ ${formatCentavos(opcao.precoCentavosDelta)}',
                style: const TextStyle(fontSize: 16, color: GogenColors.flame1, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Marcador: círculo (rádio) ou quadrado (múltipla), preenchido em flame.
class _Marca extends StatelessWidget {
  const _Marca({required this.marcada, required this.radio});
  final bool marcada;
  final bool radio;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: marcada ? GogenColors.grad : null,
        color: marcada ? null : Colors.white,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : BorderRadius.circular(9),
        border: Border.all(color: marcada ? Colors.transparent : const Color(0x33000000), width: 2),
      ),
      child: marcada ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _QtdBtn(icon: Icons.remove_rounded, onTap: onMenos),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('$qtd',
                key: const ValueKey('qtd'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
          ),
          _QtdBtn(icon: Icons.add_rounded, onTap: onMais),
          const SizedBox(width: 18),
          Expanded(
            child: Opacity(
              opacity: habilitado ? 1 : 0.4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('adicionar'),
                  onTap: habilitado ? onAdicionar : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: GogenColors.grad,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Container(
                      height: 64,
                      alignment: Alignment.center,
                      child: Text('Adicionar · ${formatCentavos(totalCentavos)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _QtdBtn extends StatelessWidget {
  const _QtdBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: GogenColors.cream2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Icon(icon, color: GogenColors.ink, size: 28),
        ),
      );
}
