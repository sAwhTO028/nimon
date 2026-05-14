import { Injectable, NotFoundException } from '@nestjs/common';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import type { PublicCreatorProfileResponseDto } from './users.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
  ) {}

  async getPublicCreatorProfile(opts: {
    targetUserId: string;
    viewerUserId: string | null;
  }): Promise<PublicCreatorProfileResponseDto> {
    const tid = opts.targetUserId.trim();
    if (!tid) throw new NotFoundException('user_not_found');

    const user = await this.prisma.user.findUnique({
      where: { id: tid },
      select: {
        id: true,
        profile: {
          select: {
            handle: true,
            displayName: true,
            avatarUrl: true,
            coverImageUrl: true,
            bio: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('user_not_found');

    const [followersCount, followingCount] = await Promise.all([
      this.prisma.userFollow.count({ where: { followingId: tid } }),
      this.prisma.userFollow.count({ where: { followerId: tid } }),
    ]);

    const vid = opts.viewerUserId;
    const isFollowingByMe =
      !vid || vid === tid
        ? false
        : (await this.prisma.userFollow.findUnique({
            where: { followerId_followingId: { followerId: vid, followingId: tid } },
            select: { followerId: true },
          })) != null;

    return {
      userId: user.id,
      handle: user.profile?.handle ?? null,
      displayName: user.profile?.displayName ?? null,
      avatarUrl: this.media.url(user.profile?.avatarUrl ?? null),
      coverImageUrl: this.media.url((user.profile as any)?.coverImageUrl ?? null),
      bio: user.profile?.bio ?? null,
      followersCount,
      followingCount,
      isFollowingByMe,
    };
  }
}

