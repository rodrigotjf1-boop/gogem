import { Module } from '@nestjs/common';
import { MidiaModule } from '../midia/midia.module';
import { OrgAuthModule } from '../org-auth/org-auth.module';
import { KioskReleaseController } from './kiosk-release.controller';
import { KioskReleaseService } from './kiosk-release.service';

/**
 * KioskReleaseModule — auto-update do APK do totem (releases GLOBAIS). A
 * publicação (/kiosk/releases) exige login da organização (OrgAuthModule).
 */
@Module({
  imports: [MidiaModule, OrgAuthModule],
  controllers: [KioskReleaseController],
  providers: [KioskReleaseService],
})
export class KioskReleaseModule {}
