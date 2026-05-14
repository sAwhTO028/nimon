import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Logger,
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
  private readonly logger = new Logger(PublishedMonosController.name);

  constructor(private readonly published: PublishedMonosService) {}

  @Get()
  @Header('Content-Type', 'application/json')
  async list(
    @Query('limit') limit: string | undefined,
    @Query('cursor') cursor: string | undefined,
    @Query('sort') sort: string | undefined,
    @Query('trashed') trashed: string | undefined,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    // M17C-5 TEMP: controller saw the request before service (remove after diagnosis).
    this.logger.log(
      `[M17C-5] route=GET /v1/published-monos PublishedMonosController.list hit ` +
        `userId=${user.userId} limit=${String(limit ?? '')} cursor=${String(cursor ?? '')} ` +
        `sort=${String(sort ?? '')} trashed=${String(trashed ?? '')}`,
    );
    const out = await this.published.listPublishedMonos(
      user.userId,
      limit,
      trashed,
      cursor,
      sort,
    );
    this.logger.log(
      `[M17C-5] route=GET /v1/published-monos PublishedMonosController.list out ` +
        `responseKeys=${Object.keys(out).sort().join(',')}`,
    );
    return out;
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
