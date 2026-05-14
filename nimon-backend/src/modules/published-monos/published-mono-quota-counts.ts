import type { Prisma } from '@prisma/client';
import { PublishState } from '@prisma/client';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';

/** Prisma client or transaction scope used by publish / restore quota guards. */
export type PublishedMonoQuotaScope = {
  publishedMono: {
    count(args: { where: Prisma.PublishedMonoWhereInput }): Promise<number>;
    findMany(args: {
      where: Prisma.PublishedMonoWhereInput;
      select: Prisma.PublishedMonoSelect;
    }): Promise<unknown[]>;
  };
  storyDraft: {
    count(args: { where: Prisma.StoryDraftWhereInput }): Promise<number>;
    findMany(args: {
      where: Prisma.StoryDraftWhereInput;
      select: Prisma.StoryDraftSelect;
    }): Promise<unknown[]>;
  };
};

export type PublishedMonoQuotaSlotBreakdown = {
  /** Catalog / list / profile — excludes trashed + edit-staging hidden. Debug only. */
  catalogVisiblePublishedMonoCount: number;
  /** Active `PublishedMono` rows (`trashedAt == null`). */
  activePublishedMonoCount: number;
  /** Published-state drafts with no `publishedMonoId` (orphan slot). */
  orphanPublishedDraftCount: number;
  /** Distinct `publishedMonoId` on dirty linked workspaces (any `publishState`, including `draft`). */
  stagingLinkedPublishedMonoIdsDistinct: number;
  /**
   * Distinct mono ids that **reserve a slot** while not covered by an active (non-trashed) row:
   * dirty staging FK pointing at trashed/missing mono **or** trashed `PublishedMono` whose JSON
   * `content.sourceDraftId` matches a dirty workspace draft with `publishedMonoId == null` (M17E-5).
   */
  stagingSlotsOnTrashedOrMissingMonoCount: number;
  quotaSlots: number;
  /** M17E-4 diagnosis — `published_monos` with `trashedAt != null`. */
  trashedPublishedMonoRows: number;
  /** `story_drafts` rows with non-null `publishedMonoId`. */
  draftsWithPublishedMonoId: number;
  /**
   * `story_drafts` rows whose `id` appears as **`content.sourceDraftId`** on some **active**
   * owned `PublishedMono` (canonical workspace id stored on the published snapshot JSON).
   */
  draftsWithSourceDraftIdMatchingPublishedMono: number;
  /** `story_drafts` with `hasUnpublishedCoreChanges === true`. */
  dirtyPublishedDrafts: number;
};

function sourceDraftIdFromMonoContent(content: unknown): string {
  if (content == null || typeof content !== 'object' || Array.isArray(content)) {
    return '';
  }
  const raw = (content as Record<string, unknown>).sourceDraftId;
  return typeof raw === 'string' ? raw.trim() : '';
}

/**
 * Catalog / list / feed visibility — excludes trashed and edit-staged hidden rows.
 * Debug-safe: do **not** use for free-tier publish quota.
 */
export async function countCatalogVisiblePublishedMonos(
  scope: Pick<PublishedMonoQuotaScope, 'publishedMono'>,
  ownerId: string,
): Promise<number> {
  return scope.publishedMono.count({
    where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
  });
}

/**
 * V1 **published mono ownership slots** (cap 30) for **brand-new** `PublishedMono` creates
 * and **restore** guards.
 *
 * **Union model (M17E-3 / M17E-4 / M17E-5):**
 * - Every **active** (`trashedAt == null`) owned `PublishedMono` id is one slot (includes
 *   catalog-hidden edit-staging rows — same as M17E-2).
 * - **Plus** distinct mono ids that are **not** among active rows but are still reserved by:
 *   - dirty **`StoryDraft`** rows with non-null **`publishedMonoId`** (any `publishState`, including
 *     `draft` while the client holds a staging workspace) when that mono is trashed or missing; and
 *   - **trashed** `PublishedMono` rows whose JSON **`content.sourceDraftId`** equals the id of a
 *     dirty **`StoryDraft`** with **`publishedMonoId == null`** (workspace lost FK but snapshot
 *     still points at the edit draft — M17E-5 phone leak).
 * - **Plus** each **orphan** published workspace: `publishState` is a published state and
 *   `publishedMonoId` is null (counts as its own slot; dedup is N/A).
 *
 * Republish / update paths that already carry `publishedMonoId` (or resolve via
 * **`content.sourceDraftId`**) do not consume an extra slot.
 */
