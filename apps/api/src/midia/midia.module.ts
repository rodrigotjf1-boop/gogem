import { Module } from '@nestjs/common';
import { MidiaController } from './midia.controller';
import { MidiaService } from './midia.service';

/** MidiaModule — upload de imagens para o Storage (Supabase/S3). */
@Module({
  controllers: [MidiaController],
  providers: [MidiaService],
})
export class MidiaModule {}
