import { PartialType } from '@nestjs/swagger';
import { CreateGrupoDto } from './create-grupo.dto';

/**
 * Atualização parcial de um grupo: todos os campos opcionais, preservando os
 * validadores do DTO de criação. A coerência min/max é reavaliada no service.
 */
export class UpdateGrupoDto extends PartialType(CreateGrupoDto) {}
