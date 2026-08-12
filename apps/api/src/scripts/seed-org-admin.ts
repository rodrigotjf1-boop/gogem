/* eslint-disable no-console */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

/**
 * Cria (ou atualiza a senha de) o 1º usuário da ORGANIZAÇÃO (DMS) — acesso ao
 * Console da Distribuição. Não há cadastro público; a org nasce por este seed.
 * Idempotente (upsert por e-mail). Roda no container da API (tem DATABASE_URL).
 *
 * Uso:
 *   node dist/scripts/seed-org-admin.js <email> <senha> [nome]
 *   ORG_ADMIN_EMAIL=... ORG_ADMIN_SENHA=... node dist/scripts/seed-org-admin.js
 * (ou em dev: npm run seed:org-admin -- <email> <senha> [nome])
 */
async function main(): Promise<void> {
  const email = (process.argv[2] || process.env.ORG_ADMIN_EMAIL || '').trim();
  const senha = process.argv[3] || process.env.ORG_ADMIN_SENHA || '';
  const nome = process.argv[4] || process.env.ORG_ADMIN_NOME || 'DMS';

  if (!email || senha.length < 8) {
    console.error(
      'Uso: seed-org-admin <email> <senha(>=8)> [nome]  (ou via ORG_ADMIN_EMAIL/ORG_ADMIN_SENHA)',
    );
    process.exit(1);
  }

  const prisma = new PrismaClient();
  const senhaHash = await bcrypt.hash(senha, 10);
  const u = await prisma.orgUsuario.upsert({
    where: { email },
    update: { senhaHash, nome, ativo: true },
    create: { email, senhaHash, nome, papel: 'admin' },
  });
  console.log(`[seed-org-admin] OK — org admin '${u.email}' (id ${u.id})`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error('[seed-org-admin] erro:', e);
  process.exit(1);
});
