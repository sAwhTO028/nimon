import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [PrismaModule, AuthModule, MediaUrlCanonicalizerModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}

