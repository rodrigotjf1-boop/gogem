import 'package:flutter/material.dart';
import '../comum/sucesso_comum.dart';
import '../escala.dart';
import '../kiosk_template.dart';
import 'neon_comum.dart';
import 'neon_tokens.dart';

const _t = neonTokens;

/// Confirmação do Neon 2.0 (docs/templates/04-neon-2.md §6.8 e 00 §4.8): check `accent`
/// com anel, "PEDIDO CONFIRMADO!" em Unbounded 88, senha em Unbounded 170 `accent` com
/// brilho, recibo saindo da impressora e confete [accent, accent2, ciano, branco].
///
/// Avisos de segurança (ERR-022/V20) com os MESMOS textos, condições e chaves da GoGen:
/// pague no caixa (`dinheiro`), comprovante não impresso (`impresso == false`) e cupom
/// fiscal não impresso (`fiscal == false`).
class NeonSucessoView extends StatelessWidget {
  const NeonSucessoView({super.key, required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    final mov = p.mov;
    return Scaffold(
      backgroundColor: _t.bg,
      body: Stack(children: [
        SafeArea(
          child: NeonEntrada(
            mov: mov,
            child: Column(children: [
              Expanded(
                child: CustomScrollView(slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(context.dz(56), context.dz(44), context.dz(56), context.dz(24)),
                      child: Column(children: [
                        const NeonMarca(escala: .9, centro: true),
                        SizedBox(height: context.dz(10)),
                        CheckPulsante(
                          cor: _t.accent,
                          tinta: _t.onAccent,
                          mov: mov,
                          tamanho: 190,
                          icone: p.dinheiro ? Icons.payments_outlined : Icons.check_rounded,
                        ),
                        Text(
                          (p.dinheiro ? 'Dirija-se ao caixa para pagar' : 'Pagamento aprovado').toUpperCase(),
                          key: const ValueKey('sucesso-kicker'),
                          textAlign: TextAlign.center,
                          style: neonTexto(context.dz(26), peso: FontWeight.w700, cor: _t.accent, espaco: .12),
                        ),
                        SizedBox(height: context.dz(14)),
                        Text(
                          _t.caixa(p.dinheiro ? 'Pedido enviado!' : 'Pedido confirmado!'),
                          key: const ValueKey('sucesso-titulo'),
                          textAlign: TextAlign.center,
                          style: neonDisplay(context.dz(88), altura: 1.02, espaco: -.03),
                        ),
                        SizedBox(height: context.dz(28)),
                        _Senha(p: p),
                        if (p.dinheiro) ...[
                          SizedBox(height: context.dz(20)),
                          const _Aviso(
                            chave: 'aviso-caixa',
                            icone: Icons.point_of_sale_rounded,
                            titulo: 'PAGUE NO CAIXA PARA RETIRAR',
                            texto: 'dirija-se ao caixa, informe a senha e efetue o pagamento',
                          ),
                        ],
                        if (!p.impresso) ...[
                          SizedBox(height: context.dz(20)),
                          const _Aviso(
                            chave: 'aviso-sem-cupom',
                            icone: Icons.receipt_long_rounded,
                            texto: 'cupom não impresso — ANOTE A SENHA e informe o balcão',
                          ),
                        ],
                        if (!p.fiscal) ...[
                          SizedBox(height: context.dz(20)),
                          const _Aviso(
                            chave: 'aviso-sem-nota',
                            icone: Icons.description_outlined,
                            texto: 'cupom fiscal não impresso — retire no balcão com a senha',
                          ),
                        ],
                        if (p.impresso) ...[
                          SizedBox(height: context.dz(26)),
                          ReciboImpresso(senha: p.senha, tokens: _t, mov: mov, corFenda: const Color(0xFF222222)),
                        ],
                        const Spacer(),
                        SizedBox(height: context.dz(30)),
                        SizedBox(
                          width: double.infinity,
                          child: NeonBotao(
                            key: const ValueKey('novo-pedido'),
                            rotulo: 'Fazer novo pedido',
                            tipo: NeonBotaoTipo.suave,
                            fonte: 30,
                            onTap: p.onNovoPedido,
                          ),
                        ),
                        if (p.segundos > 0) ...[
                          SizedBox(height: context.dz(18)),
                          Text('Voltando ao início em ${p.segundos} s',
                              key: const ValueKey('contador-standby'), style: neonTexto(context.dz(24), cor: _t.muted)),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Confete(cores: const [Color(0xFFC8FF2E), Color(0xFFFF3EA5), neonCiano, Color(0xFFFFFFFF)], mov: mov),
          ),
        ),
      ]),
    );
  }
}

/// Cartão da senha: "Sua senha" e a senha gigante em `accent` (com brilho no perfil forte).
class _Senha extends StatelessWidget {
  const _Senha({required this.p});
  final SucessoProps p;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.dz(48), vertical: context.dz(28)),
      decoration: BoxDecoration(color: _t.surface, borderRadius: BorderRadius.circular(context.dz(_t.raio))),
      child: Column(children: [
        Text('Sua senha', style: neonTexto(context.dz(28), cor: _t.muted)),
        SizedBox(height: context.dz(6)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ContagemSenha(
            senha: p.senha,
            mov: p.mov,
            estilo: neonDisplay(
              context.dz(170),
              cor: _t.accent,
              espaco: -.04,
              sombras: p.mov.brilho ? const [Shadow(color: Color(0x80C8FF2E), blurRadius: 30)] : null,
            ),
          ),
        ),
        SizedBox(height: context.dz(10)),
        Text('Vamos chamar sua senha no painel',
            textAlign: TextAlign.center, style: neonTexto(context.dz(32), altura: 1.4)),
      ]),
    );
  }
}

/// Aviso de segurança em destaque (borda e ícone em `accent2`).
class _Aviso extends StatelessWidget {
  const _Aviso({required this.chave, required this.icone, required this.texto, this.titulo});
  final String chave;
  final IconData icone;
  final String? titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(chave),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.dz(28), vertical: context.dz(22)),
      decoration: BoxDecoration(
        color: const Color(0x1FFF3EA5),
        borderRadius: BorderRadius.circular(context.dz(20)),
        border: Border.all(color: _t.accent2, width: context.dz(3)),
      ),
      child: Row(children: [
        Icon(icone, size: context.dz(52), color: _t.accent2),
        SizedBox(width: context.dz(20)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (titulo != null) ...[
              Text(titulo!, style: neonTexto(context.dz(30), peso: FontWeight.w700, espaco: .02)),
              SizedBox(height: context.dz(6)),
            ],
            Text(texto,
                style: neonTexto(context.dz(titulo == null ? 30 : 26),
                    peso: titulo == null ? FontWeight.w700 : FontWeight.w400,
                    cor: titulo == null ? _t.text : _t.muted,
                    altura: 1.3)),
          ]),
        ),
      ]),
    );
  }
}
