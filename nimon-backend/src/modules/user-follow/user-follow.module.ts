import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { UserFollowController } from './user-follow.controller';
import { UserFollowService } from './user-follow.service';

@Module({
  imports: [PrismaModule],
  controllers: [UserFollowController],
  providers: [UserFollowService],
  exports: [UserFollowService],
})
export class UserFollowModule {}

