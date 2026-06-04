import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { assertNoBlockingValidationIssues } from '../../common/validation/validation-exception';
import { validateCollectionName } from '../../common/validation/collection-validation';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import type { Prisma } from '@prisma/client';

import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import type { CatalogLanguageContext } from '../published-monos/published-mono-catalog-locale';
import {
  publishedMonoCatalogLocaleWhere,
  resolveCatalogLanguageContext,
  type CatalogLanguageResolveOptions,
} from '../published-monos/published-mono-catalog-locale';
import {
  attachWriterProfileToListItem,
  publishedMonoListItemFromCatalogSummaryRow,
  publishedMonoListItemFromRow,
  type WriterProfileSlice,
} from '../published-monos/published-mono-common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import type { PublishedMonoListItemDto } from '../published-monos/published-monos.dto';

import type {
  BulkAddCreatorCollectionItemsDto,
  CreateCreatorMonoCollectionDto,
  CreatorMonoCollectionDto,
  CreatorMonoCollectionMonosResponseDto,
  UpdateCreatorMonoCollectionDto,
} from './creator-collections.dto';

const DEFAULT_MONO_PAGE = 20;
const MAX_MONO_PAGE = 50;

/** Public collection mono list — denormalized summary only (M22B parity). */
const PUBLIC_COLLECTION_MONO_SELECT = {
  id: true,
  ownerId: true,
  title: true,
  category: true,
  level: true,
  description: true,
  createdAt: true,
  updatedAt: true,
  coverImageUrl: true,
  publishKind: true,
} as const satisfies Prisma.PublishedMonoSelect;

