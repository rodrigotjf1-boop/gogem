import 'package:flutter/widgets.dart';
import '../kiosk_template.dart';
import '../template_tokens.dart';
import 'brasa2_tokens.dart';
import 'carrinho.dart';
import 'catalogo.dart';
import 'descanso.dart';
import 'identificacao.dart';
import 'pagamento.dart';
import 'peca_tambem.dart';
import 'produto.dart';
import 'sucesso.dart';

/// Template **Brasa 2.0** (`temaPreset: 'brasa2'`, docs/templates/01): steakhouse premium
/// com fogo — descanso com foto em Ken Burns e brasas subindo, o resto escuro e aconchegante,
/// fotos com brilho laranja por trás, títulos em DM Serif Display e preços em âmbar.
///
/// Só desenha: a lógica (sacola, portões, PIX/Point, fiscal, inatividade) continua nas telas.
class Brasa2Template extends KioskTemplate {
  const Brasa2Template();

  @override
  TemplateTokens get tokens => brasa2Tokens;

  @override
  Widget descanso(DescansoProps p) => Brasa2Descanso(p);

  @override
  Widget catalogo() => const Brasa2Catalogo();

  @override
  Widget carrinho() => const Brasa2Carrinho();

  @override
  Widget produto(ProdutoProps p) => Brasa2Produto(p);

  @override
  Widget pecaTambem(PecaTambemProps p) => Brasa2PecaTambem(p);

  @override
  Widget identificacao(IdentificacaoProps p) => Brasa2Identificacao(p);

  @override
  Widget pagamento(PagamentoProps p) => Brasa2Pagamento(p);

  @override
  Widget sucesso(SucessoProps p) => Brasa2Sucesso(p);
}
