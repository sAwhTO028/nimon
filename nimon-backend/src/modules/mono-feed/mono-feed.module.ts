import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MonoFeedController } from './mono-feed.controller';
import { MonoFeedService } from './mono-feed.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [MonoFeedController],
  providers: [MonoFeedService],
  exports: [MonoFeedService],
})
export class MonoFeedModule {}