export async function getPublishedMonoQuotaSlotBreakdown(
  scope: PublishedMonoQuotaScope,
  ownerId: string,
): Promise<PublishedMonoQuotaSlotBreakdown> {
  const [
    activeMonoRows,
    orphanPublishedDraftCount,
    stagingDraftRows,
    trashedPublishedMonoRows,
    draftsWithPublishedMonoId,
    dirtyPublishedDrafts,
    dirtyNullFkDraftRows,
    trashedMonoRows,
  ] = await Promise.all([
    scope.publishedMono.findMany({
      where: { ownerId, trashedAt: null },
      select: { id: true, content: true },
    }),
    scope.storyDraft.count({
      where: {
        ownerId,
        publishState: {
          in: [PublishState.reading_only_published, PublishState.full_learn_published],
        },
        publishedMonoId: null,
      },
    }),
    scope.storyDraft.findMany({
      where: {
        ownerId,
        hasUnpublishedCoreChanges: true,
        publishedMonoId: { not: null },
      },
      select: { publishedMonoId: true },
    }),
    scope.publishedMono.count({ where: { ownerId, trashedAt: { not: null } } }),
    scope.storyDraft.count({
      where: { ownerId, publishedMonoId: { not: null } },
    }),
    scope.storyDraft.count({
      where: { ownerId, hasUnpublishedCoreChanges: true },
    }),
    scope.storyDraft.findMany({
      where: {
        ownerId,
        hasUnpublishedCoreChanges: true,
        publishedMonoId: null,
      },
      select: { id: true },
    }),
    scope.publishedMono.findMany({
      where: { ownerId, trashedAt: { not: null } },
      select: { id: true, content: true },
    }),
  ]);

  const activePublishedMonoCount = activeMonoRows.length;
  const activeMonoIds = new Set(
    (activeMonoRows as { id: string }[]).map((r) => r.id).filter(Boolean),
  );

  const stagingMonoIds = [
    ...new Set(
      (stagingDraftRows as { publishedMonoId: string | null }[])
        .map((r) => r.publishedMonoId)
        .filter((id): id is string => id != null && String(id).trim() !== ''),
    ),
  ];

  const dirtyNullFkDraftIds = new Set(
    (dirtyNullFkDraftRows as { id: string }[]).map((r) => r.id).filter(Boolean),
  );

  const reservedMonoSlotIds = new Set<string>();
  for (const id of stagingMonoIds) {
    if (!activeMonoIds.has(id)) {
      reservedMonoSlotIds.add(id);
    }
  }
  for (const row of trashedMonoRows as { id: string; content: unknown }[]) {
    const sid = sourceDraftIdFromMonoContent(row.content);
    if (sid && dirtyNullFkDraftIds.has(sid)) {
      reservedMonoSlotIds.add(row.id);
    }
  }

  const stagingSlotsOnTrashedOrMissingMonoCount = reservedMonoSlotIds.size;

  const sourceDraftIdsFromActiveMonos = new Set<string>();
  for (const row of activeMonoRows as { content: unknown }[]) {
    const sid = sourceDraftIdFromMonoContent(row.content);
    if (sid) {
      sourceDraftIdsFromActiveMonos.add(sid);
    }
  }

  let draftsWithSourceDraftIdMatchingPublishedMono = 0;
  if (sourceDraftIdsFromActiveMonos.size > 0) {
    draftsWithSourceDraftIdMatchingPublishedMono = await scope.storyDraft.count({
      where: { ownerId, id: { in: [...sourceDraftIdsFromActiveMonos] } },
    });
  }

  const catalogVisiblePublishedMonoCount = await countCatalogVisiblePublishedMonos(
    scope,
    ownerId,
  );

  const quotaSlots =
    activePublishedMonoCount + stagingSlotsOnTrashedOrMissingMonoCount + orphanPublishedDraftCount;

  return {
    catalogVisiblePublishedMonoCount,
    activePublishedMonoCount,
    orphanPublishedDraftCount,
    stagingLinkedPublishedMonoIdsDistinct: stagingMonoIds.length,
    stagingSlotsOnTrashedOrMissingMonoCount,
    quotaSlots,
    trashedPublishedMonoRows,
    draftsWithPublishedMonoId,
    draftsWithSourceDraftIdMatchingPublishedMono,
    dirtyPublishedDrafts,
  };
}

export async function countPublishedMonoQuotaSlots(
  scope: PublishedMonoQuotaScope,
  ownerId: string,
): Promise<number> {
  const b = await getPublishedMonoQuotaSlotBreakdown(scope, ownerId);
  return b.quotaSlots;
}