@Injectable()
export class CreatorCollectionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
  ) {}

  private async writerProfile(ownerId: string): Promise<WriterProfileSlice | null> {
    const p = await this.prisma.userProfile.findUnique({
      where: { userId: ownerId },
      select: { displayName: true, handle: true, avatarUrl: true },
    });
    if (!p) return null;
    return {
      displayName: p.displayName ?? null,
      handle: p.handle ?? null,
      avatarUrl: p.avatarUrl ?? null,
    };
  }

  private toDto(
    row: {
      id: string;
      ownerId: string;
      title: string;
      description: string | null;
      coverImageUrl: string | null;
      visibility: string;
      createdAt: Date;
      updatedAt: Date;
    },
    itemCount: number,
  ): CreatorMonoCollectionDto {
    return {
      id: row.id,
      ownerId: row.ownerId,
      title: row.title,
      description: row.description,
      coverImageUrl: this.media.url(row.coverImageUrl),
      visibility: row.visibility,
      itemCount,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  private catalogVisiblePublishedMonoWhere(
    lang?: CatalogLanguageContext,
  ): Prisma.PublishedMonoWhereInput {
    if (!lang) {
      return PUBLISHED_MONO_CATALOG_VISIBLE;
    }
    return {
      AND: [PUBLISHED_MONO_CATALOG_VISIBLE, publishedMonoCatalogLocaleWhere(lang)],
    };
  }

  private async visibleItemCountsForCollections(
    collectionIds: string[],
    publishedMonoWhere: Prisma.PublishedMonoWhereInput = PUBLISHED_MONO_CATALOG_VISIBLE,
  ): Promise<Map<string, number>> {
    if (collectionIds.length === 0) return new Map();
    const grouped = await this.prisma.creatorMonoCollectionItem.groupBy({
      by: ['collectionId'],
      where: {
        collectionId: { in: collectionIds },
        publishedMono: publishedMonoWhere,
      },
      _count: { _all: true },
    });
    return new Map(grouped.map((g) => [g.collectionId, g._count._all]));
  }

  private async derivedCoversForCollections(
    collectionIds: string[],
    publishedMonoWhere: Prisma.PublishedMonoWhereInput = PUBLISHED_MONO_CATALOG_VISIBLE,
  ): Promise<Map<string, string>> {
    if (collectionIds.length === 0) return new Map();
    const rows = await this.prisma.creatorMonoCollectionItem.findMany({
      where: {
        collectionId: { in: collectionIds },
        publishedMono: publishedMonoWhere,
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
      select: {
        collectionId: true,
        publishedMono: {
          select: {
            id: true,
            ownerId: true,
            title: true,
            category: true,
            level: true,
            description: true,
            createdAt: true,
            updatedAt: true,
            content: true,
          },
        },
      },
    });

    const out = new Map<string, string>();
    const base = this.media.mediaPublicBaseUrl();
    for (const r of rows) {
      if (out.has(r.collectionId)) continue;
      const dto = publishedMonoListItemFromRow(
        r.publishedMono,
        base,
      );
      const cover = (dto.coverImageUrl ?? '').trim();
      if (cover) out.set(r.collectionId, cover);
    }
    return out;
  }

  /** First viewer-visible mono cover via M22B `coverImageUrl` column (no `content` JSONB). */
  private async derivedCoversForCollectionsFromSummary(
    collectionIds: string[],
    publishedMonoWhere: Prisma.PublishedMonoWhereInput,
  ): Promise<Map<string, string>> {
    if (collectionIds.length === 0) return new Map();
    const rows = await this.prisma.creatorMonoCollectionItem.findMany({
      where: {
        collectionId: { in: collectionIds },
        publishedMono: publishedMonoWhere,
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
      select: {
        collectionId: true,
        publishedMono: { select: { coverImageUrl: true } },
      },
    });
    const out = new Map<string, string>();
    for (const r of rows) {
      if (out.has(r.collectionId)) continue;
      const cover = this.media.url(r.publishedMono.coverImageUrl);
      if ((cover ?? '').trim()) out.set(r.collectionId, cover!.trim());
    }
    return out;
  }

  async listMine(ownerId: string): Promise<{ collections: CreatorMonoCollectionDto[] }> {
    const rows = await this.prisma.creatorMonoCollection.findMany({
      where: { ownerId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    const counts = await this.visibleItemCountsForCollections(rows.map((r) => r.id));
    const derivedCovers = await this.derivedCoversForCollections(rows.map((r) => r.id));
    return {
      collections: rows.map((r) => {
        const explicit = (r.coverImageUrl ?? '').trim();
        const derived = derivedCovers.get(r.id);
        const cover = explicit || (derived ?? null);
        return this.toDto(
          {
            ...r,
            coverImageUrl: cover,
          },
          counts.get(r.id) ?? 0,
        );
      }),
    };
  }

  async create(
    ownerId: string,
    dto: CreateCreatorMonoCollectionDto,
  ): Promise<{ collection: CreatorMonoCollectionDto }> {
    const title = dto.title.trim();
    const titleVal = validateCollectionName(title);
    assertNoBlockingValidationIssues(titleVal);
    const collectionCount = await this.prisma.creatorMonoCollection.count({
      where: { ownerId },
    });
    if (collectionCount >= FREE_TIER_QUOTAS.collections) {
      throw new QuotaExceededException(
        FREE_TIER_QUOTA_KEYS.collections,
        FREE_TIER_QUOTAS.collections,
        collectionCount,
      );
    }
    const row = await this.prisma.creatorMonoCollection.create({
      data: {
        ownerId,
        title,
        description: dto.description ?? null,
        coverImageUrl: dto.coverImageUrl ?? null,
        visibility: dto.visibility ?? 'public',
        sortOrder: dto.sortOrder ?? 0,
      },
    });
    return { collection: this.toDto(row, 0) };
  }

  async updateMine(
    ownerId: string,
    collectionId: string,
    dto: UpdateCreatorMonoCollectionDto,
  ): Promise<{ collection: CreatorMonoCollectionDto }> {
    const existing = await this.prisma.creatorMonoCollection.findFirst({
      where: { id: collectionId, ownerId },
    });
    if (!existing) {
      throw new NotFoundException('collection_not_found');
    }
    const data: Record<string, unknown> = {};
    if (dto.title !== undefined) {
      const t = dto.title.trim();
      const titleVal = validateCollectionName(t);
      assertNoBlockingValidationIssues(titleVal);
      data.title = t;
    }
    if (dto.description !== undefined) data.description = dto.description;
    if (dto.coverImageUrl !== undefined) data.coverImageUrl = dto.coverImageUrl;
    if (dto.visibility !== undefined) data.visibility = dto.visibility;
    if (dto.sortOrder !== undefined) data.sortOrder = dto.sortOrder;

    const row = await this.prisma.creatorMonoCollection.update({
      where: { id: collectionId },
      data: data as object,
    });
    const counts = await this.visibleItemCountsForCollections([row.id]);
    return { collection: this.toDto(row, counts.get(row.id) ?? 0) };
  }

  async deleteMine(ownerId: string, collectionId: string): Promise<void> {
    const existing = await this.prisma.creatorMonoCollection.findFirst({
      where: { id: collectionId, ownerId },
      select: { id: true },
    });
    if (!existing) {
      throw new NotFoundException('collection_not_found');
    }

    const itemCount = await this.prisma.creatorMonoCollectionItem.count({
      where: { collectionId },
    });
    if (itemCount > 0) {
      throw new ConflictException('collection_not_empty');
    }

    const res = await this.prisma.creatorMonoCollection.deleteMany({
      where: { id: collectionId, ownerId },
    });
    if (res.count === 0) {
      throw new NotFoundException('collection_not_found');
    }
  }

  async addItemMine(
    ownerId: string,
    collectionId: string,
    publishedMonoId: string,
  ): Promise<{ created: boolean; itemId: string }> {
    const coll = await this.prisma.creatorMonoCollection.findFirst({
      where: { id: collectionId, ownerId },
    });
    if (!coll) throw new NotFoundException('collection_not_found');

    const mono = await this.prisma.publishedMono.findFirst({
      where: { id: publishedMonoId, ownerId },
    });
    if (!mono) {
      throw new ForbiddenException('not_owner_of_published_mono');
    }

    // Product rule: a published mono can belong to only one collection.
    // - already in target: no-op
    // - in another: move (update row's collectionId + sortOrder)
    return await this.prisma.$transaction(async (tx) => {
      const existing = await tx.creatorMonoCollectionItem.findFirst({
        where: { publishedMonoId },
      });
      if (existing && existing.collectionId === collectionId) {
        return { created: false, itemId: existing.id };
      }

      const targetCount = await tx.creatorMonoCollectionItem.count({
        where: { collectionId },
      });
      if (targetCount >= FREE_TIER_QUOTAS.collectionItems) {
        throw new QuotaExceededException(
          FREE_TIER_QUOTA_KEYS.collectionItems,
          FREE_TIER_QUOTAS.collectionItems,
          targetCount,
        );
      }

      const maxSort = await tx.creatorMonoCollectionItem.aggregate({
        where: { collectionId },
        _max: { sortOrder: true },
      });
      const nextOrder = (maxSort._max.sortOrder ?? -1) + 1;

      if (existing) {
        const moved = await tx.creatorMonoCollectionItem.update({
          where: { id: existing.id },
          data: {
            collectionId,
            sortOrder: nextOrder,
          },
        });
        return { created: true, itemId: moved.id };
      }

      const row = await tx.creatorMonoCollectionItem.create({
        data: {
          collectionId,
          publishedMonoId,
          sortOrder: nextOrder,
        },
      });
      return { created: true, itemId: row.id };
    });
  }

  async removeItemMine(
    ownerId: string,
    collectionId: string,
    publishedMonoId: string,
  ): Promise<void> {
    const coll = await this.prisma.creatorMonoCollection.findFirst({
      where: { id: collectionId, ownerId },
    });
    if (!coll) throw new NotFoundException('collection_not_found');

    const res = await this.prisma.creatorMonoCollectionItem.deleteMany({
      where: { collectionId, publishedMonoId },
    });
    if (res.count === 0) {
      throw new NotFoundException('collection_item_not_found');
    }
  }

  async bulkAddItemsMine(
    ownerId: string,
    collectionId: string,
    dto: BulkAddCreatorCollectionItemsDto,
  ): Promise<{
    inserted: number;
    skippedDuplicates: number;
    skippedNotOwnedOrMissing: number;
  }> {
    const coll = await this.prisma.creatorMonoCollection.findFirst({
      where: { id: collectionId, ownerId },
    });
    if (!coll) throw new NotFoundException('collection_not_found');

    const ids = [...new Set(dto.publishedMonoIds)];
    if (ids.length === 0) {
      return { inserted: 0, skippedDuplicates: 0, skippedNotOwnedOrMissing: 0 };
    }

    const owned = await this.prisma.publishedMono.findMany({
      where: { ownerId, id: { in: ids } },
      select: { id: true },
    });
    const ownedSet = new Set(owned.map((o) => o.id));
    const skippedNotOwnedOrMissing = ids.filter((id) => !ownedSet.has(id)).length;

    const eligible = ids.filter((id) => ownedSet.has(id));
    if (eligible.length === 0) {
      return {
        inserted: 0,
        skippedDuplicates: 0,
        skippedNotOwnedOrMissing,
      };
    }

    // Product rule: one mono can belong to only one collection.
    // Bulk add implements "move to collection" semantics.
    return await this.prisma.$transaction(async (tx) => {
      const maxSort = await tx.creatorMonoCollectionItem.aggregate({
        where: { collectionId },
        _max: { sortOrder: true },
      });
      let orderBase = (maxSort._max.sortOrder ?? -1) + 1;

      const existingRows = await tx.creatorMonoCollectionItem.findMany({
        where: { publishedMonoId: { in: eligible } },
        select: { id: true, publishedMonoId: true, collectionId: true },
      });
      const byMono = new Map(existingRows.map((r) => [r.publishedMonoId, r]));

      let projectedTargetCount = await tx.creatorMonoCollectionItem.count({
        where: { collectionId },
      });

      let skippedDuplicates = 0;
      let inserted = 0;

      for (const publishedMonoId of eligible) {
        const ex = byMono.get(publishedMonoId);
        if (ex && ex.collectionId === collectionId) {
          skippedDuplicates += 1;
          continue;
        }
        if (ex && ex.collectionId !== collectionId) {
          if (projectedTargetCount >= FREE_TIER_QUOTAS.collectionItems) {
            throw new QuotaExceededException(
              FREE_TIER_QUOTA_KEYS.collectionItems,
              FREE_TIER_QUOTAS.collectionItems,
              projectedTargetCount,
            );
          }
          projectedTargetCount += 1;
          await tx.creatorMonoCollectionItem.update({
            where: { id: ex.id },
            data: { collectionId, sortOrder: orderBase++ },
          });
          inserted += 1;
          continue;
        }
        if (projectedTargetCount >= FREE_TIER_QUOTAS.collectionItems) {
          throw new QuotaExceededException(
            FREE_TIER_QUOTA_KEYS.collectionItems,
            FREE_TIER_QUOTAS.collectionItems,
            projectedTargetCount,
          );
        }
        projectedTargetCount += 1;
        await tx.creatorMonoCollectionItem.create({
          data: { collectionId, publishedMonoId, sortOrder: orderBase++ },
        });
        inserted += 1;
      }

      return { inserted, skippedDuplicates, skippedNotOwnedOrMissing };
    });
  }

  /** Public: collections visible on creator profile (viewer language filter). */
  async listPublicForUser(
    targetUserId: string,
    viewer: CatalogLanguageResolveOptions = { viewerUserId: null },
  ): Promise<{
    collections: CreatorMonoCollectionDto[];
  }> {
    const langCtx = await resolveCatalogLanguageContext(this.prisma, viewer);
    const visibleMonoWhere = this.catalogVisiblePublishedMonoWhere(langCtx);

    const rows = await this.prisma.creatorMonoCollection.findMany({
      where: { ownerId: targetUserId, visibility: 'public' },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    const counts = await this.visibleItemCountsForCollections(
      rows.map((r) => r.id),
      visibleMonoWhere,
    );
    const visibleRows = rows.filter((r) => (counts.get(r.id) ?? 0) > 0);
    const derivedCovers = await this.derivedCoversForCollectionsFromSummary(
      visibleRows.map((r) => r.id),
      visibleMonoWhere,
    );
    return {
      collections: visibleRows.map((r) => {
        const explicit = (r.coverImageUrl ?? '').trim();
        const derived = derivedCovers.get(r.id);
        const cover = explicit || (derived ?? null);
        return this.toDto(
          {
            ...r,
            coverImageUrl: cover,
          },
          counts.get(r.id) ?? 0,
        );
      }),
    };
  }

  async listPublicCollectionMonos(
    profileUserId: string,
    collectionId: string,
    limitRaw?: string,
    cursor?: string,
    viewer: CatalogLanguageResolveOptions = { viewerUserId: null },
  ): Promise<CreatorMonoCollectionMonosResponseDto> {
    const coll = await this.prisma.creatorMonoCollection.findFirst({
      where: {
        id: collectionId,
        ownerId: profileUserId,
        visibility: 'public',
      },
    });
    if (!coll) {
      throw new NotFoundException('collection_not_found');
    }

    const langCtx = await resolveCatalogLanguageContext(this.prisma, viewer);
    const visibleMonoWhere = this.catalogVisiblePublishedMonoWhere(langCtx);

    const take = this.parseMonoLimit(limitRaw);
    const rows = await this.prisma.creatorMonoCollectionItem.findMany({
      where: {
        collectionId,
        publishedMono: visibleMonoWhere,
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
      take: take + 1,
      ...(cursor
        ? {
            cursor: { id: cursor },
            skip: 1,
          }
        : {}),
      select: {
        id: true,
        publishedMono: { select: PUBLIC_COLLECTION_MONO_SELECT },
      },
    });

    const page = rows.slice(0, take);
    const hasMore = rows.length > take;
    const writer = await this.writerProfile(profileUserId);
    const base = this.media.mediaPublicBaseUrl();
    const items: PublishedMonoListItemDto[] = page.map((r) =>
      attachWriterProfileToListItem(
        publishedMonoListItemFromCatalogSummaryRow(r.publishedMono, base),
        writer,
        base,
      ),
    );
    const last = page[page.length - 1];
    return {
      items,
      nextCursor: hasMore && last ? last.id : null,
    };
  }

  /** Owner: list monos inside a collection (includes private collections). */
  async listMineCollectionMonos(
    ownerId: string,
    collectionId: string,
    limitRaw?: string,
    cursor?: string,
  ): Promise<CreatorMonoCollectionMonosResponseDto> {
    const coll = await this.prisma.creatorMonoCollection.findFirst({
      where: {
        id: collectionId,
        ownerId,
      },
    });
    if (!coll) {
      throw new NotFoundException('collection_not_found');
    }

    const take = this.parseMonoLimit(limitRaw);
    const rows = await this.prisma.creatorMonoCollectionItem.findMany({
      where: {
        collectionId,
        publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE,
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
      take: take + 1,
      ...(cursor
        ? {
            cursor: { id: cursor },
            skip: 1,
          }
        : {}),
      include: {
        publishedMono: true,
      },
    });

    const page = rows.slice(0, take);
    const hasMore = rows.length > take;
    const writer = await this.writerProfile(ownerId);
    const base = this.media.mediaPublicBaseUrl();
    const items: PublishedMonoListItemDto[] = page.map((r) =>
      attachWriterProfileToListItem(
        publishedMonoListItemFromRow(r.publishedMono, base),
        writer,
        base,
      ),
    );
    const last = page[page.length - 1];
    return {
      items,
      nextCursor: hasMore && last ? last.id : null,
    };
  }

  private parseMonoLimit(raw?: string): number {
    if (raw == null || String(raw).trim() === '') return DEFAULT_MONO_PAGE;
    const n = Number(raw);
    if (!Number.isFinite(n)) return DEFAULT_MONO_PAGE;
    const v = Math.floor(n);
    return Math.min(Math.max(v, 1), MAX_MONO_PAGE);
  }
}
