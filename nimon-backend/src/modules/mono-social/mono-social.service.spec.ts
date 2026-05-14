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
});

