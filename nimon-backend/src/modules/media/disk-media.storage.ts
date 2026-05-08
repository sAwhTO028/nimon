import { mkdir, writeFile } from 'node:fs/promises';
import { isAbsolute, join, relative, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type {
  MediaStorage,
  MediaStorageSaveParams,
  MediaStorageSaveResult,
} from './media-storage';

const DEFAULT_PUBLIC_BASE = 'http://localhost:3000/uploads';
const DEFAULT_UPLOAD_DIR = 'uploads';

/**
 * Local disk persistence under {@link MEDIA_UPLOAD_DIR}, public URLs from {@link MEDIA_PUBLIC_BASE_URL}.
 * Matches pre–M6b {@link MediaService} filesystem layout and URL shape.
 */
@Injectable()
export class DiskMediaStorage implements MediaStorage {
  constructor(private readonly config: ConfigService) {}

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

    const uploadRoot = this.uploadRootDirResolved();
    const dir = join(uploadRoot, uid, params.kind);

    await mkdir(dir, { recursive: true });

    const absolutePath = join(dir, storedName);
    const rootResolved = resolve(uploadRoot);
    const fileResolved = resolve(absolutePath);
    const rel = relative(rootResolved, fileResolved);
    if (rel.startsWith('..') || rel.split(/[/\\]/).some((p) => p === '..')) {
      throw new BadRequestException('Unsafe storage path.');
    }

    await writeFile(absolutePath, params.buffer);

    const key = `${uid}/${params.kind}/${storedName}`;
    const url = this.buildPublicUrl(uid, params.kind, storedName);
    return { key, url };
  }

  private uploadRootDirResolved(): string {
    const raw =
      this.config.get<string>('MEDIA_UPLOAD_DIR') ??
      process.env.MEDIA_UPLOAD_DIR ??
      DEFAULT_UPLOAD_DIR;
    const trimmed = raw.trim().replace(/^[/\\]+/, '').trim() || DEFAULT_UPLOAD_DIR;
    if (trimmed.includes('..')) {
      return resolve(process.cwd(), DEFAULT_UPLOAD_DIR);
    }
    if (isAbsolute(trimmed)) {
      return trimmed;
    }
    return resolve(process.cwd(), trimmed);
  }

  private publicBaseUrl(): string {
    const raw =
      this.config.get<string>('MEDIA_PUBLIC_BASE_URL') ??
      process.env.MEDIA_PUBLIC_BASE_URL ??
      DEFAULT_PUBLIC_BASE;
    const t = raw.trim().replace(/\/+$/, '');
    return t.length > 0 ? t : DEFAULT_PUBLIC_BASE;
  }

  private buildPublicUrl(
    userId: string,
    kind: 'cover' | 'audio',
    storedFileName: string,
  ): string {
    const base = this.publicBaseUrl();
    const segments = [userId, kind, storedFileName].map((s) =>
      encodeURIComponent(s),
    );
    return `${base}/${segments.join('/')}`;
  }
}
