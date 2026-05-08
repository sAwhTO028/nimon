import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import type { MulterMemoryUploadedFile } from './media-upload.types';
import type { MediaUploadResponseDto } from './media-upload-response.dto';
import {
  readAudioMaxBytesFromEnv,
  readCoverMaxBytesFromEnv,
} from './media-file-limits';
import { MEDIA_STORAGE, type MediaStorage } from './media-storage';
import {
  assertWithinMax,
  CANONICAL_AUDIO_MPEG,
  CANONICAL_AUDIO_MP4,
  CANONICAL_AUDIO_WAV,
  resolveAudioMime,
  resolveCoverMime,
  sanitizeOriginalFilename,
  type MediaKind,
} from './media.validation';

function extensionForMime(normalizedMime: string): string {
  switch (normalizedMime) {
    case 'image/jpeg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    case CANONICAL_AUDIO_MPEG:
      return '.mp3';
    case CANONICAL_AUDIO_MP4:
      return '.m4a';
    case CANONICAL_AUDIO_WAV:
      return '.wav';
    default:
      return '.bin';
  }
}

@Injectable()
export class MediaService {
  constructor(
    @Inject(MEDIA_STORAGE) private readonly storage: MediaStorage,
  ) {}

  async saveCover(
    userId: string,
    file: MulterMemoryUploadedFile,
  ): Promise<MediaUploadResponseDto> {
    const maxBytes = this.coverMaxBytes();
    assertWithinMax(file.size, maxBytes);
    const mime = resolveCoverMime(file.mimetype, file.originalname);
    return this.persistFile(userId, 'cover', file, mime);
  }

  async saveAudio(
    userId: string,
    file: MulterMemoryUploadedFile,
  ): Promise<MediaUploadResponseDto> {
    const maxBytes = this.audioMaxBytes();
    assertWithinMax(file.size, maxBytes);
    const mime = resolveAudioMime(file.mimetype, file.originalname);
    return this.persistFile(userId, 'audio', file, mime);
  }

  coverMaxBytes(): number {
    return readCoverMaxBytesFromEnv();
  }

  audioMaxBytes(): number {
    return readAudioMaxBytesFromEnv();
  }

  private async persistFile(
    userId: string,
    kind: MediaKind,
    file: MulterMemoryUploadedFile,
    normalizedMime: string,
  ): Promise<MediaUploadResponseDto> {
    const uid = userId.trim();
    if (!uid || uid.includes('..') || uid.includes('/') || uid.includes('\\')) {
      throw new BadRequestException('Invalid user id.');
    }

    const ext = extensionForMime(normalizedMime);
    const { url } = await this.storage.save({
      userId: uid,
      kind,
      buffer: file.buffer,
      extension: ext,
      mediaType: normalizedMime,
    });

    const originalName = sanitizeOriginalFilename(file.originalname ?? '');

    return {
      url,
      mediaType: normalizedMime,
      originalName,
      sizeBytes: file.size,
      durationSeconds: null,
    };
  }
}
