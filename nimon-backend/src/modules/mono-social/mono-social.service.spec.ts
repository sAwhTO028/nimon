import { NotFoundException } from '@nestjs/common';
import { MonoSocialService } from './mono-social.service';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';

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
      },
      monoReaction: {
        upsert: jest.fn(),
        deleteMany: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
        groupBy: jest.fn().mockResolvedValue([]),
        findMany: jest.fn().mockResolvedValue([]),
      },
    } as any;
    return { prisma, svc: new MonoSocialService(prisma) };
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
    await svc.bookmark(userId, monoId);
    expect(prisma.monoBookmark.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId_publishedMonoId: { userId, publishedMonoId: monoId } },
      }),
    );
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

