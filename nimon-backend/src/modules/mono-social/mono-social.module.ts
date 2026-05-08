import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MonoSocialController } from './mono-social.controller';
import { MonoSocialService } from './mono-social.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [MonoSocialController],
  providers: [MonoSocialService],
})
export class MonoSocialModule {}

