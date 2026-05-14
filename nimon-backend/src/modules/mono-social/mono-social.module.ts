import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PublicWebBaseUrlModule } from '../common/public-web-base-url.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MonoSocialController } from './mono-social.controller';
import { MonoSocialService } from './mono-social.service';

@Module({
  imports: [PrismaModule, AuthModule, MediaUrlCanonicalizerModule, PublicWebBaseUrlModule],
  controllers: [MonoSocialController],
  providers: [MonoSocialService],
})
export class MonoSocialModule {}

