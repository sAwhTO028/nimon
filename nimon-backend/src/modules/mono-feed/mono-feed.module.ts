import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PublicWebBaseUrlModule } from '../common/public-web-base-url.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MonoFeedController } from './mono-feed.controller';
import { MonoFeedService } from './mono-feed.service';

@Module({
  imports: [PrismaModule, AuthModule, MediaUrlCanonicalizerModule, PublicWebBaseUrlModule],
  controllers: [MonoFeedController],
  providers: [MonoFeedService],
  exports: [MonoFeedService],
})
export class MonoFeedModule {}
