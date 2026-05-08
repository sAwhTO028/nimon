import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { MEDIA_STORAGE } from './media-storage';
import { createMediaStorage } from './media-storage.factory';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

@Module({
  imports: [AuthModule],
  controllers: [MediaController],
  providers: [
    {
      provide: MEDIA_STORAGE,
      useFactory: (config: ConfigService) => createMediaStorage(config),
      inject: [ConfigService],
    },
    MediaService,
  ],
})
export class MediaModule {}
