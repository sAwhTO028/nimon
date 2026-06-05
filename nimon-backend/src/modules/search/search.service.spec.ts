import { BadRequestException } from '@nestjs/common';

import type { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import { SearchService } from './search.service';

function mkMedia(
  base = 'http://localhost:3000/uploads',
): MediaUrlCanonicalizerService {
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

function mkPublicWeb(web = 'http://localhost:3000'): PublicWebBaseUrlService {
  const b = web.replace(/\/+$/, '') || 'http://localhost:3000';
  return {
    baseUrl: () => b,
    monoShareUrl: (id: string) => `${b}/mono/${id.trim()}`,
  } as unknown as PublicWebBaseUrlService;
}

const catalogLocaleWhere = (
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

function mkSearchPrisma(
  prefs?: { contentLocale: string; learningLanguage: string } | null,
) {
  const findMany = jest.fn().mockResolvedValue([]);
  const count = jest.fn().mockResolvedValue(0);
  const prisma = {
    publishedMono: { findMany, count },
    userPreference: {
      findUnique: jest.fn().mockResolvedValue(prefs ?? null),
    },
    monoReaction: {
      groupBy: jest.fn().mockResolvedValue([]),
      findMany: jest.fn().mockResolvedValue([]),
    },
    monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
  } as any;
  return { prisma, findMany, count };
}

function findKeywordBlock(and: unknown[]): Record<string, unknown> | undefined {
  return and.find((x) => {
    if (typeof x !== 'object' || x === null || !('AND' in (x as object))) {
      return false;
    }
    const inner = (x as { AND: unknown[] }).AND;
    return inner.some((clause) => {
      if (typeof clause !== 'object' || clause === null || !('OR' in clause)) {
        return false;
      }
      const or = (clause as { OR: unknown[] }).OR;
      return or.some((o) => typeof o === 'object' && o !== null && 'title' in o);
    });
  }) as Record<string, unknown> | undefined;
}

function sampleRow(
  id: string,
  ownerId: string,
  opts: Partial<{
    title: string;
    description: string;
    level: string;
    category: string;
    updatedMs: number;
    profile: { displayName: string | null; handle: string | null; avatarUrl: string | null } | null;
  }> = {},
) {
  const updatedAt = new Date(opts.updatedMs ?? Date.UTC(2026, 0, 1, 0, 0, 0));
  return {
    id,
    ownerId,
    title: opts.title ?? 'T',
    category: opts.category ?? '',
    level: opts.level ?? '',
    description: opts.description ?? '',
    createdAt: updatedAt,
    updatedAt,
    content: {},
    owner: {
      profile: opts.profile ?? {
        displayName: 'Writer',
        handle: 'writer',
        avatarUrl: null,
      },
    },
  };
}

describe('SearchService.searchPublishedMonos (M18A)', () => {
  it('empty q uses catalog visibility + guest locale lens (no keyword AND)', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});

    expect(findMany).toHaveBeenCalledTimes(1);
    const where = findMany.mock.calls[0][0].where;
    expect(where).toEqual({
      AND: [PUBLISHED_MONO_CATALOG_VISIBLE, catalogLocaleWhere('en', 'ja')],
    });
  });

  it('q matches title case-insensitively in Prisma where', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'Hello' });

    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(findKeywordBlock(where.AND)).toEqual({
      AND: [
        {
          OR: expect.arrayContaining([
            { title: { contains: 'Hello', mode: 'insensitive' } },
            { description: { contains: 'Hello', mode: 'insensitive' } },
            {
              owner: {
                profile: {
                  OR: [
                    { displayName: { contains: 'Hello', mode: 'insensitive' } },
                    { handle: { contains: 'Hello', mode: 'insensitive' } },
                  ],
                },
              },
            },
          ]),
        },
      ],
    });
  });

  it('q matches description in OR clause', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'Tokyo' });
    const kw = findKeywordBlock(
      (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND,
    )!;
    const or = (kw.AND as any[])[0].OR;
    expect(or).toEqual(
      expect.arrayContaining([{ description: { contains: 'Tokyo', mode: 'insensitive' } }]),
    );
  });

  it('q matches creator display name and handle in profile OR', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'alice' });
    const kw = findKeywordBlock(
      (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND,
    )!;
    const profileOr = (kw.AND as any[])[0].OR[2].owner.profile.OR;
    expect(profileOr).toEqual([
      { displayName: { contains: 'alice', mode: 'insensitive' } },
      { handle: { contains: 'alice', mode: 'insensitive' } },
    ]);
  });

  it('level filter adds exact level predicate', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ level: 'N3' });
    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(where.AND).toContainEqual({ level: 'N3' });
  });

  it('category filter adds exact category predicate', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      category: 'Horror',
    });
    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(where.AND).toContainEqual({ category: 'Horror' });
  });

  it('q + level + category combine with AND', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'x',
      level: 'N5',
      category: 'Cat',
    });
    const and = (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND;
    expect(and).toContainEqual({ level: 'N5' });
    expect(and).toContainEqual({ category: 'Cat' });
    expect(findKeywordBlock(and)).toBeDefined();
  });

  it('where includes trashedAt null (catalog)', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'z' });
    const and = (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND;
    expect(and[0]).toMatchObject({ trashedAt: null });
  });

  it('where includes NOT drafts with unpublished core changes', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});
    const and = (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND;
    expect(and[0].NOT).toEqual(PUBLISHED_MONO_CATALOG_VISIBLE.NOT);
  });

  it('limit=20 with 21 rows returns 20 items, hasMore, nextCursor, totalCount 35', async () => {
    const rows: ReturnType<typeof sampleRow>[] = [];
    for (let i = 0; i < 21; i++) {
      const hex = (0x100000000000 + i).toString(16).padStart(12, '0');
      rows.push(
        sampleRow(`20000000-0000-4000-8000-${hex}`, 'cccccccc-cccc-cccc-cccc-cccccccccccc', {
          updatedMs: Date.UTC(2026, 1, 1, 0, 0, i),
        }),
      );
    }
    const { prisma, findMany } = mkSearchPrisma();
    findMany.mockResolvedValue(rows);
    prisma.publishedMono.count = jest.fn().mockResolvedValue(35);

    const out = await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      limitRaw: '20',
    });

    expect(out.items).toHaveLength(20);
    expect(out.hasMore).toBe(true);
    expect(out.nextCursor).toBeTruthy();
    expect(out.totalCount).toBe(35);
    expect(findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 21 }));
  });

  it('page 2 with cursor returns next slice and totalCount null', async () => {
    const r0 = sampleRow('30000000-0000-4000-8000-000000000001', 'u', {
      updatedMs: Date.UTC(2026, 2, 1, 0, 0, 2),
    });
    const r1 = sampleRow('30000000-0000-4000-8000-000000000002', 'u', {
      updatedMs: Date.UTC(2026, 2, 1, 0, 0, 1),
    });
    const page1 = Array.from({ length: 21 }, (_, i) =>
      sampleRow(`30000000-0000-4000-8000-${(0x300 + i).toString(16)}`, 'u', {
        updatedMs: Date.UTC(2026, 2, 1, 0, 0, 100 - i),
      }),
    );
    const { prisma, findMany } = mkSearchPrisma();
    findMany.mockResolvedValueOnce(page1).mockResolvedValueOnce([r0, r1]);
    prisma.publishedMono.count = jest.fn().mockResolvedValue(22);
    const svc = new SearchService(prisma, mkMedia(), mkPublicWeb());

    const first = await svc.searchPublishedMonos({ limitRaw: '20' });
    const second = await svc.searchPublishedMonos({
      limitRaw: '20',
      cursor: first.nextCursor!,
    });

    expect(first.items).toHaveLength(20);
    expect(second.items.map((x) => x.id)).toEqual([r0.id, r1.id]);
    expect(second.hasMore).toBe(false);
    expect(second.totalCount).toBeNull();
    const all = [...first.items.map((x) => x.id), ...second.items.map((x) => x.id)];
    expect(new Set(all).size).toBe(all.length);
  });

  it('invalid cursor throws before findMany', async () => {
    const { prisma } = mkSearchPrisma();
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ cursor: '%%%' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.publishedMono.findMany).not.toHaveBeenCalled();
  });

  it('multi-token q adds AND of per-token clauses', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'foo bar' });
    const kw = findKeywordBlock(
      (findMany.mock.calls[0][0].where as { AND: any[] }).AND,
    )!;
    expect(kw.AND).toHaveLength(2);
    expect(kw.AND[0].OR).toEqual(
      expect.arrayContaining([{ title: { contains: 'foo', mode: 'insensitive' } }]),
    );
    expect(kw.AND[1].OR).toEqual(
      expect.arrayContaining([{ title: { contains: 'bar', mode: 'insensitive' } }]),
    );
  });

  it('invalid level throws BadRequestException', async () => {
    const { prisma } = mkSearchPrisma();
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ level: 'N0' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.publishedMono.findMany).not.toHaveBeenCalled();
  });

  it('unsupported sort throws BadRequestException', async () => {
    const { prisma } = mkSearchPrisma();
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ sort: 'popular' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('optional viewer loads bookmarks and reactions for page ids', async () => {
    const row = sampleRow('40000000-0000-4000-8000-000000000099', 'u', {});
    const { prisma, findMany } = mkSearchPrisma();
    findMany.mockResolvedValue([row]);
    prisma.publishedMono.count = jest.fn().mockResolvedValue(1);
    prisma.monoBookmark.findMany = jest
      .fn()
      .mockResolvedValue([{ publishedMonoId: row.id }]);
    prisma.monoReaction.findMany = jest
      .fn()
      .mockResolvedValue([{ publishedMonoId: row.id }]);
    prisma.monoReaction.groupBy = jest
      .fn()
      .mockResolvedValue([{ publishedMonoId: row.id, _count: { _all: 3 } }]);

    const out = await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      viewerUserId: 'viewer-uuid-0000-0000-0000-000000000001',
    });

    expect(prisma.monoBookmark.findMany).toHaveBeenCalled();
    expect(prisma.monoReaction.findMany).toHaveBeenCalled();
    expect(out.items[0]!.isBookmarkedByMe).toBe(true);
    expect(out.items[0]!.myReaction).toBe('heart');
    expect(out.items[0]!.likesCount).toBe(3);
  });

  it('maps shareUrl on items', async () => {
    const row = sampleRow('50000000-0000-4000-8000-000000000088', 'u', {});
    const { prisma, findMany } = mkSearchPrisma();
    findMany.mockResolvedValue([row]);
    prisma.publishedMono.count = jest.fn().mockResolvedValue(1);

    const out = await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});
    expect(out.items[0]!.shareUrl).toBe(`http://localhost:3000/mono/${row.id}`);
  });
});

