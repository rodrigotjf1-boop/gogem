import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import * as bcrypt from 'bcryptjs';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOpenDeliveryAppDto } from './dto/create-app.dto';

const BCRYPT_ROUNDS = 10;
const ESCOPOS_PADRAO = ['catalog:read', 'orders:write'];

/**
 * Gestão dos apps parceiros do modo Open Delivery (GoGeM provedor). Tenant-scoped
 * (o middleware injeta o tenant §2). O `clientSecret` é gerado no cadastro e
 * devolvido UMA única vez — só o hash fica no banco.
 */
@Injectable()
export class OpenDeliveryAppService {
  constructor(private readonly prisma: PrismaService) {}

  /** Cria o app e devolve o clientSecret em claro (não recuperável depois). */
  async criar(dto: CreateOpenDeliveryAppDto): Promise<{
    id: string;
    nome: string;
    clientId: string;
    clientSecret: string;
    escopos: string[];
    ativo: boolean;
  }> {
    const clientId = `od_${randomBytes(12).toString('hex')}`;
    const clientSecret = randomBytes(24).toString('hex');
    const clientSecretHash = await bcrypt.hash(clientSecret, BCRYPT_ROUNDS);
    const escopos = dto.escopos?.length ? dto.escopos : ESCOPOS_PADRAO;

    const data = {
      nome: dto.nome,
      clientId,
      clientSecretHash,
      escopos,
    } satisfies Omit<Prisma.OpenDeliveryAppUncheckedCreateInput, 'tenantId'>;
    const app = await this.prisma.openDeliveryApp.create({
      data: data as Prisma.OpenDeliveryAppUncheckedCreateInput,
    });

    return {
      id: app.id,
      nome: app.nome,
      clientId,
      clientSecret, // ⚠️ mostrado só agora
      escopos: app.escopos,
      ativo: app.ativo,
    };
  }

  /** Lista os apps do tenant (sem segredo). */
  async listar() {
    const apps = await this.prisma.openDeliveryApp.findMany({
      orderBy: { createdAt: 'desc' },
    });
    return apps.map((a) => ({
      id: a.id,
      nome: a.nome,
      clientId: a.clientId,
      escopos: a.escopos,
      ativo: a.ativo,
      ultimoUso: a.ultimoUso,
      createdAt: a.createdAt,
    }));
  }

  /** Revoga (desativa) um app — os tokens dele param de valer na próxima checagem. */
  async revogar(id: string): Promise<{ id: string }> {
    const app = await this.prisma.openDeliveryApp.findFirst({ where: { id } });
    if (!app) throw new NotFoundException('App não encontrado.');
    await this.prisma.openDeliveryApp.update({
      where: { id },
      data: { ativo: false },
    });
    return { id };
  }
}
