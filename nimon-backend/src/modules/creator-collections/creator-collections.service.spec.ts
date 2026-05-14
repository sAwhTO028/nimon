import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';

import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';

import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import { CreatorCollectionsService } from './creator-collections.service';

function mkMedia(
  base = 'http://localhost:3000/uploads',
): MediaUrlCanonicalizerService {
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

describe('CreatorCollectionsService', () => {
  const ownerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const otherOwner = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const collId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

  it('listMine maps rows with visible-only itemCount via groupBy', async () => {
    const findMany = jest.fn().mockResolvedValue([
      {
        id: collId,
        ownerId,
        title: 'T',
        description: null,
        coverImageUrl: null,
        visibility: 'public',
        createdAt: new Date('2026-01-01T00:00:00.000Z'),
        updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      },
    ]);
    const groupBy = jest.fn().mockResolvedValue([{ collectionId: collId, _count: { _all: 3 } }]);
    const prisma = {
      creatorMonoCollection: { findMany },
      creatorMonoCollectionItem: { groupBy, findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).listMine(ownerId);

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      }),
    );
    expect(groupBy).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          collectionId: { in: [collId] },
          publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE,
        }),
      }),
    );
    expect(out.collections[0].itemCount).toBe(3);
  });

  it('create rejects empty name with validation_failed', async () => {
    const prisma = { creatorMonoCollection: {} } as any;
    try {
      await new CreatorCollectionsService(prisma, mkMedia()).create(ownerId, {
        title: '   ',
        description: null,
        coverImageUrl: null,
        visibility: 'public',
        sortOrder: 0,
      } as any);
      throw new Error('expected BadRequestException');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      const body = (e as BadRequestException).getResponse() as Record<
        string,
        unknown
      >;
      expect(body['message']).toBe('validation_failed');
      const issues = body['issues'] as Array<{ field?: string }>;
      expect(issues.some((i) => i.field === 'collection.title')).toBe(true);
    }
  });

  it('create throws quota when user already has 10 collections', async () => {
    const prisma = {
      creatorMonoCollection: {
        count: jest.fn().mockResolvedValue(10),
        create: jest.fn(),
      },
    } as any;

    try {
      await new CreatorCollectionsService(prisma, mkMedia()).create(ownerId, {
        title: 'Eleventh',
      } as any);
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toEqual({
        code: 'quota_exceeded',
        key: FREE_TIER_QUOTA_KEYS.collections,
        limit: FREE_TIER_QUOTAS.collections,
        current: 10,
      });
    }
    expect(prisma.creatorMonoCollection.create).not.toHaveBeenCalled();
  });

  it('create succeeds when user has 9 collections', async () => {
    const create = jest.fn().mockResolvedValue({
      id: collId,
      ownerId,
      title: 'Hello',
      description: null,
      coverImageUrl: null,
      visibility: 'public',
      sortOrder: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = {
      creatorMonoCollection: {
        create,
        count: jest.fn().mockResolvedValue(9),
      },
      creatorMonoCollectionItem: { groupBy: jest.fn() },
    } as any;

    await new CreatorCollectionsService(prisma, mkMedia()).create(ownerId, {
      title: '  Hello  ',
    } as any);

    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        ownerId,
        title: 'Hello',
        visibility: 'public',
      }),
    });
  });

  it('updateMine throws NotFound when collection not owned', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { creatorMonoCollection: { findFirst } } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).updateMine(ownerId, collId, {
        title: 'x',
      } as any),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('deleteMine throws NotFound when nothing deleted', async () => {
    const deleteMany = jest.fn().mockResolvedValue({ count: 0 });
    const findFirst = jest.fn().mockResolvedValue({ id: collId });
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      creatorMonoCollection: { deleteMany, findFirst },
      creatorMonoCollectionItem: { count },
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).deleteMine(ownerId, collId),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('deleteMine deletes only owner collection (cascade items at DB)', async () => {
    const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
    const findFirst = jest.fn().mockResolvedValue({ id: collId });
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      creatorMonoCollection: { deleteMany, findFirst },
      creatorMonoCollectionItem: { count },
    } as any;

    await new CreatorCollectionsService(prisma, mkMedia()).deleteMine(ownerId, collId);

    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: collId, ownerId },
    });
  });

  it('deleteMine rejects when collection has items', async () => {
    const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
    const findFirst = jest.fn().mockResolvedValue({ id: collId });
    const count = jest.fn().mockResolvedValue(2);
    const prisma = {
      creatorMonoCollection: { deleteMany, findFirst },
      creatorMonoCollectionItem: { count },
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).deleteMine(ownerId, collId),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(deleteMany).not.toHaveBeenCalled();
  });

  it('addItemMine rejects mono not owned by user', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const findFirstMono = jest.fn().mockResolvedValue(null);
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findFirst: findFirstMono },
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).addItemMine(ownerId, collId, monoId),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(findFirstMono).toHaveBeenCalledWith({
      where: { id: monoId, ownerId },
    });
  });

  it('addItemMine is idempotent when link exists', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const findFirstMono = jest.fn().mockResolvedValue({ id: monoId, ownerId });
    const findFirstItem = jest
      .fn()
      .mockResolvedValue({ id: 'item-1', publishedMonoId: monoId, collectionId: collId });
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findFirst: findFirstMono },
      creatorMonoCollectionItem: {
        findFirst: findFirstItem,
        aggregate: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).addItemMine(ownerId, collId, monoId);

    expect(out.created).toBe(false);
    expect(out.itemId).toBe('item-1');
    expect(prisma.creatorMonoCollectionItem.create).not.toHaveBeenCalled();
    expect(prisma.creatorMonoCollectionItem.update).not.toHaveBeenCalled();
  });

  it('addItemMine moves mono from another collection into target', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const findFirstMono = jest.fn().mockResolvedValue({ id: monoId, ownerId });
    const findFirstItem = jest
      .fn()
      .mockResolvedValue({ id: 'item-1', publishedMonoId: monoId, collectionId: 'old-coll' });
    const aggregate = jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } });
    const update = jest.fn().mockResolvedValue({ id: 'item-1' });
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findFirst: findFirstMono },
      creatorMonoCollectionItem: {
        findFirst: findFirstItem,
        aggregate,
        count: jest.fn().mockResolvedValue(5),
        create: jest.fn(),
        update,
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).addItemMine(ownerId, collId, monoId);
    expect(out.created).toBe(true);
    expect(update).toHaveBeenCalled();
  });

  it('bulkAdd skips duplicates and non-owned ids', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const publishedMonoFindMany = jest
      .fn()
      .mockResolvedValue([{ id: monoId }]); // only one owned
    const findManyExisting = jest.fn().mockResolvedValue([
      { id: 'item-1', publishedMonoId: monoId, collectionId: collId },
    ]);
    const aggregate = jest.fn().mockResolvedValue({ _max: { sortOrder: 5 } });
    const create = jest.fn().mockResolvedValue({});
    const update = jest.fn().mockResolvedValue({});
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findMany: publishedMonoFindMany },
      creatorMonoCollectionItem: {
        findMany: findManyExisting,
        aggregate,
        count: jest.fn().mockResolvedValue(0),
        create,
        update,
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).bulkAddItemsMine(ownerId, collId, {
      publishedMonoIds: [monoId, otherOwner, monoId],
    });

    expect(out.skippedNotOwnedOrMissing).toBe(1);
    expect(out.skippedDuplicates).toBe(1);
    expect(out.inserted).toBe(0);
    expect(create).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });

  it('bulkAdd moves from another collection into target', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const publishedMonoFindMany = jest.fn().mockResolvedValue([{ id: monoId }]);
    const findManyExisting = jest.fn().mockResolvedValue([
      { id: 'item-1', publishedMonoId: monoId, collectionId: 'old-coll' },
    ]);
    const aggregate = jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } });
    const update = jest.fn().mockResolvedValue({});
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findMany: publishedMonoFindMany },
      creatorMonoCollectionItem: {
        findMany: findManyExisting,
        aggregate,
        count: jest.fn().mockResolvedValue(0),
        create: jest.fn(),
        update,
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).bulkAddItemsMine(ownerId, collId, {
      publishedMonoIds: [monoId],
    });
    expect(out.inserted).toBe(1);
    expect(update).toHaveBeenCalled();
  });

  it('listPublicForUser only returns visibility public', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      creatorMonoCollection: { findMany },
      creatorMonoCollectionItem: {
        groupBy: jest.fn().mockResolvedValue([]),
        findMany: jest.fn().mockResolvedValue([]),
      },
    } as any;

    await new CreatorCollectionsService(prisma, mkMedia()).listPublicForUser(ownerId);

    expect(findMany).toHaveBeenCalledWith({
      where: { ownerId, visibility: 'public' },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  });

  it('listMine derives coverImageUrl from first visible mono when unset', async () => {
    const findManyCollections = jest.fn().mockResolvedValue([
      {
        id: collId,
        ownerId,
        title: 'T',
        description: null,
        coverImageUrl: null,
        visibility: 'public',
        sortOrder: 0,
        createdAt: new Date('2026-01-01T00:00:00.000Z'),
        updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      },
    ]);
    const groupBy = jest.fn().mockResolvedValue([
      { collectionId: collId, _count: { _all: 1 } },
    ]);
    const findManyItems = jest.fn().mockResolvedValue([
      {
        collectionId: collId,
        publishedMono: {
          id: monoId,
          ownerId,
          title: 'Hello',
          category: 'c',
          level: 'N3',
          description: 'd',
          createdAt: new Date('2026-01-01T00:00:00.000Z'),
          updatedAt: new Date('2026-01-02T00:00:00.000Z'),
          content: { core: { coverImageUrl: 'https://img.test/x.png' } },
        },
      },
    ]);
    const prisma = {
      creatorMonoCollection: { findMany: findManyCollections },
      creatorMonoCollectionItem: { groupBy, findMany: findManyItems },
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).listMine(ownerId);
    expect(out.collections[0].coverImageUrl).toBe('https://img.test/x.png');
  });

  it('explicit coverImageUrl wins over derived cover', async () => {
    const findManyCollections = jest.fn().mockResolvedValue([
      {
        id: collId,
        ownerId,
        title: 'T',
        description: null,
        coverImageUrl: 'https://img.test/explicit.png',
        visibility: 'public',
        sortOrder: 0,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
    const groupBy = jest.fn().mockResolvedValue([
      { collectionId: collId, _count: { _all: 1 } },
    ]);
    const findManyItems = jest.fn().mockResolvedValue([
      {
        collectionId: collId,
        publishedMono: {
          id: monoId,
          ownerId,
          title: 'Hello',
          category: 'c',
          level: 'N3',
          description: 'd',
          createdAt: new Date(),
          updatedAt: new Date(),
          content: { core: { coverImageUrl: 'https://img.test/derived.png' } },
        },
      },
    ]);
    const prisma = {
      creatorMonoCollection: { findMany: findManyCollections },
      creatorMonoCollectionItem: { groupBy, findMany: findManyItems },
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).listMine(ownerId);
    expect(out.collections[0].coverImageUrl).toBe('https://img.test/explicit.png');
  });

  it('listPublicCollectionMonos applies catalog visibility filter', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: collId,
      ownerId,
      visibility: 'public',
    });
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      creatorMonoCollection: { findFirst },
      creatorMonoCollectionItem: { findMany },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    await new CreatorCollectionsService(prisma, mkMedia()).listPublicCollectionMonos(ownerId, collId);

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          collectionId: collId,
          publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE,
        }),
      }),
    );
  });

  it('listPublicCollectionMonos 404 when collection not public or wrong profile user', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = {
      creatorMonoCollection: { findFirst },
      creatorMonoCollectionItem: { findMany: jest.fn() },
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).listPublicCollectionMonos(ownerId, collId),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('listPublicCollectionMonos stamps writer identity from collection owner profile', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: collId,
      ownerId,
      visibility: 'public',
    });
    const findMany = jest.fn().mockResolvedValue([
      {
        id: 'it1',
        collectionId: collId,
        publishedMono: {
          id: monoId,
          ownerId,
          title: 'Hello',
          category: 'c',
          level: 'N3',
          description: 'd',
          createdAt: new Date('2026-01-01T00:00:00.000Z'),
          updatedAt: new Date('2026-01-02T00:00:00.000Z'),
          content: {},
        },
      },
    ]);
    const prisma = {
      creatorMonoCollection: { findFirst },
      creatorMonoCollectionItem: { findMany },
      userProfile: {
        findUnique: jest.fn().mockResolvedValue({
          displayName: 'Author',
          handle: 'auth_one',
          avatarUrl: 'https://avatar.test/a.png',
        }),
      },
    } as any;

    const out = await new CreatorCollectionsService(prisma, mkMedia()).listPublicCollectionMonos(ownerId, collId);
    expect(out.items).toHaveLength(1);
    expect(out.items[0]?.writerDisplayName).toBe('Author');
    expect(out.items[0]?.writerHandle).toBe('auth_one');
    expect(out.items[0]?.writerAvatarUrl).toBe('https://avatar.test/a.png');
  });

  it('addItemMine blocks move into target when target already has 30 items', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const findFirstMono = jest.fn().mockResolvedValue({ id: monoId, ownerId });
    const findFirstItem = jest
      .fn()
      .mockResolvedValue({ id: 'item-1', publishedMonoId: monoId, collectionId: 'old-coll' });
    const aggregate = jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } });
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findFirst: findFirstMono },
      creatorMonoCollectionItem: {
        findFirst: findFirstItem,
        aggregate,
        count: jest.fn().mockResolvedValue(30),
        update: jest.fn(),
        create: jest.fn(),
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).addItemMine(ownerId, collId, monoId),
    ).rejects.toBeInstanceOf(QuotaExceededException);
    expect(prisma.creatorMonoCollectionItem.update).not.toHaveBeenCalled();
  });

  it('bulkAdd blocks when adding would exceed 30 items in target', async () => {
    const findFirstColl = jest.fn().mockResolvedValue({ id: collId, ownerId });
    const publishedMonoFindMany = jest.fn().mockResolvedValue([{ id: monoId }]);
    const findManyExisting = jest.fn().mockResolvedValue([]);
    const aggregate = jest.fn().mockResolvedValue({ _max: { sortOrder: 0 } });
    const prisma = {
      creatorMonoCollection: { findFirst: findFirstColl },
      publishedMono: { findMany: publishedMonoFindMany },
      creatorMonoCollectionItem: {
        findMany: findManyExisting,
        aggregate,
        count: jest.fn().mockResolvedValue(30),
        create: jest.fn(),
        update: jest.fn(),
      },
      $transaction: async (fn: any) =>
        await fn({
          creatorMonoCollectionItem: prisma.creatorMonoCollectionItem,
        }),
    } as any;

    await expect(
      new CreatorCollectionsService(prisma, mkMedia()).bulkAddItemsMine(ownerId, collId, {
        publishedMonoIds: [monoId],
      }),
    ).rejects.toBeInstanceOf(QuotaExceededException);
    expect(prisma.creatorMonoCollectionItem.create).not.toHaveBeenCalled();
  });
});
