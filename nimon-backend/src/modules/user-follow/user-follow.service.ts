import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type {
  FollowStateDto,
  MeFollowingListResponseDto,
  UserFollowersListResponseDto,
} from './user-follow.dto';

type CursorPayload = { c: string; i: string };

@Injectable()
export class UserFollowService {
  constructor(private readonly prisma: PrismaService) {}

  private encodeCursor(createdAt: Date, followingId: string): string {
    const payload: CursorPayload = { c: createdAt.toISOString(), i: followingId };
    return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  }

  private decodeCursor(raw: string): CursorPayload {
    let json: string;
    try {
      json = Buffer.from(raw, 'base64url').toString('utf8');
    } catch {
      throw new BadRequestException('invalid_cursor');
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(json);
    } catch {
      throw new BadRequestException('invalid_cursor');
    }
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      !('c' in parsed) ||
      !('i' in parsed)
    ) {
      throw new BadRequestException('invalid_cursor');
    }
    const c = (parsed as CursorPayload).c;
    const i = (parsed as CursorPayload).i;
    if (typeof c !== 'string' || typeof i !== 'string' || !c.trim() || !i.trim()) {
      throw new BadRequestException('invalid_cursor');
    }
    const d = new Date(c);
    if (Number.isNaN(d.getTime())) throw new BadRequestException('invalid_cursor');
    return { c, i };
  }

  private async ensureUserExists(userId: string): Promise<void> {
    const found = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!found) throw new NotFoundException('user_not_found');
  }

  private async countsFor(userId: string): Promise<{
    followersCount: number;
    followingCount: number;
  }> {
    const [followersCount, followingCount] = await Promise.all([
      this.prisma.userFollow.count({ where: { followingId: userId } }),
      this.prisma.userFollow.count({ where: { followerId: userId } }),
    ]);
    return { followersCount, followingCount };
  }

  async follow(
    meUserId: string,
    targetUserId: string,
  ): Promise<FollowStateDto> {
    const tid = targetUserId.trim();
    if (!tid) throw new NotFoundException('user_not_found');
    if (tid === meUserId) {
      throw new BadRequestException('cannot_follow_self');
    }
    await this.ensureUserExists(tid);

    await this.prisma.userFollow.upsert({
      where: { followerId_followingId: { followerId: meUserId, followingId: tid } },
      update: {},
      create: { followerId: meUserId, followingId: tid },
    });

    const { followersCount, followingCount } = await this.countsFor(tid);
    return {
      userId: tid,
      isFollowing: true,
      followersCount,
      followingCount,
    };
  }

  async unfollow(
    meUserId: string,
    targetUserId: string,
  ): Promise<FollowStateDto> {
    const tid = targetUserId.trim();
    if (!tid) throw new NotFoundException('user_not_found');
    if (tid === meUserId) {
      throw new BadRequestException('cannot_follow_self');
    }
    await this.ensureUserExists(tid);

    await this.prisma.userFollow.deleteMany({
      where: { followerId: meUserId, followingId: tid },
    });

    const { followersCount, followingCount } = await this.countsFor(tid);
    return {
      userId: tid,
      isFollowing: false,
      followersCount,
      followingCount,
    };
  }

  async listMeFollowing(opts: {
    meUserId: string;
    limit: number;
    cursor?: string;
  }): Promise<MeFollowingListResponseDto> {
    const limit = Math.min(Math.max(Math.floor(opts.limit || 15), 1), 30);
    const take = limit + 1;

    const and: import('@prisma/client').Prisma.UserFollowWhereInput[] = [
      { followerId: opts.meUserId },
    ];
    if (opts.cursor) {
      const { c, i } = this.decodeCursor(opts.cursor);
      const cAt = new Date(c);
      and.push({
        OR: [
          { createdAt: { lt: cAt } },
          { AND: [{ createdAt: cAt }, { followingId: { lt: i } }] },
        ],
      });
    }

    const rows = await this.prisma.userFollow.findMany({
      where: { AND: and },
      orderBy: [{ createdAt: 'desc' }, { followingId: 'desc' }],
      take,
      select: {
        createdAt: true,
        followingId: true,
        following: {
          select: {
            id: true,
            profile: { select: { handle: true, displayName: true, avatarUrl: true } },
          },
        },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page[page.length - 1];
    const nextCursor =
      hasMore && last ? this.encodeCursor(last.createdAt, last.followingId) : null;

    return {
      items: page.map((r) => ({
        userId: r.followingId,
        handle: r.following.profile?.handle ?? null,
        displayName: r.following.profile?.displayName ?? null,
        avatarUrl: r.following.profile?.avatarUrl ?? null,
        followedAt: r.createdAt.toISOString(),
      })),
      nextCursor,
      hasMore,
    };
  }

  async followedUserIds(meUserId: string): Promise<string[]> {
    const rows = await this.prisma.userFollow.findMany({
      where: { followerId: meUserId },
      select: { followingId: true },
    });
    return rows.map((r) => r.followingId);
  }

  /**
   * Public list: users who follow `targetUserId` (cursor uses followerId tie-break,
   * same encoding as [listMeFollowing]).
   */
  async listFollowersOfUser(opts: {
    targetUserId: string;
    limit: number;
    cursor?: string;
  }): Promise<UserFollowersListResponseDto> {
    const tid = opts.targetUserId.trim();
    if (!tid) throw new NotFoundException('user_not_found');
    await this.ensureUserExists(tid);

    const limit = Math.min(Math.max(Math.floor(opts.limit || 15), 1), 30);
    const take = limit + 1;

    const and: import('@prisma/client').Prisma.UserFollowWhereInput[] = [
      { followingId: tid },
    ];
    if (opts.cursor) {
      const { c, i } = this.decodeCursor(opts.cursor);
      const cAt = new Date(c);
      and.push({
        OR: [
          { createdAt: { lt: cAt } },
          { AND: [{ createdAt: cAt }, { followerId: { lt: i } }] },
        ],
      });
    }

    const rows = await this.prisma.userFollow.findMany({
      where: { AND: and },
      orderBy: [{ createdAt: 'desc' }, { followerId: 'desc' }],
      take,
      select: {
        createdAt: true,
        followerId: true,
        follower: {
          select: {
            id: true,
            profile: { select: { handle: true, displayName: true, avatarUrl: true } },
          },
        },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page[page.length - 1];
    const nextCursor =
      hasMore && last ? this.encodeCursor(last.createdAt, last.followerId) : null;

    return {
      items: page.map((r) => ({
        userId: r.followerId,
        handle: r.follower.profile?.handle ?? null,
        displayName: r.follower.profile?.displayName ?? null,
        avatarUrl: r.follower.profile?.avatarUrl ?? null,
        followedAt: r.createdAt.toISOString(),
      })),
      nextCursor,
      hasMore,
    };
  }
}

