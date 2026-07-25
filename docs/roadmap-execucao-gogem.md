# Roadmap de Execução — Novo Produto de Autoatendimento (Catálogo DMS)
**DMS — Desenvolvimento e Manutenção de Software · Família: Regem · Farol · GoGeM**
Versão 1.0 — 24/07/2026 · Documento de partida oficial do desenvolvimento

---

## 1. Nome do Produto — ESCOLHIDO: **GoGeM**

**GoGeM by DMS** — nome oficial definido. Significado em três camadas:

- **Go** — ação e movimento: o cliente *vai* e se serve sozinho. É o vocabulário universal do autoatendimento e do fast food ("on the go"), tendência que define o mercado;
- **GeM** — literalmente as três letras finais de **re·GEM**: o produto carrega o DNA do Regem no próprio nome. Em inglês, *gem* = joia — a joia da coroa do rei;
- **Grafia GoGeM** (G e M maiúsculos) — assinatura visual própria do catálogo DMS: *Regem governa, Farol guia, GoGeM atende.*

Verificação de originalidade (24/07/2026): nenhum produto, empresa ou app relevante chamado "GoGeM" encontrado na web (resultados próximos como GoGest/GoMeta são marcas distintas).

**Providências de marca:** registrar `gogem.com.br` / `gogem.app` / `gogem.io` + perfis sociais + protocolo INPI (classes 9 e 42, marca mista com o logotipo). Atenção de branding: o concorrente Gototem usa o prefixo "go" no app — nossa identidade visual (logotipo, cores, tipografia) deve se distanciar claramente da deles para evitar qualquer associação; a análise de colidência do INPI tende a ser tranquila por se tratar de conjuntos distintos, mas vale prioridade no protocolo.

Histórico da pesquisa de nomes (registro): Servyum, Ordyum e Solyum verificados e limpos (ficam como reserva de portfólio); Kyngo, Thronix, Sceptro, Autorex, Solium e Regnix descartados por uso existente.

---

## 2. A Grande Decisão: por onde começar? (retaguarda/telemetria × catálogo)

**Resposta: Retaguarda-núcleo COM catálogo primeiro; telemetria entra imediatamente depois, antes do pagamento.** Justificativa caso a caso:

1. **O app do totem não existe sem catálogo.** Tela, carrinho, combos e preços são todos derivados do catálogo. Catálogo é a dependência raiz de tudo.
2. **Catálogo é também a porta da integração Regem** (códigos do PDV). Construí-lo primeiro obriga a definir cedo o modelo de dados e o de-para `codigo_pdv`, evitando retrabalho.
3. **Telemetria não pode ficar para o fim** — é a resposta direta à dor real do Gototem (papel acabando e pedido travando). Mas telemetria monitora o *app rodando no totem*; logo precisa existir um app mínimo antes. Por isso ela entra na sequência imediata: assim que o app abrir o cardápio e imprimir, o agente de telemetria embarca junto.
4. **TEF e fiscal ficam por último dentro do MVP** porque dependem de homologação externa (prazo que não controlamos) — iniciamos o processo comercial/homologação com a integradora **em paralelo desde a semana 1**, mas o código entra depois.

**Ordem oficial:** Fundação (infra+auth+tenant) → **Catálogo + API v1** → App Totem (pedido + impressão com status) → **Telemetria/frota** → TEF + PIX → Fiscal → Relatórios/Dashboard completos → White-label/API pública.

---

## 3. Diferencial nº 1 — Gestão de papel e resiliência de pedido (a falha do Gototem)

Dor observada em campo: a TM-T88VII fica sem papel, o app do concorrente não percebe, o pedido **trava depois do pagamento**, gerando cancelamentos e até crash do app. Nossa solução, caso a caso:

### 3.1 Leitura de status da impressora (TM-T88VII via ESC/POS USB)
- **ASB (Automatic Status Back, `GS a`)**: a impressora passa a enviar status em tempo real (tampa aberta, sem papel, near-end, erro de guilhotina) sem precisar de polling — o app mantém um listener permanente.
- **Consulta ativa (`DLE EOT n`)**: checagem síncrona usada nos "portões" do fluxo.
- **Sensor de near-end (fim próximo do papel)**: a T88VII tem sensor de pouco papel — usamos como alerta amarelo.

