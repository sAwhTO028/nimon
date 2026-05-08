import { ConfigService } from '@nestjs/config';
import { DiskMediaStorage } from './disk-media.storage';
import { createMediaStorage } from './media-storage.factory';
import { S3MediaStorage } from './s3-media.storage';

const ENV_KEYS = [
  'MEDIA_STORAGE_DRIVER',
  'MEDIA_BUCKET',
  'MEDIA_REGION',
  'MEDIA_ENDPOINT',
  'MEDIA_ACCESS_KEY_ID',
  'MEDIA_SECRET_ACCESS_KEY',
  'MEDIA_PUBLIC_BASE_URL',
  'MEDIA_OBJECT_KEY_PREFIX',
] as const;

describe('createMediaStorage', () => {
  beforeEach(() => {
    for (const k of ENV_KEYS) {
      delete process.env[k];
    }
  });

  it('chooses DiskMediaStorage when MEDIA_STORAGE_DRIVER is unset', () => {
    const config = new ConfigService({
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:3000/uploads',
      MEDIA_UPLOAD_DIR: 'uploads',
    });
    const storage = createMediaStorage(config);
    expect(storage).toBeInstanceOf(DiskMediaStorage);
  });

  it('chooses DiskMediaStorage when MEDIA_STORAGE_DRIVER is disk', () => {
    const config = new ConfigService({
      MEDIA_STORAGE_DRIVER: 'disk',
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:3000/uploads',
      MEDIA_UPLOAD_DIR: 'uploads',
    });
    expect(createMediaStorage(config)).toBeInstanceOf(DiskMediaStorage);
  });

  it('chooses S3MediaStorage when MEDIA_STORAGE_DRIVER is s3 with required env', () => {
    const config = new ConfigService({
      MEDIA_STORAGE_DRIVER: 's3',
      MEDIA_BUCKET: 'test-bucket',
      MEDIA_REGION: 'us-east-1',
      MEDIA_ACCESS_KEY_ID: 'AKIA_TEST',
      MEDIA_SECRET_ACCESS_KEY: 'secret',
      MEDIA_PUBLIC_BASE_URL: 'https://cdn.example.com',
    });
    expect(createMediaStorage(config)).toBeInstanceOf(S3MediaStorage);
  });

  it('chooses S3MediaStorage when MEDIA_STORAGE_DRIVER is r2 (R2 uses same driver)', () => {
    const config = new ConfigService({
      MEDIA_STORAGE_DRIVER: 'r2',
      MEDIA_BUCKET: 'r2-bucket',
      MEDIA_REGION: 'auto',
      MEDIA_ENDPOINT: 'https://account.r2.cloudflarestorage.com',
      MEDIA_ACCESS_KEY_ID: 'token',
      MEDIA_SECRET_ACCESS_KEY: 'secret',
      MEDIA_PUBLIC_BASE_URL: 'https://pub.example.com',
    });
    expect(createMediaStorage(config)).toBeInstanceOf(S3MediaStorage);
  });

  it('throws a clear error when s3 is selected but MEDIA_SECRET_ACCESS_KEY is missing', () => {
    const config = new ConfigService({
      MEDIA_STORAGE_DRIVER: 's3',
      MEDIA_BUCKET: 'b',
      MEDIA_REGION: 'auto',
      MEDIA_ACCESS_KEY_ID: 'k',
      MEDIA_PUBLIC_BASE_URL: 'https://cdn.example.com',
    });
    expect(() => createMediaStorage(config)).toThrow(
      /MEDIA_SECRET_ACCESS_KEY.*s3 or r2/i,
    );
  });

  it('throws when driver value is unknown', () => {
    const config = new ConfigService({
      MEDIA_STORAGE_DRIVER: 'minio',
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:3000/uploads',
      MEDIA_UPLOAD_DIR: 'uploads',
    });
    expect(() => createMediaStorage(config)).toThrow(/unknown MEDIA_STORAGE_DRIVER/i);
  });
});
