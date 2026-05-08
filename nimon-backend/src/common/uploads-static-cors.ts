import type { IncomingMessage } from 'node:http';
import type { Request, Response } from 'express';

/**
 * True when the request Origin is safe for local Flutter Web / Vite / webpack-dev-server.
 * (CORS does not support `http://localhost:*` as a string; we validate the URL instead.)
 */
export function isLocalWebDevOrigin(origin: string | undefined): boolean {
  if (origin == null || origin.length === 0) {
    // e.g. Postman, curl, same-origin, or some embedded contexts
    return true;
  }
  try {
    const u = new URL(origin);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') {
      return false;
    }
    const h = u.hostname;
    if (h === 'localhost' || h === '127.0.0.1' || h === '::1' || h === '[::1]') {
      return true;
    }
  } catch {
    return false;
  }
  return false;
}

/**
 * Resolves `Access-Control-Allow-Origin` for static `/uploads` responses.
 *
 * - `CORS_ORIGIN=*` → `*`
 * - `CORS_ORIGIN=<absolute origin>` → that value (single origin)
 * - unset → reflect localhost-style origins; non-production falls back to `*`
 * - production without `CORS_ORIGIN` and non-localhost Origin → no header (`null`)
 */
export function resolveUploadsAccessControlAllowOrigin(
  req: Pick<IncomingMessage, 'headers'>,
): string | null {
  const env = process.env.CORS_ORIGIN?.trim();
  if (env === '*') {
    return '*';
  }
  if (env && env.length > 0) {
    return env;
  }

  const origin = req.headers?.origin;
  if (typeof origin === 'string' && isLocalWebDevOrigin(origin)) {
    return origin;
  }
  if (process.env.NODE_ENV === 'production') {
    return null;
  }
  return '*';
}

/**
 * Headers for files served by `express.static` under `/uploads` so browsers / Flutter web
 * can load images cross-origin (Nest `enableCors` does not attach to this middleware).
 */
export function applyUploadsStaticCors(req: Request, res: Response): void {
  const allow = resolveUploadsAccessControlAllowOrigin(req);
  if (allow != null) {
    res.setHeader('Access-Control-Allow-Origin', allow);
    if (allow !== '*') {
      res.setHeader('Vary', 'Origin');
    }
  }

  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Accept, Range, Content-Type, If-None-Match',
  );
  res.setHeader('Access-Control-Max-Age', '86400');
}
