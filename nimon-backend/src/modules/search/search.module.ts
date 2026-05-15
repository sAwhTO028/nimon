import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PublicWebBaseUrlModule } from '../common/public-web-base-url.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

@Module({
  imports: [PrismaModule, AuthModule, MediaUrlCanonicalizerModule, PublicWebBaseUrlModule],
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
