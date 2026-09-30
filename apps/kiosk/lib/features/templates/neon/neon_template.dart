import 'package:flutter/widgets.dart';
import '../kiosk_template.dart';
import '../template_tokens.dart';
import 'carrinho.dart';
import 'catalogo.dart';
import 'descanso.dart';
import 'identificacao.dart';
import 'neon_tokens.dart';
import 'pagamento.dart';
import 'peca_tambem.dart';
import 'produto.dart';
import 'sucesso.dart';

/// Template **Neon 2.0** (`temaPreset: 'neon'`) — noite urbana com energia de fliperama
/// (docs/templates/04-neon-2.md). Só apresentação: a lógica continua nas telas.
class NeonTemplate extends KioskTemplate {
  const NeonTemplate();

  @override
  TemplateTokens get tokens => neonTokens;

  @override
  Widget descanso(DescansoProps p) => NeonDescanso(p: p);

  @override
  Widget catalogo() => const NeonCatalogoScreen();

  @override
  Widget carrinho() => const NeonCarrinhoScreen();

  @override
  Widget produto(ProdutoProps p) => NeonProdutoView(p: p);

  @override
  Widget pecaTambem(PecaTambemProps p) => NeonPecaTambemView(p: p);

  @override
  Widget identificacao(IdentificacaoProps p) => NeonIdentificacaoView(p: p);

  @override
  Widget pagamento(PagamentoProps p) => NeonPagamentoView(p: p);

  @override
  Widget sucesso(SucessoProps p) => NeonSucessoView(p: p);
}
