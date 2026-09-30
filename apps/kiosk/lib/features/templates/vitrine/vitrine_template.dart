import 'package:flutter/widgets.dart';
import '../kiosk_template.dart';
import '../template_tokens.dart';
import 'carrinho.dart';
import 'catalogo.dart';
import 'descanso.dart';
import 'identificacao.dart';
import 'pagamento.dart';
import 'peca_tambem.dart';
import 'produto.dart';
import 'sucesso.dart';
import 'vitrine_tokens.dart';

/// Template **Vitrine** — cardápio em stories (`temaPreset: 'vitrine'`, docs/templates/02).
/// Cada produto ocupa a tela inteira com a foto em close; texto e botões flutuam em vidro
/// fosco por cima da comida. Só apresentação: a regra do pedido continua nas telas.
class VitrineTemplate extends KioskTemplate {
  const VitrineTemplate();

  @override
  TemplateTokens get tokens => vitrineTokens;

  @override
  Widget descanso(DescansoProps p) => VitrineDescanso(p: p);

  @override
  Widget catalogo() => const VitrineCatalogoScreen();

  @override
  Widget carrinho() => const VitrineCarrinhoScreen();

  @override
  Widget produto(ProdutoProps p) => VitrineProdutoView(p: p);

  @override
  Widget pecaTambem(PecaTambemProps p) => VitrinePecaTambemView(p: p);

  @override
  Widget identificacao(IdentificacaoProps p) => VitrineIdentificacaoView(p: p);

  @override
  Widget pagamento(PagamentoProps p) => VitrinePagamentoView(p: p);

  @override
  Widget sucesso(SucessoProps p) => VitrineSucessoView(p: p);
}