### 3.2 Portões de segurança no fluxo (state machine do pedido)
| Momento | Checagem | Comportamento |
|---|---|---|
| Tela de descanso | Status a cada 30s + ASB | Papel acabou → totem entra em "FORA DE OPERAÇÃO" com aviso amigável e alerta à equipe. **Cliente nunca inicia pedido que não pode terminar** |
| Antes de abrir o pagamento | `DLE EOT` síncrono | Sem papel/tampa aberta → bloqueia pagamento, orienta chamar atendente. **Nunca cobrar sem poder concluir** |
| Near-end detectado | ASB | Totem segue vendendo; alerta amarelo no dashboard + WhatsApp (via n8n) para a loja trocar bobina; contador de km de papel/cortes na telemetria confirma tendência |
| Papel acaba APÓS pagamento aprovado (janela residual) | ASB | **Pedido jamais se perde**: venda já está persistida com UUID; app exibe a senha na tela em fonte grande + envia pedido à cozinha (KDS/API) + guarda cupom na **fila de reimpressão** (menu admin e remoto); fiscal emitido segue válido no servidor |
| Queda de energia no meio | Journal em SQLite (write-ahead) | No boot: resolve pendência TEF (confirma/desfaz), reimprime o que faltou, ressincroniza. Nada de tela branca |

### 3.3 Telemetria que transforma a dor em produto
- Heartbeat 60s: online, versão, uptime, status impressora (OK/near-end/sem papel/tampa), status pinpad, fila offline, memória livre.
- Contadores da impressora (km de papel, nº de cortes — visíveis no TM Utility) coletados 1×/dia → **manutenção preditiva**: "bobina deve acabar hoje à noite", "guilhotina se aproxima da vida útil".
- Alertas por n8n (já rodando na VPS): WhatsApp/e-mail para o lojista e painel de frota para a DMS/revenda.
- Argumento de venda: *"O GoGeM avisa que o papel vai acabar antes do cliente descobrir."*

---

## 4. Infraestrutura — aproveitando o que já existe (VPS Ubuntu + EasyPanel + n8n)

| Serviço | Container (EasyPanel) | Papel |
|---|---|---|
| PostgreSQL 16 | `gogem-db` | Banco principal multi-tenant (schemas ou coluna tenant_id + RLS) |
| Redis | `gogem-redis` | Cache de cardápio publicado, filas (BullMQ), sessões |
| MinIO (S3) | `gogem-media` | Fotos de produtos, logos white-label, pacotes OTA (APK/instaladores assinados) |
| API núcleo | `gogem-api` | REST + WebSocket (telemetria/pedidos em tempo real) |
| Backoffice web | `gogem-admin` | Retaguarda (SPA) |
| n8n (existente) | reaproveitado | Alertas WhatsApp/e-mail (papel, totem offline, fechamento), automações de onboarding, ponte para integrações rápidas |
| Reverse proxy | Traefik/Nginx do EasyPanel | TLS, subdomínios `api.`, `admin.`, `ota.` |

Regras: ambientes **staging e produção separados** desde o dia 1 (dois projetos no EasyPanel); backup diário do Postgres para o MinIO + cópia externa; segredos no gerenciador do EasyPanel; logs centralizados (Loki ou simples journald + retenção).

## 5. Stack e Monorepo (preparado para Claude Code)

```
gogem/
├── CLAUDE.md                  # contexto p/ Claude Code: arquitetura, convenções, comandos
├── apps/
│   ├── kiosk/                 # Flutter (Android armeabi-v7a/arm64 + Windows)
│   ├── admin/                 # Backoffice web (React + Vite + Tailwind + shadcn)
│   └── api/                   # NestJS (Node 20 + TypeScript + Prisma) — REST/WS/OpenAPI
├── packages/
│   ├── contracts/             # Tipos/DTOs compartilhados + OpenAPI gerado
│   ├── escpos/                # Driver impressão (ESC/POS, ASB, status) — Dart
│   └── payment/               # Contrato PaymentProvider + adaptadores TEF/PIX
├── integrations/
│   └── regem/                 # Cliente da API do Regem + de-para de códigos PDV
└── infra/                     # docker-compose/EasyPanel templates, CI (GitHub Actions)
```

