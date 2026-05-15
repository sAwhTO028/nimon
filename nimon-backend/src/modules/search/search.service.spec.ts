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
  it('empty q uses catalog visibility only (no keyword AND)', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});

    expect(findMany).toHaveBeenCalledTimes(1);
    const where = findMany.mock.calls[0][0].where;
    expect(where).toEqual(PUBLISHED_MONO_CATALOG_VISIBLE);
  });

  it('q matches title case-insensitively in Prisma where', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'Hello' });

    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(where.AND).toHaveLength(2);
    expect(where.AND[1]).toEqual({
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
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'Tokyo' });
    const or = (findMany.mock.calls[0][0].where as { AND: any[] }).AND[1].AND[0].OR;
    expect(or).toEqual(
      expect.arrayContaining([{ description: { contains: 'Tokyo', mode: 'insensitive' } }]),
    );
  });

  it('q matches creator display name and handle in profile OR', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'alice' });
    const profileOr = (findMany.mock.calls[0][0].where as { AND: any[] }).AND[1].AND[0].OR[2].owner.profile
      .OR;
    expect(profileOr).toEqual([
      { displayName: { contains: 'alice', mode: 'insensitive' } },
      { handle: { contains: 'alice', mode: 'insensitive' } },
    ]);
  });

  it('level filter adds exact level predicate', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ level: 'N3' });
    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(where.AND).toContainEqual({ level: 'N3' });
  });

  it('category filter adds exact category predicate', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ category: 'Horror' });
    const where = findMany.mock.calls[0][0].where as { AND: unknown[] };
    expect(where.AND).toContainEqual({ category: 'Horror' });
  });

  it('q + level + category combine with AND', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      q: 'x',
      level: 'N5',
      category: 'Cat',
    });
    const and = (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND;
    expect(and).toContainEqual({ level: 'N5' });
    expect(and).toContainEqual({ category: 'Cat' });
    expect(and.some((x) => typeof x === 'object' && x !== null && 'AND' in (x as object))).toBe(true);
  });

  it('where includes trashedAt null (catalog)', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'z' });
    const and = (findMany.mock.calls[0][0].where as { AND: unknown[] }).AND;
    expect(and[0]).toMatchObject({ trashedAt: null });
  });

  it('where includes NOT drafts with unpublished core changes', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});
    const w = findMany.mock.calls[0][0].where as { NOT?: unknown };
    expect(w.NOT).toEqual(PUBLISHED_MONO_CATALOG_VISIBLE.NOT);
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
    const findMany = jest.fn().mockResolvedValue(rows);
    const count = jest.fn().mockResolvedValue(35);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

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
    const r0 = sampleRow('30000000-0000-4000-8000-000000000001', 'u', { updatedMs: Date.UTC(2026, 2, 1, 0, 0, 2) });
    const r1 = sampleRow('30000000-0000-4000-8000-000000000002', 'u', { updatedMs: Date.UTC(2026, 2, 1, 0, 0, 1) });
    const page1 = Array.from({ length: 21 }, (_, i) =>
      sampleRow(`30000000-0000-4000-8000-${(0x300 + i).toString(16)}`, 'u', {
        updatedMs: Date.UTC(2026, 2, 1, 0, 0, 100 - i),
      }),
    );
    const findMany = jest.fn().mockResolvedValueOnce(page1).mockResolvedValueOnce([r0, r1]);
    const count = jest.fn().mockResolvedValue(22);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;
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
    const prisma = {
      publishedMono: { findMany: jest.fn(), count: jest.fn() },
      monoReaction: { groupBy: jest.fn(), findMany: jest.fn() },
      monoBookmark: { findMany: jest.fn() },
    } as any;
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ cursor: '%%%' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.publishedMono.findMany).not.toHaveBeenCalled();
  });

  it('multi-token q adds AND of per-token clauses', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ q: 'foo bar' });
    const kw = (findMany.mock.calls[0][0].where as { AND: any[] }).AND[1];
    expect(kw.AND).toHaveLength(2);
    expect(kw.AND[0].OR).toEqual(
      expect.arrayContaining([{ title: { contains: 'foo', mode: 'insensitive' } }]),
    );
    expect(kw.AND[1].OR).toEqual(
      expect.arrayContaining([{ title: { contains: 'bar', mode: 'insensitive' } }]),
    );
  });

  it('invalid level throws BadRequestException', async () => {
    const prisma = {
      publishedMono: { findMany: jest.fn(), count: jest.fn() },
      monoReaction: { groupBy: jest.fn(), findMany: jest.fn() },
      monoBookmark: { findMany: jest.fn() },
    } as any;
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ level: 'N0' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.publishedMono.findMany).not.toHaveBeenCalled();
  });

  it('unsupported sort throws BadRequestException', async () => {
    const prisma = {
      publishedMono: { findMany: jest.fn(), count: jest.fn() },
      monoReaction: { groupBy: jest.fn(), findMany: jest.fn() },
      monoBookmark: { findMany: jest.fn() },
    } as any;
    await expect(
      new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({ sort: 'popular' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('optional viewer loads bookmarks and reactions for page ids', async () => {
    const row = sampleRow('40000000-0000-4000-8000-000000000099', 'u', {});
    const findMany = jest.fn().mockResolvedValue([row]);
    const count = jest.fn().mockResolvedValue(1);
    const bookmarkFind = jest.fn().mockResolvedValue([{ publishedMonoId: row.id }]);
    const reactionFind = jest.fn().mockResolvedValue([{ publishedMonoId: row.id }]);
    const prisma = {
      publishedMono: { findMany, count },
      monoReaction: {
        groupBy: jest.fn().mockResolvedValue([{ publishedMonoId: row.id, _count: { _all: 3 } }]),
        findMany: reactionFind,
      },
      monoBookmark: { findMany: bookmarkFind },
    } as any;

    const out = await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({
      viewerUserId: 'viewer-uuid-0000-0000-0000-000000000001',
    });

    expect(bookmarkFind).toHaveBeenCalled();
    expect(reactionFind).toHaveBeenCalled();
    expect(out.items[0]!.isBookmarkedByMe).toBe(true);
    expect(out.items[0]!.myReaction).toBe('heart');
    expect(out.items[0]!.likesCount).toBe(3);
  });

  it('maps shareUrl on items', async () => {
    const row = sampleRow('50000000-0000-4000-8000-000000000088', 'u', {});
    const prisma = {
      publishedMono: { findMany: jest.fn().mockResolvedValue([row]), count: jest.fn().mockResolvedValue(1) },
      monoReaction: { groupBy: jest.fn().mockResolvedValue([]), findMany: jest.fn().mockResolvedValue([]) },
      monoBookmark: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;

    const out = await new SearchService(prisma, mkMedia(), mkPublicWeb()).searchPublishedMonos({});
    expect(out.items[0]!.shareUrl).toBe(`http://localhost:3000/mono/${row.id}`);
  });
});
