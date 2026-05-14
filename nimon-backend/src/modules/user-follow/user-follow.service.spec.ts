import { BadRequestException, NotFoundException } from '@nestjs/common';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { UserFollowService } from './user-follow.service';

function mkMedia(): MediaUrlCanonicalizerService {
  const base = 'http://localhost:3000/uploads';
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

describe('UserFollowService', () => {
  const prisma = {
    user: { findUnique: jest.fn() },
    userFollow: {
      upsert: jest.fn(),
      deleteMany: jest.fn(),
      count: jest.fn(),
      findMany: jest.fn(),
    },
  };

  let svc: UserFollowService;

  beforeEach(async () => {
    jest.resetAllMocks();
    svc = new UserFollowService(prisma as any, mkMedia());
  });

  it('follow: creates (idempotent upsert) and returns counts', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u2' });
    prisma.userFollow.upsert.mockResolvedValue({});
    prisma.userFollow.count.mockResolvedValueOnce(10).mockResolvedValueOnce(3);

    await expect(svc.follow('u1', 'u2')).resolves.toEqual({
      userId: 'u2',
      isFollowing: true,
      followersCount: 10,
      followingCount: 3,
    });
  });

  it('unfollow: deleteMany idempotent and returns counts', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u2' });
    prisma.userFollow.deleteMany.mockResolvedValue({ count: 0 });
    prisma.userFollow.count.mockResolvedValueOnce(2).mockResolvedValueOnce(9);

    await expect(svc.unfollow('u1', 'u2')).resolves.toEqual({
      userId: 'u2',
      isFollowing: false,
      followersCount: 2,
      followingCount: 9,
    });
  });

  it('follow: cannot follow self', async () => {
    await expect(svc.follow('u1', 'u1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('follow: target missing -> 404', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(svc.follow('u1', 'u2')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('listMeFollowing: returns page + nextCursor', async () => {
    const d1 = new Date('2026-01-02T03:04:05.000Z');
    const d2 = new Date('2026-01-01T03:04:05.000Z');
    prisma.userFollow.findMany.mockResolvedValue([
      {
        createdAt: d1,
        followingId: 'b',
        following: { id: 'b', profile: { handle: 'hb', displayName: 'DB', avatarUrl: 'ab' } },
      },
      {
        createdAt: d2,
        followingId: 'a',
        following: { id: 'a', profile: { handle: 'ha', displayName: 'DA', avatarUrl: 'aa' } },
      },
    ]);

    const res = await svc.listMeFollowing({ meUserId: 'me', limit: 1 });
    expect(res.items).toHaveLength(1);
    expect(res.hasMore).toBe(true);
    expect(res.nextCursor).toEqual(expect.any(String));
  });

  it('listFollowersOfUser: target missing -> 404', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(svc.listFollowersOfUser({ targetUserId: 'x', limit: 15 })).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('listFollowersOfUser: returns followers page + nextCursor', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'target' });
    const d1 = new Date('2026-01-02T03:04:05.000Z');
    const d2 = new Date('2026-01-01T03:04:05.000Z');
    prisma.userFollow.findMany.mockResolvedValue([
      {
        createdAt: d1,
        followerId: 'f-b',
        follower: {
          id: 'f-b',
          profile: { handle: 'hb', displayName: 'DB', avatarUrl: 'ab' },
        },
      },
      {
        createdAt: d2,
        followerId: 'f-a',
        follower: {
          id: 'f-a',
          profile: { handle: 'ha', displayName: 'DA', avatarUrl: 'aa' },
        },
      },
    ]);

    const res = await svc.listFollowersOfUser({ targetUserId: 'target', limit: 1 });
    expect(prisma.userFollow.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        orderBy: [{ createdAt: 'desc' }, { followerId: 'desc' }],
      }),
    );
    expect(res.items).toHaveLength(1);
    expect(res.items[0].userId).toBe('f-b');
    expect(res.items[0].followedAt).toBe(d1.toISOString());
    expect(res.hasMore).toBe(true);
    expect(res.nextCursor).toEqual(expect.any(String));
  });

  it('listFollowersOfUser: empty followers list', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'target' });
    prisma.userFollow.findMany.mockResolvedValue([]);

    const res = await svc.listFollowersOfUser({ targetUserId: 'target', limit: 15 });
    expect(res.items).toHaveLength(0);
    expect(res.hasMore).toBe(false);
    expect(res.nextCursor).toBeNull();
  });
});

