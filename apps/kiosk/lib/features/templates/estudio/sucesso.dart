import 'package:flutter/material.dart';
import '../comum/sucesso_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'estudio_tokens.dart';
import 'estudio_widgets.dart';

const _t = estudioTokens;

/// Confirmação do Estúdio (docs/03 §6.8 + 00 §4.8): check no acento com anel, cartão
/// branco com a senha em Sora 800 170 contando até o número, recibo saindo da impressora
/// (quando imprimiu) e confete. Os AVISOS DE SEGURANÇA são os da GoGen, com os mesmos
/// textos e chaves (ERR-022): pague no caixa (`dinheiro`), comprovante não impresso
/// (`impresso: false`) e cupom fiscal não impresso (`fiscal: false`). VIEW PURA: o timer
/// de volta ao início e a navegação ficam na `ConfirmacaoScreen`.
class EstudioSucesso extends StatelessWidget {
  const EstudioSucesso({super.key, required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final mov = p.mov;
    final dinheiro = p.dinheiro;
    return TelaEstudio(
      mov: mov,
      child: Stack(children: [
        Column(children: [
          Padding(
            padding: EdgeInsets.only(top: 44 * k),
            child: const Center(child: LogoDaLoja(escala: .9)),
          ),
          Expanded(
            child: CorpoEstudio(
              centro: true,
              inicio: [
                SizedBox(height: 16 * k),
                SizedBox(
                  width: 190 * k,
                  height: 190 * k,
                  child: OverflowBox(
                    maxWidth: 190 * 1.6 * k,
                    maxHeight: 190 * 1.6 * k,
                    child: CheckPulsante(
                      cor: _t.accent,
                      tinta: _t.onAccent,
                      mov: mov,
                      icone: dinheiro ? Icons.payments_rounded : Icons.check_rounded,
                    ),
                  ),
                ),
                SizedBox(height: 24 * k),
                Kicker(dinheiro ? 'Dirija-se ao caixa para pagar' : 'Pagamento aprovado'),
                SizedBox(height: 18 * k),
                TituloTela(dinheiro ? 'Pedido enviado!' : 'Pedido confirmado!', centro: true, tamanho: 88),
                SizedBox(height: 28 * k),
                _Senha(p: p),
                if (dinheiro) ...[
                  SizedBox(height: 20 * k),
                  const _AvisoCaixa(),
                ],
                if (!p.impresso) ...[
                  SizedBox(height: 20 * k),
                  const _AvisoFalha(
                    chave: 'aviso-sem-cupom',
                    icone: Icons.receipt_long_rounded,
                    texto: 'cupom não impresso — ANOTE A SENHA e informe o balcão',
                  ),
                ],
                if (!p.fiscal) ...[
                  SizedBox(height: 20 * k),
                  const _AvisoFalha(
                    chave: 'aviso-sem-nota',
                    icone: Icons.description_outlined,
                    texto: 'cupom fiscal não impresso — retire no balcão com a senha',
                  ),
                ],
                if (p.impresso) ...[
                  SizedBox(height: 28 * k),
                  ComAparencia(
                    builder: (_, ap) => ReciboImpresso(
                      senha: p.senha,
                      nomeLoja: ap?.nomeLoja,
                      tokens: _t,
                      mov: mov,
                      corFenda: EstudioCores.fenda,
                    ),
                  ),
                ],
              ],
            ),
          ),
          RodapeEstudio(
            linha: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: double.infinity,
                child: BotaoEstudio(
                  chave: 'novo-pedido',
                  rotulo: 'Fazer novo pedido',
                  tipo: TipoBotao.soft,
                  onTap: p.onNovoPedido,
                ),
              ),
              if (p.segundos > 0) ...[
                SizedBox(height: 18 * k),
                Text('Voltando ao início em ${p.segundos} s',
                    key: const ValueKey('contador-standby'),
                    style: _t.texto(24 * k, peso: FontWeight.w400, cor: _t.muted)),
              ],
            ]),
          ),
        ]),
        if (mov.particulas && mov.anima)
          Positioned.fill(
            child: RepaintBoundary(
              child: Confete(
                cores: [_t.accent, _t.accent2, _t.text, EstudioCores.branco],
                mov: mov,
              ),
            ),
          ),
      ]),
    );
  }
}

/// Cartão branco com "Sua senha", a senha gigante (conta até o número) e a frase do painel.
class _Senha extends StatelessWidget {
  const _Senha({required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(48 * k, 28 * k, 48 * k, 32 * k),
      decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(_t.raio * k)),
      child: Column(children: [
        Text('Sua senha', style: _t.texto(28 * k, peso: FontWeight.w400, cor: _t.muted)),
        SizedBox(height: 6 * k),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ContagemSenha(
            senha: p.senha,
            mov: p.mov,
            estilo: _t.display(170 * k, cor: _t.accent, altura: 1).copyWith(letterSpacing: -170 * .04 * k),
          ),
        ),
        SizedBox(height: 10 * k),
        Text('Vamos chamar sua senha no painel',
            textAlign: TextAlign.center,
            style: _t.texto(32 * k, peso: FontWeight.w400, altura: 1.4)),
      ]),
    );
  }
}

/// Pedido em dinheiro: pagar no caixa para retirar (textos da GoGen).
class _AvisoCaixa extends StatelessWidget {
  const _AvisoCaixa();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: const ValueKey('aviso-caixa'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 32 * k, vertical: 24 * k),
      decoration: BoxDecoration(
        color: _t.hi,
        borderRadius: BorderRadius.circular((_t.raio - 8) * k),
        border: Border.all(color: _t.accent, width: 3 * k),
      ),
      child: Column(children: [
        Icon(Icons.point_of_sale_rounded, size: 52 * k, color: _t.accent),
        SizedBox(height: 10 * k),
        Text('PAGUE NO CAIXA PARA RETIRAR',
            textAlign: TextAlign.center,
            style: _t.texto(32 * k, peso: FontWeight.w800, espaco: 32 * .04 * k)),
        SizedBox(height: 6 * k),
        Text('dirija-se ao caixa, informe a senha e efetue o pagamento',
            textAlign: TextAlign.center,
            style: _t.texto(26 * k, peso: FontWeight.w600, cor: _t.muted, altura: 1.3)),
      ]),
    );
  }
}

/// Comprovante ou cupom fiscal que não saiu no papel (textos da GoGen).
class _AvisoFalha extends StatelessWidget {
  const _AvisoFalha({required this.chave, required this.icone, required this.texto});
  final String chave;
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      key: ValueKey(chave),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 28 * k, vertical: 20 * k),
      decoration: BoxDecoration(
        color: _t.err.withAlpha(22),
        borderRadius: BorderRadius.circular((_t.raio - 14) * k),
        border: Border.all(color: _t.err, width: 3 * k),
      ),
      child: Row(children: [
        Icon(icone, size: 40 * k, color: _t.err),
        SizedBox(width: 16 * k),
        Expanded(
          child: Text(texto, style: _t.texto(28 * k, peso: FontWeight.w800, cor: _t.err, altura: 1.3)),
        ),
      ]),
    );
  }
}
