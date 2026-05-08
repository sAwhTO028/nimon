import { randomUUID } from 'node:crypto';
import {
  PutObjectCommand,
  type PutObjectCommandInput,
  S3Client,
} from '@aws-sdk/client-s3';
import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type {
  MediaStorage,
  MediaStorageSaveParams,
  MediaStorageSaveResult,
} from './media-storage';

const CFG_ERR = 'Media storage (S3/R2) configuration:';

/** Required when {@link MEDIA_STORAGE_DRIVER} is `s3` or `r2`. */
export function assertObjectStorageEnv(config: ConfigService): void {
  const keys = [
    'MEDIA_BUCKET',
    'MEDIA_REGION',
    'MEDIA_ACCESS_KEY_ID',
    'MEDIA_SECRET_ACCESS_KEY',
    'MEDIA_PUBLIC_BASE_URL',
  ] as const;
  for (const key of keys) {
    const raw = config.get<string>(key) ?? process.env[key];
    const v = raw !== undefined && raw !== null ? String(raw).trim() : '';
    if (!v) {
      throw new Error(
        `${CFG_ERR} ${key} is required when MEDIA_STORAGE_DRIVER is s3 or r2.`,
      );
    }
  }
}

export type S3MediaStorageOptions = {
  /** Injected for tests; default client is built from env. */
  client?: S3Client;
};

/**
 * S3-compatible object storage (AWS S3 or Cloudflare R2) implementing {@link MediaStorage}.
 * Keys match disk layout after optional {@link MEDIA_OBJECT_KEY_PREFIX}.
 */
@Injectable()
export class S3MediaStorage implements MediaStorage {
  private readonly s3: S3Client;

  constructor(
    private readonly config: ConfigService,
    @Optional() options?: S3MediaStorageOptions,
  ) {
    this.s3 =
      options?.client ??
      new S3Client({
        region:
          this.config.get<string>('MEDIA_REGION')?.trim() ??
          process.env.MEDIA_REGION?.trim() ??
          'us-east-1',
        endpoint: this.optionalTrimmed('MEDIA_ENDPOINT'),
        credentials: {
          accessKeyId:
            this.config.get<string>('MEDIA_ACCESS_KEY_ID')?.trim() ??
            process.env.MEDIA_ACCESS_KEY_ID?.trim() ??
            '',
          secretAccessKey:
            this.config.get<string>('MEDIA_SECRET_ACCESS_KEY')?.trim() ??
            process.env.MEDIA_SECRET_ACCESS_KEY?.trim() ??
            '',
        },
        forcePathStyle: this.resolveForcePathStyle(),
      });
  }

  async save(params: MediaStorageSaveParams): Promise<MediaStorageSaveResult> {
    const uid = params.userId.trim();
    if (!uid || uid.includes('..') || uid.includes('/') || uid.includes('\\')) {
      throw new BadRequestException('Invalid user id.');
    }

    const ext = params.extension.trim();
    if (!ext.startsWith('.') || ext.length < 2) {
      throw new BadRequestException('Invalid storage extension.');
    }

    const storedName = `${Date.now()}-${randomUUID()}${ext}`;
    if (
      storedName.includes('..') ||
      storedName.includes('/') ||
      storedName.includes('\\')
    ) {
      throw new BadRequestException('Invalid storage name.');
    }

    const key = this.buildObjectKey(uid, params.kind, storedName);
    const bucket = (
      this.config.get<string>('MEDIA_BUCKET') ??
      process.env.MEDIA_BUCKET ??
      ''
    ).trim();

    const body = params.buffer;
    const input: PutObjectCommandInput = {
      Bucket: bucket,
      Key: key,
      Body: body,
      ContentType: params.mediaType,
      ContentLength: body.length,
    };

    await this.s3.send(new PutObjectCommand(input));

    const url = this.buildPublicUrl(key);
    return { key, url };
  }

  private optionalTrimmed(key: string): string | undefined {
    const raw = this.config.get<string>(key) ?? process.env[key];
    if (raw === undefined || raw === null) return undefined;
    const t = String(raw).trim();
    return t.length > 0 ? t : undefined;
  }

  private resolveForcePathStyle(): boolean {
    const raw =
      this.config.get<string>('MEDIA_S3_FORCE_PATH_STYLE') ??
      process.env.MEDIA_S3_FORCE_PATH_STYLE;
    if (raw !== undefined && raw !== null && String(raw).trim() !== '') {
      const lower = String(raw).trim().toLowerCase();
      if (lower === 'true' || lower === '1' || lower === 'yes') return true;
      if (lower === 'false' || lower === '0' || lower === 'no') return false;
    }
    return Boolean(this.optionalTrimmed('MEDIA_ENDPOINT'));
  }

  private objectKeyPrefix(): string {
    const raw =
      this.config.get<string>('MEDIA_OBJECT_KEY_PREFIX') ??
      process.env.MEDIA_OBJECT_KEY_PREFIX ??
      '';
    const t = String(raw).trim().replace(/^[/\\]+|[/\\]+$/g, '');
    if (t.includes('..') || t.includes('\\')) {
      throw new BadRequestException('Invalid MEDIA_OBJECT_KEY_PREFIX.');
    }
    return t;
  }

  private buildObjectKey(
    userId: string,
    kind: 'cover' | 'audio',
    storedName: string,
  ): string {
    const rel = `${userId}/${kind}/${storedName}`;
    const prefix = this.objectKeyPrefix();
    if (!prefix) return rel;
    return `${prefix}/${rel}`;
  }

  private publicBaseUrl(): string {
    const raw =
      this.config.get<string>('MEDIA_PUBLIC_BASE_URL') ??
      process.env.MEDIA_PUBLIC_BASE_URL ??
      '';
    const t = raw.trim().replace(/\/+$/, '');
    if (!t) {
      throw new Error(
        `${CFG_ERR} MEDIA_PUBLIC_BASE_URL is required for S3/R2 storage.`,
      );
    }
    return t;
  }

  private buildPublicUrl(objectKey: string): string {
    const base = this.publicBaseUrl();
    const segments = objectKey
      .split('/')
      .filter((s) => s.length > 0)
      .map((s) => encodeURIComponent(s));
    return `${base}/${segments.join('/')}`;
  }
}