- **API em NestJS/TypeScript**: alinha com o ecossistema JS já usado (n8n, VPS), OpenAPI nativo (vira a doc da API pública), fácil de o Claude Code navegar.
- **Fluxo com Claude Code**: (1) rodar Claude Code no repositório do **Regem** para mapear endpoints/modelos existentes → gerar `integrations/regem/ENDPOINTS.md`; (2) manter `CLAUDE.md` com convenções para acelerar cada sprint; (3) PRs pequenos com testes.

## 6. Integração de Catálogo via Códigos do PDV (Regem e terceiros)

Modelo: todo produto/complemento no GoGeM tem `external_refs[]` = `{sistema: "regem", codigo_pdv: "123", loja: X}`.

1. **Importação inicial**: job lê produtos do Regem (endpoints mapeados via Claude Code) → cria rascunho de cardápio com preços e códigos → gestor organiza categorias/fotos/combos no admin → publica.
2. **Sincronização contínua** (configurável por loja): preço/disponibilidade podem seguir o Regem (fonte da verdade) ou ser gerenciados no GoGeM; conflitos aparecem numa fila de revisão ("preço divergente: Regem R$29,90 × GoGeM R$27,90").
3. **Venda de volta**: pedido pago → lançado no Regem com os `codigo_pdv` de cada item (garante baixa de estoque/ficha técnica corretas) → resposta com nº do lançamento guardada no pedido (auditoria bidirecional).
4. **Terceiros**: mesmo mecanismo — o parceiro informa os códigos dele via API (`PUT /v1/menu/items/{id}/external-refs`) ou importação CSV; webhooks `order.paid` entregam o pedido com os códigos do parceiro.

> **Nota de implementação (do ENDPOINTS.md):** no Regem o código PDV é `produto.codigo`; a leitura de catálogo com o código exige o endpoint autenticado `GET /api/v1/produtos` (o menu público esconde o código); a venda de volta paga por `codigo_pdv` é a lacuna **L-VEN-1** no backlog do Regem, prioridade do piloto.

## 7. TEF e Pagamentos — análise caso a caso das integrações possíveis

| Opção | Como integra | Prós | Contras | Veredito |
|---|---|---|---|---|
| **PayGo Integrado (PGWebLib)** | .aar/intent (Android), DLL (Win); pinpad USB | Comprovado no NOSSO hardware (Gototem usa); homologa PPC930; multiadquirente; menu admin pronto (tabelas, trace) | Depende de credenciamento PayGo/adquirentes por CNPJ | **Fase 1 — fazer primeiro** |
| **SiTef/CliSiTef (Software Express)** | Lib .so/JNI (Android), DLL (Win) | Padrão de grandes redes/franquias; exigido por muitos clientes enterprise | Requer servidor SiTef; contrato mais burocrático | **Fase 2** — abre mercado corporativo |
| **Auttar / TOTVS TEF** | Lib/gerenciador | Presença forte em varejo TOTVS | Sobreposição com SiTef; menor demanda em food | Sob demanda de cliente |
| **Elgin TEF / Destaxa** | SDK Android | Simples, boa doc | Menos adquirentes em alguns cenários | Alternativa tática p/ revendas Elgin |
| **Stone (Smart POS/Connect)** | Terminal inteligente da adquirente | Sem pinpad próprio; conciliação Stone | Prende o cliente à adquirente única | Oferta opcional white-label |
| **Cielo LIO / PagBank / Mercado Pago Point** | APIs dos smart POS | Setup rápido p/ pequenos | Idem: lock-in de adquirente; hardware próprio deles | Roadmap futuro (linha "lite") |
| **PIX dinâmico via PSP (Efí, Asaas, Inter, etc.)** | API REST + webhook | Sem pinpad; barato; cai em minutos | Exige internet estável; conciliação própria | **Fase 1 junto com TEF** (QR na tela) |

