import {
  Controller,
  Post,
  UploadedFile,
  UseFilters,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { MulterMemoryUploadedFile } from './media-upload.types';
import { createMulterMemoryStorage } from './multer-memory.storage';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import type { MediaUploadResponseDto } from './media-upload-response.dto';
import {
  readAudioMaxBytesFromEnv,
  readCoverMaxBytesFromEnv,
} from './media-file-limits';
import { MediaService } from './media.service';
import { assertFilePresent } from './media.validation';
import { MulterExceptionFilter } from './multer-exception.filter';

@Controller('v1/media')
@UseGuards(JwtAuthGuard)
@UseFilters(MulterExceptionFilter)
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post('upload/cover')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: createMulterMemoryStorage(),
      limits: { fileSize: readCoverMaxBytesFromEnv() },
    }),
  )
  async uploadCover(
    @UploadedFile() file: MulterMemoryUploadedFile | undefined,
    @CurrentUser() user: JwtValidatedUser,
  ): Promise<MediaUploadResponseDto> {
    assertFilePresent(file);
    return this.media.saveCover(user.userId, file);
  }

  @Post('upload/audio')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: createMulterMemoryStorage(),
      limits: { fileSize: readAudioMaxBytesFromEnv() },
    }),
  )
  async uploadAudio(
    @UploadedFile() file: MulterMemoryUploadedFile | undefined,
    @CurrentUser() user: JwtValidatedUser,
  ): Promise<MediaUploadResponseDto> {
    assertFilePresent(file);
    return this.media.saveAudio(user.userId, file);
  }
}
