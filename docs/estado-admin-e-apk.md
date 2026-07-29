# GoGeM — Estado atual do Admin e do APK (repasse)

> Documento de repasse (jul/2026). Resume **o que o painel Admin oferece hoje** e
> **o estado do APK do totem (kiosk Flutter)**, incluindo o **contrato de API**
> que o APK consome. Base: `main` do monorepo `C:\GoGeM` (PRs #33–#43).

## Visão geral da arquitetura

```
[Admin web (cloud)] --edita/publica--> [API NestJS (cloud)] <--sync--> [APK totem (offline-first)]
        |                                     |                              |
   app.gogem.com.br                    api.gogem.com.br               SQLite local + fila
```

- **Admin** (`apps/admin`, React+Vite+Tailwind): retaguarda que o lojista usa para
  montar o cardápio, integrar sistemas (ex.: Regem), publicar versões e gerir os
  totens. Fala com a **API** (JWT).
- **API** (`apps/api`, NestJS + Prisma/Postgres): multi-tenant (fail-closed) + RBAC.
  Publica o catálogo versionado; autentica o totem por **X-Device-Token**.
- **APK / kiosk** (`apps/kiosk`, Flutter): app do totem, **offline-first**
  (cache SQLite + fila de pedidos idempotente). Baixa o catálogo publicado e lança
  as vendas na API. Versão atual do pubspec: **0.3.0**.

Multi-tenant, dinheiro **sempre em centavos** (inteiro), de-para PDV por
`codigo_pdv` (chave da integração com o Regem).

---

## 1) ADMIN — o que oferece hoje

Menu (sidebar): **Cardápios · Catálogo · Integrações · Publicar · Auto atendimentos**.
RBAC no front (escrita só para gerente+; a autorização real é no servidor).

### Cardápios (`/cardapios`)
- Até **2 cardápios** por loja; **só um ativo** por vez. **O totem recebe SEMPRE o
  cardápio ativo** (a publicação snapshota o ativo).
- Cards com **Ativo/Inativo**, filtros **Todos/Ativos/Inativos**, ações
  **Gerenciar / Renomear / Ativar (exclusivo) / Excluir** (não exclui o ativo nem
  o último).
- Criar cardápio: **vazio**, **duplicar o ativo** (cópia inativa p/ preparar
  migração de sistema/testes), ou importar de um sistema integrado para ele.

### Catálogo (`/catalogo`) — árvore Categoria → Produto → Etapa → Opção
- Layout em **árvore** (espelha o Regem): **categorias na coluna à esquerda** +
  **produtos agrupados por categoria** à direita, na ordem das categorias.
- **Seletor de cardápio** no topo (edita o cardápio escolhido; avisa quando é um
  inativo).
- **Produto**: nome, **foto** (upload padrão), descrição, preço (centavos),
  **código PDV (Regem)**, categoria, disponível. Ações por linha:
  **Pausar/Despausar**, **Complementos**, **Editar**, **Excluir**.
- **Complementos/Etapas** (por produto, via modal): etapas com nome + min/max +
  obrigatória; **opções** com nome, acréscimo (R$), **código PDV** e **foto**;
  regra **"opção sem código = informativa"** (não lança no PDV).
  - **Etapas são REUTILIZÁVEIS** (backend pronto — #43): a mesma etapa pode ser
    ligada a vários produtos; editar reflete em todos. *A tela "Etapas" (biblioteca
    de etapas) + "reutilizar" no produto é o próximo PR do admin.*
- **Upload de imagem padrão** (`ImageUploadTile`): só o **quadrado com "+"**
  (clica → abre o seletor); com imagem, prévia + "×". JPG/PNG/WEBP/GIF até 5 MB.
  Vai para o Supabase Storage (URL pública).

### Integrações (`/integracoes`)
- Galeria de conectores (o GoGeM é uma **API aberta**). **Regem** é o 1º conector
  funcional; **Open Delivery** entra como padrão (contrato em `packages/contracts`).
- Por conector: **credenciais por loja** (segredos mascarados), **testar conexão**,
  **importar catálogo** para um cardápio-alvo, ativar/desativar.
- Token do Regem é **por tenant** (não é mais global) — resolve o multi-loja.

### Publicar (`/publicar`)
- Publica uma **nova versão** do catálogo ativo (snapshot imutável, versionado).
  Lista as versões e marca a atual como "No ar". É isto que o totem sincroniza.

### Auto atendimentos (`/frota`)
- Cadastro/pareamento dos totens (código de 6 dígitos, 15 min → token do
  dispositivo). Coluna **"Ao vivo"** com **telemetria** (online/offline, estado da
  impressora, fila, versão do catálogo/app) via heartbeat.

### Pausa de item (Regem ↔ GoGeM)
- **Pausar no GoGeM** propaga ao Regem (canal `gogem`), e **pausar no Regem** some
  do totem no próximo sync (reflete inativo/esgotado/canal pausado).

---

## 2) APK / KIOSK — estado atual

Flutter + Riverpod + go_router + sqflite. **Offline-first**: cache do catálogo em
SQLite + fila de pedidos com **ID idempotente**; sincroniza ao reconectar.
Dependência de imagem: `cached_network_image` (cache em disco → fotos funcionam
**offline** após o 1º carregamento online).

### Telas (rotas)
`/parear` · `/descanso` · `/catalogo` · `/produto/:id` · `/carrinho` ·
`/identificacao` · `/pagamento` · `/confirmacao` · painel admin (gate + panel).

### O que já funciona
- **Pareamento** do dispositivo (troca código → **X-Device-Token**), com redirect
  global até parear.
- **Sync do catálogo** por **versão** (delta): baixa o snapshot publicado e guarda
  local; selo de estado (sincronizando/atualizado/offline/erro).
- **Cardápio = vitrine**: categorias (chips) + **cards com foto** do produto,
  preço em selo, fallback elegante sem foto. Foto-herói no detalhe do produto.
- **Fluxo de pedido**: produto → **complementos/etapas** (min/max/obrigatório,
  soma de deltas ao vivo) → carrinho → identificação → pagamento → confirmação.
- **Impressão ESC/POS** (`packages/escpos`) com **portões de papel** (não trava o
  pedido pós-pagamento) + fila de reimpressão.
- **Modo quiosque** (Android lock task via MethodChannel `gogem/kiosk`).
- **Telemetria**: heartbeat periódico (papel, fila, versão) quando pareado.

### O que ainda NÃO faz (TODO / oportunidades pro Fable)
- **Foto da OPÇÃO**: o snapshot já traz `opcoes[].imagemUrl` (#43), mas o kiosk
  ainda **não renderiza** a foto da opção na tela de complementos — dá pra usar o
  `ProdutoImagem`/`cached_network_image`.
- **Telas de descanso configuráveis** (mídia da loja / carrossel) — pendente no
  admin e no kiosk.
- **Pagamento real (TEF/CliSiTef + pinpad)** — hoje o fluxo cobre o mock; a
  integração TEF é presencial.
- **Fallback LAN** (totem ↔ edge do Regem quando cai a internet) — frente futura.

---

## 3) Contrato de API que o APK consome

Base: `https://api.gogem.com.br/api/v1`. Auth do totem: header **`X-Device-Token`**
(device-authed); o pareamento é público.

| Método | Rota | Uso |
|---|---|---|
| `POST` | `/publico/dispositivos/parear` | troca o **código de 6 dígitos** por um **token** de dispositivo |
| `GET`  | `/catalogo/publicado?desde=<versao>` | catálogo publicado (delta por versão); `{versao, atualizado:false}` se já estiver na última |
| `POST` | `/dispositivos/heartbeat` | telemetria (versão do catálogo, fila, impressora, papel, appVersao) |
| `POST` | `/vendas` | lança o **pedido pago** (idempotente por `idempotencyKey`); o GoGeM repassa ao Regem |

### Shape do snapshot (`GET /catalogo/publicado`)
```jsonc
{
  "versao": 12,
  "atualizado": true,
  "snapshot": {
    "geradoEm": "ISO",
    "categorias": [{ "id", "nome", "ordem" }],
    "produtos": [{
      "id", "nome", "descricao", "precoCentavos", "disponivel",
      "imagemUrl",                 // foto do produto (ou null)
      "categoriaId", "externalRefs",
      "grupos": [{                 // ETAPAS (resolvidas do vínculo; ordem por produto)
        "id", "nome", "min", "max", "obrigatorio", "ordem",
        "opcoes": [{
          "id", "nome", "precoCentavosDelta", "disponivel",
          "imagemUrl",             // NOVO (#43): foto da opção (ou null)
          "ordem", "externalRefs"
        }]
      }]
    }]
  }
}
```
> **Importante:** o shape do snapshot **não mudou** com as etapas reutilizáveis —
> o produto continua trazendo `grupos[]` (agora resolvidos do vínculo N:N). A
> única adição relevante pro kiosk é **`opcoes[].imagemUrl`**.

### Corpo da venda (`POST /vendas`)
```jsonc
{
  "idempotencyKey": "uuid-do-totem",
  "itens": [{ "codigoPdv": "101", "quantidade": 1, "observacao?": "" }],
  "pagamentos": [{ "forma": "cartao", "valor": 2990, "nsu?": "", "autorizacao?": "" }], // centavos
  "cpf?": "", "taxaServicoPct?": 10, "senhaLocal?": 42
}
```
> O GoGeM converte para o formato do Regem na borda (reais + senha string) — o
> totem trabalha em **centavos** e manda em **centavos** para o GoGeM.

---

## 3b) NOVO: Aparência do totem (`/catalogo/publicado`) — para o Fable plugar o render

O admin ganhou **Configurações · Aparência** (por loja). A API expõe a aparência
**LIVE em toda resposta** do `GET /catalogo/publicado` (inclusive quando
`atualizado:false`) — o totem deve **aplicar a aparência a cada sync**, sem
depender da versão do catálogo. Campo novo na resposta:

```jsonc
{
  "versao": 12, "atualizado": true|false, "snapshot": { ... },
  "aparencia": {
    "corPrimaria": "#FFC24B",   // CTA / preço
    "corDestaque": "#3ECF8E",   // positivo
    "corFundo":    "#0F1713",
    "corPainel":   "#16211B",
    "raio": 16,                  // raio dos cantos (px)
    "nomeLoja": "MISTER BURGERS",
    "logoUrl": "https://.../logo.png",   // ou null
    "fonteDisplay": "Tektur",    // 'Tektur' | 'Poppins' | 'Montserrat'
    "descansoTipo": "padrao",    // 'padrao' (robô GoGeM) | 'carrossel'
    "descansoIntervaloSeg": 6,
    "descansoMidias": [{ "url": "https://...", "tipo": "imagem|gif|video" }],
    "chamada": "TOQUE PARA PEDIR",
    "precoIsca": "combos a partir de R$ 19,90",  // ou null
    "estiloCard": "cheia",       // 'cheia' | 'lateral'
    "animacoes": "cheio"         // 'cheio' | 'reduzido' | 'off'
  }
}
```

**Mapeamento pro tema do totem** (bate com o protótipo `prototipo-vitrine-gogem.html`):
`corPrimaria→--primaria`, `corDestaque→--destaque`, `corFundo→--fundo`,
`corPainel→--painel`, `raio→--raio`, `fonteDisplay→--fdisplay`. `descansoTipo`
escolhe carrossel (usa `descansoMidias`+`descansoIntervaloSeg`) vs robô padrão;
`estiloCard` alterna foto-cheia/lateral; `animacoes` combina com o
`HardwareCaps` (off/reduzido força; senão respeita o hardware). `logoUrl`/`nomeLoja`
na tela de descanso; `chamada`/`precoIsca` nos textos do descanso.

> A aparência **não** entra no snapshot versionado — é config viva por loja.
> Editar em Configurações reflete no totem no próximo sync (≤60s), sem publicar.

## 4) Resumo do que mudou recentemente (relevante pro kiosk)
- **`opcoes[].imagemUrl`** no snapshot → renderizar foto da opção (TODO no kiosk).
- **Disponibilidade reflete pausa do Regem** (inativo/esgotado/canal) — o totem só
  precisa respeitar `disponivel`.
- **Multi-cardápio**: transparente pro kiosk (só o **ativo** é publicado).
- **Etapas reutilizáveis**: transparente pro kiosk (snapshot inalterado).
- **Upload de imagem** corrigido no admin (multipart) — fotos passam a subir.
