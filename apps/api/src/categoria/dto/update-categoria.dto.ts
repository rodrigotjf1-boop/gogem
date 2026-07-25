import { PartialType } from '@nestjs/swagger';
import { CreateCategoriaDto } from './create-categoria.dto';

/**
 * Atualização parcial de categoria: todos os campos opcionais, mantendo os
 * validadores do DTO de criação.
 */
export class UpdateCategoriaDto extends PartialType(CreateCategoriaDto) {}
