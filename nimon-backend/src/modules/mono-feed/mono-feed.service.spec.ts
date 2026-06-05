import { BadRequestException, NotFoundException } from '@nestjs/common';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import type { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import { MONO_FEED_LIST_PUBLISHED_MONO_SELECT, MonoFeedService } from './mono-feed.service';

const DEFAULT_CANON_BASE = 'http://localhost:3000/uploads';

function mkMedia(
  base: string = DEFAULT_CANON_BASE,
): MediaUrlCanonicalizerService {
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

function mkPublicWeb(webBase = 'http://localhost:3000'): PublicWebBaseUrlService {
  const b = webBase.replace(/\/+$/, '') || 'http://localhost:3000';
  return {
    baseUrl: () => b,
    monoShareUrl: (id: string) => `${b}/mono/${id.trim()}`,
  } as unknown as PublicWebBaseUrlService;
}

describe('MonoFeedService', () => {
  const feedLocaleWhere = (
    contentLocale: 'en' | 'my' | 'ja',
    learningLanguage: 'ja' | 'en',
  ) => ({
    AND: [
      {
        OR: [{ contentLocale }, { contentLocale: null }],
      },
      {
        OR: [{ learningLanguage }, { learningLanguage: null }],
      },
    ],
  });

  const t0 = new Date('2026-01-15T12:00:00.000Z');
  const t1 = new Date('2026-01-10T10:00:00.000Z');
  const id0 = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const id1 = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  const sampleRow = {
    id: id0,
    ownerId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    contentLocale: 'my' as string | null,
    learningLanguage: 'en' as string | null,
    title: 'Test Mono',
    category: 'Love',
    level: 'N5',
    description: 'Short teaser',
    createdAt: t1,
    updatedAt: t0,
    coverImageUrl: 'https://cdn.example/cover.jpg',
    publishKind: 'read_only_v1',
    hasAudio: false,
    sentenceCount: 2,
    vocabCount: 3,
    grammarCount: 1,
    quizCount: 4,
    owner: {
      profile: {
        displayName: 'Writer',
        handle: '@writer',
        avatarUrl: 'https://cdn.example/a.png',
      },
    },
  };

  const mkSvc = (
    mediaBase: string = DEFAULT_CANON_BASE,
    webBase = 'http://localhost:3000',
  ) => {
    const findMany = jest.fn();
    const findFirst = jest.fn();
    const prisma = {
      publishedMono: { findMany, findFirst },
      userPreference: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
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
    return {
      svc: new MonoFeedService(prisma, mkMedia(mediaBase), mkPublicWeb(webBase)),
      findMany,
      findFirst,
    };
  };

  it('shareUrl uses NIMON_PUBLIC_WEB_BASE_URL host (not media base)', async () => {
    const row = {
      ...sampleRow,
      owner: {
        profile: {
          displayName: 'Writer',
          handle: '@writer',
          avatarUrl: 'https://cdn.example/a.png',
        },
      },
    };
    const { svc, findMany } = mkSvc(
      'http://192.168.11.5:3000/uploads',
      'http://192.168.11.5:3000',
    );
    findMany.mockResolvedValue([row]);
    const out = await svc.listFeed({ limit: 15, userId: null });
    expect(out.items[0]!.shareUrl).toBe(
      'http://192.168.11.5:3000/mono/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    );
  });

  it('rewrites loopback upload coverUrl and writerAvatarUrl using MEDIA_PUBLIC_BASE_URL', async () => {
    const row = {
      ...sampleRow,
      coverImageUrl: 'http://localhost:3000/uploads/u/cover/a.webp',
      owner: {
        profile: {
          displayName: 'Writer',
          handle: '@writer',
          avatarUrl: 'http://127.0.0.1:3000/uploads/u/cover/av.webp',
        },
      },
    };
    const { svc, findMany } = mkSvc('http://192.168.11.5:3000/uploads');
    findMany.mockResolvedValue([row]);
    const out = await svc.listFeed({ limit: 15, userId: null });
    const it = out.items[0]!;
    expect(it.coverUrl).toBe(
      'http://192.168.11.5:3000/uploads/u/cover/a.webp',
    );
    expect(it.writerAvatarUrl).toBe(
      'http://192.168.11.5:3000/uploads/u/cover/av.webp',
    );
  });

  it('listFeed findMany does not select content JSONB (M22B)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    await svc.listFeed({ limit: 15, userId: null });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: MONO_FEED_LIST_PUBLISHED_MONO_SELECT,
      }),
    );
    expect(
      (MONO_FEED_LIST_PUBLISHED_MONO_SELECT as Record<string, unknown>).content,
    ).toBeUndefined();
  });

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
    expect(it.contentLocale).toBe('my');
    expect(it.learningLanguage).toBe('en');
    expect((it as any).content).toBeUndefined();
    expect(out.hasMore).toBe(false);
    expect(out.nextCursor).toBeNull();
  });

  describe('M23A-6D-3 feed summary locale pair', () => {
    it('listFeed returns contentLocale and learningLanguage on summary items', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([sampleRow]);
      const out = await svc.listFeed({ limit: 15, userId: null });
      expect(out.items[0]).toMatchObject({
        contentLocale: 'my',
        learningLanguage: 'en',
      });
    });

    it('following feed returns locale pair on summary items', async () => {
      const followedOwner = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
      const row = {
        ...sampleRow,
        contentLocale: 'en',
        learningLanguage: 'ja',
      };
      const findMany = jest.fn().mockResolvedValue([row]);
      const prisma = {
        publishedMono: { findMany, findFirst: jest.fn() },
        userPreference: { findUnique: jest.fn().mockResolvedValue(null) },
        userFollow: {
          findMany: jest
            .fn()
            .mockResolvedValue([{ followingId: followedOwner }]),
        },
        userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
        monoReaction: {
          groupBy: jest.fn().mockResolvedValue([]),
          count: jest.fn().mockResolvedValue(0),
          findMany: jest.fn().mockResolvedValue([]),
          findFirst: jest.fn().mockResolvedValue(null),
        },
        monoBookmark: {
          findMany: jest.fn().mockResolvedValue([]),
          count: jest.fn().mockResolvedValue(0),
        },
      } as any;
      const svc = new MonoFeedService(prisma, mkMedia(), mkPublicWeb());
      const out = await svc.listFeed({
        limit: 15,
        userId: 'viewer-1',
        followingOnly: true,
      });
      expect(out.items[0]).toMatchObject({
        contentLocale: 'en',
        learningLanguage: 'ja',
      });
    });

    it('writerId feed returns locale pair on summary items', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([
        {
          ...sampleRow,
          contentLocale: 'ja',
          learningLanguage: 'en',
        },
      ]);
      const out = await svc.listFeed({
        limit: 15,
        userId: null,
        writerId: sampleRow.ownerId,
      });
      expect(out.items[0]).toMatchObject({
        contentLocale: 'ja',
        learningLanguage: 'en',
      });
    });

    it('legacy null locale fields are preserved on summary items', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([
        {
          ...sampleRow,
          contentLocale: null,
          learningLanguage: null,
        },
      ]);
      const out = await svc.listFeed({ limit: 15, userId: null });
      expect(out.items[0]).toMatchObject({
        contentLocale: null,
        learningLanguage: null,
      });
    });
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
            feedLocaleWhere('en', 'ja'),
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
            feedLocaleWhere('en', 'ja'),
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
          AND: expect.arrayContaining([
            PUBLISHED_MONO_CATALOG_VISIBLE,
            feedLocaleWhere('en', 'ja'),
          ]),
        },
      }),
    );
  });

  it('authenticated my user feed filter is my+ja not en+ja (strict; no en fallback)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
      contentLocale: 'my',
      learningLanguage: 'ja',
    });
    await svc.listFeed({ limit: 15, userId: 'u1' });
    const call = findMany.mock.calls[0][0];
    const andClauses = call.where.AND as unknown[];
    expect(andClauses).toEqual(
      expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
    );
    expect(andClauses).not.toEqual(
      expect.arrayContaining([feedLocaleWhere('en', 'ja')]),
    );
  });

  it('authenticated my user receives my-tagged catalog rows from findMany', async () => {
    const myRow = {
      ...sampleRow,
      contentLocale: 'my',
      learningLanguage: 'ja',
    };
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([myRow]);
    (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
      contentLocale: 'my',
      learningLanguage: 'ja',
    });
    const out = await svc.listFeed({ limit: 15, userId: 'u1' });
    expect(out.items).toHaveLength(1);
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
        },
      }),
    );
  });

  it('authenticated feed uses saved preferences when params absent', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
      contentLocale: 'my',
      learningLanguage: 'ja',
    });
    await svc.listFeed({ limit: 15, userId: 'u1' });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
        },
      }),
    );
  });

  it('query params override saved preferences', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
      contentLocale: 'my',
      learningLanguage: 'ja',
    });
    await svc.listFeed({
      limit: 15,
      userId: 'u1',
      contentLocale: 'en',
      learningLanguage: 'ja',
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([feedLocaleWhere('en', 'ja')]),
        },
      }),
    );
  });

  it('invalid stored preferences fall back to defaults (no throw)', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([]);
    (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
      contentLocale: 'not-a-locale',
      learningLanguage: 'ko',
    });
    await svc.listFeed({ limit: 15, userId: 'u1' });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([feedLocaleWhere('en', 'ja')]),
        },
      }),
    );
  });

  it('invalid query contentLocale throws', async () => {
    const { svc } = mkSvc();
    await expect(
      svc.listFeed({ limit: 15, userId: null, contentLocale: 'th' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  describe('M23A-6A English catalog discovery', () => {
    it('en+my viewer feed filter is my+en (not coerced to ja)', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([]);
      (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
        contentLocale: 'my',
        learningLanguage: 'en',
      });
      await svc.listFeed({ limit: 15, userId: 'u-en' });
      expect(findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            AND: expect.arrayContaining([feedLocaleWhere('my', 'en')]),
          },
        }),
      );
      const andClauses = findMany.mock.calls[0][0].where.AND as unknown[];
      expect(andClauses).not.toEqual(
        expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
      );
    });

    it('ja+my viewer feed filter excludes en+my lens', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([]);
      (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
        contentLocale: 'my',
        learningLanguage: 'ja',
      });
      await svc.listFeed({ limit: 15, userId: 'u-ja' });
      const andClauses = findMany.mock.calls[0][0].where.AND as unknown[];
      expect(andClauses).toEqual(
        expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
      );
      expect(andClauses).not.toEqual(
        expect.arrayContaining([feedLocaleWhere('my', 'en')]),
      );
    });

    it('guest default feed filter is en+ja', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([]);
      await svc.listFeed({ limit: 15, userId: null });
      expect(findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            AND: expect.arrayContaining([feedLocaleWhere('en', 'ja')]),
          },
        }),
      );
    });

    it('query override learningLanguage=en contentLocale=my applies my+en filter', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([]);
      await svc.listFeed({
        limit: 15,
        userId: null,
        learningLanguage: 'en',
        contentLocale: 'my',
      });
      expect(findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            AND: expect.arrayContaining([feedLocaleWhere('my', 'en')]),
          },
        }),
      );
    });

    it('invalid query learningLanguage=ko throws learningLanguage_invalid', async () => {
      const { svc, findMany } = mkSvc();
      await expect(
        svc.listFeed({ limit: 15, userId: null, learningLanguage: 'ko' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(findMany).not.toHaveBeenCalled();
    });

    it('following feed uses en+my lens for en+my viewer', async () => {
      const followedOwner = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
      const findMany = jest.fn().mockResolvedValue([]);
      const prisma = {
        publishedMono: { findMany, findFirst: jest.fn() },
        userPreference: {
          findUnique: jest.fn().mockResolvedValue({
            contentLocale: 'my',
            learningLanguage: 'en',
          }),
        },
        userFollow: {
          findMany: jest.fn().mockResolvedValue([{ followingId: followedOwner }]),
        },
        userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
        monoReaction: {
          groupBy: jest.fn().mockResolvedValue([]),
          count: jest.fn().mockResolvedValue(0),
          findMany: jest.fn().mockResolvedValue([]),
          findFirst: jest.fn().mockResolvedValue(null),
        },
        monoBookmark: {
          findMany: jest.fn().mockResolvedValue([]),
          count: jest.fn().mockResolvedValue(0),
        },
      } as any;
      const svc = new MonoFeedService(prisma, mkMedia(), mkPublicWeb());
      await svc.listFeed({
        limit: 15,
        userId: 'u-en',
        followingOnly: true,
      });
      expect(findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            AND: expect.arrayContaining([
              feedLocaleWhere('my', 'en'),
              { ownerId: { in: [followedOwner] } },
            ]),
          },
        }),
      );
    });

    it('writerId feed uses en+my lens for en+my viewer (public profile Monos)', async () => {
      const { svc, findMany } = mkSvc();
      findMany.mockResolvedValue([]);
      (svc as any).prisma.userPreference.findUnique.mockResolvedValue({
        contentLocale: 'my',
        learningLanguage: 'en',
      });
      await svc.listFeed({
        limit: 15,
        userId: 'u-en',
        writerId: sampleRow.ownerId,
      });
      expect(findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            AND: expect.arrayContaining([
              feedLocaleWhere('my', 'en'),
              { ownerId: sampleRow.ownerId },
            ]),
          },
        }),
      );
      const andClauses = findMany.mock.calls[0][0].where.AND as unknown[];
      expect(andClauses).not.toEqual(
        expect.arrayContaining([feedLocaleWhere('my', 'ja')]),
      );
    });
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

  it('list uses denormalized hasAudio when present', async () => {
    const { svc, findMany } = mkSvc();
    findMany.mockResolvedValue([
      {
        ...sampleRow,
        hasAudio: true,
        publishKind: 'full_learn_v1',
      },
    ]);
    const out = await svc.listFeed({ limit: 15, userId: null });
    expect(out.items[0]!.hasAudio).toBe(true);
    expect(out.items[0]!.publishKind).toBe('full_learn_v1');
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
