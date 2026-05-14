import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  monShareUrlForMonoId,
  normalizeNimonPublicWebBaseUrl,
} from './nimon-public-web-url';

@Injectable()
export class PublicWebBaseUrlService {
  constructor(private readonly config: ConfigService) {}

  /**
   * Effective `NIMON_PUBLIC_WEB_BASE_URL` (trimmed, no trailing slash).
   * Falls back to `PUBLIC_WEB_BASE_URL`, then `http://localhost:3000`.
   */
  baseUrl(): string {
    const raw =
      this.config.get<string>('NIMON_PUBLIC_WEB_BASE_URL') ??
      process.env.NIMON_PUBLIC_WEB_BASE_URL ??
      this.config.get<string>('PUBLIC_WEB_BASE_URL') ??
      process.env.PUBLIC_WEB_BASE_URL ??
      '';
    return normalizeNimonPublicWebBaseUrl(raw || undefined);
  }

  /** `${base}/mono/${monoId}` — never uses media upload base. */
  monoShareUrl(monoId: string): string {
    return monShareUrlForMonoId(this.baseUrl(), monoId);
  }
}
