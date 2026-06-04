import {
  Controller,
  Get,
  Header,
  Param,
  Query,
  Req,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';

import { OptionalJwtUserGuard } from '../auth/optional-jwt-user.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';

import { CreatorCollectionsService } from './creator-collections.service';

@Controller()
export class PublicCreatorCollectionsController {
  constructor(private readonly collections: CreatorCollectionsService) {}

  @Get('v1/users/:userId/creator-collections')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async listPublic(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('contentLocale') contentLocale?: string,
    @Query('learningLanguage') learningLanguage?: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    return await this.collections.listPublicForUser(userId, {
      viewerUserId: req?.user?.userId ?? null,
      contentLocaleQuery: contentLocale,
      learningLanguageQuery: learningLanguage,
    });
  }

  @Get('v1/users/:userId/creator-collections/:collectionId/monos')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async listCollectionMonos(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('collectionId', ParseUUIDPipe) collectionId: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('contentLocale') contentLocale?: string,
    @Query('learningLanguage') learningLanguage?: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    return await this.collections.listPublicCollectionMonos(
      userId,
      collectionId,
      limit,
      cursor,
      {
        viewerUserId: req?.user?.userId ?? null,
        contentLocaleQuery: contentLocale,
        learningLanguageQuery: learningLanguage,
      },
    );
  }
}
