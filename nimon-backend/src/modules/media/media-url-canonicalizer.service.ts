import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  canonicalizeMediaUrl,
  normalizeMediaPublicBaseUrl,
} from './media-url-canonicalizer';

@Injectable()
export class MediaUrlCanonicalizerService {
  constructor(private readonly config: ConfigService) {}

  /** Effective `MEDIA_PUBLIC_BASE_URL` (trimmed, no trailing slash). */
  mediaPublicBaseUrl(): string {
    const raw =
      this.config.get<string>('MEDIA_PUBLIC_BASE_URL') ??
      process.env.MEDIA_PUBLIC_BASE_URL ??
      undefined;
    return normalizeMediaPublicBaseUrl(raw);
  }

  /** Canonicalize a single media URL for API responses. */
  url(raw: string | null | undefined): string | null {
    return canonicalizeMediaUrl(raw, this.mediaPublicBaseUrl());
  }
}
