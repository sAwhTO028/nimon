import { BadRequestException, HttpStatus, NotFoundException } from '@nestjs/common';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import type { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';
import { PublishedMonosService } from './published-monos.service';

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

/** `publishedMono.count` matching {@link countPublishedTabVisibleMonos} (owner Published tab). */
function mockPublishedMonoCountPublishedTabVisible(
  total: number,
  opts?: { totalAllRows?: number; activeNonTrashed?: number },
) {
  return jest.fn((call: { where: Record<string, unknown> }) => {
    const w = call.where as Record<string, unknown> & { id?: string };
    const keysExOwner = Object.keys(w).filter((k) => k !== 'ownerId');
    if (w.ownerId != null && keysExOwner.length === 0) {
      return Promise.resolve(opts?.totalAllRows ?? total);
    }
    if (
      w.ownerId != null &&
      w.trashedAt === null &&
      !w.NOT &&
      w.id === undefined &&
      keysExOwner.length === 1 &&
      keysExOwner[0] === 'trashedAt'
    ) {
      return Promise.resolve(opts?.activeNonTrashed ?? total);
    }
    if (w.NOT != null && typeof w.id === 'string') {
      return Promise.resolve(0);
    }
    if (w.NOT != null) {
      return Promise.resolve(total);
    }
    if (
      w.trashedAt &&
      typeof w.trashedAt === 'object' &&
      (w.trashedAt as { not?: unknown }).not === null
    ) {
      return Promise.resolve(0);
    }
    return Promise.resolve(0);
  });
}

describe('PublishedMonosService owner scoping', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  it('listPublishedMonos scopes by ownerId and excludes dirty-linked published rows', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      publishedMono: {
        findMany,
        count: jest.fn().mockResolvedValue(0),
      },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(ownerId, '20');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
        take: 21,
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      }),
    );
  });

  it('getPublishedMonoById throws NotFound when row not owned', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst } } as any;

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).getPublishedMonoById(
        ownerId,
        'mono-missing',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('getPublishedMonoById applies catalog visibility (404 when draft has unpublished edits)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst } } as any;

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).getPublishedMonoById(ownerId, monoId),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: monoId,
          ownerId,
          ...PUBLISHED_MONO_CATALOG_VISIBLE,
        },
      }),
    );
  });

  it('listPublishedMonos stamps writer fields from owner UserProfile', async () => {
    const row = {
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      content: {},
    };
    const findMany = jest.fn().mockResolvedValue([row]);
    const findUnique = jest.fn().mockResolvedValue({
      displayName: 'Owner Name',
      handle: 'own_h',
      avatarUrl: 'https://avatars.test/o.png',
    });
    const prisma = {
      publishedMono: { findMany, count: jest.fn().mockResolvedValue(1) },
      userProfile: { findUnique },
    } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(ownerId);

    expect(out.items).toHaveLength(1);
    expect(out.hasMore).toBe(false);
    expect(out.nextCursor).toBeNull();
    expect(out.totalCount).toBe(1);
    expect(findUnique).toHaveBeenCalledWith({
      where: { userId: ownerId },
      select: { displayName: true, handle: true, avatarUrl: true },
    });
    expect(out.items[0]?.writerDisplayName).toBe('Owner Name');
    expect(out.items[0]?.writerHandle).toBe('own_h');
    expect(out.items[0]?.writerAvatarUrl).toBe('https://avatars.test/o.png');
  });

  it('listPublishedMonos canonicalizes localhost coverImageUrl to MEDIA_PUBLIC_BASE_URL', async () => {
    const row = {
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      content: {
        core: {
          coverImageUrl: 'http://localhost:3000/uploads/u/c.webp',
        },
      },
    };
    const findMany = jest.fn().mockResolvedValue([row]);
    const findUnique = jest.fn().mockResolvedValue({
      displayName: 'Owner Name',
      handle: 'own_h',
      avatarUrl: 'http://127.0.0.1:3000/uploads/a.webp',
    });
    const prisma = {
      publishedMono: { findMany, count: jest.fn().mockResolvedValue(1) },
      userProfile: { findUnique },
    } as any;

    const out = await new PublishedMonosService(
      prisma,
      mkMedia('http://192.168.11.5:3000/uploads'),
      mkPublicWeb('http://192.168.11.5:3000'),
    ).listPublishedMonos(ownerId);

    expect(out.items[0]?.coverImageUrl).toBe(
      'http://192.168.11.5:3000/uploads/u/c.webp',
    );
    expect(out.items[0]?.writerAvatarUrl).toBe(
      'http://192.168.11.5:3000/uploads/a.webp',
    );
    expect(out.items[0]?.shareUrl).toBe(
      `http://192.168.11.5:3000/mono/${monoId}`,
    );
  });

  it('getPublishedMonoById attaches writer identity', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: new Date(),
      updatedAt: new Date(),
      content: { publishKind: 'read_only_v1' },
    });
    const findUnique = jest.fn().mockResolvedValue({
      displayName: 'Me',
      handle: 'me_h',
      avatarUrl: 'https://avatars.test/me.png',
    });
    const prisma = {
      publishedMono: { findFirst },
      userProfile: { findUnique },
      monoReaction: {
        count: jest.fn().mockResolvedValue(7),
        findFirst: jest.fn().mockResolvedValue({ kind: 'heart' }),
      },
      monoBookmark: { count: jest.fn().mockResolvedValue(1) },
    } as any;

    const d = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).getPublishedMonoById(ownerId, monoId);

    expect(d.writerDisplayName).toBe('Me');
    expect(d.writerHandle).toBe('me_h');
    expect(d.writerAvatarUrl).toBe('https://avatars.test/me.png');
    expect(d.shareUrl).toBe(`http://localhost:3000/mono/${monoId}`);
    expect(d.likesCount).toBe(7);
    expect(d.isBookmarkedByMe).toBe(true);
    expect(d.myReaction).toBe('heart');
  });

  it('listPublishedMonos with trashed=true queries trashedAt not null only', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      publishedMono: { findMany },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(ownerId, '20', 'true');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId, trashedAt: { not: null } },
        take: 21,
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      }),
    );
  });
});

