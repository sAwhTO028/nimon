import { ConfigService } from '@nestjs/config';

/** Non-secret placeholder for local dev only; ≥32 chars for HS256 keys in dev. */
const DEV_ONLY_JWT_SECRET_FALLBACK =
  'nimon-dev-only-jwt-secret-min-32-chars!!';

export function resolveJwtSecret(config: ConfigService): string {
  const raw = config.get<string>('JWT_SECRET') ?? process.env.JWT_SECRET;
  const s = typeof raw === 'string' ? raw.trim() : '';
  if (s.length >= 32) {
    return s;
  }

  const nodeEnv =
    config.get<string>('NODE_ENV') ?? process.env.NODE_ENV ?? 'development';
  if (nodeEnv === 'production') {
    throw new Error(
      'JWT_SECRET must be set and at least 32 characters when NODE_ENV=production',
    );
  }
  // eslint-disable-next-line no-console
  console.warn(
    '[auth] JWT_SECRET missing or shorter than 32 chars — using dev-only fallback. Set JWT_SECRET for real auth.',
  );
  return DEV_ONLY_JWT_SECRET_FALLBACK;
}

export function resolveAccessExpiresIn(config: ConfigService): string {
  return (
    config.get<string>('JWT_EXPIRES_IN') ??
    process.env.JWT_EXPIRES_IN ??
    '15m'
  );
}

/**
 * Refresh token lifetime in seconds (integer). Env: JWT_REFRESH_EXPIRES_IN.
 * Default: 7 days.
 */
export function resolveRefreshExpiresSeconds(config: ConfigService): number {
  const raw =
    config.get<string>('JWT_REFRESH_EXPIRES_IN') ??
    process.env.JWT_REFRESH_EXPIRES_IN;
  if (raw != null && String(raw).trim() !== '') {
    const n = Number.parseInt(String(raw).trim(), 10);
    if (!Number.isFinite(n) || n <= 0) {
      throw new Error(
        'JWT_REFRESH_EXPIRES_IN must be a positive integer (seconds)',
      );
    }
    return n;
  }
  return 604800;
}
