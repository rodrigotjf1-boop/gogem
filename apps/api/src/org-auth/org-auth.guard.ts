import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * OrgAuthGuard — protege as rotas do Console da Distribuição: exige um Bearer
 * token da ORGANIZAÇÃO (estratégia 'org-jwt', `tipo: 'org'`). Um token de
 * cliente (tenant) é rejeitado.
 */
@Injectable()
export class OrgAuthGuard extends AuthGuard('org-jwt') {}
