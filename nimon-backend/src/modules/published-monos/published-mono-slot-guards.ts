import type { Prisma } from '@prisma/client';
import type { PublishedTabQuotaScope } from './published-mono-published-tab-quota';

/** Client / transaction scope for read-only publish resolution + create guard. */
export type PublishedMonoReadOnlyPublishScope = PublishedTabQuotaScope & {
  publishedMono: PublishedTabQuotaScope['publishedMono'] & {
    findFirst(args: {
      where: Prisma.PublishedMonoWhereInput;
      select: { id: true };
    }): Promise<{ id: string } | null>;
  };
};

export type ReadOnlyPublishMonoResolution =
  | { publishedMonoId: string; via: 'story_draft_publishedMonoId' | 'mono_content_sourceDraftId' }
  | { publishedMonoId: null; via: 'none' };

/**
 * V1 read-only publish: canonical mono id from the draft FK, else from
 * **`published_monos.content.sourceDraftId`** (JSON) matching **`draft.id`** for an **active**
 * non-trashed row owned by the user.
 *
 * Schema fields on `StoryDraft`: only **`publishedMonoId`** links the workspace to a mono.
 * **`PublishedMono.content.sourceDraftId`** is the cross-table link when the draft FK was cleared
 * but the snapshot still references the workspace draft id (M17E-4). If the row is **trashed**,
 * the same match is used so read-only publish updates/restores that snapshot instead of creating
 * a duplicate row (M17E-5).
 */
export async function resolvePublishedMonoIdForReadOnlyPublish(
  scope: Pick<PublishedMonoReadOnlyPublishScope, 'publishedMono'>,
  ownerId: string,
  draft: { id: string; publishedMonoId: string | null },
): Promise<ReadOnlyPublishMonoResolution> {
  const fk = (draft.publishedMonoId ?? '').trim();
  if (fk.length > 0) {
    return { publishedMonoId: fk, via: 'story_draft_publishedMonoId' };
  }
  const rowActive = await scope.publishedMono.findFirst({
    where: {
      ownerId,
      trashedAt: null,
      content: {
        path: ['sourceDraftId'],
        equals: draft.id,
      },
    },
    select: { id: true },
  });
  if (rowActive) {
    return { publishedMonoId: rowActive.id, via: 'mono_content_sourceDraftId' };
  }
  const rowTrashed = await scope.publishedMono.findFirst({
    where: {
      ownerId,
      trashedAt: { not: null },
      content: {
        path: ['sourceDraftId'],
        equals: draft.id,
      },
    },
    select: { id: true },
  });
  if (rowTrashed) {
    return { publishedMonoId: rowTrashed.id, via: 'mono_content_sourceDraftId' };
  }
  return { publishedMonoId: null, via: 'none' };
}
