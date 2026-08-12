import { Module } from '@nestjs/common';
import { OrgAuthModule } from '../org-auth/org-auth.module';
import { TelemetriaDeviceController } from './telemetria-device.controller';
import { TelemetriaOrgController } from './telemetria-org.controller';
import { TelemetriaService } from './telemetria.service';

/**
 * TelemetriaModule — o totem sobe eventos (device-auth) e o Console da
 * Distribuição lê cross-tenant (org-auth).
 */
@Module({
  imports: [OrgAuthModule],
  controllers: [TelemetriaDeviceController, TelemetriaOrgController],
  providers: [TelemetriaService],
})
export class TelemetriaModule {}
