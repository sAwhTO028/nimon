import type { Prisma } from '@prisma/client';

/**
 * Active catalog / published list / public reader:
 * - P1: exclude trashed rows (`trashedAt == null`).
 * - M5d: exclude rows hidden while a linked `StoryDraft` has `hasUnpublishedCoreChanges === true`.
 */
export const PUBLISHED_MONO_CATALOG_VISIBLE: Prisma.PublishedMonoWhereInput = {
  trashedAt: null,
  NOT: {
    drafts: {
      some: {
        hasUnpublishedCoreChanges: true,
      },
    },
  },
};

/**
 * Free-tier **published mono cap** (M17E-6):
 * V1 enforcement uses **only** the owner **Published tab** visible row count
 * (`countOwnerPublishedTabVisibleMonos` — same predicate as this export), not
 * ownership-slot unions.
 *
 * Rows hidden while a linked `StoryDraft` has `hasUnpublishedCoreChanges === true`
 * are **excluded** from that tab-visible count (and from the cap).
 *
 * Historical: `PUBLISHED_MONO_QUOTA_CONSUMING` described a slot-union model; that
 * predicate is **not** used for V1 published-mono limit checks after M17E-6.
 */
export const PUBLISHED_MONO_QUOTA_CONSUMING: Prisma.PublishedMonoWhereInput = {
  trashedAt: null,
};
