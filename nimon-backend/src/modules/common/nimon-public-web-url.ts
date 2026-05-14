/**
 * **Web / share links** — distinct from {@link MEDIA_PUBLIC_BASE_URL} (uploads only).
 *
 * `NIMON_PUBLIC_WEB_BASE_URL` is the public origin for routes like `/mono/:id`.
 */

export const DEFAULT_NIMON_PUBLIC_WEB_BASE_URL = 'http://localhost:3000';

/**
 * Trim, strip trailing slashes. Empty / null → {@link DEFAULT_NIMON_PUBLIC_WEB_BASE_URL}.
 */
export function normalizeNimonPublicWebBaseUrl(raw: string | null | undefined): string {
  const t = (raw ?? '').trim().replace(/\/+$/, '');
  return t.length > 0 ? t : DEFAULT_NIMON_PUBLIC_WEB_BASE_URL;
}

/**
 * Canonical mono share URL for a published mono id.
 *
 * @param base — output of {@link normalizeNimonPublicWebBaseUrl} (no trailing slash)
 */
export function monShareUrlForMonoId(base: string, monoId: string): string {
  const id = monoId.trim();
  if (!id) return `${normalizeNimonPublicWebBaseUrl(base)}/mono/`;
  const b = normalizeNimonPublicWebBaseUrl(base);
  return `${b}/mono/${id}`;
}
