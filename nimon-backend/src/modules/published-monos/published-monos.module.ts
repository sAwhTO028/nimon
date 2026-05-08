import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PublishedMonosController } from './published-monos.controller';
import { PublishedMonosService } from './published-monos.service';

@Module({
  imports: [AuthModule],
  controllers: [PublishedMonosController],
  providers: [PublishedMonosService],
})
export class PublishedMonosModule {}

