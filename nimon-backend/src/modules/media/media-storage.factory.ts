import { ConfigService } from '@nestjs/config';
import { DiskMediaStorage } from './disk-media.storage';
import type { MediaStorage } from './media-storage';
import { S3MediaStorage, assertObjectStorageEnv } from './s3-media.storage';

/**
 * Selects {@link DiskMediaStorage} or {@link S3MediaStorage} from env.
 * Default driver is `disk`.
 */
export function createMediaStorage(config: ConfigService): MediaStorage {
  const raw =
    config.get<string>('MEDIA_STORAGE_DRIVER') ??
    process.env.MEDIA_STORAGE_DRIVER ??
    'disk';
  const d = String(raw).trim().toLowerCase();
  if (d === 's3' || d === 'r2') {
    assertObjectStorageEnv(config);
    return new S3MediaStorage(config);
  }
  if (d === 'disk' || d === '') {
    return new DiskMediaStorage(config);
  }
  throw new Error(
    `Media storage: unknown MEDIA_STORAGE_DRIVER "${raw}". Use disk, s3, or r2.`,
  );
}
