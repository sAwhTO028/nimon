import { Controller, Get, Header, Query, Req, UseGuards } from '@nestjs/common';

import { OptionalJwtUserGuard } from '../auth/optional-jwt-user.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { SearchService } from './search.service';

/**
 * Public published-mono search (M18A). Optional JWT enriches bookmark/reaction fields.
 */
@Controller('v1/search')
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @Get('monos')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async searchMonos(
    @Query('q') q?: string,
    @Query('level') level?: string,
    @Query('category') category?: string,
    @Query('sort') sort?: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    return await this.search.searchPublishedMonos({
      q,
      level,
      category,
      sort,
      limitRaw: limit,
      cursor,
      viewerUserId: req?.user?.userId ?? null,
    });
  }
}
