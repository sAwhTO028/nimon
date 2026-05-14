import type { Prisma } from '@prisma/client';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';

/** Prisma scope for owner Published tab visible counts (same predicate as list). */
export type PublishedTabQuotaScope = {
  publishedMono: {
    count(args: { where: Prisma.PublishedMonoWhereInput }): Promise<number>;
  };
};

export type PublishedTabRevealQuotaLogTag = 'publish-quota' | 'cancel-edit' | 'restore-quota';

export type PublishedTabRevealQuotaAttempt = {
  tag: PublishedTabRevealQuotaLogTag;
  draftId?: string;
  publishedMonoId?: string;
};

/**
 * Owner **Published tab** visible mono count — identical predicate to
 * `GET /v1/published-monos` default list (`PUBLISHED_MONO_CATALOG_VISIBLE`).
 */
export async function countOwnerPublishedTabVisibleMonos(
  scope: PublishedTabQuotaScope,
  ownerId: string,
): Promise<number> {
  return scope.publishedMono.count({
    where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
  });
}

/** @deprecated Prefer {@link countOwnerPublishedTabVisibleMonos} (M17E-7 naming). */
export const countPublishedTabVisibleMonos = countOwnerPublishedTabVisibleMonos;

/** Whether this owned mono currently matches the Published tab row predicate. */
export async function isOwnerPublishedMonoTabVisible(
  scope: PublishedTabQuotaScope,
  ownerId: string,
  publishedMonoId: string,
): Promise<boolean> {
  const n = await scope.publishedMono.count({
    where: { id: publishedMonoId, ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
  });
  return n > 0;
}

/**
 * M17E-7: actions that **add or reveal** one catalog-visible Published tab row
 * must satisfy `visiblePublishedCount + 1 <= limit` (i.e. block when next > limit).
 *
 * `current` in {@link QuotaExceededException} is the **visible** count before the action.
 */
export async function assertCanRevealOnePublishedTabMono(
  scope: PublishedTabQuotaScope,
  ownerId: string,
  ctx: PublishedTabRevealQuotaAttempt,
  log?: (line: string) => void,
): Promise<{ current: number; nextVisibleCount: number }> {
  const current = await countOwnerPublishedTabVisibleMonos(scope, ownerId);
  const limit = FREE_TIER_QUOTAS.publishedMonos;
  const nextVisibleCount = current + 1;
  const willBlock = nextVisibleCount > limit;
  if (process.env.NODE_ENV !== 'production') {
    log?.(
      `[M17E-7 ${ctx.tag}] ownerId=${ownerId} draftId=${ctx.draftId ?? 'n/a'} publishedMonoId=${ctx.publishedMonoId ?? 'n/a'} visiblePublishedCount=${current} nextVisibleCount=${nextVisibleCount} limit=${limit} willBlock=${willBlock}`,
    );
  }
  if (willBlock) {
    throw new QuotaExceededException(FREE_TIER_QUOTA_KEYS.publishedMonos, limit, current);
  }
  return { current, nextVisibleCount };
}

/**
 * Dev-only log when a publish path does **not** add a catalog-visible row (mono already on
 * Published tab), so quota `nextVisibleCount` stays at `current`.
 */
export async function logPublishedTabPublishQuotaIfDev(
  scope: PublishedTabQuotaScope,
  ownerId: string,
  ctx: PublishedTabRevealQuotaAttempt,
  log: (line: string) => void,
  addsOneVisibleCatalogRow: boolean,
): Promise<void> {
  if (process.env.NODE_ENV === 'production') {
    return;
  }
  const current = await countOwnerPublishedTabVisibleMonos(scope, ownerId);
  const limit = FREE_TIER_QUOTAS.publishedMonos;
  const nextVisibleCount = addsOneVisibleCatalogRow ? current + 1 : current;
  const willBlock = addsOneVisibleCatalogRow && nextVisibleCount > limit;
  log(
    `[M17E-7 ${ctx.tag}] ownerId=${ownerId} draftId=${ctx.draftId ?? 'n/a'} publishedMonoId=${ctx.publishedMonoId ?? 'n/a'} visiblePublishedCount=${current} nextVisibleCount=${nextVisibleCount} limit=${limit} willBlock=${willBlock}`,
  );
}
