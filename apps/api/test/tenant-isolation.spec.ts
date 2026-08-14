import { describe, it, expect } from 'vitest';
import { Prisma } from '@prisma/client';
import { TENANT_SCOPED_MODELS } from '../src/prisma/tenant-scope.middleware';

/**
 * Blindagem de regressão da isolação multi-tenant (Fase 1 do plano de segurança).
 *
 * O middleware do Prisma injeta `tenantId` em TODA query dos modelos escopados e
 * falha fechado (ForbiddenException) sem tenant no contexto. O risco nº 1 é
 * ALGUÉM ADICIONAR UM MODEL NOVO COM DADO DE EMPRESA e esquecer de escopá-lo →
 * vazamento cross-tenant silencioso. Estes testes forçam a classificação de todo
 * model: ou é tenant-scoped, ou é global/org com justificativa explícita aqui.
 */

// Modelos que, de propósito, NÃO são tenant-scoped — cada um com o porquê.
const GLOBAIS_INTENCIONAIS = new Set<string>([
  'Tenant', // é a própria empresa (raiz do multi-tenant)
  'KioskRelease', // release do APK do totem — global do produto
  'WindowsBuild', // build Windows — global do produto
  'OrgUsuario', // usuários da Distribuição (DMS), cross-tenant por design
]);

const modelos = Prisma.dmmf.datamodel.models;
const nomes = modelos.map((m) => m.name);

describe('Isolação multi-tenant — cobertura de modelos', () => {
  it('todo model do schema está CLASSIFICADO (escopado ou global explícito)', () => {
    const naoClassificados = nomes.filter(
      (m) => !TENANT_SCOPED_MODELS.has(m) && !GLOBAIS_INTENCIONAIS.has(m),
    );
    // Se falhar: adicione o model novo em TENANT_SCOPED_MODELS (tem tenantId?)
    // ou, se for global/org de propósito, em GLOBAIS_INTENCIONAIS com o motivo.
    expect(naoClassificados).toEqual([]);
  });

  it('todo model tenant-scoped tem a coluna tenantId', () => {
    const porNome = new Map(modelos.map((m) => [m.name, m]));
    const semTenant: string[] = [];
    for (const nome of TENANT_SCOPED_MODELS) {
      const model = porNome.get(nome);
      if (!model) {
        semTenant.push(`${nome} (não existe no schema)`);
        continue;
      }
      if (!model.fields.some((f) => f.name === 'tenantId')) {
        semTenant.push(`${nome} (sem coluna tenantId)`);
      }
    }
    expect(semTenant).toEqual([]);
  });

  it('a allowlist de globais não apodrece (todos existem no schema)', () => {
    const set = new Set(nomes);
    const inexistentes = [...GLOBAIS_INTENCIONAIS].filter((m) => !set.has(m));
    expect(inexistentes).toEqual([]);
  });

  it('nenhum global intencional tem coluna tenantId (senão deveria ser escopado)', () => {
    const porNome = new Map(modelos.map((m) => [m.name, m]));
    const suspeitos: string[] = [];
    for (const nome of GLOBAIS_INTENCIONAIS) {
      if (nome === 'Tenant') continue; // Tenant tem id próprio, não tenantId
      const model = porNome.get(nome);
      if (model?.fields.some((f) => f.name === 'tenantId'))
        suspeitos.push(nome);
    }
    // Se um "global" tem tenantId, provavelmente deveria estar em
    // TENANT_SCOPED_MODELS — revisar.
    expect(suspeitos).toEqual([]);
  });
});
