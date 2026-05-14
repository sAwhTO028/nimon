import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PublicWebBaseUrlModule } from '../common/public-web-base-url.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PublishedMonosController } from './published-monos.controller';
import { PublishedMonosService } from './published-monos.service';

@Module({
  imports: [AuthModule, MediaUrlCanonicalizerModule, PublicWebBaseUrlModule],
  controllers: [PublishedMonosController],
  providers: [PublishedMonosService],
})
export class PublishedMonosModule {}

