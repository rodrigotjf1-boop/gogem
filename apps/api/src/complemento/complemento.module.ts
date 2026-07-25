import { Module } from '@nestjs/common';
import { ComplementoController } from './complemento.controller';
import { ComplementoService } from './complemento.service';

@Module({
  controllers: [ComplementoController],
  providers: [ComplementoService],
  exports: [ComplementoService],
})
export class ComplementoModule {}
