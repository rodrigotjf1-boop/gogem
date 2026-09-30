import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/aparencia.dart';
import '../../../data/catalog/catalog_sync.dart';
import '../comum/sucesso_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'diner_comum.dart';
import 'diner_tokens.dart';

const _t = dinerTokens;

/// Confirmação do **Diner 58** (docs/templates/05 §6.8 e 00 §4.8): check vermelho com anel
/// pulsando, "Pedido confirmado!" em Bungee, a senha gigante num cartão de borda tracejada,
/// o recibo saindo da impressora e confete. Os AVISOS DE SEGURANÇA são os da GoGen — mesmos
/// textos, mesmas condições e mesmas chaves (ERR-022 / V20): pague no caixa (`dinheiro`),
/// comprovante não impresso (`impresso == false`) e nota fiscal não impressa
/// (`fiscal == false`). O timer de volta e a navegação ficam na `ConfirmacaoScreen`.
class DinerSucesso extends ConsumerWidget {
  const DinerSucesso({super.key, required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(aparenciaProvider).valueOrNull ?? Aparencia.padrao;
    final mov = p.mov;
    final nomeLoja = (ap.nomeLoja ?? '').trim();
    return DinerTema(
      child: Scaffold(
        backgroundColor: _t.bg,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(44), context.dz(56), context.dz(30)),
                  child: Column(children: [
                    DinerLogo(nomeLoja: ap.nomeLoja, logoUrl: ap.logoUrl, escala: .9),
                    SizedBox(height: context.dz(6)),
                    Stack(alignment: Alignment.center, children: [
                      // Sem animação, o anel fica parado em volta do selo (como no mockup).
                      if (!mov.anima)
                        Container(
                          width: context.dz(280),
                          height: context.dz(280),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _t.accent.withAlpha(70), width: context.dz(6)),
                          ),
                        ),
                      CheckPulsante(
                        cor: _t.accent,
                        tinta: _t.onAccent,
                        mov: mov,
                        tamanho: 190,
                        icone: p.dinheiro ? Icons.payments_outlined : Icons.check_rounded,
                      ),
                    ]),
                    Text(
                      (p.dinheiro ? 'Dirija-se ao caixa para pagar' : 'Pagamento aprovado').toUpperCase(),
                      key: const ValueKey('sucesso-kicker'),
                      textAlign: TextAlign.center,
                      style: dinerKicker(context),
                    ),
                    SizedBox(height: context.dz(18)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(p.dinheiro ? 'Pedido enviado!' : 'Pedido confirmado!',
                          style: _t.display(context.dz(88), altura: 1.05)),
                    ),
                    SizedBox(height: context.dz(24)),
                    CaixaTracejada(
                      key: const ValueKey('sucesso-senha'),
                      padding: EdgeInsets.symmetric(horizontal: context.dz(48), vertical: context.dz(28)),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(children: [
                          Text('Sua senha', style: _t.texto(context.dz(28), cor: _t.muted)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ContagemSenha(
                              senha: p.senha,
                              mov: mov,
                              estilo: _t.display(context.dz(170), cor: _t.accent, altura: 1.05),
                            ),
                          ),
                          SizedBox(height: context.dz(6)),
                          Text('Vamos chamar sua senha no painel',
                              textAlign: TextAlign.center, style: _t.texto(context.dz(32), altura: 1.4)),
                        ]),
                      ),
                    ),
                    if (p.dinheiro)
                      const _Aviso(
                        chave: 'aviso-caixa',
                        icone: Icons.point_of_sale_rounded,
                        titulo: 'PAGUE NO CAIXA PARA RETIRAR',
                        texto: 'dirija-se ao caixa, informe a senha e efetue o pagamento',
                      ),
                    if (!p.impresso)
                      const _Aviso(
                        chave: 'aviso-sem-cupom',
                        icone: Icons.receipt_long_outlined,
                        texto: 'cupom não impresso — ANOTE A SENHA e informe o balcão',
                      ),
                    if (!p.fiscal)
                      const _Aviso(
                        chave: 'aviso-sem-nota',
                        icone: Icons.description_outlined,
                        texto: 'cupom fiscal não impresso — retire no balcão com a senha',
                      ),
                    if (p.impresso) ...[
                      SizedBox(height: context.dz(30)),
                      ReciboImpresso(
                        senha: p.senha,
                        nomeLoja: nomeLoja.isEmpty ? 'Diner 58' : nomeLoja,
                        tokens: _t,
                        mov: mov,
                        corFenda: const Color(0xFF222222),
                      ),
                    ],
                  ]),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(48)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: double.infinity,
                    child: DinerBotao(
                      key: const ValueKey('novo-pedido'),
                      rotulo: 'Fazer novo pedido',
                      estilo: DinerEstilo.suave,
                      expandir: true,
                      onTap: p.onNovoPedido,
                    ),
                  ),
                  if (p.segundos > 0) ...[
                    SizedBox(height: context.dz(18)),
                    Text('Voltando ao início em ${p.segundos} s',
                        key: const ValueKey('contador-standby'), style: _t.texto(context.dz(24), cor: _t.muted)),
                  ],
                ]),
              ),
            ]),
            Positioned.fill(
              child: IgnorePointer(
                child: Confete(
                  cores: [_t.accent, _t.accent2, _t.text, const Color(0xFFFFFFFF)],
                  mov: mov,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Aviso de segurança da confirmação: caixa `hi` com borda vermelha e ícone.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.chave, required this.icone, required this.texto, this.titulo});
  final String chave;
  final IconData icone;
  final String? titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.dz(20)),
      child: Container(
        key: ValueKey(chave),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(20)),
        decoration: BoxDecoration(
          color: _t.hi,
          borderRadius: BorderRadius.circular(context.dz(24)),
          border: Border.all(color: _t.accent, width: context.dz(3)),
        ),
        child: Row(children: [
          Icon(icone, size: context.dz(48), color: _t.accent),
          SizedBox(width: context.dz(18)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (titulo != null) Text(titulo!, style: _t.texto(context.dz(30), peso: FontWeight.w900, cor: _t.text)),
              Text(texto,
                  style: _t.texto(context.dz(titulo == null ? 28 : 24),
                      peso: titulo == null ? FontWeight.w900 : FontWeight.w800,
                      cor: titulo == null ? _t.accent : _t.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
