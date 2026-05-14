import { Prisma } from '@prisma/client';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';

/** Prisma scope for owner Published tab visible counts (same predicate as list). */
export type PublishedTabQuotaScope = {
  publishedMono: {
    count(args: { where: Prisma.PublishedMonoWhereInput }): Promise<number>;
  };
  /** When present (real Prisma client / tx), M17E-9 diagnostics can include draft row totals. */
  storyDraft?: {
    count(args: { where: Prisma.StoryDraftWhereInput }): Promise<number>;
  };
};

type QueryRawCapable = {
  $queryRaw?: <T>(query: Prisma.Sql) => Promise<T>;
};

/**
 * M17E-9: canonical SQL for “Published tab” visible rows — non-trashed `published_monos`
 * with no linked `story_drafts` row where `hasUnpublishedCoreChanges` is true.
 * Matches `PUBLISHED_MONO_CATALOG_VISIBLE` + `ownerId` (same as Prisma `count`, without ORM edge cases).
 */
async function countOwnerPublishedTabVisibleMonosViaSql(
  scope: PublishedTabQuotaScope,
  ownerId: string,
): Promise<number | null> {
  const qr = (scope as QueryRawCapable).$queryRaw;
  if (typeof qr !== 'function') {
    return null;
  }
  try {
    const rows = await qr<Array<{ c: bigint }>>(
      Prisma.sql`
        SELECT COUNT(*)::bigint AS c
        FROM "published_monos" AS pm
        WHERE pm."ownerId" = ${ownerId}::uuid
          AND pm."trashedAt" IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM "story_drafts" AS sd
            WHERE sd."publishedMonoId" = pm."id"
              AND sd."hasUnpublishedCoreChanges" = true
          )
      `,
    );
    const c = rows[0]?.c;
    return typeof c === 'bigint' ? Number(c) : Number(c ?? 0);
  } catch {
    return null;
  }
}

export type PublishedTabRevealQuotaLogTag = 'publish-quota' | 'cancel-edit' | 'restore-quota';

export type PublishedTabRevealQuotaAttempt = {
  tag: PublishedTabRevealQuotaLogTag;
  draftId?: string;
  publishedMonoId?: string;
  /** M17E-9: stable action label for quota diagnostics (e.g. `publishReadOnly_firstPublish`). */
  actionName?: string;
};

/**
 * Owner **Published tab** visible mono count — identical predicate to
 * `GET /v1/published-monos` default list (`PUBLISHED_MONO_CATALOG_VISIBLE`).
 *
 * M17E-9: when the scope supports `$queryRaw` (Prisma client / transaction), uses explicit SQL
 * so the count cannot diverge from the owner list predicate.
 */
export async function countOwnerPublishedTabVisibleMonos(
  scope: PublishedTabQuotaScope,
  ownerId: string,
): Promise<number> {
  const viaSql = await countOwnerPublishedTabVisibleMonosViaSql(scope, ownerId);
  if (viaSql != null) {
    return viaSql;
  }
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

async function logM17e9QuotaBlock(params: {
  scope: PublishedTabQuotaScope;
  ownerId: string;
  ctx: PublishedTabRevealQuotaAttempt;
  current: number;
  nextVisibleCount: number;
  limit: number;
  log?: (line: string) => void;
}): Promise<void> {
  const { scope, ownerId, ctx, current, nextVisibleCount, limit, log } = params;
  const publishedMonosTotal = await scope.publishedMono.count({ where: { ownerId } });
  const publishedMonosActiveNonTrashed = await scope.publishedMono.count({
    where: { ownerId, trashedAt: null },
  });
  let storyDraftRows: number | string = 'n/a';
  if (scope.storyDraft?.count) {
    storyDraftRows = await scope.storyDraft.count({ where: { ownerId } });
  }
  const actionName = ctx.actionName ?? ctx.tag;
  const countSource =
    typeof (scope as QueryRawCapable).$queryRaw === 'function'
      ? 'sql:published_monos+NOT_EXISTS_dirty_story_drafts'
      : 'orm:publishedMono.count+PUBLISHED_MONO_CATALOG_VISIBLE';
  const line =
    `[M17E-9 quota-block] ownerId=${ownerId} actionName=${actionName} countSource=${countSource} ` +
    `publishedMonosTotal=${publishedMonosTotal} publishedMonosActiveNonTrashed=${publishedMonosActiveNonTrashed} ` +
    `publishedTabVisibleCount=${current} storyDraftRows=${storyDraftRows} nextCount=${nextVisibleCount} ` +
    `limit=${limit} willBlock=true throwingKey=${FREE_TIER_QUOTA_KEYS.publishedMonos}`;
  log?.(line);
}

/**
 * M17E-7 / M17E-9: actions that **add or reveal** one catalog-visible Published tab row
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
    await logM17e9QuotaBlock({
      scope,
      ownerId,
      ctx,
      current,
      nextVisibleCount,
      limit,
      log,
    });
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