Arquitetura blindada: contrato único `PaymentProvider` (iniciar, capturar, confirmar, desfazer, cancelar, reimprimir, fechar) + **resolução de pendências idempotente no boot** (regra de ouro do TEF: nunca confirmar sem cupom persistido, nunca perder desfazimento).

Ações comerciais da semana 1 (paralelas ao código): abrir credenciamento de desenvolvedor na Software Express/SiTef (acesso dev ao CliSiTef + servidor de homologação), PayGo como 2ª onda, definir PSP do PIX.

## 8. UX — "menu de jogo" adaptado a fast food

Direção de arte: dark theme com acentos vibrantes da marca do lojista (white-label), cards grandes com foto full-bleed, microanimações (Rive/Lottie leves), sons curtos de feedback, mascote opcional, tipografia display bold. Referência funcional: seleção de personagem/loadout de jogos — categorias como "abas de skin", combos como "bundles", adicionais como "power-ups (+R$2)".

Regras de engenharia p/ RK3288 (2GB, 32-bit): 60fps alvo mas degradação elegante (desligar blur/partículas por flag de perfil de hardware), imagens WebP pré-dimensionadas via CDN/MinIO, cache local integral, zero jank na lista (builders preguiçosos), teste contínuo nos totens reais.

Acessibilidade: modo rebaixado (cadeirante), alto contraste, PT/EN/ES, fluxo concluível em ≤ 6 toques para pedido simples.

## 9. Uso dos 4 Totens Disponíveis

| Totem | Papel | Detalhe |
|---|---|---|
| nº 1 | **Bancada de desenvolvimento** (escritório) | Aberto, com ADB; ciclo diário de build |
| nº 2 | **QA/homologação** | Imagem "de fábrica" do provisionamento; testes de kiosk, energia, papel (bobinas curtas de teste!), TEF simulado |
| nº 3 e 4 | **Piloto em campo** | Loja(s) parceira(s) reais na Fase Piloto; telemetria comparada |

Criar desde já o **runbook de provisionamento** (imagem Android + checklist de hardening + pareamento por código) — ele vira o manual da revenda.

## 10. Roadmap Completo por Sprints (2 semanas cada)

| Sprint | Entregas | Critério de aceite |
|---|---|---|
| **S0 — Setup (1 sem)** | Nome/domínio; monorepo + CI; staging no EasyPanel; CLAUDE.md; mapeamento endpoints Regem; credenciamento dev SiTef (CliSiTef + ambiente de homologação) | Pipeline deploy staging OK; ENDPOINTS.md do Regem gerado |
| **S1–S2 — Fundação + Catálogo** | API núcleo (tenants, lojas, usuários, auth JWT/RBAC); CRUD completo de cardápio (categorias, produtos, grupos de complementos, combos, preços, disponibilidade, fotos); publicação versionada; import Regem v1 (leitura por codigo_pdv) | Gestor monta e publica um cardápio real da loja piloto no admin |
| **S3–S4 — App Totem núcleo** | Flutter: descanso→categorias→produto→complementos→carrinho→identificação; sync do cardápio publicado (delta + cache offline); driver ESC/POS com **ASB/status/near-end**; impressão de pedido não-fiscal; kiosk mode Android (launcher+watchdog) | Pedido completo impresso no totem nº 1 sem rede; papel removido → totem bloqueia ANTES do pagamento e alerta |
| **S5 — Telemetria & Frota** | Heartbeat, painel de frota no admin, alertas n8n (WhatsApp), fila de reimpressão, OTA v1 (download+instala assinado), contadores de papel/corte | Derrubar rede/tirar papel do totem QA gera alertas em <2 min; OTA aplicado remotamente |
| **S6–S7 — Pagamentos** | Adaptador SiTef/CliSiTef (venda, cancelamento, pendências, fechamento, menu TEF admin com teclado embaralhado); PIX dinâmico via PSP com QR na tela; state machine de pedido com journal | Venda crédito/débito/PIX no totem QA com pinpad PPC930; queda de energia no meio da venda se resolve sozinha no boot |
| **S8 — Fiscal** | NFC-e via módulo fiscal (certificado A1 por CNPJ na retaguarda; numeração por totem; contingência); modo "sem fiscal" e modo "fiscal no integrado (Regem)" | Cupom NFC-e autorizado impresso com QR SEFAZ na loja piloto (CNPJ real) |
| **S9 — Integração Regem completa** | Pedido pago → lançamento no Regem (códigos PDV) + baixa estoque; conciliação de fechamento; sincronização contínua de preços | Venda no totem aparece no Regem em <30s com itens corretos |
| **S10 — Relatórios & Dashboard** | Vendas geral/por categoria/ranking/por hora/por pagamento com filtros de data; exportações; dashboard com gráficos e saúde da frota | Todos os relatórios batem com os lançamentos do Regem no período |
| **S11 — Piloto de campo (4 sem)** | Totens 3 e 4 em loja real; SLA interno; ajustes de UX por funil (iniciados×concluídos); hardening final | 2 semanas seguidas sem intervenção manual; conversão >85% dos pedidos iniciados |
| **S12+ — Produto de prateleira** | White-label (temas por tenant), API pública documentada (OpenAPI+sandbox+webhooks), portal/manual da revenda, build Windows + Shell Launcher, 2ª integradora TEF (PayGo) | Primeira revenda externa ativa um cliente sem ajuda da DMS |

