import { Injectable } from '@nestjs/common';
import { Prisma, type Aparencia } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateAparenciaDto } from './dto/update-aparencia.dto';

/**
 * AparenciaService — aparência do totem POR LOJA (Fase 6). Uma linha por tenant
 * (auto-criada com os padrões da marca GoGeM). O totem recebe no
 * `/catalogo/publicado` e aplica no próximo sync — o render é do app do totem.
 *
 * Multi-tenant (§2): o middleware injeta o tenant; create sem tenantId à mão.
 */
@Injectable()
export class AparenciaService {
  constructor(private readonly prisma: PrismaService) {}

  /** Obtém a aparência do tenant; cria com os padrões se ainda não existir. */
  async obter(): Promise<Aparencia> {
    const existente = await this.prisma.aparencia.findFirst();
    if (existente) return existente;
    // Colunas usam @default no schema; o middleware injeta o tenantId.
    return this.prisma.aparencia.create({
      data: {} as Prisma.AparenciaUncheckedCreateInput,
    });
  }

  /** Atualização parcial (upsert lógico: garante a linha, aplica o patch). */
  async atualizar(dto: UpdateAparenciaDto): Promise<Aparencia> {
    const atual = await this.obter();
    return this.prisma.aparencia.update({
      where: { id: atual.id },
      data: {
        corPrimaria: dto.corPrimaria,
        corDestaque: dto.corDestaque,
        corFundo: dto.corFundo,
        corPainel: dto.corPainel,
        raio: dto.raio,
        nomeLoja: dto.nomeLoja,
        logoUrl: dto.logoUrl,
        fonteDisplay: dto.fonteDisplay,
        temaPreset: dto.temaPreset,
        descansoTipo: dto.descansoTipo,
        descansoIntervaloSeg: dto.descansoIntervaloSeg,
        descansoMidias:
          dto.descansoMidias === undefined
            ? undefined
            : (dto.descansoMidias as unknown as Prisma.InputJsonValue),
        chamada: dto.chamada,
        precoIsca: dto.precoIsca,
        estiloCard: dto.estiloCard,
        animacoes: dto.animacoes,
      },
    });
  }
}
