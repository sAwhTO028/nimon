import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import { MonoFeedService } from './mono-feed.service';

describe('MonoFeedService', () => {
  const t0 = new Date('2026-01-15T12:00:00.000Z');
  const t1 = new Date('2026-01-10T10:00:00.000Z');
  const id0 = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const id1 = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  const sampleRow = {
    id: id0,
    ownerId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    title: 'Test Mono',
    category: 'Love',
    level: 'N5',
    description: 'Short teaser',
    createdAt: t1,
    updatedAt: t0,
    content: {
      publishKind: 'read_only_v1',
      core: { coverImageUrl: 'https://cdn.example/cover.jpg' },
    },
    owner: {
      profile: {
        displayName: 'Writer',
        handle: '@writer',
        avatarUrl: 'https://cdn.example/a.png',
      },
    },
  };

  const mkSvc = () => {
    const findMany = jest.fn();
    const findFirst = jest.fn();
    const prisma = {
      publishedMono: { findMany, findFirst },
      userProfile: {
        findUnique: jest.fn().mockResolvedValue({
          displayName: 'Writer',
          handle: 'writer_h',
          avatarUrl: 'https://prof.example/me.png',
        }),
      },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), count: jest.fn().mockResolvedValue(0), findMany: jest.fn().mockResolvedValue([]), findFirst: jest.fn().mockResolvedValue(null) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]), count: jest.fn().mockResolvedValue(0) },
    } as any;
    return { svc: new MonoFeedService(prisma), findMany, findFirst };
  };

  it('list returns items with slim summary fields (no content in response)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([sampleRow]);
    const out = await svc.listFeed({ limit: 15, userId: null });
    expect(out.items).toHaveLength(1);
    const it = out.items[0]!;
    expect(it.monoId).toBe(id0);
    expect(it.title).toBe('Test Mono');
    expect(it.coverUrl).toBe('https://cdn.example/cover.jpg');
    expect(it.level).toBe('N5');
    expect(it.category).toBe('Love');
    expect(it.categories).toEqual(['Love']);
    expect(it.description).toBe('Short teaser');
    expect(it.writerId).toBe(sampleRow.ownerId);
    expect(it.writerHandle).toBe('@writer');
    expect(it.writerDisplayName).toBe('Writer');
    expect(it.writerAvatarUrl).toBe('https://cdn.example/a.png');
    expect(it.likesCount).toBe(0);
    expect(it.hasAudio).toBe(false);
    expect(it.isBookmarkedByMe).toBe(false);
    expect(it.myReaction).toBeNull();
    expect(it.shareUrl).toContain(`/mono/${id0}`);
    expect(it.publishKind).toBe('read_only_v1');
    expect(it.accessType).toBe('public');
    expect((it as any).content).toBeUndefined();
    expect(out.hasMore).toBe(false);
    expect(out.nextCursor).toBeNull();
  });

  it('default limit 15 uses take 16 for hasMore', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    await svc.listFeed({ limit: svc.parseLimit(undefined), userId: null });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 16 }),
    );
  });

  it('max limit caps at 30 (take 31)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    const limit = svc.parseLimit('999');
    expect(limit).toBe(30);
    await svc.listFeed({ limit, userId: null });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 31 }),
    );
  });

  it('applies level and category filters', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    await svc.listFeed({ limit: 15, level: 'N4', category: 'Culture', userId: null });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: [
            PUBLISHED_MONO_CATALOG_VISIBLE,
            { level: 'N4' },
            { category: 'Culture' },
          ],
        },
      }),
    );
  });

  it('applies writerId filter (ownerId)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    await svc.listFeed({
      limit: 15,
      writerId: sampleRow.ownerId,
      userId: null,
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([
            PUBLISHED_MONO_CATALOG_VISIBLE,
            { ownerId: sampleRow.ownerId },
          ]),
        },
      }),
    );
  });

  it('listFeed always excludes published monos with a dirty linked draft', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    await svc.listFeed({ limit: 15, userId: null });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([PUBLISHED_MONO_CATALOG_VISIBLE]),
        },
      }),
    );
  });

  it('PUBLISHED_MONO_CATALOG_VISIBLE excludes trashed rows', () => {
    expect(PUBLISHED_MONO_CATALOG_VISIBLE).toMatchObject({
      trashedAt: null,
      NOT: {
        drafts: { some: { hasUnpublishedCoreChanges: true } },
      },
    });
  });

  it('cursor continuation encodes nextCursor and sets hasMore', async () => {
    const { svc, findMany } = mkSvc();
    const older = {
      ...sampleRow,
      id: id1,
      updatedAt: t1,
      createdAt: t1,
    };
    findMany.mockResolvedValue([sampleRow, older]);
    const out = await svc.listFeed({ limit: 1, userId: null });
    expect(out.items).toHaveLength(1);
    expect(out.hasMore).toBe(true);
    expect(out.nextCursor).toBeTruthy();
    const payload = JSON.parse(
      Buffer.from(out.nextCursor!, 'base64url').toString('utf8'),
    );
    expect(payload.u).toBe(sampleRow.updatedAt.toISOString());
    expect(payload.i).toBe(id0);
  });

  it('empty result', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    const out = await svc.listFeed({ limit: 15, userId: null });
    expect(out.items).toEqual([]);
    expect(out.hasMore).toBe(false);
    expect(out.nextCursor).toBeNull();
  });

  it('bad cursor throws BadRequestException', async () => {
    const { svc, findMany } = mkSvc();
    await expect(
      svc.listFeed({ limit: 15, cursor: '%%%', userId: null }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(findMany).not.toHaveBeenCalled();
  });

  it('unsupported sort throws', async () => {
    const { svc } = mkSvc();
    await expect(
      svc.listFeed({ limit: 15, sort: 'popular', userId: null }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('get detail returns full content compatible with PublishedMono detail', async () => {
    const { svc, findFirst } = mkSvc();
    findFirst.mockResolvedValue({
      id: id0,
      ownerId: sampleRow.ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: t1,
      updatedAt: t0,
      content: { publishKind: 'read_only_v1', core: {} },
    });
    const d = await svc.getPublicMonoById(id0, null);
    expect(d.id).toBe(id0);
    expect(d.writerDisplayName).toBe('Writer');
    expect(d.writerHandle).toBe('writer_h');
    expect(d.writerAvatarUrl).toBe('https://prof.example/me.png');
    expect(d.content).toEqual({ publishKind: 'read_only_v1', core: {} });
    expect(d.displayPublishKind).toBe('read_only');
    expect((d as any).likesCount).toBeDefined();
    expect((d as any).shareUrl).toContain(`/mono/${id0}`);
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: id0, ...PUBLISHED_MONO_CATALOG_VISIBLE },
      }),
    );
  });

  it('get detail missing throws NotFound', async () => {
    const { svc, findFirst } = mkSvc();
    findFirst.mockResolvedValue(null);
    await expect(svc.getPublicMonoById(id0)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

});
