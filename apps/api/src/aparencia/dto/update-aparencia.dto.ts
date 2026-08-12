import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsHexColor,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

/** Uma mídia da tela de descanso (imagem/gif/vídeo curto) + legendas (F3). */
export class DescansoMidiaDto {
  @IsString()
  @MaxLength(500)
  url!: string;

  @IsOptional()
  @IsIn(['imagem', 'gif', 'video'])
  tipo?: string;

  /** Chapéu/kicker do slide (ex.: "Feito na brasa"). */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  kicker?: string;

  /** Título do slide (ex.: "Mister Double"). */
  @IsOptional()
  @IsString()
  @MaxLength(60)
  titulo?: string;

  /** Subtítulo do slide (ex.: "Dois blends, cheddar duplo"). */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  subtitulo?: string;
}

/**
 * Atualização (parcial) da aparência do totem. Cores em hex; `raio` em px;
 * enums validados. Segue o mesmo padrão de dinheiro/segurança do projeto.
 */
export class UpdateAparenciaDto {
  @ApiPropertyOptional() @IsOptional() @IsHexColor() corPrimaria?: string;
  @ApiPropertyOptional() @IsOptional() @IsHexColor() corDestaque?: string;
  @ApiPropertyOptional() @IsOptional() @IsHexColor() corFundo?: string;
  @ApiPropertyOptional() @IsOptional() @IsHexColor() corPainel?: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(40) raio?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nomeLoja?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  logoUrl?: string;

  @ApiPropertyOptional({ enum: ['Tektur', 'Poppins', 'Montserrat'] })
  @IsOptional()
  @IsIn(['Tektur', 'Poppins', 'Montserrat'])
  fonteDisplay?: string;

  @ApiPropertyOptional({ enum: ['padrao', 'brasa', 'burger', 'gogen'] })
  @IsOptional()
  @IsIn(['padrao', 'brasa', 'burger', 'gogen'])
  temaPreset?: string;

  @ApiPropertyOptional({ enum: ['padrao', 'carrossel'] })
  @IsOptional()
  @IsIn(['padrao', 'carrossel'])
  descansoTipo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(2)
  @Max(60)
  descansoIntervaloSeg?: number;

  @ApiPropertyOptional({ type: [DescansoMidiaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DescansoMidiaDto)
  descansoMidias?: DescansoMidiaDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(60)
  chamada?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(60)
  precoIsca?: string;

  @ApiPropertyOptional({ enum: ['cheia', 'lateral'] })
  @IsOptional()
  @IsIn(['cheia', 'lateral'])
  estiloCard?: string;

  @ApiPropertyOptional({ enum: ['cheio', 'reduzido', 'off'] })
  @IsOptional()
  @IsIn(['cheio', 'reduzido', 'off'])
  animacoes?: string;
}
