import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/catalog/catalog_sync.dart' show aparenciaProvider;
import '../comum/sucesso_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'vitrine_tokens.dart';
import 'vitrine_ui.dart';

/// Confirmação do Vitrine (docs/templates/02 §6.8 e 00 §4.8): check `accent` de 190 com
/// anel pulsando, "Pedido confirmado!" em Syne 800 88, a senha em Syne 800 170 `accent`
/// contando, o recibo saindo (só quando imprimiu) e confete `[accent, accent2, branco]`.
///
/// Avisos de segurança (ERR-022/V20) com os MESMOS textos e chaves da GoGen:
/// `aviso-caixa` (dinheiro), `aviso-sem-cupom` (`impresso: false`) e `aviso-sem-nota`
/// (`fiscal: false`). O timer de volta ao início é da `ConfirmacaoScreen`.
class VitrineSucessoView extends StatelessWidget {
  const VitrineSucessoView({super.key, required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    final mov = p.mov;
    return Scaffold(
      backgroundColor: t.bg,
      body: EntradaVitrine(
        mov: mov,
        child: Stack(fit: StackFit.expand, children: [
          SafeArea(
            child: Column(children: [
              Padding(
                padding: EdgeInsets.only(top: context.dz(44)),
                child: const LogoVitrine(tamanho: 58 * .9),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(24), context.dz(56), context.dz(30)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (c.maxHeight - context.dz(54)).clamp(0.0, double.infinity),
                      ),
                      child: Column(children: [
                        CheckPulsante(
                          cor: t.accent,
                          tinta: t.onAccent,
                          mov: mov,
                          tamanho: 190,
                          icone: p.dinheiro ? Icons.payments_outlined : Icons.check_rounded,
                        ),
                        Text((p.dinheiro ? 'Dirija-se ao caixa para pagar' : 'Pagamento aprovado').toUpperCase(),
                            key: const ValueKey('sucesso-kicker'),
                            textAlign: TextAlign.center,
                            style: context.vKicker(26)),
                        SizedBox(height: context.dz(18)),
                        Text(p.dinheiro ? 'Pedido enviado!' : 'Pedido confirmado!',
                            textAlign: TextAlign.center, style: context.vDisplay(88, altura: 1)),
                        SizedBox(height: context.dz(30)),
                        _Senha(p: p),
                        if (p.dinheiro) ...[
                          SizedBox(height: context.dz(24)),
                          AvisoVitrine(
                            key: const ValueKey('aviso-caixa'),
                            icone: Icons.point_of_sale_rounded,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('PAGUE NO CAIXA PARA RETIRAR',
                                  style: context.vTexto(30, peso: FontWeight.w800, altura: 1.2)),
                              SizedBox(height: context.dz(6)),
                              Text('dirija-se ao caixa, informe a senha e efetue o pagamento',
                                  style: context.vTexto(24, peso: FontWeight.w600, cor: t.muted, altura: 1.3)),
                            ]),
                          ),
                        ],
                        if (!p.impresso) ...[
                          SizedBox(height: context.dz(20)),
                          AvisoVitrine(
                            key: const ValueKey('aviso-sem-cupom'),
                            icone: Icons.receipt_long_outlined,
                            child: Text('cupom não impresso — ANOTE A SENHA e informe o balcão',
                                style: context.vTexto(26, peso: FontWeight.w800, cor: t.accent, altura: 1.3)),
                          ),
                        ],
                        if (!p.fiscal) ...[
                          SizedBox(height: context.dz(20)),
                          AvisoVitrine(
                            key: const ValueKey('aviso-sem-nota'),
                            icone: Icons.description_outlined,
                            child: Text('cupom fiscal não impresso — retire no balcão com a senha',
                                style: context.vTexto(26, peso: FontWeight.w800, cor: t.accent, altura: 1.3)),
                          ),
                        ],
                        if (p.impresso) ...[
                          SizedBox(height: context.dz(28)),
                          _Recibo(p: p),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.dz(48), context.dz(22), context.dz(48), context.dz(40)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: double.infinity,
                    child: BotaoVitrine(
                      key: const ValueKey('novo-pedido'),
                      rotulo: 'Fazer novo pedido',
                      estilo: EstiloBotaoVitrine.suave,
                      mov: mov,
                      onTap: p.onNovoPedido,
                    ),
                  ),
                  if (p.segundos > 0) ...[
                    SizedBox(height: context.dz(18)),
                    Text('Voltando ao início em ${p.segundos} s',
                        key: const ValueKey('contador-standby'),
                        style: context.vTexto(24, peso: FontWeight.w400, cor: t.muted)),
                  ],
                ]),
              ),
            ]),
          ),
          // Confete por cima de tudo, sem pegar toque (só com partículas).
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Confete(cores: [t.accent, t.accent2, const Color(0xFFFFFFFF)], mov: mov),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Cartão "Sua senha" com a senha gigante contando e a frase do painel (Fase A: sem o
/// nome — o checkout é limpo antes da confirmação).
class _Senha extends StatelessWidget {
  const _Senha({required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    const t = vitrineTokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.dz(48), vertical: context.dz(28)),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(context.dz(t.raio))),
      child: Column(children: [
        Text('Sua senha', style: context.vTexto(28, peso: FontWeight.w400, cor: t.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ContagemSenha(
            senha: p.senha,
            mov: p.mov,
            estilo: context.vDisplay(170, cor: t.accent, altura: 1.05),
          ),
        ),
        SizedBox(height: context.dz(6)),
        Text('Vamos chamar sua senha no painel',
            textAlign: TextAlign.center, style: context.vTexto(32, peso: FontWeight.w400, altura: 1.4)),
      ]),
    );
  }
}

/// O recibo saindo da impressora (`ReciboImpresso` da base) com o nome da loja.
class _Recibo extends ConsumerWidget {
  const _Recibo({required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(aparenciaProvider).valueOrNull;
    return ReciboImpresso(
      senha: p.senha,
      nomeLoja: '${LogoVitrineMarca.nomeDaMarca(ap?.nomeLoja)}.',
      tokens: vitrineTokens,
      mov: p.mov,
      corFenda: vitrineTokens.surface2,
    );
  }
}
