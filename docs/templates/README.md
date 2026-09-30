# GoGeM · Pacote de templates de autoatendimento

Especificação completa para o **Claude Code** implementar 5 templates visuais no app do totem (`apps/kiosk`, Flutter) do monorepo `rodrigotjf1-boop/gogem`, com o suporte correspondente na API (`apps/api`) e na retaguarda (`apps/admin`).

| # | Template | Chave `temaPreset` | Arquivo | Mockups |
|---|----------|--------------------|---------|---------|
| — | Base comum (fazer primeiro) | — | [`00-base-templates.md`](00-base-templates.md) | — |
| 1 | Brasa 2.0 — steakhouse premium com fogo | `brasa2` | [`01-brasa-2.md`](01-brasa-2.md) | `mockups/01-brasa-2/` |
| 2 | Vitrine — cardápio em stories | `vitrine` | [`02-vitrine.md`](02-vitrine.md) | `mockups/02-vitrine/` |
| 3 | Estúdio — clean com produtos flutuando | `estudio` | [`03-estudio.md`](03-estudio.md) | `mockups/03-estudio/` |
| 4 | Neon 2.0 — noite urbana | `neon` | [`04-neon-2.md`](04-neon-2.md) | `mockups/04-neon-2/` |
| 5 | Diner 58 — lanchonete americana anos 50 | `diner` | [`05-diner-58.md`](05-diner-58.md) | `mockups/05-diner-58/` |

## Conteúdo do pacote

```
gogem-templates/
├── README.md                  ← este arquivo
├── 00-base-templates.md       ← arquitetura comum, contratos, regras, testes, API/admin
├── 01-brasa-2.md … 05-diner-58.md   ← especificação de cada template
├── mockups/
│   ├── prototipo-interativo.html    ← protótipo navegável (abra no navegador)
│   └── <template>/00-prancha.png + 01..11-*.png   ← telas 1080×1920 em tamanho real
├── referencia/
│   ├── prototipo-app.js       ← lógica e marcação do protótipo (fonte das medidas)
│   └── prototipo-kiosk.css    ← CSS do protótipo (cores, tamanhos, keyframes)
└── fotos-exemplo/*.webp       ← fotos de exemplo para cadastrar no catálogo de teste
```

## Como usar com o Claude Code

1. Copie a pasta `gogem-templates/` para `docs/templates/` do repositório (`git add docs/templates`). Os mockups PNG ficam em `docs/`, que é onde o `CLAUDE.md` permite binários.
2. Abra o Claude Code na raiz do repositório.
3. **PR 1 — base.** Cole:

   > Leia `docs/templates/README.md` e `docs/templates/00-base-templates.md` por inteiro. Implemente somente a **Fase 0 (base comum)** descrita no 00, sem nenhum template novo ainda. Siga o `CLAUDE.md` do repositório e rode o PRE-VOO do kiosk no fim. Abra um PR pequeno em PT-BR com o checklist de aceite do 00.

4. **PR 2 a 6 — um template por PR**, na ordem que preferir. Para cada um, cole (troque o arquivo):

   > Leia `docs/templates/00-base-templates.md` e `docs/templates/01-brasa-2.md`. Abra e confira as imagens em `docs/templates/mockups/01-brasa-2/`. Implemente o template **Brasa 2.0** (Fase A) seguindo o contrato da base, as especificações de tela e a tabela de animações. Não altere regras de negócio do fluxo. Rode o PRE-VOO e os testes novos. Entregue o PR com o checklist de aceite do arquivo.

5. **Fase B (opcional, depois):** recursos novos que o protótipo mostra mas o GoGeM ainda não tem (idiomas, modo acessível, combo sugerido com um toque, aviso de inatividade, foto recortada etc.). Estão descritos na seção 9 do `00-base-templates.md`. Cada item é um PR próprio, porque mexe em API, admin e contrato OpenAPI.

## Como conferir o resultado

- Abra `mockups/prototipo-interativo.html` no navegador. É a referência de movimento, com as animações rodando.
- Compare o app no totem ou no emulador (1080×1920, retrato) com os PNG da pasta do template, tela por tela.
- Cada arquivo de template termina com um **checklist de aceite**, para usar na revisão do PR.

## Observações importantes

- **Fotos:** as fotos do protótipo são de bancos gratuitos (Unsplash, Pexels e Pixabay) e servem só para teste. No totem, as imagens vêm do catálogo publicado (`imagemUrl`), que o lojista cadastra.
- **Marcas e preços:** "Brasa", "mordida.", "forma", "NEON/" e "Diner 58" são nomes de exemplo. No totem aparecem `nomeLoja` e `logoUrl` da loja.
- **Divergências do protótipo:** em dois pontos o protótipo difere de propósito do GoGeM real, e o GoGeM real vence.
  - **Cartão:** o protótipo mostra Crédito e Débito separados. No GoGeM é um botão **Cartão** só, e a maquininha pergunta crédito, débito ou vale.
  - **Pix:** o botão "Simular aprovação" da tela Pix existe só no protótipo.
