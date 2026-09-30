import 'package:flutter/widgets.dart';
import '../kiosk_template.dart';
import '../template_tokens.dart';
import 'carrinho.dart';
import 'catalogo.dart';
import 'descanso.dart';
import 'diner_tokens.dart';
import 'identificacao.dart';
import 'pagamento.dart';
import 'peca_tambem.dart';
import 'produto.dart';
import 'sucesso.dart';

/// **Diner 58** — lanchonete americana dos anos 50 (`temaPreset: 'diner'`,
/// docs/templates/05). Template CLARO: creme, vermelho e menta, letreiro com lâmpadas em
/// perseguição, cardápio de lousa com botões jukebox e sombras "duras" marrons.
/// Só desenha: a lógica continua nas telas (docs/templates/00 §3.2).
class DinerTemplate extends KioskTemplate {
  const DinerTemplate();

  @override
  TemplateTokens get tokens => dinerTokens;

  @override
  Widget descanso(DescansoProps p) => DinerDescanso(p: p);

  @override
  Widget catalogo() => const DinerCatalogo();

  @override
  Widget carrinho() => const DinerCarrinho();

  @override
  Widget produto(ProdutoProps p) => DinerProduto(p: p);

  @override
  Widget pecaTambem(PecaTambemProps p) => DinerPecaTambem(p: p);

  @override
  Widget identificacao(IdentificacaoProps p) => DinerIdentificacao(p: p);

  @override
  Widget pagamento(PagamentoProps p) => DinerPagamento(p: p);

  @override
  Widget sucesso(SucessoProps p) => DinerSucesso(p: p);
}
