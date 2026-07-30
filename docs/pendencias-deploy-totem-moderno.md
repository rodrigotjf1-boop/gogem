# Pendências de deploy — épico "Totem moderno" (F1–F4)

> Checklist do que precisa ser aplicado na **nuvem/totem** após o merge das PRs
> #53–#62. Marque `[x]` conforme executar. Ordem importa (migrations antes do APK).

## 1. Migrations no banco da nuvem (`gogem-api`) — CRÍTICO
Aplicar antes de instalar o APK novo (senão a API dá 500 por coluna ausente).

- [ ] `20260729200000_pedido_relatorio` — campos de relatório no pedido (Fase 7)
- [ ] `20260730000000_pedido_consumo` — `consumo` (comer aqui/viagem) (F1)
- [ ] `20260730100000_produto_upsell` — tabela de upsell (F2)
- [ ] `20260730200000_aparencia_tema_preset` — preset de tema (F3)
- [ ] `20260730300000_produto_selo` — `selo` do produto (F4)

**Como:** o deploy do `gogem-api` na EasyPanel roda `prisma migrate deploy` no
start. Confirmar nos logs do último deploy da `main`. Se não rodar sozinho,
executar no container: `npx prisma migrate deploy`.

## 2. Instalar o APK 0.5.0 no(s) totem(ns)
Desinstalar a versão antiga primeiro (permissões/estado limpos).

- [ ] `adb uninstall br.com.dms.gogem_kiosk`
- [ ] `adb install .../app-arm64-v8a-release.apk` (ou `armeabi-v7a` na Tinker Board)
- [ ] Parear com o código de 6 dígitos (admin → Auto atendimentos)

## 3. Configurar as features novas no admin (+ Publicar)
- [ ] **Selos** (F4): por produto → campo "Selo de destaque"
- [ ] **Upsell** (F2): produto-gatilho → botão "Peça também" → escolher sugeridos
- [ ] **Publicar** o catálogo (selos + upsell só chegam ao totem após publicar)
- [ ] **Aparência/Tema** (F3): Configurações → "Estilo do totem" (Brasa) +
      mídias do descanso com chapéu/título/subtítulo → Salvar aparência
      (ao vivo — não precisa publicar)

## 4. Testar a venda real (ponta a ponta)
- [ ] Pedido completo no totem com pagamento → confirmar comanda criada no Regem
      (o contrato de venda foi corrigido nesta rodada; antes dava 400)

## 5. Lado Regem (cross-repo) — quando o repo do Regem for desbloqueado
- [ ] Registrar `consumo` (comer aqui/viagem) na comanda em `/vendas/externa-pdv`
- [ ] Endpoint de pausa bidirecional (PR #236)
      (GoGeM já ENVIA o consumo; falta o Regem GRAVAR)
