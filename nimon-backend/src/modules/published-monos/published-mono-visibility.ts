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
