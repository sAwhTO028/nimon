import { Module } from '@nestjs/common';
import { PublishedMonosController } from './published-monos.controller';
import { PublishedMonosService } from './published-monos.service';

@Module({
  controllers: [PublishedMonosController],
  providers: [PublishedMonosService],
})
export class PublishedMonosModule {}

