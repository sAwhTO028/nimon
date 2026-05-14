/**
 * Rewrites loopback dev URLs and `/uploads/...` paths to the configured
 * {@link MEDIA_PUBLIC_BASE_URL} so physical devices can fetch media from the LAN host.
 */

export const DEFAULT_MEDIA_PUBLIC_BASE_URL = 'http://localhost:3000/uploads';

/** Matches {@link DiskMediaStorage} / disk-media.storage.ts default normalization. */
export function normalizeMediaPublicBaseUrl(raw?: string | null): string {
  const t = (raw ?? DEFAULT_MEDIA_PUBLIC_BASE_URL).trim().replace(/\/+$/, '');
  return t.length > 0 ? t : DEFAULT_MEDIA_PUBLIC_BASE_URL;
}

/**
 * @param mediaPublicBaseUrl — trimmed `MEDIA_PUBLIC_BASE_URL` (no trailing slash), e.g.
 *   `http://192.168.11.5:3000/uploads`
 */
export function canonicalizeMediaUrl(
  url: string | null | undefined,
  mediaPublicBaseUrl: string,
): string | null {
  if (url == null) return null;
  const trimmed = url.trim();
  if (!trimmed) return null;

  const base = normalizeMediaPublicBaseUrl(mediaPublicBaseUrl);

  if (trimmed.startsWith('/uploads/')) {
    const rest = trimmed.slice('/uploads'.length);
    return `${base}${rest}`;
  }
  if (trimmed === '/uploads') {
    return base;
  }

  try {
    const u = new URL(trimmed);
    const rawHost = u.hostname;
    /** WHATWG host parsing differs between runtimes; IPv6 may include brackets. */
    const host =
      rawHost.startsWith('[') && rawHost.endsWith(']')
        ? rawHost.slice(1, -1)
        : rawHost;
    const isLoopback =
      host === 'localhost' || host === '127.0.0.1' || host === '::1';
    if (!isLoopback) {
      return trimmed;
    }
    if (!u.pathname.startsWith('/uploads')) {
      return trimmed;
    }
    const pathRest =
      u.pathname === '/uploads' || u.pathname === '/uploads/'
        ? ''
        : u.pathname.startsWith('/uploads/')
          ? u.pathname.slice('/uploads'.length)
          : '';
    const merged =
      pathRest === '' || pathRest.startsWith('/')
        ? `${base}${pathRest}`
        : `${base}/${pathRest}`;
    return `${merged}${u.search}`;
  } catch {
    return trimmed;
  }
}

/** Deep-clone published `content` JSON and canonicalize nested upload URLs. */
export function clonePublishedContentWithCanonicalMedia(
  content: unknown,
  mediaPublicBaseUrl: string,
): unknown {
  if (content == null) return content;
  let cloned: unknown;
  try {
    cloned = JSON.parse(JSON.stringify(content));
  } catch {
    return content;
  }
  const c = cloned as Record<string, unknown>;

  const core = c.core;
  if (core && typeof core === 'object') {
    const co = core as Record<string, unknown>;
    if (typeof co.coverImageUrl === 'string') {
      const next = canonicalizeMediaUrl(co.coverImageUrl, mediaPublicBaseUrl);
      if (next != null) co.coverImageUrl = next;
    }
  }

  const learn = c.learn;
  if (learn && typeof learn === 'object') {
    const audio = (learn as Record<string, unknown>).audio;
    if (audio && typeof audio === 'object') {
      const storyAudio = (audio as Record<string, unknown>).storyAudio;
      if (storyAudio && typeof storyAudio === 'object') {
        const sa = storyAudio as Record<string, unknown>;
        if (typeof sa.sourceUrl === 'string') {
          const next = canonicalizeMediaUrl(sa.sourceUrl, mediaPublicBaseUrl);
          if (next != null) sa.sourceUrl = next;
        }
      }
    }
  }

  return cloned;
}
