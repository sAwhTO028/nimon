import { NotFoundException } from '@nestjs/common';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import type { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import { MonoSocialService } from './mono-social.service';

function mkMedia(): MediaUrlCanonicalizerService {
  const base = 'http://localhost:3000/uploads';
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

function mkPublicWeb(): PublicWebBaseUrlService {
  const b = 'http://localhost:3000';
  return {
    baseUrl: () => b,
    monoShareUrl: (id: string) => `${b}/mono/${id.trim()}`,
  } as unknown as PublicWebBaseUrlService;
}

describe('MonoSocialService', () => {
  const userId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const monoId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  const mk = () => {
    const prisma = {
      publishedMono: { findFirst: jest.fn() },
      monoBookmark: {
        upsert: jest.fn(),
        deleteMany: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn(),
      },
      monoReaction: {
        upsert: jest.fn(),
        deleteMany: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
        groupBy: jest.fn().mockResolvedValue([]),
        findMany: jest.fn().mockResolvedValue([]),
      },
    } as any;
    return { prisma, svc: new MonoSocialService(prisma, mkMedia(), mkPublicWeb()) };
  };

  it('bookmark 404 when mono not catalog-visible', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue(null);
    await expect(svc.bookmark(userId, monoId)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(prisma.publishedMono.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: monoId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
      }),
    );
  });

  it('bookmark POST is idempotent via upsert', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    prisma.monoBookmark.findUnique.mockResolvedValue({ publishedMonoId: monoId });
    await svc.bookmark(userId, monoId);
    expect(prisma.monoBookmark.count).not.toHaveBeenCalled();
    expect(prisma.monoBookmark.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId_publishedMonoId: { userId, publishedMonoId: monoId } },
      }),
    );
  });

  it('bookmark blocks new save when user already has 50 bookmarks', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    prisma.monoBookmark.findUnique.mockResolvedValue(null);
    prisma.monoBookmark.count.mockResolvedValue(50);
    await expect(svc.bookmark(userId, monoId)).rejects.toBeInstanceOf(QuotaExceededException);
    expect(prisma.monoBookmark.upsert).not.toHaveBeenCalled();
  });

  it('bookmark allows new save when user has 49 bookmarks', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    prisma.monoBookmark.findUnique.mockResolvedValue(null);
    prisma.monoBookmark.count.mockResolvedValue(49);
    await svc.bookmark(userId, monoId);
    expect(prisma.monoBookmark.upsert).toHaveBeenCalled();
  });

  it('bookmark DELETE is idempotent via deleteMany', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    await svc.unbookmark(userId, monoId);
    expect(prisma.monoBookmark.deleteMany).toHaveBeenCalledWith({
      where: { userId, publishedMonoId: monoId },
    });
  });

  it('react POST upserts heart and returns likesCount', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    prisma.monoReaction.count.mockResolvedValue(7);
    const out = await svc.reactHeart(userId, monoId);
    expect(prisma.monoReaction.upsert).toHaveBeenCalled();
    expect(out.likesCount).toBe(7);
    expect(out.myReaction).toBe('heart');
  });

  it('react DELETE removes and returns likesCount', async () => {
    const { prisma, svc } = mk();
    prisma.publishedMono.findFirst.mockResolvedValue({ id: monoId });
    prisma.monoReaction.count.mockResolvedValue(0);
    const out = await svc.unreact(userId, monoId);
    expect(prisma.monoReaction.deleteMany).toHaveBeenCalled();
    expect(out.myReaction).toBeNull();
  });

  it('listMyBookmarks returns paging envelope with totalCount (M17I)', async () => {
    const { prisma, svc } = mk();
    prisma.monoBookmark.count.mockResolvedValue(35);
    const mkRows = (n: number, timeOffset: number) =>
      Array.from({ length: n }, (_, j) => ({
        id: `00000000-0000-4000-8000-${String(40960 + j + timeOffset).padStart(12, '0')}`,
        createdAt: new Date(Date.UTC(2026, 0, 20, 12, 0, 0 - j - timeOffset)),
        publishedMono: {
          id: `11111111-1111-4111-8111-${String(81920 + j + timeOffset).padStart(12, '0')}`,
          ownerId: userId,
          title: `T${j}`,
          category: '',
          level: 'N5',
          description: 'd',
          createdAt: new Date(Date.UTC(2025, 5, 1)),
          updatedAt: new Date(Date.UTC(2025, 5, 2)),
          content: {},
          owner: { profile: { displayName: 'Writer', handle: 'w' } },
        },
      }));

    prisma.monoBookmark.findMany.mockResolvedValueOnce(mkRows(21, 0));
    const p1 = await svc.listMyBookmarks({ userId, limit: 20, cursor: undefined });
    expect(p1.items).toHaveLength(20);
    expect(p1.hasMore).toBe(true);
    expect(p1.nextCursor).toBeTruthy();
    expect(p1.totalCount).toBe(35);

    prisma.monoBookmark.findMany.mockResolvedValueOnce(mkRows(15, 100));
    const p2 = await svc.listMyBookmarks({
      userId,
      limit: 20,
      cursor: p1.nextCursor!,
    });
    expect(p2.items).toHaveLength(15);
    expect(p2.hasMore).toBe(false);
    expect(p2.nextCursor).toBeNull();
    expect(p2.totalCount).toBe(35);
    expect(prisma.monoBookmark.count).toHaveBeenCalled();
  });

  it('listMyBookmarks returns contentLocale and learningLanguage (M22F-1)', async () => {
    const { prisma, svc } = mk();
    prisma.monoBookmark.count.mockResolvedValue(1);
    prisma.monoBookmark.findMany.mockResolvedValue([
      {
        id: '00000000-0000-4000-8000-000000000099',
        createdAt: new Date(Date.UTC(2026, 0, 20)),
        publishedMono: {
          id: monoId,
          ownerId: userId,
          title: 'T',
          category: '',
          level: 'N5',
          description: '',
          createdAt: new Date(),
          updatedAt: new Date(),
          content: {},
          contentLocale: 'en',
          learningLanguage: 'ja',
          owner: { profile: { displayName: 'W', handle: 'w' } },
        },
      },
    ]);
    const out = await svc.listMyBookmarks({ userId, limit: 20 });
    expect(out.items[0]?.contentLocale).toBe('en');
    expect(out.items[0]?.learningLanguage).toBe('ja');
  });
});

