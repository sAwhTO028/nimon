/**
 * M17E-5 local dev diagnostic: dump PublishedMono + StoryDraft rows and quota breakdown for one owner.
 *
 * Usage (from `nimon-backend/`):
 *   set M17E5_QUOTA_SNAPSHOT=1
 *   npx ts-node scripts/m17e5-published-quota-snapshot.ts <ownerUuid>
 *
 * Refuses NODE_ENV=production. Requires M17E5_QUOTA_SNAPSHOT=1 unless NODE_ENV=development.
 */
import 'dotenv/config';
import { PrismaClient, PublishState } from '@prisma/client';
import { getPublishedMonoQuotaSlotBreakdown } from '../src/modules/published-monos/published-mono-quota-counts';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../src/modules/published-monos/published-mono-visibility';

function requireDevSnapshotGate(): void {
  if (process.env.NODE_ENV === 'production') {
    // eslint-disable-next-line no-console
    console.error('m17e5-published-quota-snapshot: refused (NODE_ENV=production)');
    process.exit(1);
  }
  const ok =
    process.env.M17E5_QUOTA_SNAPSHOT === '1' ||
    process.env.NODE_ENV === 'development' ||
    process.env.NODE_ENV === 'test';
  if (!ok) {
    // eslint-disable-next-line no-console
    console.error(
      'm17e5-published-quota-snapshot: set M17E5_QUOTA_SNAPSHOT=1 or NODE_ENV=development',
    );
    process.exit(1);
  }
}

function pickContent(content: unknown): Record<string, unknown> {
  if (content == null || typeof content !== 'object' || Array.isArray(content)) {
    return {};
  }
  return content as Record<string, unknown>;
}

async function main() {
  requireDevSnapshotGate();
  const ownerId = process.argv[2]?.trim();
  if (!ownerId) {
    // eslint-disable-next-line no-console
    console.error('Usage: M17E5_QUOTA_SNAPSHOT=1 npx ts-node scripts/m17e5-published-quota-snapshot.ts <ownerUuid>');
    process.exit(1);
  }

  const prisma = new PrismaClient();
  try {
    const [publishedRows, draftRows, qb] = await Promise.all([
      prisma.publishedMono.findMany({
        where: { ownerId },
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
        include: {
          drafts: {
            select: {
              id: true,
              hasUnpublishedCoreChanges: true,
              publishState: true,
            },
          },
        },
      }),
      prisma.storyDraft.findMany({
        where: { ownerId },
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
        select: {
          id: true,
          ownerId: true,
          publishedMonoId: true,
          publishState: true,
          hasUnpublishedCoreChanges: true,
          title: true,
          updatedAt: true,
          createdAt: true,
        },
      }),
      getPublishedMonoQuotaSlotBreakdown(prisma, ownerId),
    ]);

    const dirtyNullFkIds = new Set(
      (
        await prisma.storyDraft.findMany({
          where: { ownerId, hasUnpublishedCoreChanges: true, publishedMonoId: null },
          select: { id: true },
        })
      ).map((r) => r.id),
    );

    const publishedOut = await Promise.all(
      publishedRows.map(async (pm) => {
        const c = pickContent(pm.content);
        const sourceDraftId = typeof c.sourceDraftId === 'string' ? c.sourceDraftId : null;
        const publishKind = typeof c.publishKind === 'string' ? c.publishKind : null;
        const hasUnpublishedCoreChangesOnContent =
          typeof c.hasUnpublishedCoreChanges === 'boolean' ? c.hasUnpublishedCoreChanges : undefined;
        const catalogVisible = !!(await prisma.publishedMono.count({
          where: { id: pm.id, ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
        }));
        const quotaActiveRow = pm.trashedAt == null;
        const reservedTrashedSlot =
          pm.trashedAt != null &&
          !!sourceDraftId &&
          dirtyNullFkIds.has(sourceDraftId.trim());
        return {
          id: pm.id,
          ownerId: pm.ownerId,
          trashedAt: pm.trashedAt?.toISOString() ?? null,
          createdAt: pm.createdAt.toISOString(),
          updatedAt: pm.updatedAt.toISOString(),
          contentSourceDraftId: sourceDraftId,
          contentHasUnpublishedCoreChanges: hasUnpublishedCoreChangesOnContent,
          contentPublishKind: publishKind,
          linkedDraftDirtyFlags: pm.drafts.map((d) => ({
            draftId: d.id,
            hasUnpublishedCoreChanges: d.hasUnpublishedCoreChanges,
            publishState: d.publishState,
          })),
          catalogVisibleByPublishedMonoCatalogPredicate: catalogVisible,
          quotaCountsThisRowAsActivePublishedMono: quotaActiveRow,
          quotaReservedWhileTrashedViaSourceDraftIdLink: reservedTrashedSlot,
        };
      }),
    );

    const hiddenPublishedMonoRows = publishedOut.filter(
      (r) => r.quotaCountsThisRowAsActivePublishedMono && !r.catalogVisibleByPublishedMonoCatalogPredicate,
    ).length;

    const draftOut = draftRows.map((d) => ({
      id: d.id,
      ownerId: d.ownerId,
      publishedMonoId: d.publishedMonoId,
      publishState: d.publishState,
      hasUnpublishedCoreChanges: d.hasUnpublishedCoreChanges,
      trashedAt: null,
      deletedAt: null,
      title: d.title,
      updatedAt: d.updatedAt.toISOString(),
      createdAt: d.createdAt.toISOString(),
    }));

    const dirtyDraftRows = draftRows.filter((d) => d.hasUnpublishedCoreChanges).length;
    const draftRowsWithPublishedMonoId = draftRows.filter((d) => d.publishedMonoId != null).length;
    const orphanPublishedDraftRows = draftRows.filter(
      (d) =>
        (d.publishState === PublishState.reading_only_published ||
          d.publishState === PublishState.full_learn_published) &&
        d.publishedMonoId == null,
    ).length;

    const activePublishedMonoRows = publishedOut.filter((r) => r.quotaCountsThisRowAsActivePublishedMono)
      .length;

    const output = {
      ownerId,
      publishedMonos: publishedOut,
      storyDrafts: draftOut,
      summary: {
        catalogVisibleCount: qb.catalogVisiblePublishedMonoCount,
        activePublishedMonoRows,
        hiddenPublishedMonoRows,
        draftRowsWithPublishedMonoId,
        dirtyDraftRows,
        orphanPublishedDraftRows,
        trashedPublishedMonoRowsDbCount: qb.trashedPublishedMonoRows,
        quotaSlots: qb.quotaSlots,
        quotaSlotsSourceSummary: {
          activePublishedMonoCount: qb.activePublishedMonoCount,
          stagingSlotsOnTrashedOrMissingMonoCount: qb.stagingSlotsOnTrashedOrMissingMonoCount,
          orphanPublishedDraftCount: qb.orphanPublishedDraftCount,
          stagingLinkedPublishedMonoIdsDistinct: qb.stagingLinkedPublishedMonoIdsDistinct,
        },
        breakdown: qb,
      },
    };

    // eslint-disable-next-line no-console
    console.log(JSON.stringify(output, null, 2));
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
