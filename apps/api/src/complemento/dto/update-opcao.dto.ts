import { PartialType } from '@nestjs/swagger';
import { CreateOpcaoDto } from './create-opcao.dto';

/**
 * Atualização parcial de uma opção: todos os campos opcionais, preservando os
 * validadores (inclusive de `externalRefs`) do DTO de criação.
 */
export class UpdateOpcaoDto extends PartialType(CreateOpcaoDto) {}