describe('SearchService.searchPublishedMonos (M23A-6D-1 feed lens)', () => {
  it('en+my viewer search uses my+en lens only', async () => {
    const { prisma, findMany } = mkSearchPrisma({
      contentLocale: 'my',
      learningLanguage: 'en',
    });
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'match',
      viewerUserId: 'u-en-my',
    });
    const and = findMany.mock.calls[0][0].where.AND as unknown[];
    expect(and).toEqual(expect.arrayContaining([catalogLocaleWhere('my', 'en')]));
    expect(and).not.toEqual(expect.arrayContaining([catalogLocaleWhere('my', 'ja')]));
  });

  it('ja+my viewer search uses my+ja lens only', async () => {
    const { prisma, findMany } = mkSearchPrisma({
      contentLocale: 'my',
      learningLanguage: 'ja',
    });
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'match',
      viewerUserId: 'u-ja-my',
    });
    const and = findMany.mock.calls[0][0].where.AND as unknown[];
    expect(and).toEqual(expect.arrayContaining([catalogLocaleWhere('my', 'ja')]));
    expect(and).not.toEqual(expect.arrayContaining([catalogLocaleWhere('my', 'en')]));
  });

  it('guest default search lens is en+ja (ja learning, en content)', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'match',
      viewerUserId: null,
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([catalogLocaleWhere('en', 'ja')]),
        },
      }),
    );
    const and = findMany.mock.calls[0][0].where.AND as unknown[];
    expect(and).not.toEqual(expect.arrayContaining([catalogLocaleWhere('my', 'en')]));
  });

  it('query override learningLanguage=en contentLocale=my applies my+en lens', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'match',
      learningLanguage: 'en',
      contentLocale: 'my',
      viewerUserId: null,
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          AND: expect.arrayContaining([catalogLocaleWhere('my', 'en')]),
        },
      }),
    );
  });

  it('invalid query learningLanguage=ko throws learningLanguage_invalid', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
        learningLanguage: 'ko',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(findMany).not.toHaveBeenCalled();
  });

  it('legacy null contentLocale and learningLanguage included via OR-null lens', async () => {
    const { prisma, findMany } = mkSearchPrisma();
    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'legacy',
      viewerUserId: null,
    });
    const localeWhere = findMany.mock.calls[0][0].where.AND[1];
    expect(localeWhere).toEqual(catalogLocaleWhere('en', 'ja'));
    expect(localeWhere.AND[0].OR).toEqual(
      expect.arrayContaining([{ contentLocale: 'en' }, { contentLocale: null }]),
    );
    expect(localeWhere.AND[1].OR).toEqual(
      expect.arrayContaining([{ learningLanguage: 'ja' }, { learningLanguage: null }]),
    );
  });
});
