import { PartialType } from '@nestjs/swagger';
import { CreateProdutoDto } from './create-produto.dto';

/**
 * Atualização parcial de produto: todos os campos opcionais, preservando os
 * validadores (inclusive de `externalRefs`) do DTO de criação.
 */
export class UpdateProdutoDto extends PartialType(CreateProdutoDto) {}
