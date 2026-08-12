import 'package:flutter/material.dart';
import '../../core/util/moeda.dart';
import '../../data/catalog/catalog_models.dart';
import '../catalogo/produto_imagem.dart';
import 'gogen_tokens.dart';

/// "Peça também" no visual **GoGen**. VIEW PURA: recebe os sugeridos e os
/// callbacks do `PecaTambemScreen` (mesma lógica de upsell/redirect).
class GogenPecaTambemView extends StatelessWidget {
  const GogenPecaTambemView({
    super.key,
    required this.sugeridos,
    required this.onAdicionar,
    required this.onVoltar,
    required this.onContinuar,
  });

  final List<Produto> sugeridos;
  final void Function(Produto) onAdicionar;
  final VoidCallback onVoltar;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GogenColors.cream,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: onVoltar,
                icon: const Icon(Icons.arrow_back_rounded, color: GogenColors.ink, size: 30),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Peça também',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: GogenColors.ink)),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 2, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Que tal turbinar o pedido?',
                  style: TextStyle(fontSize: 17, color: GogenColors.ink2)),
            ),
          ),
          Expanded(
            child: sugeridos.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(gradient: GogenColors.grad, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
                      ),
                      const SizedBox(height: 16),
                      const Text('Tudo certo! Adicionado ao pedido.',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: GogenColors.ink)),
                    ]),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisExtent: 128,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: sugeridos.length,
                    itemBuilder: (_, i) => _Card(
                      key: ValueKey('sugestao-${sugeridos[i].id}'),
                      produto: sugeridos[i],
                      onAdicionar: () => onAdicionar(sugeridos[i]),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: _BtnSecundario(
                    chave: 'peca-tambem-pular',
                    rotulo: 'Agora não',
                    onTap: onContinuar,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BtnFlame(
                    chave: 'peca-tambem-continuar',
                    rotulo: 'Continuar',
                    onTap: onContinuar,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.produto, required this.onAdicionar});
  final Produto produto;
  final VoidCallback onAdicionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GogenColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        SizedBox(
          width: 76,
          height: 76,
          child: ProdutoImagem(url: produto.imagemUrl, borderRadius: BorderRadius.circular(14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(produto.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: GogenColors.ink)),
              const SizedBox(height: 4),
              Text(formatCentavos(produto.precoCentavos),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: GogenColors.flame1)),
            ],
          ),
        ),
        InkWell(
          onTap: onAdicionar,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: GogenColors.grad, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ]),
    );
  }
}

class _BtnFlame extends StatelessWidget {
  const _BtnFlame({required this.chave, required this.rotulo, required this.onTap});
  final String chave;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(chave),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(gradient: GogenColors.grad, borderRadius: BorderRadius.circular(999)),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              child: Text(rotulo,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
            ),
          ),
        ),
      );
}

class _BtnSecundario extends StatelessWidget {
  const _BtnSecundario({required this.chave, required this.rotulo, required this.onTap});
  final String chave;
  final String rotulo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        key: ValueKey(chave),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 64),
          foregroundColor: GogenColors.ink,
          side: const BorderSide(color: Color(0x1A000000), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        child: Text(rotulo),
      );
}
