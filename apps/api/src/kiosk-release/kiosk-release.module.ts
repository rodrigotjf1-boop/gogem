import { Module } from '@nestjs/common';
import { MidiaModule } from '../midia/midia.module';
import { KioskReleaseController } from './kiosk-release.controller';
import { KioskReleaseService } from './kiosk-release.service';

/** KioskReleaseModule — auto-update do APK do totem (releases GLOBAIS). */
@Module({
  imports: [MidiaModule],
  controllers: [KioskReleaseController],
  providers: [KioskReleaseService],
})
export class KioskReleaseModule {}
