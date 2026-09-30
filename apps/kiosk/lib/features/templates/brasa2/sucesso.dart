import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../comum/sucesso_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import '../movimento.dart';
import 'brasa2_tokens.dart';
import 'brasa2_ui.dart';
import 'pintores/icones.dart';

const _t = brasa2Tokens;

/// Confirmação do **Brasa 2.0** (docs/templates/01 §6.8, 00 §4.8): check com anel pulsando,
/// "Pedido confirmado!", a senha gigante contando, o recibo saindo e o confete. Os avisos de
/// segurança são os MESMOS da GoGen, com as mesmas chaves (ERR-022/V20):
/// - `dinheiro` → "PAGUE NO CAIXA PARA RETIRAR" (`aviso-caixa`);
/// - `impresso == false` → "cupom não impresso — ANOTE A SENHA…" (`aviso-sem-cupom`);
/// - `fiscal == false` → "cupom fiscal não impresso — retire no balcão…" (`aviso-sem-nota`).
/// VIEW PURA: o auto-retorno e a navegação ficam no `ConfirmacaoScreen`.
class Brasa2Sucesso extends StatelessWidget {
  const Brasa2Sucesso(this.p, {super.key});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    final mov = p.mov;
    return Brasa2Tela(
      child: Stack(fit: StackFit.expand, children: [
        Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(44), context.dz(56), 0),
            child: const Center(child: Brasa2Marca(escala: .9, alinhamento: Alignment.center)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(20), context.dz(56), context.dz(30)),
              child: Column(children: [
                CheckPulsante(
                  cor: _t.accent,
                  tinta: _t.onAccent,
                  mov: mov,
                  tamanho: 190,
                  icone: p.dinheiro ? Icons.payments_outlined : Icons.check_rounded,
                ),
                Brasa2Kicker(p.dinheiro ? 'Dirija-se ao caixa para pagar' : 'Pagamento aprovado', espacoEm: .12),
                SizedBox(height: context.dz(18)),
                Text(p.dinheiro ? 'Pedido enviado!' : 'Pedido confirmado!',
                    key: const ValueKey('sucesso-titulo'),
                    textAlign: TextAlign.center,
                    style: brasaTitulo(context, 88)),
                SizedBox(height: context.dz(24)),
                Brasa2Entrada(
                  mov: mov,
                  atraso: const Duration(milliseconds: 300),
                  duracaoMs: 600,
                  subida: 24,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: context.dz(48), vertical: context.dz(28)),
                    decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
                    child: Column(children: [
                      Text('Sua senha', style: brasaTexto(context, 28, cor: _t.muted)),
                      SizedBox(height: context.dz(10)),
                      ContagemSenha(senha: p.senha, estilo: brasaTitulo(context, 170, cor: _t.accent), mov: mov),
                      SizedBox(height: context.dz(10)),
                      Text('Vamos chamar sua senha no painel',
                          textAlign: TextAlign.center, style: brasaTexto(context, 32, altura: 1.4)),
                    ]),
                  ),
                ),
                if (p.dinheiro) ...[
                  SizedBox(height: context.dz(24)),
                  const Brasa2Aviso(
                    key: ValueKey('aviso-caixa'),
                    icone: BrasaIcone.dinheiro,
                    titulo: 'PAGUE NO CAIXA PARA RETIRAR',
                    detalhe: 'dirija-se ao caixa, informe a senha e efetue o pagamento',
                  ),
                ],
                if (!p.impresso) ...[
                  SizedBox(height: context.dz(24)),
                  const Brasa2Aviso(
                    key: ValueKey('aviso-sem-cupom'),
                    titulo: 'cupom não impresso — ANOTE A SENHA e informe o balcão',
                  ),
                ],
                if (!p.fiscal) ...[
                  SizedBox(height: context.dz(24)),
                  const Brasa2Aviso(
                    key: ValueKey('aviso-sem-nota'),
                    titulo: 'cupom fiscal não impresso — retire no balcão com a senha',
                  ),
                ],
                if (p.impresso) ...[
                  SizedBox(height: context.dz(24)),
                  _Recibo(senha: p.senha, mov: mov),
                ],
              ]),
            ),
          ),
          Brasa2Rodape(semBorda: true, children: [
            Brasa2Botao(
              key: const ValueKey('novo-pedido'),
              rotulo: 'Fazer novo pedido',
              variante: Brasa2Variante.suave,
              fonte: 34,
              mov: mov,
              largura: double.infinity,
              onTap: p.onNovoPedido,
            ),
            if (p.segundos > 0)
              Text('Voltando ao início em ${p.segundos} s',
                  key: const ValueKey('contador-standby'),
                  textAlign: TextAlign.center,
                  style: brasaTexto(context, 24, cor: _t.muted)),
          ]),
        ]),
        if (mov.particulas && mov.anima)
          Positioned.fill(child: Confete(cores: brasa2CoresConfete, mov: mov)),
      ]),
    );
  }
}

/// O recibo da base, com o nome da loja quando a aparência está à mão.
class _Recibo extends StatelessWidget {
  const _Recibo({required this.senha, required this.mov});
  final String senha;
  final Movimento mov;

  @override
  Widget build(BuildContext context) {
    final temEscopo = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (!temEscopo) return ReciboImpresso(senha: senha, tokens: _t, mov: mov, nomeLoja: 'Brasa', corFenda: const Color(0xFF222222));
    return Consumer(builder: (context, ref, _) {
      final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
      final nome = (ap.nomeLoja ?? '').trim();
      return ReciboImpresso(
        senha: senha,
        tokens: _t,
        mov: mov,
        nomeLoja: nome.isEmpty ? 'Brasa' : nome,
        corFenda: const Color(0xFF222222),
      );
    });
  }
}
