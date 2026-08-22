# GoGeM — ficha da Play + passo a passo (trilha interna)

Material pronto para preencher o Play Console. Campos entre `[...]` você completa.

## 1) Detalhes do app

- **Nome do app** (máx. 30): `GoGeM`
- **Descrição breve** (máx. 80):
  `Autoatendimento em totem: monte seu pedido e pague com cartão ou PIX.`
- **Descrição completa** (máx. 4000):

```
O GoGeM é o aplicativo de autoatendimento em totem do estabelecimento. O cliente
monta o pedido na tela, personaliza os itens e paga direto no totem por cartão ou
PIX, com envio automático para a cozinha e comprovante de retirada.

Recursos:
• Cardápio com fotos, categorias e complementos.
• Upsell e combos configuráveis pela loja.
• Pagamento integrado (cartão e PIX) via terminal Mercado Pago.
• Impressão de comprovante e envio do pedido para produção.
• Identificação opcional do pedido por nome e CPF na nota.
• Atualização automática pela Google Play.

Aplicativo destinado a uso em totens dos estabelecimentos parceiros. Requer
pareamento com a loja para funcionar.
```

- **Categoria**: `Empresas` (é uma ferramenta operacional do estabelecimento). *(Alternativa: Comida e bebida.)*
- **Tags**: autoatendimento, totem, pedidos, restaurante.
- **E-mail de contato**: `[E-MAIL, ex.: contato@gogem.com.br]`
- **Política de privacidade (URL)**: `https://app.gogem.com.br/privacidade.html` (após deploy do admin)

## 2) Data safety (Segurança dos dados) — respostas exatas

Declarar **coleta** dos seguintes (cruza com a política de privacidade):

| Tipo de dado | Coleta? | Compartilha? | Finalidade | Obrigatório? |
|---|---|---|---|---|
| Nome | Sim | Não | Funcionalidade do app (identificar pedido) | Opcional |
| CPF / Tax ID (Personal identifiers) | Sim | Sim (fisco, quando CPF na nota) | Obrigação legal / funcionalidade | Opcional |
| Info de pagamento | **Não coletada pelo app** (processada pela Mercado Pago) | — | — | — |

- Câmera, localização, contatos, arquivos, mensagens: **Não**.
- Dados **criptografados em trânsito**: **Sim**.
- Usuário **pode pedir exclusão** dos dados: **Sim** (canal na política).
- Publicidade/rastreamento: **Não**.

## 3) Classificação de conteúdo (questionário)
- Sem violência, sexo, drogas, jogos de azar, linguagem imprópria → resultado esperado **Livre / Everyone**.

## 4) Público-alvo e conteúdo
- **Faixa etária-alvo**: 18+ (não é direcionado a crianças) → evita as políticas de Famílias.
- **App destinado a crianças?** **Não**.

## 5) Acesso ao app (para o time)
- O app **exige pareamento** com a loja (device token). Como é **teste interno** (sem revisão do Google), os testadores instalam pela Play e o app é pareado na loja/totem normalmente. Não é preciso credencial de demonstração para a trilha interna.

---

## Passo a passo — Play Console (trilha de teste interno)

> Objetivo: subir o `.aab` e liberar para os testadores hoje. Teste interno **não passa por revisão** do Google.

1. Acesse **play.google.com/console** com a conta de **organização** (verificada por DUNS).
2. **Criar app**: nome `GoGeM`; idioma padrão `Português (Brasil)`; tipo **App**; **Gratuito**. Aceite as declarações.
3. Menu **Testes → Teste interno** → aba **Versões** → **Criar nova versão**.
4. Em **Assinatura de apps do Google Play**: **aceitar/continuar** (o Google gerencia a chave de assinatura; você sobe com a chave de **upload** — foi a que geramos).
5. **Enviar** o pacote: `C:\Users\Usuário\gogem-play\gogem-v0.5.19-vc24.aab`.
6. **Notas da versão** (pt-BR): `Primeira versão de teste interno.`
7. **Revisar versão → Iniciar lançamento no teste interno**.
8. Aba **Testadores**: criar uma lista de e-mails (os seus / da equipe) → salvar → **copiar o link de participação**.
9. No aparelho/totem: abrir o link, **aceitar como testador**, instalar pela Play.

### Declarações obrigatórias (menu "Conteúdo do app")
Preencher antes de conseguir publicar (mesmo interno pede a maioria):
- **Política de privacidade** (URL do item 1).
- **Acesso ao app** (item 5).
- **Anúncios**: Não contém anúncios.
- **Segurança dos dados** (item 2).
- **Classificação de conteúdo** (item 3) — responder o questionário.
- **Público-alvo** (item 4).

---

## Pendências para completar a ficha
- [ ] **Logo** da marca (PNG 1024×1024) → gero ícone do app + os 512×512 e capturas.
- [ ] **Onde hospedar** a política de privacidade (definir URL).
- [ ] Preencher `[RAZÃO SOCIAL]`, `[CNPJ]`, `[ENDEREÇO]`, `[E-MAIL DE CONTATO]` na política e na ficha.
