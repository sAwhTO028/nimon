import { Controller, Delete, Get, Header, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { MonoSocialService } from './mono-social.service';

@Controller()
export class MonoSocialController {
  constructor(private readonly social: MonoSocialService) {}

  @Post('v1/mono/:monoId/bookmark')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async bookmark(
    @Param('monoId') monoId: string,
    @Req() req: { user: JwtValidatedUser },
  ) {
    return await this.social.bookmark(req.user.userId, monoId);
  }

  @Delete('v1/mono/:monoId/bookmark')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async unbookmark(
    @Param('monoId') monoId: string,
    @Req() req: { user: JwtValidatedUser },
  ) {
    return await this.social.unbookmark(req.user.userId, monoId);
  }

  @Post('v1/mono/:monoId/react')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async react(@Param('monoId') monoId: string, @Req() req: { user: JwtValidatedUser }) {
    return await this.social.reactHeart(req.user.userId, monoId);
  }

  @Delete('v1/mono/:monoId/react')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async unreact(@Param('monoId') monoId: string, @Req() req: { user: JwtValidatedUser }) {
    return await this.social.unreact(req.user.userId, monoId);
  }

  @Get('v1/me/bookmarks')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async listMyBookmarks(
    @Req() req: { user: JwtValidatedUser },
    @Query('limit') limitRaw?: string,
    @Query('cursor') cursor?: string,
  ) {
    const limitNum = limitRaw ? Number(limitRaw) : 15;
    const limit = Number.isFinite(limitNum) ? Math.floor(limitNum) : 15;
    return await this.social.listMyBookmarks({
      userId: req.user.userId,
      limit,
      cursor: cursor?.trim() || undefined,
    });
  }
}

