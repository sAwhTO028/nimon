import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtOrDevOwnerFallbackGuard } from '../auth/jwt-or-dev-owner-fallback.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { PublishedMonosService } from './published-monos.service';
import type { PublishedMonoPermanentDeleteRequestDto } from './published-monos.dto';

/**
 * Owner-published surfaces: Bearer JWT maps to Prisma user (or dev owner fallback when enabled).
 * Matches story-drafts / published-monos GET policy (`JwtOrDevOwnerFallbackGuard`).
 */
@UseGuards(JwtOrDevOwnerFallbackGuard)
@Controller('v1/published-monos')
export class PublishedMonosController {
  constructor(private readonly published: PublishedMonosService) {}

  @Get()
  @Header('Content-Type', 'application/json')
  async list(
    @Query('limit') limit: string | undefined,
    @Query('trashed') trashed: string | undefined,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    return await this.published.listPublishedMonos(user.userId, limit, trashed);
  }

  /** Move to Trash (P1 soft-delete); idempotent. */
  @Post(':id/trash')
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'application/json')
  async trash(
    @Param('id') id: string,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    return await this.published.trashPublishedMono(user.userId, id);
  }

  /** Restore from Trash. **400 published_mono_not_trashed** when row was never trashed. */
  @Post(':id/restore')
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'application/json')
  async restore(
    @Param('id') id: string,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    return await this.published.restorePublishedMono(user.userId, id);
  }

  /** Permanent delete for trashed rows only (P3). */
  @Delete(':id/permanent')
  @HttpCode(HttpStatus.NO_CONTENT)
  async permanentDelete(
    @Param('id') id: string,
    @Body() body: PublishedMonoPermanentDeleteRequestDto,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    await this.published.permanentlyDeletePublishedMono(
      user.userId,
      id,
      body?.confirm,
    );
  }

  @Get(':id')
  @Header('Content-Type', 'application/json')
  async getOne(
    @Param('id') id: string,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    return await this.published.getPublishedMonoById(user.userId, id);
  }
}
