import { SetMetadata } from '@nestjs/common';

/**
 * Hierarquia de papéis (CLAUDE.md): presidente > gerente > supervisao >
 * execucao. Índice maior = mais poder.
 */
export const PAPEL_HIERARQUIA = [
  'execucao',
  'supervisao',
  'gerente',
  'presidente',
] as const;

export type Papel = (typeof PAPEL_HIERARQUIA)[number];

export const ROLES_KEY = 'roles_minimo';

/**
 * @Roles('gerente') — exige o papel informado OU superior na hierarquia.
 * RBAC no servidor (CLAUDE.md): o front apenas oculta, a API bloqueia.
 */
export const Roles = (papelMinimo: Papel) =>
  SetMetadata(ROLES_KEY, papelMinimo);
