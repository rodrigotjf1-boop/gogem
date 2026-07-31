import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { OdScope, OpenDeliveryAuthGuard } from './open-delivery-auth.guard';
import { OpenDeliveryCatalogService } from './open-delivery-catalog.service';

/**
 * Rotas PÚBLICAS de catálogo do Open Delivery (Bearer do /oauth/token, escopo
 * `catalog:read`). Namespace fora do /api/v1.
 */
@ApiTags('open-delivery')
@UseGuards(OpenDeliveryAuthGuard)
@Controller('open-delivery/v1/merchants')
export class OpenDeliveryCatalogController {
  constructor(private readonly catalogo: OpenDeliveryCatalogService) {}

  @Get(':merchantId')
  @OdScope('catalog:read')
  merchant(@Param('merchantId') merchantId: string) {
    return this.catalogo.merchant(merchantId);
  }

  @Get(':merchantId/catalog')
  @OdScope('catalog:read')
  catalog(@Param('merchantId') merchantId: string) {
    return this.catalogo.catalog(merchantId);
  }
}
