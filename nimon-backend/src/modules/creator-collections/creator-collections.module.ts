import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';

import { CreatorCollectionsService } from './creator-collections.service';
import { MeCreatorCollectionsController } from './me-creator-collections.controller';
import { PublicCreatorCollectionsController } from './public-creator-collections.controller';

@Module({
  imports: [PrismaModule, AuthModule, MediaUrlCanonicalizerModule],
  controllers: [MeCreatorCollectionsController, PublicCreatorCollectionsController],
  providers: [CreatorCollectionsService],
  exports: [CreatorCollectionsService],
})
export class CreatorCollectionsModule {}
