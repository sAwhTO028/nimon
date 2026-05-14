import { NotFoundException } from '@nestjs/common';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { UsersService } from './users.service';

function mkMedia(): MediaUrlCanonicalizerService {
  const base = 'http://localhost:3000/uploads';
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

describe('UsersService public profile', () => {
  const targetUserId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const viewerUserId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  const mk = () => {
    const prisma = {
      user: { findUnique: jest.fn() },
      userFollow: {
        count: jest.fn(),
        findUnique: jest.fn(),
      },
    } as any;
    return { prisma, svc: new UsersService(prisma, mkMedia()) };
  };

  it('guest profile returns counts and isFollowingByMe false', async () => {
    const { prisma, svc } = mk();
    prisma.user.findUnique.mockResolvedValue({
      id: targetUserId,
      profile: {
        handle: '@h',
        displayName: 'D',
        avatarUrl: 'a',
        coverImageUrl: 'c',
        bio: 'b',
      },
    });
    prisma.userFollow.count.mockResolvedValueOnce(3).mockResolvedValueOnce(2);

    const out = await svc.getPublicCreatorProfile({
      targetUserId,
      viewerUserId: null,
    });
    expect(out.userId).toBe(targetUserId);
    expect(out.coverImageUrl).toBe('c');
    expect(out.followersCount).toBe(3);
    expect(out.followingCount).toBe(2);
    expect(out.isFollowingByMe).toBe(false);
  });

  it('authed follower returns isFollowingByMe true', async () => {
    const { prisma, svc } = mk();
    prisma.user.findUnique.mockResolvedValue({ id: targetUserId, profile: null });
    prisma.userFollow.count.mockResolvedValueOnce(0).mockResolvedValueOnce(0);
    prisma.userFollow.findUnique.mockResolvedValue({ followerId: viewerUserId });

    const out = await svc.getPublicCreatorProfile({
      targetUserId,
      viewerUserId,
    });
    expect(out.isFollowingByMe).toBe(true);
  });

  it('self profile returns isFollowingByMe false', async () => {
    const { prisma, svc } = mk();
    prisma.user.findUnique.mockResolvedValue({ id: targetUserId, profile: null });
    prisma.userFollow.count.mockResolvedValueOnce(0).mockResolvedValueOnce(0);

    const out = await svc.getPublicCreatorProfile({
      targetUserId,
      viewerUserId: targetUserId,
    });
    expect(out.isFollowingByMe).toBe(false);
    expect(prisma.userFollow.findUnique).not.toHaveBeenCalled();
  });

  it('missing user -> 404 user_not_found', async () => {
    const { prisma, svc } = mk();
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(
      svc.getPublicCreatorProfile({
        targetUserId,
        viewerUserId: null,
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