describe('PublishedMonosService trash / restore', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const t0 = new Date('2026-04-01T12:00:00.000Z');

  it('trash sets trashedAt when active', async () => {
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({ id: monoId, trashedAt: null })
      .mockResolvedValueOnce({ trashedAt: t0 });
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = { publishedMono: { findFirst, updateMany } } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).trashPublishedMono(ownerId, monoId);

    expect(out.id).toBe(monoId);
    expect(out.trashedAt).toBe(t0.toISOString());
    expect(updateMany).toHaveBeenCalledWith({
      where: { id: monoId, ownerId, trashedAt: null },
      data: { trashedAt: expect.any(Date) },
    });
  });

  it('trash is idempotent when already trashed', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 });
    const updateMany = jest.fn();
    const prisma = { publishedMono: { findFirst, updateMany } } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).trashPublishedMono(ownerId, monoId);

    expect(out).toEqual({ id: monoId, trashedAt: t0.toISOString() });
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('trash 404 when not owner', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst, updateMany: jest.fn() } } as any;

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).trashPublishedMono(ownerId, monoId),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('restore clears trashedAt', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 });
    const count = mockPublishedMonoCountPublishedTabVisible(5);
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      publishedMono: { findFirst, updateMany, count },
    } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).restorePublishedMono(ownerId, monoId);

    expect(out).toEqual({ id: monoId, trashedAt: null });
    expect(updateMany).toHaveBeenCalledWith({
      where: { id: monoId, ownerId },
      data: { trashedAt: null },
    });
  });

  it('restore 400 when mono was never trashed', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: null });
    const prisma = { publishedMono: { findFirst, updateMany: jest.fn(), count: jest.fn() } } as any;

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).restorePublishedMono(ownerId, monoId),
    ).rejects.toMatchObject({ status: 400 });
  });
});

describe('PublishedMonosService permanent delete', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const t0 = new Date('2026-04-01T12:00:00.000Z');

  function prismaWithTx(impl: (tx: any) => Promise<void>) {
    return {
      $transaction: jest.fn().mockImplementation(impl),
    } as any;
  }

  it('requires confirm body', async () => {
    const prisma = prismaWithTx(async () => {});
    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'NOPE',
      ),
    ).rejects.toMatchObject({ status: HttpStatus.BAD_REQUEST });
  });

  it('404 when missing/not owner', async () => {
    const tx = {
      publishedMono: { findFirst: jest.fn().mockResolvedValue(null) },
      storyDraft: { deleteMany: jest.fn() },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'DELETE',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('400 when row is not trashed', async () => {
    const tx = {
      publishedMono: {
        findFirst: jest.fn().mockResolvedValue({ id: monoId, trashedAt: null }),
        deleteMany: jest.fn(),
      },
      storyDraft: { deleteMany: jest.fn() },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'DELETE',
      ),
    ).rejects.toMatchObject({ status: HttpStatus.BAD_REQUEST });
    expect(tx.storyDraft.deleteMany).not.toHaveBeenCalled();
    expect(tx.publishedMono.deleteMany).not.toHaveBeenCalled();
  });

  it('deletes linked drafts then deletes mono (trashed only)', async () => {
    const tx = {
      publishedMono: {
        findFirst: jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 }),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      storyDraft: { deleteMany: jest.fn().mockResolvedValue({ count: 2 }) },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).permanentlyDeletePublishedMono(
      ownerId,
      monoId,
      'DELETE',
    );

    expect(tx.storyDraft.deleteMany).toHaveBeenCalledWith({
      where: { ownerId, publishedMonoId: monoId },
    });
    expect(tx.publishedMono.deleteMany).toHaveBeenCalledWith({
      where: { ownerId, id: monoId },
    });
  });
});

