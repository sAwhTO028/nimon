import { BadRequestException, Controller, Get, Header, Param, Query, Req, UseGuards, UnauthorizedException } from '@nestjs/common';

import { MonoFeedService } from './mono-feed.service';
import { OptionalJwtUserGuard } from '../auth/optional-jwt-user.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';

/**
 * Public Mono catalog — no JWT. Owner-scoped published list remains on `PublishedMonosController`.
 */
@Controller('v1/mono')
export class MonoFeedController {
  constructor(private readonly feed: MonoFeedService) {}

  @Get('feed')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async listFeed(
    @Query('limit') limitStr?: string,
    @Query('cursor') cursor?: string,
    @Query('sort') sort?: string,
    @Query('level') level?: string,
    @Query('category') category?: string,
    @Query('writerId') writerId?: string,
    @Query('contentLocale') contentLocale?: string,
    @Query('learningLanguage') learningLanguage?: string,
    @Query('following') following?: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    const followingOn = (following ?? '').trim().toLowerCase() === 'true';
    const writerIdOn = (writerId ?? '').trim();
    if (followingOn && writerIdOn) {
      throw new BadRequestException('invalid_feed_filter_combo');
    }
    if (followingOn && !req?.user?.userId) {
      throw new UnauthorizedException();
    }
    const limit = this.feed.parseLimit(limitStr);
    return await this.feed.listFeed({
      limit,
      cursor: cursor?.trim() || undefined,
      sort: sort?.trim(),
      level: level?.trim(),
      category: category?.trim(),
      writerId: writerIdOn || undefined,
      contentLocale: contentLocale?.trim(),
      learningLanguage: learningLanguage?.trim(),
      userId: req?.user?.userId ?? null,
      followingOnly: followingOn,
    });
  }

  @Get(':monoId')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async getOne(
    @Param('monoId') monoId: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    return await this.feed.getPublicMonoById(monoId, req?.user?.userId ?? null);
  }
}
