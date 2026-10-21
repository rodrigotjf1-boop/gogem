-- Religa ao Regem os produtos do GoGeM depois da troca de códigos PDV no Regem (Regem PR #692, migration 331,
-- aplicada em 20/10/2026 às 23:54 de Brasília): 61 produtos da loja ganharam o código PDV dos canais (iFood,
-- Anota Aí). O de-para do GoGeM guardava só o código, então 57 produtos ficaram sem par (pararam de sincronizar)
-- e 4 passaram a espelhar OUTRO produto, cujo código novo era o antigo deles (ERR-035).
--
-- A lista abaixo é a da auditoria do Regem (`trocou_codigo_pdv`): código de antes → código novo → id do produto no
-- Regem. Só códigos e ids; nenhum nome de produto ou de loja.
--
-- O que muda: o ref `regem` de cada produto com um código "de" passa a ter o código "para" e o `regem_id` do
-- produto no Regem (o resto do ref, como `loja`, fica). Daqui em diante a sincronização acompanha a troca de
-- código pelo `regem_id`.
--
-- Travas (migration que falha impede a API de subir — V3):
--   * um comando só (atômico) e nada que lance erro em dado fora do formato (`externalRefs` que não é lista fica
--     de fora);
--   * só lojas com a integração Regem apontando para o Regem de produção (`apiBase` em api.dmsregem.com) — é UMA
--     loja do Regem ligada ao GoGeM, conferida em 21/10/2026;
--   * só ref SEM `regem_id` (idempotente: a segunda execução não muda nada, mesmo com o ciclo 8 → 76 / cw… → 8);
--   * se o mesmo cardápio já tem outro produto com o código novo (de um importar feito depois da troca), este fica
--     de fora — sobra como "órfão" na revisão, para o dono decidir (nada se apaga aqui).
--   * o ciclo (o código antigo de um é o novo de outro) se resolve por ser um único UPDATE: cada linha lê o valor
--     de antes.
WITH troca(de, para, regem_id) AS (
  VALUES
    ('cw4620894', '1', '522ea027-0a00-4040-b626-7f30c913f691'),
    ('cw4620905', '10', 'cc0ae91f-9b8a-4ab4-9ea6-1decefdfb30f'),
    ('cw4620906', '11', '158c7445-b847-4aa3-a8c1-996880a3f7da'),
    ('cw4620840', '13', '9d32ca24-e176-41e0-a5b3-64c9fb29ce55'),
    ('cw4620846', '14', 'a460b82d-2549-4ed6-bad6-1a9ecd3e047e'),
    ('cw4620845', '15', 'd2786e90-df1f-4ee4-bb82-2ba9e2248ab5'),
    ('cw4620843', '16', '38a93732-6c4a-431e-9579-0e34a9a121d8'),
    ('cw4620907', '18', '84573651-2ab5-43ee-9b3d-9cf44b86f012'),
    ('cw4620899', '2', 'ab4e13c2-09f1-4b33-87ce-025a20496c4d'),
    ('cw4620908', '20', '29b3020c-3545-40d9-a262-65cd86e1f778'),
    ('cw4620909', '24', 'cac7e454-37b2-4aef-8a91-6440c1beab54'),
    ('cw4620912', '25', 'fa26854a-f10b-4c5b-a038-a48f12e9fff3'),
    ('cw4620889', '27', '0f6207cd-a5a2-478f-b3e0-f75760414676'),
    ('cw4620891', '28', '0e9b96dd-8e14-408e-bd39-de9393ddbd16'),
    ('cw4620898', '3', 'ec8f5512-089a-4c99-b2d9-68c2290dc21e'),
    ('cw4620892', '30', '3004e652-ccda-49a1-8f6a-9b566440e2eb'),
    ('cw4620890', '38', '537a0c75-7bea-4504-afd4-01cba256e720'),
    ('cw4620888', '39', '6328b9fe-ecbb-4978-82cf-5f9fc88544be'),
    ('cw4620895', '4', '4efb1786-de6f-45ea-9813-948ae88dbec6'),
    ('cw4620869', '44', '0b911ea1-ac1a-4819-abcb-90a191a387bc'),
    ('cw4620896', '45', 'b20152cf-5971-45c6-bc8f-480d3853abb8'),
    ('30', '46', '29b90f93-0696-4ed8-a8b4-32e4e79ca116'),
    ('32', '47', '51631e23-d30a-48fa-8cf2-0bfbd5083114'),
    ('cw4620872', '48', '3ff4e26c-dca4-4788-a8c1-5224b9476603'),
    ('cw4620874', '49', '0a34204d-8549-4d40-8b54-b95fc9832ba7'),
    ('cw4620897', '5', '8a863643-349d-4323-9b64-a637ccd80239'),
    ('cw4620876', '50', '083e9cf3-ea0b-48d1-8a15-ef1dd51f55f5'),
    ('cw4620878', '51', 'afb3a39d-95a9-4ddc-bc2e-3c332cfa9add'),
    ('33', '52', 'a714b59c-ee89-4013-993c-fddef080e3e7'),
    ('31', '53', '8fe83633-3a12-476d-8b30-8055aa329ded'),
    ('cw4620881', '54', '0664c559-cda3-45f8-addb-6c518b26e7d9'),
    ('cw4620882', '55', '3ce17cd4-c6ac-47d6-b425-4dc21a2be03a'),
    ('cw4620883', '56', '1bc70fd7-5f30-4e73-b8c4-173a02e3b748'),
    ('cw4620884', '58', '04ddff7f-c1e3-4016-b02f-af7e059fecb7'),
    ('cw4620885', '59', '6f5b9170-0b07-4c4c-8ded-8f42cd91fcff'),
    ('cw4620887', '60', 'ed80af39-6bc5-4a1b-8292-485ea4076741'),
    ('cw4620911', '64', '0ea63bdf-4139-42e8-9061-a5304a2cf27c'),
    ('cw4620847', '69', '963d549c-2f9f-4469-8754-c189f9dde5e9'),
    ('cw4620848', '70', '528b3cae-6b26-4d61-9b02-7bcef81b6889'),
    ('cw4620849', '71', 'd69c1c8c-dbe2-4eaf-98f0-56429ca951cb'),
    ('cw4620850', '72', '81ee63fa-9b88-4757-89e9-70ea9e3fd6eb'),
    ('cw4620851', '73', '90b049e6-e47d-4aab-b348-f1c6743e1940'),
    ('cw4620852', '74', '46fdee88-aa94-449d-9315-64484d09d496'),
    ('9', '75', '49a0475e-c087-4d06-80e6-2b741525aaf6'),
    ('8', '76', 'fad6a3a3-2eb2-4ec7-8ec0-5d03959b1bdc'),
    ('cw4620857', '77', '9a71854a-ac83-44b6-bb49-9afc8f870a43'),
    ('cw4620858', '78', 'c7f7fd98-26ea-4e4d-b74a-f4e8acce6b02'),
    ('cw4620859', '79', '7c768ca4-0e9d-4822-92e8-df0b09822b2b'),
    ('cw4620875', '8', 'a271fd40-9146-4bad-8c8a-93fb4e6648d1'),
    ('cw4620860', '81', 'e2850c10-4e21-4f88-a61b-f16562131f01'),
    ('cw4620861', '82', '12c45074-4dde-40e8-9168-d5f19ed72b5f'),
    ('cw4620862', '83', 'ef023996-70a2-47aa-a408-2c1e6dbff779'),
    ('cw4620867', '84', '1bef6f11-d86b-42b2-9785-2e0b8b077a18'),
    ('10', '85', '3e9695c8-6607-4625-9211-ebb32fa9c8ff'),
    ('cw4620863', '86', 'b159f4fe-b931-466b-a161-e57f325a86fa'),
    ('cw4620864', '87', '1b02588d-980c-49cd-b1ff-2187ec95a2f5'),
    ('cw4620865', '88', '98dd8150-2920-46f0-8568-fffd04aecafc'),
    ('cw4620873', '89', 'c2e643d6-6f8a-4de9-8b7b-7ec1f38d6364'),
    ('cw4620913', '9', '49912075-7aa3-49c9-95d1-c9288ae66b71'),
    ('cw4620877', '90', '819bad8f-c9fc-4a72-a868-c86075f7febb'),
    ('cw4620871', '91', '642dc18a-0d50-4fe8-ae2a-ccc534c42480')
),
lojas AS (
  SELECT DISTINCT i."tenantId"
    FROM "integracoes" i
   WHERE i."tipo" = 'regem'
     AND jsonb_typeof(i."config") = 'object'
     AND btrim(coalesce(i."config"->>'apiBase', '')) ILIKE 'https://api.dmsregem.com%'
),
candidatos AS (
  -- Produto com um ref regem SEM regem_id cujo código está na lista.
  SELECT p."id", p."tenantId", p."cardapioId", p."externalRefs"
    FROM "produtos" p
   WHERE p."tenantId" IN (SELECT "tenantId" FROM lojas)
     AND jsonb_typeof(p."externalRefs") = 'array'
     AND EXISTS (
       SELECT 1
         FROM jsonb_array_elements(p."externalRefs") e
         JOIN troca t ON t.de = btrim(e->>'codigo_pdv')
        WHERE jsonb_typeof(e) = 'object'
          AND e->>'sistema' = 'regem'
          AND NOT (e ? 'regem_id')
     )
),
alvo AS (
  SELECT c."id",
         (SELECT jsonb_agg(
                   CASE
                     WHEN jsonb_typeof(x.e) = 'object' AND x.e->>'sistema' = 'regem' AND NOT (x.e ? 'regem_id')
                          AND t.de IS NOT NULL
                       THEN x.e || jsonb_build_object('codigo_pdv', t.para, 'regem_id', t.regem_id)
                     ELSE x.e
                   END
                   ORDER BY x.ord)
            FROM jsonb_array_elements(c."externalRefs") WITH ORDINALITY AS x(e, ord)
            LEFT JOIN troca t ON t.de = btrim(x.e->>'codigo_pdv')) AS refs
    FROM candidatos c
   WHERE NOT EXISTS (
     -- Já existe no mesmo cardápio outro produto com o código novo, que NÃO é um código antigo da lista
     -- (logo, veio de um importar depois da troca): este fica de fora para não nascer um par duplicado.
     SELECT 1
       FROM jsonb_array_elements(c."externalRefs") e
       JOIN troca t ON t.de = btrim(e->>'codigo_pdv')
       JOIN "produtos" q
         ON q."tenantId" = c."tenantId"
        AND q."cardapioId" IS NOT DISTINCT FROM c."cardapioId"
        AND q."id" <> c."id"
        AND jsonb_typeof(q."externalRefs") = 'array'
      WHERE jsonb_typeof(e) = 'object'
        AND e->>'sistema' = 'regem'
        AND EXISTS (
          SELECT 1
            FROM jsonb_array_elements(q."externalRefs") f
           WHERE jsonb_typeof(f) = 'object'
             AND f->>'sistema' = 'regem'
             AND btrim(f->>'codigo_pdv') = t.para
             AND ((f ? 'regem_id') OR NOT EXISTS (SELECT 1 FROM troca t2 WHERE t2.de = btrim(f->>'codigo_pdv')))
        )
   )
)
UPDATE "produtos" p
   SET "externalRefs" = a.refs,
       "updatedAt" = now()
  FROM alvo a
 WHERE p."id" = a."id";