describe('PublishedMonosService list cursor pagination (M17C)', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  function row(i: number, updatedMs: number) {
    const hex = (0x100000000000 + i).toString(16).padStart(12, '0');
    return {
      id: `10000000-0000-4000-8000-${hex}`,
      ownerId,
      title: `T${i}`,
      category: '',
      level: '',
      description: '',
      createdAt: new Date(updatedMs),
      updatedAt: new Date(updatedMs),
      content: {},
    };
  }

  it('first page returns 20 items with hasMore and nextCursor when 21 exist', async () => {
    const rows: ReturnType<typeof row>[] = [];
    for (let i = 20; i >= 0; i--) {
      rows.push(row(i, Date.UTC(2026, 0, 30, 0, 0, i)));
    }
    const findMany = jest.fn().mockResolvedValue(rows);
    const count = jest.fn().mockResolvedValue(21);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(
      ownerId,
      '20',
    );

    expect(out.items).toHaveLength(20);
    expect(out.hasMore).toBe(true);
    expect(out.nextCursor).toBeTruthy();
    expect(out.totalCount).toBe(21);
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        take: 21,
        orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      }),
    );
  });

  it('second page returns remaining item(s) and hasMore false', async () => {
    const page1: ReturnType<typeof row>[] = [];
    for (let i = 20; i >= 0; i--) {
      page1.push(row(i, Date.UTC(2026, 0, 30, 0, 0, i)));
    }
    const page2 = [row(0, Date.UTC(2026, 0, 30, 0, 0, 0))];
    const findMany = jest.fn().mockResolvedValueOnce(page1).mockResolvedValueOnce(page2);
    const count = jest.fn().mockResolvedValue(21);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;
    const svc = new PublishedMonosService(prisma, mkMedia(), mkPublicWeb());

    const first = await svc.listPublishedMonos(ownerId, '20');
    const second = await svc.listPublishedMonos(ownerId, '20', undefined, first.nextCursor!);

    expect(first.items.map((x) => x.id)).toEqual(page1.slice(0, 20).map((r) => r.id));
    expect(second.items).toHaveLength(1);
    expect(second.items[0]!.id).toBe(page2[0]!.id);
    expect(second.hasMore).toBe(false);
    expect(second.nextCursor).toBeNull();
    expect(second.totalCount).toBeNull();
    const allIds = [...first.items.map((x) => x.id), ...second.items.map((x) => x.id)];
    expect(new Set(allIds).size).toBe(allIds.length);
  });

  it('totalCount only on first page (count called once)', async () => {
    const page1: ReturnType<typeof row>[] = [];
    for (let i = 20; i >= 0; i--) {
      page1.push(row(i, Date.UTC(2026, 0, 30, 0, 0, i)));
    }
    const findMany = jest.fn().mockResolvedValueOnce(page1).mockResolvedValueOnce([]);
    const count = jest.fn().mockResolvedValue(21);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;
    const svc = new PublishedMonosService(prisma, mkMedia(), mkPublicWeb());
    const first = await svc.listPublishedMonos(ownerId, '20');
    await svc.listPublishedMonos(ownerId, '20', undefined, first.nextCursor!);
    expect(count).toHaveBeenCalledTimes(1);
  });

  it('rejects invalid cursor', async () => {
    const prisma = {
      publishedMono: { findMany: jest.fn(), count: jest.fn() },
      userProfile: { findUnique: jest.fn() },
    } as any;
    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(
        ownerId,
        '20',
        undefined,
        '%%%not-base64%%%',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.publishedMono.findMany).not.toHaveBeenCalled();
  });

  it('rejects unsupported sort', async () => {
    const prisma = {
      publishedMono: { findMany: jest.fn(), count: jest.fn() },
      userProfile: { findUnique: jest.fn() },
    } as any;
    await expect(
      new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(
        ownerId,
        '20',
        undefined,
        undefined,
        'oldest',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('no-cursor request uses default limit 20 (take 21)', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const count = jest.fn().mockResolvedValue(0);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;
    await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(ownerId);
    expect(findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 21 }));
  });
});

