import 'package:flutter/widgets.dart';
import '../kiosk_template.dart';
import '../template_tokens.dart';
import 'carrinho.dart';
import 'catalogo.dart';
import 'descanso.dart';
import 'estudio_tokens.dart';
import 'identificacao.dart';
import 'pagamento.dart';
import 'peca_tambem.dart';
import 'produto.dart';
import 'sucesso.dart';

/// Template **Estúdio** (`temaPreset: 'estudio'`, docs/templates/03-estudio.md): fundo
/// claro de estúdio fotográfico, produtos flutuando sobre discos de cor, carrossel no
/// descanso e cards que inclinam em 3D ao toque. Só desenha — a lógica continua nas telas.
class EstudioTemplate extends KioskTemplate {
  const EstudioTemplate();

  @override
  TemplateTokens get tokens => estudioTokens;

  @override
  Widget descanso(DescansoProps p) => EstudioDescanso(p: p);

  @override
  Widget catalogo() => const EstudioCatalogo();

  @override
  Widget carrinho() => const EstudioCarrinho();

  @override
  Widget produto(ProdutoProps p) => EstudioProduto(p: p);

  @override
  Widget pecaTambem(PecaTambemProps p) => EstudioPecaTambem(p: p);

  @override
  Widget identificacao(IdentificacaoProps p) => EstudioIdentificacao(p: p);

  @override
  Widget pagamento(PagamentoProps p) => EstudioPagamento(p: p);

  @override
  Widget sucesso(SucessoProps p) => EstudioSucesso(p: p);
}
