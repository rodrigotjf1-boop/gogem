import 'package:flutter/material.dart';
import '../../../core/util/moeda.dart';
import '../../../data/catalog/catalog_models.dart';
import '../../../domain/order/sugestoes.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// "Peça também" do Estúdio (docs/03 §6.5 + 00 §4.5): cartão central branco com até 3
/// sugestões. O item adicionado ganha borda no acento, fundo `hi` e ✓; o botão principal
/// é "Seguir sem sugestão" até alguém adicionar, e "Continuar" depois. VIEW PURA: a
/// lógica de pular quando não há sugestões continua na `PecaTambemScreen`.
class EstudioPecaTambem extends StatefulWidget {
  const EstudioPecaTambem({super.key, required this.p});
  final PecaTambemProps p;

  @override
  State<EstudioPecaTambem> createState() => _EstudioPecaTambemState();
}

class _EstudioPecaTambemState extends State<EstudioPecaTambem> with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;

  /// As sugestões da PRIMEIRA vez: a tela recalcula a lista a cada mudança da sacola e o
  /// item adicionado sai dela — aqui ele continua à vista, marcado com ✓.
  late final List<Produto> _mostrados;
  final _adicionados = <String>{};

  @override
  void initState() {
    super.initState();
    _mostrados = widget.p.sugeridos.take(3).toList();
    _entrada = AnimationController(vsync: this, duration: widget.p.mov.d(500));
    if (widget.p.mov.anima) {
      _entrada.forward();
    } else {
      _entrada.value = 1;
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _adicionar(Produto produto) {
    // Com etapa obrigatória a tela abre o produto: não marca como adicionado aqui.
    if (!temEtapaObrigatoria(produto)) setState(() => _adicionados.add(produto.id));
    widget.p.onAdicionar(produto);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final k = context.k;
    // Some da vista o que deixou de ser sugerido sem ter sido adicionado (ex.: acabou).
    final lista = [
      for (final s in _mostrados)
        if (_adicionados.contains(s.id) || p.sugeridos.any((x) => x.id == s.id)) s
    ];
    return TelaEstudio(
      entrada: false,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: EstudioCores.cortina),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 64 * k, vertical: 40 * k),
            child: AnimatedBuilder(
              animation: _entrada,
              builder: (_, child) {
                final v = curvaPulo.transform(_entrada.value);
                return Opacity(
                  opacity: _entrada.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 60 * k * (1 - v)),
                    child: Transform.scale(scale: .9 + .1 * v, child: child),
                  ),
                );
              },
              child: _Cartao(
                lista: lista,
                adicionados: _adicionados,
                mov: p.mov,
                onAdicionar: _adicionar,
                onVoltar: p.onVoltar,
                onContinuar: p.onContinuar,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.lista,
    required this.adicionados,
    required this.mov,
    required this.onAdicionar,
    required this.onVoltar,
    required this.onContinuar,
  });

  final List<Produto> lista;
  final Set<String> adicionados;
  final Movimento mov;
  final void Function(Produto) onAdicionar;
  final VoidCallback onVoltar;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: const ValueKey('peca-tambem-cartao'),
      padding: EdgeInsets.fromLTRB(50 * k, 56 * k, 50 * k, 50 * k),
      decoration: BoxDecoration(
        color: EstudioCores.fundoModal,
        borderRadius: BorderRadius.circular((_t.raio + 10) * k),
        boxShadow: sombraModal(k),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Peça também',
            textAlign: TextAlign.center,
            style: _t.display(68 * k, altura: 1.02).copyWith(letterSpacing: -68 * .03 * k)),
        SizedBox(height: 26 * k),
        Text('Toque para adicionar. Dá pra tirar depois.',
            textAlign: TextAlign.center,
            style: _t.texto(30 * k, peso: FontWeight.w400, cor: _t.muted, altura: 1.4)),
        SizedBox(height: 26 * k),
        LayoutBuilder(builder: (context, c) {
          final espaco = 18 * k;
          final largura = (c.maxWidth - 2 * espaco) / 3;
          return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < lista.length; i++) ...[
              if (i > 0) SizedBox(width: espaco),
              SizedBox(
                width: largura,
                child: _Sugestao(
                  p: lista[i],
                  cor: corDisco(i),
                  adicionado: adicionados.contains(lista[i].id),
                  mov: mov,
                  onTap: () => onAdicionar(lista[i]),
                ),
              ),
            ],
          ]);
        }),
        SizedBox(height: 26 * k),
        Row(children: [
          BotaoEstudio(
            chave: 'peca-tambem-voltar',
            rotulo: 'Voltar',
            tipo: TipoBotao.contorno,
            icone: Icons.chevron_left_rounded,
            onTap: onVoltar,
          ),
          SizedBox(width: 18 * k),
          Expanded(
            child: BotaoEstudio(
              chave: 'peca-tambem-continuar',
              rotulo: adicionados.isEmpty ? 'Seguir sem sugestão' : 'Continuar',
              iconeDepois: Icons.arrow_forward_rounded,
              onTap: onContinuar,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Sugestao extends StatelessWidget {
  const _Sugestao({
    required this.p,
    required this.cor,
    required this.adicionado,
    required this.mov,
    required this.onTap,
  });
  final Produto p;
  final Color cor;
  final bool adicionado;
  final Movimento mov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final raio = BorderRadius.circular((_t.raio - 6) * k);
    return GestureDetector(
      key: ValueKey('sugestao-${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: adicionado ? null : onTap,
      child: AnimatedContainer(
        duration: duracao(mov, 250),
        padding: EdgeInsets.fromLTRB(14 * k, 14 * k, 14 * k, 20 * k),
        decoration: BoxDecoration(
          color: adicionado ? _t.hi : _t.surface,
          borderRadius: raio,
          border: Border.all(color: adicionado ? _t.accent : _t.line, width: 3 * k),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 210 * k,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular((_t.raio - 14) * k),
                child: ColoredBox(
                  color: _t.art,
                  child: ArteEstudio(url: p.imagemUrl, corDisco: cor, disco: .9, foto: .82, mov: mov),
                ),
              ),
              Positioned(
                top: 10 * k,
                right: 10 * k,
                child: Container(
                  width: 62 * k,
                  height: 62 * k,
                  decoration: BoxDecoration(color: _t.accent, shape: BoxShape.circle),
                  child: Icon(adicionado ? Icons.check_rounded : Icons.add_rounded,
                      key: ValueKey(adicionado ? 'sugestao-ok-${p.id}' : 'sugestao-mais-${p.id}'),
                      size: 36 * k,
                      color: _t.onAccent),
                ),
              ),
            ]),
          ),
          SizedBox(height: 8 * k),
          Text(p.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _t.texto(26 * k, peso: FontWeight.w700, altura: 1.15)),
          SizedBox(height: 8 * k),
          Text(formatCentavos(p.precoCentavos), style: _t.texto(26 * k, peso: FontWeight.w800, cor: _t.price)),
        ]),
      ),
    );
  }
}