**Marco MVP vendável: fim do S9 (~5 meses).** Piloto público: S11.

## 11. Análise de Riscos — caso a caso

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Papel acaba pós-pagamento | Alta | Alto (cancelamentos) | Portões de status + senha na tela + fila de reimpressão + near-end preditivo (seção 3) |
| Pendência TEF após queda de energia | Média | Alto (perda financeira) | Journal + resolução idempotente no boot; testes de tomada arrancada no QA |
| Prazo de homologação TEF fora do nosso controle | Alta | Médio (atrasa S6) | Iniciar credenciamento na S0; desenvolver contra simulador PayGo; PIX independe e entra antes |
| Hardware 32-bit/2GB engasgar com UI rica | Média | Médio | Perfis de performance; testes contínuos no totem real desde S3; specs mínimas recomendadas para novos clientes (arm64/4GB) |
| Segurança (lição Gototem: AnyDesk/root expostos) | — | Alto (reputação) | Checklist de hardening no provisionamento; suporte remoto só por túnel autenticado da retaguarda; auditoria trimestral |
| Divergência de catálogo GoGeM×Regem | Média | Médio | Fonte-da-verdade configurável + fila de conflitos + auditoria bidirecional |
| SEFAZ instável / contingência fiscal | Média | Médio | Contingência NFC-e; modo degradado configurável; fila de emissão |
| Dependência de 1 pessoa/ferramenta | Média | Médio | Monorepo documentado + CLAUDE.md + runbooks; backups testados |
| Concorrente reagir (Gototem) | Baixa | Baixo | Nossos diferenciais são estruturais (telemetria, API aberta, Regem, segurança) |

## 12. Primeiro Passo — checklist desta semana (S0)

1. ✅ Aprovar o nome (**GoGeM**) — registrar domínios e INPI;
2. Criar organização Git + monorepo com esqueleto acima + CI básico;
3. Subir `gogem-db`, `redis`, `minio`, `api` (hello world) no EasyPanel **staging**;
4. Rodar Claude Code no repositório do Regem → gerar `integrations/regem/ENDPOINTS.md` (produtos, preços, lançamento de venda, estoque, auth); ✅ **feito**
5. Solicitar kit de desenvolvedor PayGo + pinpad PPC930 de desenvolvimento; contato comercial SiTef; escolher PSP do PIX;
6. Separar os 4 totens nos papéis definidos (bancada/QA/piloto) e fotografar/etiquetar;
7. Escrever a 1ª versão do runbook de provisionamento do totem bancada (kiosk + hardening);
8. Kickoff de design: moodboard "game menu fast food" + 3 telas-chave (descanso, categoria, produto) para validar a direção antes do S3.

---
*Roadmap elaborado considerando: 4 totens Tinker Board S/Android 11 disponíveis, VPS Ubuntu com EasyPanel + n8n em produção, acesso ao Claude Code e ao código-fonte do Regem, e as falhas de campo observadas no concorrente Gototem (gestão de papel inexistente, lockdown ausente).*
