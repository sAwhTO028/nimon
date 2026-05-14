import { Module } from '@nestjs/common';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { UserFollowController } from './user-follow.controller';
import { UserFollowService } from './user-follow.service';

@Module({
  imports: [PrismaModule, MediaUrlCanonicalizerModule],
  controllers: [UserFollowController],
  providers: [UserFollowService],
  exports: [UserFollowService],
})
export class UserFollowModule {}

