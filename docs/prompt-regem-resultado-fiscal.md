# Prompt — Regem: a venda do totem informa o resultado fiscal

> Cole numa sessão do Claude Code aberta em `C:\Regen`. Escrito em 23/09/2026; revisado em
> 24/09/2026 a partir de `origin/main` = 7d6276b (PR #569 do totem mesclado).

---

## 0. Pré-condição — confira ANTES de tudo

O módulo do totem pelo servidor local **está em `origin/main` desde o PR #569** (merge `7d6276b`):
`backend/src/modules/totem/`, `fiscal/resumo-nfce.ts` e, em `delivery.service.ts`,
`criarPedidoTotemRetido` / `liberarPagamentoTotem` / `cancelarPedidoTotem`. Trabalhe numa
worktree off `origin/main` (o `main` local de `C:\Regen` fica defasado — ver CLAUDE.md).

**Não procure nem aproveite o commit `170e18d` (K6)** que ficou no `main` local: ele conflita com
o #566/#567 no `imprimirDanfe`, e a seção A abaixo o substitui.

Já resolvido no #569 — **não refaça**: o CPF do totem chega ao pedido (`documento_cliente`) e à
comanda (ERR-096); o cardápio do totem leva `fiscal: {ativo, limiteIdentificacaoCentavos}` e o
totem exige o CPF acima do limite ANTES da maquininha; retido de cartão nunca vai para a cozinha
antes de aprovar; o job de expiração só roda no servidor local.

---

## 1. Contexto

O totem GoGeM (app Android) vende pela LAN através do servidor local do Regem. A ordem é:

1. o cliente monta o pedido; o totem abre um pedido **retido** no Regem (`POST /vendas/retido`) —
   nada vai para a cozinha nem para o fiscal ainda;
2. o cliente paga na maquininha do Mercado Pago (ao lado do totem, com internet própria);
3. aprovado, o totem **libera** a venda (`POST /vendas/:id/liberar` → `liberarPagamentoTotem` →
   `venderTotem`);
4. o Regem emite a NFC-e e devolve o DANFE pronto; o totem imprime na térmica dele;
5. se o fiscal falhar, o **totem estorna** o pagamento no Mercado Pago (pela nuvem do GoGeM) e
   registra o motivo.

A emissão é do Regem, que já tem certificado, CSC e configuração. O totem só imprime e estorna.

**Regras do dono (não negociar):**
- **pagamento primeiro, fiscal depois** — nunca abrir nota antes de o pagamento aprovar;
- **contingência é aprovação** — nota em `contingencia` é cupom válido: o totem imprime e NÃO estorna.

---

## 2. O que está errado hoje (verificado em `origin/main` 7d6276b)

1. **Falha fiscal chega ao totem como "loja sem fiscal".** `emitirSeAtivo` devolve `null` nos dois
   casos (`fiscal.service.ts` ~1737: `if (!cfg?.ativo) return null` e `catch { return null }`). O
   totem entrega a venda sem cupom fiscal e ninguém fica sabendo.
2. **Na contingência, a venda do totem não recebe o DANFE.** No `emitir()`, os dois caminhos de
   contingência fazem `return rc.nota` (~483 e ~507) — quem chamou não recebe o texto para imprimir.
3. **A produção sai antes do fiscal.** `venderTotem` chama `this.producao.emitirNovos(...)` e só
   depois `emitirSeAtivo` (`vendas.service.ts` 1544-1545 em 7d6276b). Com o fiscal falhando e o pagamento
   estornado, a cozinha já recebeu o pedido.
4. **O DANFE da venda do totem sairia duas vezes** — o `imprimirDanfe` imprime na impressora da
   loja e o totem imprime na dele.
5. **Certificado vencido não é barrado no pré-voo.** `problemasDoCertificado` só roda no upload
   (`credencial.ts` ~120) e no "Testar certificado" (~276); na emissão, `certificadoParaAssinar`
   só abre o arquivo. **A investigar** (seção E): se a SEFAZ recusa o TLS de um certificado
   vencido e o `soap.ts` classifica como `SefazInalcancavel`, a venda cai em CONTINGÊNCIA com QR
   assinado por certificado vencido — DANFE impresso de uma nota que nunca vai autorizar.

---

## 3. O que fazer

### A. Um só montador de DANFE

Extraia o texto hoje montado em `montarEEnfileirarDanfe` para uma função pura (sugestão:
`fiscal/danfe-texto.ts`), usada **pela impressora da loja e pela resposta ao totem**. Mesmo texto,
mesmo marcador `@QR:<dados>` na linha do QR, com "EMITIDA EM CONTINGENCIA" + "Aguardando
autorizacao da SEFAZ." na contingência. A 2ª via continua opcional (mig 287) e, quando existir,
sai no formato de hoje: o mesmo conteúdo + separador + `VIA DO ESTABELECIMENTO` no fim.

### B. A venda do totem devolve o resultado fiscal completo

`venderTotem` — e, por ele, `liberarPagamentoTotem` — devolve `nfce` neste contrato. **O totem já
está preparado para ele**; mantenha os nomes.

| Situação | `nfce` |
|---|---|
| loja sem fiscal ativo | `null` — **e SÓ neste caso** |
| autorizada (cStat 100/120/150) | `{status:'autorizada', chave, numero, serie, protocolo, qrcode, ambiente, simulada, contingencia:false, emitidaEm, danfe, viaEstabelecimento:false}` |
| contingência | `{status:'contingencia', ..., protocolo:null, contingencia:true, danfe, viaEstabelecimento:<fiscal_config.contingencia_via_estabelecimento>}` |
| não emitida | `{status:'nao_emitida', danfe:null, erro:{etapa, codigo, motivo, repete}}` |

- `erro.etapa`: `'configuracao'` (pré-voo: NCM, campos faltando, certificado, venda acima do
  limite sem CPF) · `'rejeitada'` · `'denegada'` · `'sem_contingencia'` (SEFAZ muda e a
  contingência indisponível: sem certificado ou UF em QR v2) · `'interno'`.
- `erro.codigo`: o cStat, quando houver; senão `null`.
- `erro.motivo`: o texto que o Regem já produz hoje (é o que vai para o relatório do GoGeM).
- `erro.repete`: `true` quando a PRÓXIMA venda vai falhar igual (configuração, denegada,
  emitente irregular 781/301) — o totem usa para alertar o gestor em vez de estornar venda
  atrás de venda em silêncio.

Regras:
- **Só diga `nao_emitida` com certeza de que NÃO existe nota válida para a venda.** Nota que foi
  à SEFAZ sem resposta segue o caminho da contingência, como já faz hoje.
- **Não mude o `emitirSeAtivo` para os outros chamadores** (PDV, delivery, balcão): eles dependem
  de a venda nunca travar por causa do fiscal. Crie o caminho do totem à parte (opção ou método
  próprio).
- **Na venda do totem, a impressora da loja NÃO imprime o DANFE** — nem `impressao_job`, nem
  `edge_comando imprimir_danfe`. Quem imprime é o totem.

### C. Venda do totem com fiscal ativo: produção só depois da nota

- Com fiscal ativo, `emitirNovos` só depois de a nota ficar `autorizada` ou `contingencia`.
- Se `nao_emitida`: desfaça a venda do lado do Regem (estoque e caixa — existe
  `estornarVendaExterna`), marque o pedido retido como **cancelado com o motivo fiscal** e NÃO
  libere produção.
- Sem fiscal ativo, nada muda.

### D. Rota de estorno no proxy do servidor local

Acrescente `'pagamentos/estorno'` à lista do `@All([...])` em `totem/totem-nuvem.controller.ts`.
É a rota que a nuvem do GoGeM expõe para o totem pedir o estorno de um pagamento APROVADO
(`POST`, corpo `{orderId, motivo, etapa}`). O Regem só repassa — não interpreta nada.

### E. Certificado vencido — investigar e barrar

Reproduza uma emissão com certificado fora da validade. Se ela cair em contingência (ou
reservar número e deixar buraco), barre no **pré-voo, antes de reservar o número**: certificado
fora da validade → `nao_emitida` com `etapa:'configuracao'` e `repete:true`. Registre no
`ERROS-CONHECIDOS.md`.

### F. DANFE que não saiu no totem — o totem avisa e o Regem desfaz

Rota nova no módulo do totem (mesmo guard das outras de `vendas`):
`POST /vendas/:pedidoId/falha-impressao` com `{motivo}`. O totem chama quando o DANFE não sai
no papel. O Regem:

- **nota autorizada** → cancela a NFC-e por evento (no RJ o prazo é **30 min** da autorização;
  justificativa ≥ 15 caracteres, ex.: "Cupom fiscal nao impresso no totem; venda desfeita"),
  desfaz a venda (estoque/caixa), cancela o que foi para a produção e marca o pedido cancelado;
- **nota em contingência** → ela **não pode ser inutilizada** (Ajuste SINIEF 19/16, cl. 11ª, §2º,
  II): marque-a para ser **cancelada assim que autorizar** na transmissão da fila, e desfaça a
  venda do mesmo jeito;
- devolve `{ok, notaCancelada: bool, cancelamentoPendente: bool}`. O estorno do pagamento é o
  totem que pede (seção D).

---

## 4. Testes que provam

- resposta da venda do totem nos QUATRO casos da tabela da seção B;
- contingência devolve `danfe` preenchido e `viaEstabelecimento` conforme a configuração;
- nota rejeitada na venda do totem: nenhuma produção emitida, estoque e caixa revertidos, pedido
  retido cancelado com o motivo;
- venda do totem: nenhum `impressao_job` nem `edge_comando imprimir_danfe` para o DANFE;
- `emitirSeAtivo` dos outros chamadores: comportamento idêntico ao de hoje;
- `falha-impressao`: autorizada → evento de cancelamento; contingência → marcada para cancelar
  após autorizar, nunca inutilizada;
- SQL novo contra Postgres real (V6).

---

## 5. Regras do projeto que valem aqui

- Consulte `ERROS-CONHECIDOS.md` antes (V22 fiscal, V6, V11, V26) e registre erro novo no mesmo
  trabalho da correção.
- Migration: não prevista. Se precisar, o próximo número conferido em `origin/main`.
- **Não toque no GoGeM.**
- Branch → PR → CI verde → merge **só sob comando do dono**. O módulo do totem roda no servidor
  local: registre a pendência distribuível em `RELEASES.md`.
- Ao terminar, liste para o dono: o contrato final de `nfce` (se algum nome mudou, diga qual), a
  rota `falha-impressao` e o resultado da investigação do certificado vencido.
