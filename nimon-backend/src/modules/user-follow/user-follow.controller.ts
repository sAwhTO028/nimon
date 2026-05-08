import { Controller, Delete, Get, Header, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { UserFollowService } from './user-follow.service';

@Controller('v1')
export class UserFollowController {
  constructor(private readonly follows: UserFollowService) {}

  @Post('users/:userId/follow')
  @Header('Content-Type', 'application/json')
  @UseGuards(JwtAuthGuard)
  async follow(
    @Param('userId') userId: string,
    @Req() req: { user: JwtValidatedUser },
  ) {
    return await this.follows.follow(req.user.userId, userId);
  }

  @Delete('users/:userId/follow')
  @Header('Content-Type', 'application/json')
  @UseGuards(JwtAuthGuard)
  async unfollow(
    @Param('userId') userId: string,
    @Req() req: { user: JwtValidatedUser },
  ) {
    return await this.follows.unfollow(req.user.userId, userId);
  }

  @Get('me/following')
  @Header('Content-Type', 'application/json')
  @UseGuards(JwtAuthGuard)
  async listMeFollowing(
    @Query('limit') limitStr: string | undefined,
    @Query('cursor') cursor: string | undefined,
    @Req() req: { user: JwtValidatedUser },
  ) {
    const limit = Number.isFinite(Number(limitStr)) ? Math.floor(Number(limitStr)) : 15;
    return await this.follows.listMeFollowing({
      meUserId: req.user.userId,
      limit,
      cursor: cursor?.trim() || undefined,
    });
  }

  /** Public: followers of a user (same item shape as GET /v1/me/following). */
  @Get('users/:userId/followers')
  @Header('Content-Type', 'application/json')
  async listFollowers(
    @Param('userId') userId: string,
    @Query('limit') limitStr: string | undefined,
    @Query('cursor') cursor: string | undefined,
  ) {
    const limit = Number.isFinite(Number(limitStr)) ? Math.floor(Number(limitStr)) : 15;
    return await this.follows.listFollowersOfUser({
      targetUserId: userId,
      limit,
      cursor: cursor?.trim() || undefined,
    });
  }
}