describe('PublishedMonosService list cursor pagination (M17C-2 limit 10)', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  function row(i: number, updatedMs: number) {
    const hex = (0x100000000000 + i).toString(16).padStart(12, '0');
    return {
      id: `10000000-0000-4000-8000-${hex}`,
      ownerId,
      title: `T${i}`,
      category: '',
      level: '',
      description: '',
      createdAt: new Date(updatedMs),
      updatedAt: new Date(updatedMs),
      content: {},
    };
  }

  it('21 rows with limit 10: three pages, no duplicates, hasMore false on last', async () => {
    const all: ReturnType<typeof row>[] = [];
    for (let i = 20; i >= 0; i--) {
      all.push(row(i, Date.UTC(2026, 0, 30, 0, 0, i)));
    }
    const page1 = all.slice(0, 11);
    const page2 = all.slice(10, 21);
    const page3 = [all[20]!];
    const findMany = jest
      .fn()
      .mockResolvedValueOnce(page1)
      .mockResolvedValueOnce(page2)
      .mockResolvedValueOnce(page3);
    const count = jest.fn().mockResolvedValue(21);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;
    const svc = new PublishedMonosService(prisma, mkMedia(), mkPublicWeb());

    const first = await svc.listPublishedMonos(ownerId, '10');
    expect(first.items).toHaveLength(10);
    expect(first.hasMore).toBe(true);
    expect(first.nextCursor).toBeTruthy();
    expect(first.totalCount).toBe(21);
    expect(findMany).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({ take: 11 }),
    );

    const second = await svc.listPublishedMonos(ownerId, '10', undefined, first.nextCursor!);
    expect(second.items).toHaveLength(10);
    expect(second.hasMore).toBe(true);
    expect(second.nextCursor).toBeTruthy();
    expect(second.totalCount).toBeNull();

    const third = await svc.listPublishedMonos(ownerId, '10', undefined, second.nextCursor!);
    expect(third.items).toHaveLength(1);
    expect(third.hasMore).toBe(false);
    expect(third.nextCursor).toBeNull();
    expect(third.totalCount).toBeNull();

    const allIds = [...first.items, ...second.items, ...third.items].map((x) => x.id);
    expect(new Set(allIds).size).toBe(21);
    expect(count).toHaveBeenCalledTimes(1);
  });

  it('first-page list serializes pagination keys for wire clients', async () => {
    const all: ReturnType<typeof row>[] = [];
    for (let i = 20; i >= 0; i--) {
      all.push(row(i, Date.UTC(2026, 0, 30, 0, 0, i)));
    }
    const page1 = all.slice(0, 11);
    const findMany = jest.fn().mockResolvedValueOnce(page1);
    const count = jest.fn().mockResolvedValue(21);
    const prisma = {
      publishedMono: { findMany, count },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;
    const svc = new PublishedMonosService(prisma, mkMedia(), mkPublicWeb());
    const first = await svc.listPublishedMonos(ownerId, '10');
    const json = JSON.parse(JSON.stringify(first)) as Record<string, unknown>;
    expect(json).toMatchObject({
      hasMore: true,
      totalCount: 21,
    });
    expect(typeof json.nextCursor).toBe('string');
    expect((json.nextCursor as string).length).toBeGreaterThan(0);
    expect(Array.isArray(json.items)).toBe(true);
  });
});

describe('PublishedMonosService M17E-6 restore quota (Published tab visible count)', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  it('blocks restore when Published tab visible count is already 30', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: monoId,
      trashedAt: new Date(),
    });
    const count = mockPublishedMonoCountPublishedTabVisible(30, {
      totalAllRows: 30,
      activeNonTrashed: 30,
    });
    const updateMany = jest.fn();
    const prisma = {
      publishedMono: { findFirst, count, updateMany },
    } as any;

    try {
      await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).restorePublishedMono(ownerId, monoId);
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toEqual({
        code: 'quota_exceeded',
        key: FREE_TIER_QUOTA_KEYS.publishedMonos,
        limit: FREE_TIER_QUOTAS.publishedMonos,
        current: 30,
      });
    }
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('allows restore when Published tab visible count is 29', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: monoId,
      trashedAt: new Date(),
    });
    const count = mockPublishedMonoCountPublishedTabVisible(29);
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      publishedMono: { findFirst, count, updateMany },
    } as any;

    await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).restorePublishedMono(ownerId, monoId);
    expect(count).toHaveBeenCalled();
    expect(updateMany).toHaveBeenCalled();
  });
});
