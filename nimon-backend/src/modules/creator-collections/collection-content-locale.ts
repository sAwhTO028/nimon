import { BadRequestException } from '@nestjs/common';

import {
  DEFAULT_CATALOG_CONTENT_LOCALE,
  ensureAllowedContentLocaleQuery,
  safeStoredContentLocale,
  type CatalogContentLocale,
} from '../published-monos/published-mono-catalog-locale';

export type CollectionContentLocale = CatalogContentLocale;

function trimLocale(v: string | null | undefined): string | null {
  if (v == null) return null;
  const t = String(v).trim().toLowerCase();
  return t.length > 0 ? t : null;
}

/** Validates optional wire code for collection community; throws `contentLocale_invalid`. */
export function normalizeCollectionContentLocaleInput(
  raw: string | null | undefined,
): CollectionContentLocale {
  const t = trimLocale(raw);
  if (t == null) {
    throw new BadRequestException('contentLocale_invalid');
  }
  return ensureAllowedContentLocaleQuery(t)!;
}

/** Resolves create payload locale: explicit body → user prefs → `en`. */
export function resolveCollectionContentLocaleForCreate(
  explicit: string | null | undefined,
  prefContentLocale: string | null | undefined,
): CollectionContentLocale {
  const t = trimLocale(explicit);
  if (t != null) {
    return normalizeCollectionContentLocaleInput(t);
  }
  return safeStoredContentLocale(prefContentLocale);
}

/**
 * When [collectionLocale] is set, [monoLocale] must match (non-null).
 * Legacy collections (`collectionLocale` null) skip enforcement.
 */
export function assertCollectionContentLocaleCompatible(
  collectionLocale: string | null | undefined,
  monoLocale: string | null | undefined,
  publishedMonoId?: string,
): void {
  const coll = trimLocale(collectionLocale);
  if (coll == null) return;

  const mono = trimLocale(monoLocale);
  if (mono == null || mono !== coll) {
    const body: Record<string, unknown> = { message: 'content_locale_mismatch' };
    if (publishedMonoId) body.publishedMonoId = publishedMonoId;
    throw new BadRequestException(body);
  }
}

/** Fail entire bulk add when any mono mismatches a non-null collection locale. */
export function assertBulkCollectionContentLocaleCompatible(
  collectionLocale: string | null | undefined,
  monos: ReadonlyArray<{ id: string; contentLocale: string | null | undefined }>,
): void {
  const coll = trimLocale(collectionLocale);
  if (coll == null) return;

  const mismatched = monos
    .filter((m) => {
      const mono = trimLocale(m.contentLocale);
      return mono == null || mono !== coll;
    })
    .map((m) => m.id);

  if (mismatched.length === 0) return;

  throw new BadRequestException({
    message: 'content_locale_mismatch',
    publishedMonoIds: mismatched,
  });
}

export { DEFAULT_CATALOG_CONTENT_LOCALE };
